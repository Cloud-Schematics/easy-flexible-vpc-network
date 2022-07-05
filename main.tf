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