##############################################################################
# Template Level Variables
##############################################################################

variable "region" {
  description = "The region to which to deploy the VPC"
  type        = string
}

variable "prefix" {
  description = "The prefix that you would like to prepend to your resources"
  type        = string
}

variable "tags" {
  description = "List of Tags for the resource created"
  type        = list(string)
  default     = null
}

##############################################################################

##############################################################################
# VPC Variables
##############################################################################

variable "vpcs" {
  description = "A map describing VPCs to be created in this repo."
  type = list(
    object({
      prefix                      = string           # VPC prefix
      resource_group              = optional(string) # Name of the group where VPC will be created
      use_manual_address_prefixes = optional(bool)
      classic_access              = optional(bool)
      default_network_acl_name    = optional(string)
      default_security_group_name = optional(string)
      default_security_group_rules = optional(
        list(
          object({
            name      = string
            direction = string
            remote    = string
            tcp = optional(
              object({
                port_max = optional(number)
                port_min = optional(number)
              })
            )
            udp = optional(
              object({
                port_max = optional(number)
                port_min = optional(number)
              })
            )
            icmp = optional(
              object({
                type = optional(number)
                code = optional(number)
              })
            )
          })
        )
      )
      default_routing_table_name = optional(string)
      flow_logs_bucket_name      = optional(string)
      address_prefixes = optional(
        object({
          zone-1 = optional(list(string))
          zone-2 = optional(list(string))
          zone-3 = optional(list(string))
        })
      )
      network_acls = list(
        object({
          name              = string
          add_cluster_rules = optional(bool)
          rules = list(
            object({
              name        = string
              action      = string
              destination = string
              direction   = string
              source      = string
              tcp = optional(
                object({
                  port_max        = optional(number)
                  port_min        = optional(number)
                  source_port_max = optional(number)
                  source_port_min = optional(number)
                })
              )
              udp = optional(
                object({
                  port_max        = optional(number)
                  port_min        = optional(number)
                  source_port_max = optional(number)
                  source_port_min = optional(number)
                })
              )
              icmp = optional(
                object({
                  type = optional(number)
                  code = optional(number)
                })
              )
            })
          )
        })
      )
      use_public_gateways = object({
        zone-1 = optional(bool)
        zone-2 = optional(bool)
        zone-3 = optional(bool)
      })
      subnets = object({
        zone-1 = list(object({
          name           = string
          cidr           = string
          public_gateway = optional(bool)
          acl_name       = string
        }))
        zone-2 = list(object({
          name           = string
          cidr           = string
          public_gateway = optional(bool)
          acl_name       = string
        }))
        zone-3 = list(object({
          name           = string
          cidr           = string
          public_gateway = optional(bool)
          acl_name       = string
        }))
      })
      vpn_gateway = object({
        use_vpn_gateway = bool             # create vpn gateway
        name            = optional(string) # gateway name
        subnet_name     = optional(string) # Do not include prefix, use same name as in `var.subnets`
        mode            = optional(string) # Can be `route` or `policy`. Default is `route`
        connections = optional(list(
          object({
            peer_address   = string
            preshared_key  = string
            local_cidrs    = optional(list(string))
            peer_cidrs     = optional(list(string))
            admin_state_up = optional(bool)
          })
        ))
      })
    })
  )
  default = []
}

##############################################################################

##############################################################################
# Security Group Variables
##############################################################################

variable "security_groups" {
  description = "Security groups for VPC"
  type = list(
    object({
      name           = string
      vpc_name       = string
      resource_group = optional(string)
      rules = list(
        object({
          name      = string
          direction = string
          remote    = string
          tcp = optional(
            object({
              port_max = number
              port_min = number
            })
          )
          udp = optional(
            object({
              port_max = number
              port_min = number
            })
          )
          icmp = optional(
            object({
              type = number
              code = number
            })
          )
        })
      )
    })
  )

  default = []

  validation {
    error_message = "Each security group rule must have a unique name."
    condition = length(var.security_groups) == 0 ? true : length([
      for security_group in var.security_groups :
      true if length(distinct(security_group.rules.*.name)) != length(security_group.rules.*.name)
    ]) == 0
  }

  validation {
    error_message = "Security group rules can only use one of the following blocks: `tcp`, `udp`, `icmp`."
    condition = length(var.security_groups) == 0 ? true : length(
      # Ensure length is 0
      [
        # For each group in security groups
        for group in var.security_groups :
        # Return true if length isn't 0
        true if length(
          distinct(
            flatten([
              # For each rule, return true if using more than one `tcp`, `udp`, `icmp block
              for rule in group.rules :
              true if length([for type in ["tcp", "udp", "icmp"] : true if lookup(rule, type, null) != null]) > 1
            ])
          )
        ) != 0
      ]
    ) == 0
  }

  validation {
    error_message = "Security group rule direction can only be `inbound` or `outbound`."
    condition = length(var.security_groups) == 0 ? true : length(
      [
        for group in var.security_groups :
        true if length(
          distinct(
            flatten([
              for rule in group.rules :
              false if !contains(["inbound", "outbound"], rule.direction)
            ])
          )
        ) != 0
      ]
    ) == 0
  }

}

##############################################################################

##############################################################################
# Transit Gateway Variables
##############################################################################

variable "enable_transit_gateway" {
  description = "Create transit gateway"
  type        = bool
  default     = true
}

variable "transit_gateway_resource_group" {
  description = "Name of existing resource group to use"
  type        = string
  default     = "Default"
}

variable "transit_gateway_connections" {
  description = "Transit gateway vpc connections. Will only be used if transit gateway is enabled."
  type        = list(string)
  default     = ["management", "workload"]
}

#############################################################################

#############################################################################
# Service Endpoints
#############################################################################

variable "service_endpoints" {
  description = "Service endpoints. Can be `public`, `private`, or `public-and-private`"
  type        = string
  default     = "private"

  validation {
    error_message = "Service endpoints can only be `public`, `private`, or `public-and-private`."
    condition     = contains(["public", "private", "public-and-private"], var.service_endpoints)
  }
}

##############################################################################

##############################################################################
# Key Management Variables
##############################################################################

variable "disable_key_management" {
  description = "OPTIONAL - If true, key management resources will not be created."
  type        = bool
  default     = false
}

variable "key_management" {
  description = "Configuration for Key Management Service"
  type = object({
    name                      = string           # Name of the service
    use_hs_crypto             = optional(bool)   # Will force data source to be used. If not true, will default to kms
    use_data                  = optional(bool)   # Use existing Key Protect instnace
    authorize_vpc_reader_role = optional(bool)   # Allow keys to be used to encrypt VPC block storage instances
    resource_group_name       = optional(string) # Resource group for key management resources
  })
  default = {
    name                      = "kms"
    authorize_vpc_reader_role = true
  }
}

variable "keys" {
  description = "List of keys to be created for the service"
  type = list(
    object({
      name            = string           # Key name
      root_key        = optional(bool)   # Is root key
      payload         = optional(string) # Arbitrary key payload
      key_ring        = optional(string) # Any key_ring added will be created
      force_delete    = optional(bool)   # Force delete key. This is automatically set to `true`
      endpoint        = optional(string) # can be public or private
      iv_value        = optional(string) # (Optional, Forces new resource, String) Used with import tokens. The initialization vector (IV) that is generated when you encrypt a nonce. The IV value is required to decrypt the encrypted nonce value that you provide when you make a key import request to the service. To generate an IV, encrypt the nonce by running ibmcloud kp import-token encrypt-nonce. Only for imported root key.
      encrypted_nonce = optional(string) # The encrypted nonce value that verifies your request to import a key to Key Protect. This value must be encrypted by using the key that you want to import to the service. To retrieve a nonce, use the ibmcloud kp import-token get command. Then, encrypt the value by running ibmcloud kp import-token encrypt-nonce. Only for imported root key.
      policies = optional(
        object({
          rotation = optional(
            object({
              interval_month = number
            })
          )
          dual_auth_delete = optional(
            object({
              enabled = bool
            })
          )
        })
      )
    })
  )

  default = []

  validation {
    error_message = "Each key must have a unique name."
    condition     = length(var.keys) == 0 ? true : length(distinct(var.keys.*.name)) == length(var.keys.*.name)
  }

  validation {
    error_message = "Key endpoints can only be `public` or `private`."
    condition = length(var.keys) == 0 ? true : length([
      for kms_key in var.keys :
      true if lookup(kms_key, "endpoint", null) == null ? false : kms_key.endpoint != "public" && kms_key.endpoint != "private"
    ]) == 0
  }

  validation {
    error_message = "Rotation interval month can only be from 1 to 12."
    condition = length(var.keys) == 0 ? true : length([
      for kms_key in [
        for rotation_key in [
          for policy_key in var.keys :
          policy_key if lookup(policy_key, "policies", null) != null
        ] :
        rotation_key if lookup(rotation_key, "policies", null) == null ? false : rotation_key.policies.rotation != null
      ] : true if kms_key.policies.rotation.interval_month < 1 || kms_key.policies.rotation.interval_month > 12
    ]) == 0
  }
}

##############################################################################

##############################################################################
# Object Storage Variables
##############################################################################

variable "cos_use_random_suffix" {
  description = "Add a randomize suffix to the end of each Object Storage resource created in this module."
  type        = bool
  default     = true
}

variable "cos" {
  description = "Object describing the cloud object storage instance, buckets, and keys. Set `use_data` to true to use existing instance instance"
  type = list(
    object({
      name                = string
      use_data            = optional(bool)
      resource_group_name = optional(string)
      plan                = optional(string)
      buckets = list(object({
        name                  = string
        storage_class         = string
        endpoint_type         = string
        force_delete          = bool
        single_site_location  = optional(string)
        region_location       = optional(string)
        cross_region_location = optional(string)
        kms_key               = optional(string)
        allowed_ip            = optional(list(string))
        hard_quota            = optional(number)
        archive_rule = optional(object({
          days    = number
          enable  = bool
          rule_id = optional(string)
          type    = string
        }))
        activity_tracking = optional(object({
          activity_tracker_crn = string
          read_data_events     = bool
          write_data_events    = bool
        }))
        metrics_monitoring = optional(object({
          metrics_monitoring_crn  = string
          request_metrics_enabled = optional(bool)
          usage_metrics_enabled   = optional(bool)
        }))
      }))
      keys = optional(
        list(object({
          name        = string
          role        = string
          enable_HMAC = bool
        }))
      )

    })
  )

  default = []

  validation {
    error_message = "Each COS key must have a unique name."
    condition = length(var.cos) == 0 ? true : length(
      flatten(
        [
          for instance in var.cos :
          [
            for keys in instance.keys :
            keys.name
          ] if lookup(instance, "keys", false) != false
        ]
      )
      ) == length(
      distinct(
        flatten(
          [
            for instance in var.cos :
            [
              for keys in instance.keys :
              keys.name
            ] if lookup(instance, "keys", false) != false
          ]
        )
      )
    )
  }

  validation {
    error_message = "Plans for COS instances can only be `lite` or `standard`."
    condition = length(var.cos) == 0 ? true : length([
      for instance in var.cos :
      true if contains(["lite", "standard"], instance.plan)
    ]) == length(var.cos)
  }

  validation {
    error_message = "COS Bucket names must be unique."
    condition = length(var.cos) == 0 ? true : length(
      flatten([
        for instance in var.cos :
        instance.buckets.*.name
      ])
      ) == length(
      distinct(
        flatten([
          for instance in var.cos :
          instance.buckets.*.name
        ])
      )
    )
  }

  # https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-classes 
  validation {
    error_message = "Storage class can only be `standard`, `vault`, `cold`, or `smart`."
    condition = length(var.cos) == 0 ? true : length(
      flatten(
        [
          for instance in var.cos :
          [
            for bucket in instance.buckets :
            true if contains(["standard", "vault", "cold", "smart"], bucket.storage_class)
          ]
        ]
      )
    ) == length(flatten([for instance in var.cos : [for bucket in instance.buckets : true]]))
  }

  # https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket#endpoint_type 
  validation {
    error_message = "Endpoint type can only be `public`, `private`, or `direct`."
    condition = length(var.cos) == 0 ? true : length(
      flatten(
        [
          for instance in var.cos :
          [
            for bucket in instance.buckets :
            true if contains(["public", "private", "direct"], bucket.endpoint_type)
          ]
        ]
      )
    ) == length(flatten([for instance in var.cos : [for bucket in instance.buckets : true]]))
  }

  # https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket#single_site_location
  validation {
    error_message = "All single site buckets must specify `ams03`, `che01`, `hkg02`, `mel01`, `mex01`, `mil01`, `mon01`, `osl01`, `par01`, `sjc04`, `sao01`, `seo01`, `sng01`, or `tor01`."
    condition = length(var.cos) == 0 ? true : length(
      [
        for site_bucket in flatten(
          [
            for instance in var.cos :
            [
              for bucket in instance.buckets :
              bucket if lookup(bucket, "single_site_location", null) != null
            ]
          ]
        ) : site_bucket if !contains(["ams03", "che01", "hkg02", "mel01", "mex01", "mil01", "mon01", "osl01", "par01", "sjc04", "sao01", "seo01", "sng01", "tor01"], site_bucket.single_site_location)
      ]
    ) == 0
  }

  # https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket#region_location
  validation {
    error_message = "All regional buckets must specify `au-syd`, `eu-de`, `eu-gb`, `jp-tok`, `us-east`, `us-south`, `ca-tor`, `jp-osa`, `br-sao`."
    condition = length(var.cos) == 0 ? true : length(
      [
        for site_bucket in flatten(
          [
            for instance in var.cos :
            [
              for bucket in instance.buckets :
              bucket if lookup(bucket, "region_location", null) != null
            ]
          ]
        ) : site_bucket if !contains(["au-syd", "eu-de", "eu-gb", "jp-tok", "us-east", "us-south", "ca-tor", "jp-osa", "br-sao"], site_bucket.region_location)
      ]
    ) == 0
  }

  # https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket#cross_region_location
  validation {
    error_message = "All cross-regional buckets must specify `us`, `eu`, `ap`."
    condition = length(var.cos) == 0 ? true : length(
      [
        for site_bucket in flatten(
          [
            for instance in var.cos :
            [
              for bucket in instance.buckets :
              bucket if lookup(bucket, "cross_region_location", null) != null
            ]
          ]
        ) : site_bucket if !contains(["us", "eu", "ap"], site_bucket.cross_region_location)
      ]
    ) == 0
  }

  # https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket#archive_rule
  validation {
    error_message = "Each archive rule must specify a type of `Glacier` or `Accelerated`."
    condition = length(var.cos) == 0 ? true : length(
      [
        for site_bucket in flatten(
          [
            for instance in var.cos :
            [
              for bucket in instance.buckets :
              bucket if lookup(bucket, "archive_rule", null) != null
            ]
          ]
        ) : site_bucket if !contains(["Glacier", "Accelerated"], site_bucket.archive_rule.type)
      ]
    ) == 0
  }
}

##############################################################################

##############################################################################
# Secrets Manager Variables
##############################################################################

variable "secrets_manager" {
  description = "Map describing an optional secrets manager deployment"
  type = object({
    use_secrets_manager = bool
    name                = optional(string)
    kms_key_name        = optional(string)
    resource_group_name = optional(string)
  })
  default = {
    use_secrets_manager = false
  }
}

##############################################################################

##############################################################################
# Flow Logs
##############################################################################

variable "enable_flow_logs" {
  description = "Create flow logs instances for VPCs."
  type        = bool
  default     = true
}

##############################################################################

##############################################################################
# Atracker Variables
##############################################################################

variable "enable_atracker" {
  description = "Enable Atracker"
  type        = bool
  default     = true
}

variable "atracker" {
  description = "atracker variables"
  type = object({
    receive_global_events = optional(bool)
    add_route             = optional(bool)
    collector_bucket_name = optional(string)
  })
}

##############################################################################