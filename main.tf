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
# Get Subnets, Public Gateways, and VPN Gateways
##############################################################################

module "subnet_config" {
  for_each                            = toset(var.vpc_names)
  source                              = "./config_modules/subnet_config"
  prefix                              = var.prefix
  vpc_name                            = each.key
  vpc_names                           = var.vpc_names
  zones                               = var.zones
  vpc_subnet_tiers                    = var.vpc_subnet_tiers
  vpc_subnet_tiers_add_public_gateway = var.vpc_subnet_tiers_add_public_gateway
  vpcs_add_vpn_subnet                 = var.vpcs_add_vpn_subnet
}

##############################################################################

##############################################################################
# Create Network ACLs
##############################################################################

module "network_acls" {
  for_each                   = toset(var.vpc_names)
  source                     = "./config_modules/acl_config"
  prefix                     = var.prefix
  vpc_name                   = each.key
  vpc_names                  = var.vpc_names
  vpc_subnet_tiers           = var.vpc_subnet_tiers
  add_cluster_rules          = var.add_cluster_rules
  global_inbound_allow_list  = var.global_inbound_allow_list
  global_outbound_allow_list = var.global_outbound_allow_list
  global_inbound_deny_list   = var.global_inbound_deny_list
  global_outbound_deny_list  = var.global_outbound_deny_list
  vpcs_add_vpn_subnet        = var.vpcs_add_vpn_subnet
}

##############################################################################

locals {
  ##############################################################################
  # VPC Config
  ##############################################################################
  vpcs = [
    for network in var.vpc_names :
    {
      prefix                       = network
      resource_group               = ibm_resource_group.resource_group[network].id
      default_security_group_rules = []
      address_prefixes = {
        zone-1 = []
        zone-2 = []
        zone-3 = []
      }
      subnets               = module.subnet_config[network].subnets
      use_public_gateways   = module.subnet_config[network].use_public_gateways
      vpn_gateway           = module.subnet_config[network].vpn_gateway
      network_acls          = module.network_acls[network].network_acls
      flow_logs_bucket_name = "${network}-flow-logs-bucket"
    }
  ]
  ##############################################################################

  # Shortcut for management resource group
  management_rg = ibm_resource_group.resource_group[var.vpc_names[0]].id

  ##############################################################################
  # Config
  ##############################################################################
  config = {
    vpcs = local.vpcs
    ##############################################################################
    # Key Management
    ##############################################################################
    key_management = {
      name                      = var.existing_hs_crypto_name == null ? "kms" : var.existing_hs_crypto_name
      use_hs_crypto             = var.existing_hs_crypto_name == null ? false : true
      use_data                  = var.existing_hs_crypto_name == null ? false : true
      resource_group_name       = var.existing_hs_crypto_resource_group == null ? local.management_rg : var.existing_hs_crypto_resource_group
      authorize_vpc_reader_role = true
    }
    ##############################################################################

    ##############################################################################
    # Atracker
    ##############################################################################
    atracker = {
      receive_global_events = true
      add_route             = var.add_atracker_route
      collector_bucket_name = "atracker-bucket"
    }
    enable_atracker = var.enable_atracker
    ##############################################################################

    ##############################################################################
    # Cloud Object Storage
    ##############################################################################
    cos = [
      {
        name                = "cos"
        resource_group_name = local.management_rg
        random_suffix       = var.cos_use_random_suffix
        plan                = "standard"
        use_data            = false
        buckets = [
          # Create a flow log bucket for each vpc and a bucket for atracker
          for network in concat(var.vpc_names, var.enable_atracker == true ? ["atracker"] : []) :
          {
            name          = network == "atracker" ? "atracker-bucket" : "${network}-flow-logs-bucket"
            endpoint_type = "public"
            force_delete  = true
            storage_class = "standard"
            kms_key       = "bucket-key"
          }
        ]
        keys = []
      }
    ]
    ##############################################################################
  }
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