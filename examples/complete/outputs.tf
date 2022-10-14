output "name" {
  description = "ECS cluster name"
  value       = module.example.name
}

output "id" {
  description = "ECS cluster id"
  value = module.example.id
}

output "arn" {
  description = "ECS cluster arn"
  value = module.example.arn
}
