##############################################################################
# IBM Cloud Provider
##############################################################################

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  ibmcloud_timeout = 60
}

##############################################################################

##############################################################################
# Create Resource Groups
##############################################################################

resource "ibm_resource_group" "resource_group" {
  for_each = toset(var.vpc_names)
  name     = "${var.prefix}-${each.key}-rg"
}

##############################################################################

##############################################################################
# VPC Module
##############################################################################

module "icse_vpc_network" {
  source                         = "./vpc_module"
  region                         = var.region
  prefix                         = var.prefix
  tags                           = var.tags
  enable_transit_gateway         = var.enable_transit_gateway
  transit_gateway_connections    = var.transit_gateway_connections
  vpcs                           = local.config.vpcs
  transit_gateway_resource_group = local.management_rg
  key_management                 = local.config.key_management
  atracker                       = local.config.atracker
  cos                            = local.config.cos
  security_groups                = []
  keys = [
    {
      name     = "bucket-key"
      root_key = true
    }
  ]
}

##############################################################################

##############################################################################
# Detailed Network ACL Configuration
##############################################################################

locals {
  all_network_acl_list = flatten([
    # For each VPC network
    for network in module.icse_vpc_network.vpc_networks :
    [
      # For each ACL in that network
      for network_acl in network.network_acls :
      # Create an object with existing data (name, id, first_rule_id) and and shortname
      merge(network_acl, {
        shortname = replace(network_acl.name, "/${var.prefix}-|-acl/", "")
      })
    ]
  ])
}

module "detailed_acl_rules" {
  source                           = "github.com/Cloud-Schematics/detailed-network-acl-rules/detailed_acl_rules_module"
  network_acls                     = local.all_network_acl_list
  network_cidr                     = "10.0.0.0/8"
  apply_new_rules_before_old_rules = var.apply_new_rules_before_old_rules
  deny_all_tcp_ports               = var.deny_all_tcp_ports
  deny_all_udp_ports               = var.deny_all_udp_ports
  get_detailed_acl_rules_from_json = var.get_detailed_acl_rules_from_json
  detailed_acl_rules               = var.detailed_acl_rules
  acl_rule_json                    = file("./acl-rules.json")
}

##############################################################################

##############################################################################
# Virtual Private Endpoints
##############################################################################

module "vpe_subnets" {
  source           = "./get_subnets"
  for_each         = module.icse_vpc_network.vpc_networks
  subnet_zone_list = each.value.subnet_zone_list
  regex            = "-vpe-"
}

module "virtual_private_endpoints" {
  source            = "github.com/Cloud-Schematics/vpe-module"
  for_each          = toset(var.enable_virtual_private_endpoints == true ? var.vpcs_create_endpoint_gateway_on_vpe_tier : [])
  prefix            = var.prefix
  region            = var.region
  vpc_name          = each.key
  vpc_id            = module.icse_vpc_network.vpc_networks[each.key].id
  subnet_zone_list  = module.vpe_subnets[each.key].subnets
  resource_group_id = ibm_resource_group.resource_group[each.key].id
  service_endpoints = "private"
  cloud_services    = var.vpe_services
}

##############################################################################