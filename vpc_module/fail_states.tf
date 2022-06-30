##############################################################################
# Fail State Locals
##############################################################################

locals {
  all_bucket_names = flatten([
    for instance in var.cos :
    instance.buckets.*.name if length(instance.buckets) > 0
  ])
  flow_logs_bucket_names = [
    for network in var.vpcs :
    network.flow_logs_bucket_name if network.flow_logs_bucket_name != null
  ]
}

##############################################################################

##############################################################################
# Fail if Atracket COS Bucket Not Found
##############################################################################

locals {
  atracker_cos_bucket_not_found = (
    var.enable_atracker == true
    ? contains(local.all_bucket_names, var.atracker.collector_bucket_name)
    : true
  )
  CONFIGURATION_FAILURE_atracker_cos_bucket_not_found = regex("true", local.atracker_cos_bucket_not_found)
}

##############################################################################

##############################################################################
# Fail if COS bucket for Flow Logs instance is not found
##############################################################################

locals {
  flow_logs_cos_bucket_not_found = length([
    for name in local.flow_logs_bucket_names :
    true if !contains(local.all_bucket_names, name)
  ]) != 0
  CONFIGURATION_FAILURE_flow_logs_cos_bucket_not_found = regex("false", local.flow_logs_cos_bucket_not_found)
}

##############################################################################