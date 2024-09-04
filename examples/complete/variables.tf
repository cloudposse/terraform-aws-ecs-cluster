variable "region" {
  type        = string
  description = "AWS region"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of Availability Zones IDs (e.g. `['us-east-1a', 'us-east-1b', 'us-east-1c']`)"
}