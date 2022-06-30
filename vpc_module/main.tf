##############################################################################
# VPC Module
##############################################################################

module "vpc" {
  source                         = "github.com/Cloud-Schematics/icse-multiple-vpc-network"
  region                         = var.region
  prefix                         = var.prefix
  tags                           = var.tags
  vpcs                           = var.vpcs
  security_groups                = var.security_groups
  enable_transit_gateway         = var.enable_transit_gateway
  transit_gateway_resource_group = var.transit_gateway_resource_group
  transit_gateway_connections    = var.transit_gateway_connections
}

##############################################################################

##############################################################################
# Cloud Services Module
##############################################################################

module "services" {
  source                 = "github.com/Cloud-Schematics/icse-cloud-services"
  prefix                 = var.prefix
  region                 = var.region
  tags                   = var.tags
  service_endpoints      = var.service_endpoints
  disable_key_management = var.disable_key_management
  key_management         = var.key_management
  keys                   = var.keys
  cos_use_random_suffix  = var.cos_use_random_suffix
  cos                    = var.cos
  secrets_manager        = var.secrets_manager
  use_resource_group_ids = true
}

##############################################################################

##############################################################################
# Flow Logs
##############################################################################

module "flow_logs" {
  source             = "github.com/Cloud-Schematics/icse-flow-logs-module"
  prefix             = var.prefix
  cos_instances      = var.enable_flow_logs == true ? module.services.cos_instances : []
  cos_buckets        = var.enable_flow_logs == true ? module.services.cos_buckets : []
  vpc_flow_logs_data = var.enable_flow_logs == true ? module.vpc.vpc_flow_logs_data : []
}

##############################################################################

##############################################################################
# Atracker
##############################################################################

module "activity_tracker" {
  source          = "github.com/Cloud-Schematics/icse-atracker"
  region          = var.region
  prefix          = var.prefix
  tags            = var.tags
  enable_atracker = var.enable_atracker
  atracker        = var.atracker
  cos_buckets     = module.services.cos_buckets
}

##############################################################################

##############################################################################
# Create Environment Configuration
##############################################################################


locals {
  env = {
    region                         = var.region
    prefix                         = var.prefix
    tags                           = var.tags
    vpcs                           = var.vpcs
    security_groups                = var.security_groups
    enable_transit_gateway         = var.enable_transit_gateway
    transit_gateway_resource_group = var.transit_gateway_resource_group
    transit_gateway_connections    = var.transit_gateway_connections
    service_endpoints              = var.service_endpoints
    disable_key_management         = var.disable_key_management
    key_management                 = var.key_management
    keys                           = var.keys
    cos_use_random_suffix          = var.cos_use_random_suffix
    cos                            = var.cos
    secrets_manager                = var.secrets_manager
    enable_flow_logs               = var.enable_flow_logs
    enable_atracker                = var.enable_atracker
    atracker                       = var.atracker
  }
  string = "\"${jsonencode(local.env)}\""
}

data "external" "format_output" {
  program = ["python3", "${path.module}/scripts/output.py", local.string]
}


##############################################################################