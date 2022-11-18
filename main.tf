locals {
  enabled      = module.this.enabled
  cluster_name = join("", aws_ecs_cluster.default.*.name)

  capacity_providers_fargate = [
    for name, is_enabled in {
      FARGATE : var.capacity_providers_fargate,
      FARGATE_SPOT : var.capacity_providers_fargate_spot
    } : name if is_enabled
  ]

  capacity_providers = distinct(concat(
    [for key, value in aws_ecs_capacity_provider.ec2 : value.name],
    [for key, value in aws_ecs_capacity_provider.external_ec2 : value.name],
    local.capacity_providers_fargate
  ))

  default_capacity_strategy = [
    for name, weight in var.default_capacity_strategy.weights : {
      capacity_provider = name,
      weight            = weight,
      base              = var.default_capacity_strategy.base.provider == name ? var.default_capacity_strategy.base.value : null
    }
  ]
}

resource "aws_ecs_cluster" "default" {
  count = local.enabled ? 1 : 0

  name = module.this.id

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_id
      logging    = var.logging
      dynamic "log_configuration" {
        for_each = var.logging == "OVERRIDE" ? [var.log_configuration] : []
        content {
          cloud_watch_encryption_enabled = log_configuration.value["cloud_watch_encryption_enabled"]
          cloud_watch_log_group_name     = log_configuration.value["cloud_watch_log_group_name"]
          s3_bucket_name                 = log_configuration.value["s3_bucket_name"]
          s3_bucket_encryption_enabled   = true
          s3_key_prefix                  = log_configuration.value["s3_key_prefix"]
        }
      }
    }
  }

  tags = module.this.tags
}

resource "aws_ecs_cluster_capacity_providers" "default" {
  count = local.enabled && length(local.capacity_providers) > 0 ? 1 : 0

  cluster_name = local.cluster_name

  capacity_providers = local.capacity_providers

  dynamic "default_capacity_provider_strategy" {
    for_each = local.default_capacity_strategy
    content {
      base              = default_capacity_provider_strategy.value["base"]
      weight            = default_capacity_provider_strategy.value["weight"]
      capacity_provider = default_capacity_provider_strategy.value["capacity_provider"]
    }
  }
}
