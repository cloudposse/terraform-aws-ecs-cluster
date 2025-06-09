output "name" {
  description = "ECS cluster name"
  value       = module.context.enabled ? local.cluster_name : null
}

output "id" {
  description = "ECS cluster id"
  value       = module.context.enabled ? join("", aws_ecs_cluster.default[*].id) : null
}

output "arn" {
  description = "ECS cluster arn"
  value       = module.context.enabled ? join("", aws_ecs_cluster.default[*].arn) : null
}

output "role_name" {
  description = "IAM role name"
  value       = module.context.enabled ? join("", module.role.name) : null
}

output "role_arn" {
  description = "IAM role name"
  value       = module.context.enabled ? join("", module.role.arn) : null
}

output "role_instance_profile" {
  description = "IAM role name"
  value       = module.context.enabled ? join("", module.role.instance_profile) : null
}
