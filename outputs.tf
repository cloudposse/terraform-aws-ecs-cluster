output "id" {
  description = "ID of the created example"
  value       = module.this.enabled ? module.this.id : null
}

