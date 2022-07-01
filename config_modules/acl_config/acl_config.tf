##############################################################################
# ACL Variables
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
  description = "Names for VPCs to create. A resource group will be dynamically created for each VPC."
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

variable "vpc_subnet_tiers" {
  description = "List of names for subnet tiers to add to each VPC. For each tier, a subnet will be created in each zone of each VPC. Each tier of subnet will have a unique access control list on each VPC."
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

variable "vpcs_add_vpn_subnet" {
  description = "List of VPCs to add a subnet and VPN gateway. VPCs must be defined in `var.vpc_names`. A subnet and address prefix will be added in zone 1 for the VPN Gateway."
  type        = list(string)
  default     = ["management"]

  validation {
    error_message = "Each VPC to add a VPN gateway must have a unique name."
    condition     = length(var.vpcs_add_vpn_subnet) == length(distinct(var.vpcs_add_vpn_subnet))
  }
}

variable "add_cluster_rules" {
  description = "Automatically add needed ACL rules to allow each network to create and manage Openshift and IKS clusters."
  type        = bool
  default     = true
}

variable "global_inbound_allow_list" {
  description = "List of CIDR blocks where inbound traffic will be allowed. These allow rules will be added to each subnet."
  type        = list(string)
  default = [
    "10.0.0.0/8",   # Internal network traffic
    "161.26.0.0/16" # IBM Network traffic
  ]

  validation {
    error_message = "Global inbound allow list should contain no duplicate CIDR blocks."
    condition = length(var.global_inbound_allow_list) == 0 ? true : (
      length(var.global_inbound_allow_list) == length(distinct(var.global_inbound_allow_list))
    )
  }
}

variable "global_outbound_allow_list" {
  description = "List of CIDR blocks where outbound traffic will be allowed. These allow rules will be added to each subnet."
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]

  validation {
    error_message = "Global outbound allow list should contain no duplicate CIDR blocks."
    condition = length(var.global_outbound_allow_list) == 0 ? true : (
      length(var.global_outbound_allow_list) == length(distinct(var.global_outbound_allow_list))
    )
  }
}

variable "global_inbound_deny_list" {
  description = "List of CIDR blocks where inbound traffic will be denied. These deny rules will be added to each network acl. Deny rules will be added after all allow rules."
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]

  validation {
    error_message = "Global inbound allow list should contain no duplicate CIDR blocks."
    condition = length(var.global_inbound_deny_list) == 0 ? true : (
      length(var.global_inbound_deny_list) == length(distinct(var.global_inbound_deny_list))
    )
  }
}

variable "global_outbound_deny_list" {
  description = "List of CIDR blocks where outbound traffic will be denied. These deny rules will be added to each network acl. Deny rules will be added after all allow rules."
  type        = list(string)
  default     = []

  validation {
    error_message = "Global outbound allow list should contain no duplicate CIDR blocks."
    condition = length(var.global_outbound_deny_list) == 0 ? true : (
      length(var.global_outbound_deny_list) == length(distinct(var.global_outbound_deny_list))
    )
  }
}

##############################################################################

##############################################################################
# Create Network ACLs
##############################################################################

locals {
  network_acls = [
    # for each subnet tier in each VPC create a network ACL with allow rules
    # from `global_inbound_allow_list` and `global_outbound_allow_list`
    for tier in concat(var.vpc_subnet_tiers, contains(var.vpcs_add_vpn_subnet, var.vpc_name) ? ["vpn"] : []) :
    {
      name              = "${tier}-acl"
      add_cluster_rules = var.add_cluster_rules
      rules = flatten([
        [
          for cidr in var.global_inbound_allow_list :
          {
            name        = "${tier}-allow-inbound-${index(var.global_inbound_allow_list, cidr) + 1}"
            action      = "allow"
            source      = cidr
            destination = "10.0.0.0/8"
            direction   = "inbound"
          }
        ],
        [
          for cidr in var.global_outbound_allow_list :
          {
            name        = "${tier}-allow-outbound-${index(var.global_outbound_allow_list, cidr) + 1}"
            action      = "allow"
            destination = cidr
            source      = "10.0.0.0/8"
            direction   = "outbound"
          }
        ],
        [
          for cidr in var.global_inbound_deny_list :
          {
            name        = "${tier}-deny-inbound-${index(var.global_inbound_deny_list, cidr) + 1}"
            action      = "deny"
            source      = cidr
            destination = "10.0.0.0/8"
            direction   = "inbound"
          }
        ],
        [
          for cidr in var.global_outbound_deny_list :
          {
            name        = "${tier}-deny-outbound-${index(var.global_outbound_deny_list, cidr) + 1}"
            action      = "deny"
            destination = cidr
            source      = "10.0.0.0/8"
            direction   = "outbound"
          }
        ],
      ])
    }
  ]
}

##############################################################################

##############################################################################
# Outputs
##############################################################################

output "network_acls" {
  description = "Network access control list."
  value       = local.network_acls
}

##############################################################################