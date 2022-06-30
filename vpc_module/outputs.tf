##############################################################################
# VPC Outputs
##############################################################################

output "vpc_networks" {
  description = "VPC network information"
  value       = module.vpc.networks
}

output "vpc_flow_logs_data" {
  description = "Information for Connecting VPC to flow logs using ICSE Flow Logs Module"
  value       = module.vpc.vpc_flow_logs_data
}

output "security_groups" {
  description = "List of security group names and ids"
  value       = module.vpc.security_groups
}

##############################################################################

##############################################################################
# Key Management Outputs
##############################################################################

output "key_management_name" {
  description = "Name of key management service"
  value       = module.services.key_management_name
}

output "key_management_crn" {
  description = "CRN for KMS instance"
  value       = module.services.key_management_crn
}

output "key_management_guid" {
  description = "GUID for KMS instance"
  value       = module.services.key_management_guid
}

output "key_rings" {
  description = "Key rings created by module"
  value       = module.services.key_rings
}

output "keys" {
  description = "List of names and ids for keys created."
  value       = module.services.keys
}

##############################################################################

##############################################################################
# Cloud Object Storage Variables
##############################################################################


output "cos_instances" {
  description = "List of COS resource instances with shortname, name, id, and crn."
  value       = module.services.cos_instances
}

output "cos_buckets" {
  description = "List of COS bucket instances with shortname, instance_shortname, name, id, crn, and instance id."
  value       = module.services.cos_buckets
}

output "cos_keys" {
  description = "List of COS bucket instances with shortname, instance_shortname, name, id, crn, and instance id."
  value       = module.services.cos_keys
}

##############################################################################

##############################################################################
# Secrets Manager Outputs
##############################################################################

output "secrets_manager_name" {
  description = "Name of secrets manager instance"
  value       = module.services.secrets_manager_name
}

output "secrets_manager_id" {
  description = "id of secrets manager instance"
  value       = module.services.secrets_manager_id
}

output "secrets_manager_guid" {
  description = "guid of secrets manager instance"
  value       = module.services.secrets_manager_guid
}

##############################################################################

##############################################################################
# JSON Config
##############################################################################

output "json" {
  description = "JSON formatted environment configuration"
  value       = data.external.format_output.result
}

##############################################################################