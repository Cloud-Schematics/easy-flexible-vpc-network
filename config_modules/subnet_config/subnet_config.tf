##############################################################################
# Variables
##############################################################################

variable "prefix" {
  description = "The prefix that you would like to prepend to your resources"
  type        = string
}

variable "vpc_name" {
  description = "Name of VPC"
  type        = string
}

variable "vpc_names" {
  description = "Names for VPCs to create."
  type        = list(string)
  default     = ["management", "workload"]

  validation {
    error_message = "VPCs must all have unique names."
    condition     = length(var.vpc_names) == length(distinct(var.vpc_names))
  }

  validation {
    error_message = "At least one VPC must be provisioned."
    condition     = length(var.vpc_names) > 0
  }
}

variable "zones" {
  description = "Number of zones for each VPC"
  type        = number
  default     = 3

  validation {
    error_message = "VPCs zones can only be 1, 2, or 3."
    condition     = var.zones > 0 && var.zones < 4
  }
}

variable "vpc_subnet_tiers" {
  description = "List of names for subnet tiers to add to each VPC. For each tier, a subnet will be created in each zone of each VPC."
  type        = list(string)
  default     = ["vsi", "vpe"]

  validation {
    error_message = "Each subnet tier must have a unique name."
    condition     = length(var.vpc_subnet_tiers) == length(distinct(var.vpc_subnet_tiers))
  }

  validation {
    error_message = "At least one subnet tier must be added to VPCs."
    condition     = length(var.vpc_subnet_tiers) > 0
  }

  validation {
    error_message = "The subnet tier name `vpn` is reserved. Please use a different name."
    condition     = !contains(var.vpc_subnet_tiers, "vpn")
  }
}

variable "vpc_subnet_tiers_add_public_gateway" {
  description = "List of subnet tiers where a public gateway will be attached. Public gateways will be created in each VPC using these network tiers."
  type        = list(string)
  default     = ["vpn"]

  validation {
    error_message = "Each subnet tier must have a unique name."
    condition     = length(var.vpc_subnet_tiers_add_public_gateway) == length(distinct(var.vpc_subnet_tiers_add_public_gateway))
  }
}

variable "vpcs_add_vpn_subnet" {
  description = "List of VPCs to add a subnet and VPN gateway. VPCs must be defined in `var.vpc_names`. A subnet and address prefix will be added in zone 1 for the VPN Gateway."
  type        = list(string)
  default     = ["management"]

  validation {
    error_message = "Each VPC to add a VPN gateway must have a unique name."
    condition     = length(var.vpcs_add_vpn_subnet) == length(distinct(var.vpcs_add_vpn_subnet))
  }
}

##############################################################################

##############################################################################
# Create Subnet Config
##############################################################################

locals {

  vpc_subnet_object = {
    for zone in [1, 2, 3] :
    "zone-${zone}" => (
      zone > var.zones # if zone is less than total number of zones
      ? []             # empty array
      : flatten([
        [
          # Create a list with a CIDR block for each subnet tier
          for tier in var.vpc_subnet_tiers :
          {
            name           = "${tier}-${zone}"
            acl_name       = "${tier}-acl"
            public_gateway = contains(var.vpc_subnet_tiers_add_public_gateway, tier)
            cidr = format(
              "10.%s0.%s0.0/24",
              (index(var.vpc_names, var.vpc_name) * 3) + zone, # VPC number 
              index(var.vpc_subnet_tiers, tier) + 1,           # Tier Number
            )
          }
        ],
        [
          for vpn_network in(var.vpcs_add_vpn_subnet == null ? [] : var.vpcs_add_vpn_subnet) :
          {
            name           = "vpn-1"
            acl_name       = "vpn-acl"
            public_gateway = contains(var.vpc_subnet_tiers_add_public_gateway, "vpn")
            cidr = format(
              "10.0.%s0.0/24",
              length(var.vpc_subnet_tiers) + 1, # Zone Number
            )
          } if zone == 1 && vpn_network == var.vpc_name
        ]
      ])
    )
  }

  use_public_gateways = {
    for zone in [1, 2, 3] :
    "zone-${zone}" => (
      zone == 1 && length(var.vpcs_add_vpn_subnet) > 0 && contains(var.vpcs_add_vpn_subnet, var.vpc_name)
      ? true
      : length(var.vpc_subnet_tiers_add_public_gateway) > 0 && zone > var.zones
    )
  }

  vpn_gateway = {
    use_vpn_gateway = var.vpcs_add_vpn_subnet == null ? false : contains(var.vpcs_add_vpn_subnet, var.vpc_name)
    name            = "vpn-gateway"
    subnet_name = (
      var.vpcs_add_vpn_subnet == null
      ? null
      : contains(var.vpcs_add_vpn_subnet, var.vpc_name)
      ? "vpn-1"
      : null
    )
  }

}

##############################################################################

##############################################################################
# Outputs
##############################################################################

output "subnets" {
  description = "Map of subnets by zone"
  value       = local.vpc_subnet_object
}

output "use_public_gateways" {
  description = "Map of needed public gateways by zone"
  value       = local.use_public_gateways
}

output "vpn_gateway" {
  description = "VPN gateway map"
  value       = local.vpn_gateway
}

##############################################################################