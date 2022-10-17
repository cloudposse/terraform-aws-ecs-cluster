data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

locals {
  ec2_capacity_providers_cleanup = {
    for name, provider in var.capacity_providers_ec2 :
    name => {
      for key, value in provider :
      key => value
      if value != null
    }
  }

  ec2_capacity_provider_default = {
    image_id                             = data.aws_ssm_parameter.ami.value
    instance_initiated_shutdown_behavior = "terminate"
    instance_warmup_period               = 300
    maximum_scaling_step_size            = 1
    minimum_scaling_step_size            = 1
    target_capacity_utilization          = 100
    key_name                             = ""
    user_data                            = ""
    enable_monitoring                    = true
    associate_public_ip_address          = false
    ebs_optimized                        = false
    block_device_mappings                = []
    instance_market_options              = null
    instance_refresh                     = null
    mixed_instances_policy               = null
    placement                            = null
    credit_specification                 = null
    elastic_gpu_specifications           = null
    disable_api_termination              = false
    default_cooldown                     = 300
    health_check_grace_period            = 300
    force_delete                         = false
    termination_policies                 = ["Default"]
    suspended_processes                  = []
    placement_group                      = ""
    metrics_granularity                  = "1Minute"
    enabled_metrics = [
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
    ]
    wait_for_capacity_timeout            = "10m"
    service_linked_role_arn              = ""
    metadata_http_endpoint_enabled       = true
    metadata_http_put_response_hop_limit = 2
    metadata_http_tokens_required        = true
    metadata_http_protocol_ipv6_enabled  = false
    tag_specifications_resource_types = [
      "instance",
      "volume"
    ]
    max_instance_lifetime = null
    capacity_rebalance    = false
    warm_pool             = null
  }

  ec2_capacity_providers = local.enabled ? {
    for name, provider in local.ec2_capacity_providers_cleanup :
    name => merge(local.ec2_capacity_provider_default, provider)
  } : {}

  instance_profile_name = join("", aws_iam_instance_profile.default.*.name)
}

data "template_cloudinit_config" "default" {
  for_each      = local.ec2_capacity_providers
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<EOT
#!/bin/bash
echo ECS_CLUSTER="${local.cluster_name}" >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
echo ECS_POLL_METRICS=true >> /etc/ecs/ecs.config
echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=${each.value.instance_market_options != null && each.value.mixed_instances_policy != null} >> /etc/ecs/ecs.config
echo ECS_WARM_POOLS_CHECK=${each.value.warm_pool != null} >> /etc/ecs/ecs.config
EOT
  }

  part {
    content_type = "text/x-shellscript"
    content      = replace(each.value["user_data"], "#!/bin/bash", "")
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
  version = "0.30.1"

  context = module.ecs_labels[each.key].context

  image_id      = each.value["image_id"]
  instance_type = each.value["instance_type"]


  ## ECS autoscaling group does not have ELB integration, so we use EC2 health check type
  health_check_type = "EC2"
  # The Auto Scaling group must have instance protection from scale in enabled to use managed termination protection for a capacity provider,
  protect_from_scale_in = true
  # Disable autoscaling rules because scaling would be managed by ECS
  autoscaling_policies_enabled = false
  default_alarms_enabled       = false

  iam_instance_profile_name = local.instance_profile_name
  user_data_base64          = data.template_cloudinit_config.default[each.key].rendered

  instance_initiated_shutdown_behavior = each.value["instance_initiated_shutdown_behavior"]
  key_name                             = each.value["key_name"]
  security_group_ids                   = each.value["security_group_ids"]
  subnet_ids                           = each.value["subnet_ids"]
  associate_public_ip_address          = each.value["associate_public_ip_address"]
  enable_monitoring                    = each.value["enable_monitoring"]
  ebs_optimized                        = each.value["ebs_optimized"]
  block_device_mappings                = each.value["block_device_mappings"]
  instance_market_options              = each.value["instance_market_options"]
  instance_refresh                     = each.value["instance_refresh"]
  mixed_instances_policy               = each.value["mixed_instances_policy"]
  placement                            = each.value["placement"]
  credit_specification                 = each.value["credit_specification"]
  elastic_gpu_specifications           = each.value["elastic_gpu_specifications"]
  disable_api_termination              = each.value["disable_api_termination"]
  max_size                             = each.value["max_size"]
  min_size                             = each.value["min_size"]
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

