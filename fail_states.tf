##############################################################################
# Configuration Failure States
##############################################################################

locals {
  # fail configuration if virtual private endpoints are enabled and `vpe` tier is not in tier list.
  CONFIGURATION_FAILURE_vpe_tier_not_found = regex("true", var.enable_virtual_private_endpoints != true ? true : contains(var.vpc_subnet_tiers, "vpe"))
}

##############################################################################