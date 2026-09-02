output "name" {
  description = "ECS cluster name"
  value       = module.this.enabled ? local.cluster_name : null
}

output "id" {
  description = "ECS cluster id"
  value       = module.this.enabled ? join("", aws_ecs_cluster.default[*].id) : null
}

output "arn" {
  description = "ECS cluster arn"
  value       = module.this.enabled ? join("", aws_ecs_cluster.default[*].arn) : null
}

output "role_name" {
  description = "IAM role name"
  value       = module.this.enabled ? join("", aws_iam_role.default[*].name) : null
}

output "ec2_capacity_providers" {
  description = "EC2 capacity provider and autoscale group names and ARNs, keyed by capacity provider"
  value = module.this.enabled ? {
    for key, provider in aws_ecs_capacity_provider.ec2 : key => {
      capacity_provider_name = provider.name
      autoscaling_group_name = module.autoscale_group[key].autoscaling_group_name
      autoscaling_group_arn  = module.autoscale_group[key].autoscaling_group_arn
    }
  } : {}
}
