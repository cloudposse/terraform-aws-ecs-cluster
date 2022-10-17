variable "container_insights_enabled" {
  description = "Whether or not to enable container insights"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "The AWS Key Management Service key ID to encrypt the data between the local client and the container."
  type        = string
  default     = null
}

variable "logging" {
  description = "The AWS Key Management Service key ID to encrypt the data between the local client and the container. (Valid values: 'NONE', 'DEFAULT', 'OVERRIDE')"
  type        = string
  default     = "DEFAULT"
  validation {
    condition     = contains(["NONE", "DEFAULT", "OVERRIDE"], var.logging)
    error_message = "The 'logging' value must be one of 'NONE', 'DEFAULT', 'OVERRIDE'"
  }
}

variable "log_configuration" {
  description = "The log configuration for the results of the execute command actions Required when logging is OVERRIDE"
  type = object({
    cloud_watch_encryption_enabled = string
    cloud_watch_log_group_name     = string
    s3_bucket_name                 = string
    s3_key_prefix                  = string
  })
  default = null
}

variable "capacity_providers_fargate" {
  description = "Use FARGATE capacity provider"
  type        = bool
  default     = true
}

variable "capacity_providers_fargate_spot" {
  description = "Use FARGATE_SPOT capacity provider"
  type        = bool
  default     = false
}

variable "capacity_providers_ec2" {
  description = "EC2 autoscale groups capacity providers"
  type = map(object({
    instance_type      = string
    max_size           = number
    min_size           = number
    subnet_ids         = list(string)
    security_group_ids = list(string)

    image_id                             = optional(string, null)
    instance_initiated_shutdown_behavior = optional(string, "terminate")
    key_name                             = optional(string, "")
    user_data                            = optional(string, "")
    enable_monitoring                    = optional(bool, true)
    instance_warmup_period               = optional(number, 300)
    maximum_scaling_step_size            = optional(number, 1)
    minimum_scaling_step_size            = optional(number, 1)
    target_capacity_utilization          = optional(number, 100)
    ebs_optimized                        = optional(bool, false)
    associate_public_ip_address          = optional(bool, false)
    block_device_mappings = optional(list(object({
      device_name  = string
      no_device    = bool
      virtual_name = string
      ebs = object({
        delete_on_termination = bool
        encrypted             = bool
        iops                  = number
        kms_key_id            = string
        snapshot_id           = string
        volume_size           = number
        volume_               = string
      })
    })))
    instance_market_options = optional(object({
      market_ = string
      spot_options = object({
        block_duration_minutes         = number
        instance_interruption_behavior = string
        max_price                      = number
        spot_instance_                 = string
        valid_until                    = string
      })
    }))
    instance_refresh = optional(object({
      strategy = string
      preferences = object({
        instance_warmup        = number
        min_healthy_percentage = number
      })
      triggers = list(string)
    }))
    mixed_instances_policy = optional(object({
      instances_distribution = object({
        on_demand_allocation_strategy            = string
        on_demand_base_capacity                  = number
        on_demand_percentage_above_base_capacity = number
        spot_allocation_strategy                 = string
        spot_instance_pools                      = number
        spot_max_price                           = string
      })
    }), {
      instances_distribution = null
    })
    placement = optional(object({
      affinity          = string
      availability_zone = string
      group_name        = string
      host_id           = string
      tenancy           = string
    }))
    credit_specification = optional(object({
      cpu_credits = string
    }))
    elastic_gpu_specifications = optional(object({
      type = string
    }))
    disable_api_termination   = optional(bool, false)
    default_cooldown          = optional(number, 300)
    health_check_grace_period = optional(number, 300)
    force_delete              = optional(bool, false)
    termination_policies      = optional(list(string), ["Default"])
    suspended_processes       = optional(list(string), [])
    placement_group           = optional(string, "")
    metrics_granularity       = optional(string, "1Minute")
    enabled_metrics = optional(list(string), [
      "GroupMinSize",
      "GroupMaxSize",
      "GroupDesiredCapacity",
      "GroupInServiceInstances",
      "GroupPendingInstances",
      "GroupStandbyInstances",
      "GroupTerminatingInstances",
      "GroupTotalInstances",
      "GroupInServiceCapacity",
      "GroupPendingCapacity",
      "GroupStandbyCapacity",
      "GroupTerminatingCapacity",
      "GroupTotalCapacity",
      "WarmPoolDesiredCapacity",
      "WarmPoolWarmedCapacity",
      "WarmPoolPendingCapacity",
      "WarmPoolTerminatingCapacity",
      "WarmPoolTotalCapacity",
      "GroupAndWarmPoolDesiredCapacity",
      "GroupAndWarmPoolTotalCapacity",
    ])
    wait_for_capacity_timeout            = optional(string, "10m")
    service_linked_role_arn              = optional(string, "")
    metadata_http_endpoint_enabled       = optional(bool, true)
    metadata_http_put_response_hop_limit = optional(number, 2)
    metadata_http_tokens_required        = optional(bool, true)
    metadata_http_protocol_ipv6_enabled  = optional(bool, false)
    tag_specifications_resource_types    = optional(set(string), ["instance", "volume"])
    max_instance_lifetime                = optional(number, null)
    capacity_rebalance                   = optional(bool, false)
    warm_pool = optional(object({
      pool_state                  = string
      min_size                    = number
      max_group_prepared_capacity = number
    }))
  }))
  default = {}
  validation {
    condition     = !contains(["FARGATE", "FARGATE_SPOT"], keys(var.capacity_providers_ec2))
    error_message = "'FARGATE' and 'FARGATE_SPOT' name is reserved"
  }
}

variable "default_capacity_strategy" {
  description = "The capacity provider strategy to use by default for the cluster"
  type = object({
    base = object({
      provider = string
      value    = number
    })
    weights = map(number)
  })
  default = {
    base = {
      provider = "FARGATE"
      value    = 1
    }
    weights = {}
  }
}
