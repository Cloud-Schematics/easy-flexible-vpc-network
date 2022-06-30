# IBM Cloud Solution Engineering Multiple VPC Template

Create a network with logging and monitoring using VPC, Key Management, Cloud Object Storage, Flow Logs, and Activity Tracker.

---

## Table of Contents

1. [Template Level Variables](#template-level-variables)
2. [VPC](#vpc)
    - [VPC Variable](#vpc-variable)
3. [Security Groups](#security-groups)
4. [Transit Gateway](#transit-gateway)
5. [Cloud Services](#cloud-services)
    - [Key Management](#key-management)
        - [Key Management Keys](#key-management-keys)
    - [Cloud Object Storage](#cloud-object-storage)
      - [Secrets Manager](#secrets-manager)
6. [Flow Logs](#flow-logs)
7. [Activity Tracker](#activity-tracker)
8. [Fail States](#fail-states)
9. [Outputs](#outputs)

---

## Template Level Variables

The following variables are used for all components created by this template:

Name             | Type         | Description                                                            | Sensitive | Default
---------------- | ------------ | ---------------------------------------------------------------------- | --------- | -------
ibmcloud_api_key | string       | The IBM Cloud platform API key needed to deploy IAM enabled resources. | true      | 
region           | string       | The region to which to deploy the VPC                                  |           | 
prefix           | string       | The prefix that you would like to append to your resources             |           | 
tags             | list(string) | List of Tags for the resource created                                  |           | null

---

## VPCs

This template can create one or more VPCs in a single region. This module uses the [vpc_module](./vpc) to create VPC network components. VPC Configurations are created using the [vpcs variable](./variables.tf#L35).

### VPC Variable

```terraform
  type = list(
    object({
      prefix                      = string           # VPC prefix
      resource_group              = optional(string) # Name of the resource group where VPC will be created
      use_manual_address_prefixes = optional(bool)   # Assign CIDR prefixes manually
      classic_access              = optional(bool)   # Allow classic access
      default_network_acl_name    = optional(string) # Rename default network ACL
      default_security_group_name = optional(string) # Rename default security group
      default_security_group_rules = optional(       # Add rules to default VPC security group
        list(
          object({
            name      = string # Name of security group rule
            direction = string # Can be `inbound` or `outbound`
            remote    = string # CIDR Block or IP for traffic to allow
            ##############################################################################
            # One or none of these optional blocks can be added
            # > if none are added, rule will be for any type of traffic
            ##############################################################################
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
      default_routing_table_name = optional(string) # Default Routing Table Name
      address_prefixes = optional(                  # Address prefix CIDR subnets by zone 
        object({
          zone-1 = optional(list(string))
          zone-2 = optional(list(string))
          zone-3 = optional(list(string))
        })
      )
      network_acls = list(
        object({
          name              = string                 # Name of the ACL. The value of `var.prefix` will be prepended to this name
          add_cluster_rules = optional(bool)         # Dynamically create cluster allow rules
          resource_group_id = optional(string)       # ID of the resource group where the ACL will be created
          tags              = optional(list(string)) # List of tags for the ACL
          rules = list(
            object({
              name        = string # Rule Name
              action      = string # Can be `allow` or `deny`
              destination = string # CIDR for traffic destination
              direction   = string # Can be `inbound` or `outbound`
              source      = string # CIDR for traffic source
              # Any one of the following blocks can be used to create a TCP, UDP, or ICMP rule
              # to allow all kinds of traffic, use no blocks
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
      # Use public gateways in VPC by zone
      use_public_gateways = object({
        zone-1 = optional(bool)
        zone-2 = optional(bool)
        zone-3 = optional(bool)
      })
      # Subnets by zone
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
```

### Additional Resources

- [Getting started with VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-getting-started)

---

## Security Groups

Any number of additional security groups and rules can be created using the [security_groups variable](./variables.tf#L168). These security groups will be created in the VPC resource group.

```terraform
variable "security_groups" {
  description = "Security groups for VPC"
  type = list(
    object({
      name           = string           # Name
      resource_group = optional(string) # Name of existing resource group to use for security groups
      vpc_name       = string           # Name of VPC where security groups will be added.
      rules = list(                     # List of rules
        object({
          name      = string # name of rule
          direction = string # can be inbound or outbound
          remote    = string # ip address to allow traffic from
          ##############################################################################
          # One or none of these optional blocks can be added
          # > if none are added, rule will be for any type of traffic
          ##############################################################################
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
  ...
}
```

This template uses the [VPC Security Group Module](https://github.com/Cloud-Schematics/vpc-security-group-module) to create security groups and security group rules.

### Additional Resources

- [Using VPC Security Groups](https://cloud.ibm.com/docs/vpc?topic=vpc-using-security-groups)

--- 

## Transit Gateway

This template can optionally be used to create a transit gateway and use it to connect VPCs created in this template. The following variables are used in the creation of a transit gateway:

Name                           | Type         | Description                                                                       | Sensitive | Default
------------------------------ | ------------ | --------------------------------------------------------------------------------- | --------- | --------------------------
enable_transit_gateway         | bool         | Create transit gateway                                                            |           | true
transit_gateway_resource_group | string       | Name of existing resource group to use                                            |           | Default
transit_gateway_connections    | list(string) | Transit gateway vpc connections. Will only be used if transit gateway is enabled. |           | ["management", "workload"]

---

## Cloud Services

This template can optionally be used to create the following services using the [ICSE Cloud Services Module](github.com/Cloud-Schematics/icse-atracker):

- Key Management Services
- Cloud Object Storage and Buckets
- Secrets Manager

---

### Key Management

Key Management configuration uses the [key_management variable](./variables.tf#L305).

```terraform
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
```

---

#### Key Management Keys

Key Management keys are created using the [keys variable](./variables.tf#L320).

```terraform
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
```

---

### Cloud Object Storage

Cloud Object Storage instances, buckets, and keys are managed using the [cos variable](./variables#L390)

```terraform
variable "cos" {
  description = "Object describing the cloud object storage instance, buckets, and keys. Set `use_data` to false to create instance"
  type = list(
    object({
      name              = string           # Name of the COS instance
      use_data          = optional(bool)   # Optional - Get existing COS instance from data
      resource_group_id = optional(string) # ID of resource group where COS should be provisioned
      plan              = optional(string) # Can be `lite` or `standard`
      ##############################################################################
      # For more information on bucket creation, see the Terraform Documentation
      # https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/cos_bucket
      ##############################################################################
      buckets = list(object({
        name                  = string           # Name of the bucket
        storage_class         = string           # Storage class for the bucket
        endpoint_type         = string
        force_delete          = bool
        single_site_location  = optional(string)
        region_location       = optional(string)
        cross_region_location = optional(string)
        encryption_key_id     = optional(string)
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
      ##############################################################################
      # Create Any number of keys 
      ##############################################################################
      keys = optional(
        list(object({
          name        = string
          role        = string
          enable_HMAC = bool
        }))
      )

    })
  )
```

#### COS Use Random Suffix

To append a random suffix to each Cloud Object Storage resource, set the `cos_use_random_prefix` variable to `true`.

---

### Secrets Manager

A secrets manager instance can be created using the [secrets_manager variable](./variables.tf#602). 
```terraform
variable "secrets_manager" {
  description = "Map describing an optional secrets manager deployment"
  type = object({
    use_secrets_manager = bool             # Create Secrets Manager Instance
    name                = optional(string) # Name of Secrets Manager Instance
    kms_key_name        = optional(string) # Name of KMS key from key_management module
    resource_group_id   = optional(string) # Resource Group ID for the secrets manager instance
  })
  default = {
    use_secrets_manager = false
  }
}
```

---

## Flow Logs

This template uses the [ICSE Flow Logs Module](https://github.com/Cloud-Schematics/icse-flow-logs-module) to create Flow Logs and Service Authorizations to allow VPC networks to use Cloud Object Storage buckets. These resources are created when the [enable_flow_logs variable](./variables.tf#L621) is set to `true`.

### Flow Logs IAM Authorization Policies

For each COS Instance passed using the `cos` variable, a service authorization policy is created to allow Flow Logs Collector resources to write to buckets with that instance.

### Flow Logs Collectors

For each VPC passed with a valid value for `flow_logs_bucket_name`, a collector will be created for that VPC targetting the bucket with that name. This collector will be added to the VPC's resource group.

---

## Activity Tracker 

This template uses the [ICSE Activity Tracker Module](https://github.com/Cloud-Schematics/icse-atracker) to provision Activity Tracker resources. These resource are created when the [enable_atracker variable](./variables#L633) is set to `true`.

### Activity Tracker Variables

The following is used to set up your Activity Tracker target and route. *(Note: These values are marked as optional to ensure no input is needed when `var.enable_atracker` is false)*

```terraform
variable "atracker" {
  description = "atracker variables"
  type = object({
    receive_global_events = optional(bool)   # Allow atracker to recieve globale events
    add_route             = optional(bool)   # Add a route to the instance
    collector_bucket_name = optional(string) # Shortname of the collector bucket where logs will be stored
  })
}
```

---

## Fail States

This template uses local values and the terraform `regex` function to force the template to fail if the environment cannot correctly be compiled. The template will fail under the following circumstances:

- The subnet defined within a VPN gateway is not defined within the VPC where it will be provisoned
- The name of a subnet ACL is not found withing the VPC where it will be provisioned
- Additional security groups will fail if the VPC name provided is not found with `var.vpcs`
- The name of any network to be attached to to the Transit Gateway is not found within `var.vpcs`
- A Cloud Object Storage bucket is encrypted using a key not defined in `var.keys`
- The bucket shortname for `var.atracker.collector_bucket_name` is not found in any instance in `var.cos`
- The bucket shortname for any VPC where `flow_logs_bucket_name` is not null and is not found in any instance in `var.cos` 

---

## Outputs

The following are outputs of the template.

### `networks` Output

For each network an object is created in the `networks` output that contains the following data:
  - VPC ID
  - VPC CRN
  - VPC Name
  - Subnet Zone List
  - Network ACLs
  - Public Gateways
  - Security Groups
  - VPN Gateways

### `security_groups` Output

Contains a list of security groups and IDs for those groups

### Services Outputs

Name                 | Description
-------------------- | ---------------------------------------
key_management_name  | Name of key management service
key_management_crn   | CRN for KMS instance
key_management_guid  | GUID for KMS instance
key_rings            | Key rings created by module
keys                 | List of names and ids for keys created
cos_instances        | List of COS resource instances with shortname, name, id, and crn.
cos_buckets          | List of COS bucket instances with shortname, instance_shortname, name, id, crn, and instance id.
cos_keys             | List of COS bucket instances with shortname, instance_shortname, name, id, crn, and instance id.
secrets_manager_name | Name of secrets manager instance
secrets_manager_id   | ID of secrets manager instance
secrets_manager_guid | GUID of secrets manager instance

### Key Management Keys Output

The `keys` output is a list with the following fields for each Key Management Key:

Field Name | Field Value
-----------|----------------------------
shortname  | Name of key without prefix
name       | Composed name including prefix
id         | ID of the Key
crn        | CRN of the Key
key_id     | Key ID of Key

### COS Instances Output

The `cos_instances` output is a list with the following fields for each Object Storage Instances:

Field Name | Field Value
-----------|----------------------------
shortname  | Name of instance without prefix and random suffix
name       | Composed name including prefix and random suffix
id         | ID of the instance
crn        | CRN of the instance

### COS Buckets Output

The `cos_buckets` output is a list with the following fields for each Object Storage Bucket:

Field Name          | Field Value
--------------------|----------------------------
instance_shortname  | Shortname of the Object Storage instance where the bucket is created
instance_id         | Instance ID of the Object Storage instance where the bucket is created
shortname           | Name of bucket without prefix and random suffix
name                | Composed name including prefix and random suffix
id                  | ID of the Bucket
crn                 | CRN of the Bucket


### COS Resource Keys Output

The `cos_keys` output is a list with the following fields for each Object Storage Bucket:

Field Name          | Field Value
--------------------|----------------------------
instance_shortname  | Shortname of the Object Storage instance where the key is created
instance_id         | Instance ID of the Object Storage instance where the key is created
shortname           | Name of key without prefix and random suffix
name                | Composed name including prefix and random suffix
id                  | Resource Key ID
crn                 | Resource Key CRN


### JSON Config

Show a list of resources created by this template in JSON format.