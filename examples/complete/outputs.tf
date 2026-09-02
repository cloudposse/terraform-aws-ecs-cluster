output "name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.name
}

output "id" {
  description = "ECS cluster id"
  value       = module.ecs_cluster.id
}

output "arn" {
  description = "ECS cluster arn"
  value       = module.ecs_cluster.arn
}

output "ec2_capacity_providers" {
  description = "EC2 capacity providers"
  value       = module.ecs_cluster.ec2_capacity_providers
}
