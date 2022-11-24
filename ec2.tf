data "aws_ssm_parameter" "ami" {
  count = local.enabled ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

locals {
  ec2_capacity_providers          = local.enabled ? var.capacity_providers_ec2 : {}
  external_ec2_capacity_providers = local.enabled ? var.external_ec2_capacity_providers : {}

  instance_profile_name = join("", aws_iam_instance_profile.default.*.name)
}

locals {
  user_data = {
    for name, provider in local.ec2_capacity_providers :
    name => <<EOT
#!/bin/bash
echo ECS_CLUSTER="${local.cluster_name}" >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
echo ECS_POLL_METRICS=true >> /etc/ecs/ecs.config
echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=${provider.instance_market_options != null && provider.mixed_instances_policy != null} >> /etc/ecs/ecs.config
echo ECS_WARM_POOLS_CHECK=${provider.warm_pool != null} >> /etc/ecs/ecs.config

${replace(provider.user_data, "#!/bin/bash", "")}
EOT
  }
}

module "ecs_labels" {
  for_each = local.ec2_capacity_providers
  source   = "cloudposse/label/null"
  version  = "0.25.0" # requires Terraform >= 0.13.0

  enabled    = var.enabled
  attributes = concat(module.this.context.attributes, [each.key])
  tags       = merge(module.this.context.tags, { "AmazonECSManaged" : "true" })
  context    = module.this.context
}

module "autoscale_group" {
  for_each = local.ec2_capacity_providers

  source  = "cloudposse/ec2-autoscale-group/aws"
  version = "0.31.1"

  context = module.ecs_labels[each.key].context

  image_id      = each.value["image_id"] == null ? join("", data.aws_ssm_parameter.ami.*.value) : each.value["image_id"]
  instance_type = each.value["instance_type"]


  ## ECS autoscaling group does not have ELB integration, so we use EC2 health check type
  health_check_type = "EC2"
  # The Auto Scaling group must have instance protection from scale in enabled to use managed termination protection for a capacity provider,
  protect_from_scale_in = true
  # Disable autoscaling rules because scaling would be managed by ECS
  autoscaling_policies_enabled = false
  default_alarms_enabled       = false

  iam_instance_profile_name = local.instance_profile_name
  user_data_base64          = base64encode(local.user_data[each.key])

  instance_initiated_shutdown_behavior = each.value["instance_initiated_shutdown_behavior"]
  key_name                             = each.value["key_name"]
  security_group_ids                   = each.value["security_group_ids"]
  subnet_ids                           = each.value["subnet_ids"]
  associate_public_ip_address          = each.value["associate_public_ip_address"]
  enable_monitoring                    = each.value["enable_monitoring"]
  ebs_optimized                        = each.value["ebs_optimized"]
  ## Workaround to solve option type validation failure.
  block_device_mappings      = jsondecode(jsonencode(each.value["block_device_mappings"]))
  instance_market_options    = jsondecode(jsonencode(each.value["instance_market_options"]))
  instance_refresh           = each.value["instance_refresh"]
  mixed_instances_policy     = merge(each.value["mixed_instances_policy"], { override = null })
  placement                  = each.value["placement"]
  credit_specification       = each.value["credit_specification"]
  elastic_gpu_specifications = each.value["elastic_gpu_specifications"]
  disable_api_termination    = each.value["disable_api_termination"]
  max_size                   = each.value["max_size"]
  min_size                   = each.value["min_size"]
  ## Desired capacity managed by ECS so by default we set it equal min_size
  desired_capacity                     = each.value["min_size"]
  default_cooldown                     = each.value["default_cooldown"]
  health_check_grace_period            = each.value["health_check_grace_period"]
  force_delete                         = each.value["force_delete"]
  termination_policies                 = each.value["termination_policies"]
  suspended_processes                  = each.value["suspended_processes"]
  placement_group                      = each.value["placement_group"]
  metrics_granularity                  = each.value["metrics_granularity"]
  enabled_metrics                      = each.value["enabled_metrics"]
  wait_for_capacity_timeout            = each.value["wait_for_capacity_timeout"]
  service_linked_role_arn              = each.value["service_linked_role_arn"]
  metadata_http_endpoint_enabled       = each.value["metadata_http_endpoint_enabled"]
  metadata_http_put_response_hop_limit = each.value["metadata_http_put_response_hop_limit"]
  metadata_http_tokens_required        = each.value["metadata_http_tokens_required"]
  metadata_http_protocol_ipv6_enabled  = each.value["metadata_http_protocol_ipv6_enabled"]
  tag_specifications_resource_types    = each.value["tag_specifications_resource_types"]
  max_instance_lifetime                = each.value["max_instance_lifetime"]
  capacity_rebalance                   = each.value["capacity_rebalance"]
  warm_pool                            = each.value["warm_pool"]
}

resource "aws_ecs_capacity_provider" "ec2" {
  for_each = local.ec2_capacity_providers
  name     = each.key

  auto_scaling_group_provider {
    auto_scaling_group_arn         = module.autoscale_group[each.key].autoscaling_group_arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      instance_warmup_period    = each.value["instance_warmup_period"]
      maximum_scaling_step_size = each.value["maximum_scaling_step_size"]
      minimum_scaling_step_size = each.value["minimum_scaling_step_size"]
      status                    = "ENABLED"
      target_capacity           = each.value["target_capacity_utilization"]
    }
  }
}

resource "aws_ecs_capacity_provider" "external_ec2" {
  for_each = local.external_ec2_capacity_providers
  name     = each.key

  auto_scaling_group_provider {
    auto_scaling_group_arn         = each.value["autoscaling_group_arn"]
    managed_termination_protection = each.value["managed_termination_protection"] ? "ENABLED" : "DISABLED"

    managed_scaling {
      instance_warmup_period    = each.value["instance_warmup_period"]
      maximum_scaling_step_size = each.value["maximum_scaling_step_size"]
      minimum_scaling_step_size = each.value["minimum_scaling_step_size"]
      status                    = each.value["managed_scaling_status"] ? "ENABLED" : "DISABLED"
      target_capacity           = each.value["target_capacity_utilization"]
    }
  }
}
