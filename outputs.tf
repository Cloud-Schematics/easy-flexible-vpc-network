##############################################################################
# VPC Outputs
##############################################################################

output "vpc_networks" {
  description = "VPC network information"
  value       = module.icse_vpc_network.vpc_networks
}

output "vpc_flow_logs_data" {
  description = "Information for Connecting VPC to flow logs using ICSE Flow Logs Module"
  value       = module.icse_vpc_network.vpc_flow_logs_data
}

output "vpc_network_acls" {
  description = "List of network ACLs"
  value = flatten([
    for network in module.icse_vpc_network.vpc_networks :
    [
      for network_acl in network.network_acls:
      merge(network_acl, {
        shortname = replace(network_acl.name, "/${var.prefix}-|-acl/", "")
      })
    ]
  ])
}

##############################################################################

##############################################################################
# Key Management Outputs
##############################################################################

output "key_management_name" {
  description = "Name of key management service"
  value       = module.icse_vpc_network.key_management_name
}

output "key_management_crn" {
  description = "CRN for KMS instance"
  value       = module.icse_vpc_network.key_management_crn
}

output "key_management_guid" {
  description = "GUID for KMS instance"
  value       = module.icse_vpc_network.key_management_guid
}

output "key_rings" {
  description = "Key rings created by module"
  value       = module.icse_vpc_network.key_rings
}

output "keys" {
  description = "List of names and ids for keys created."
  value       = module.icse_vpc_network.keys
}

##############################################################################

##############################################################################
# Cloud Object Storage Variables
##############################################################################


output "cos_instances" {
  description = "List of COS resource instances with shortname, name, id, and crn."
  value       = module.icse_vpc_network.cos_instances
}

output "cos_buckets" {
  description = "List of COS bucket instances with shortname, instance_shortname, name, id, crn, and instance id."
  value       = module.icse_vpc_network.cos_buckets
}

##############################################################################