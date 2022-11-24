module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "1.2.0"

  context                 = module.this.context
  ipv4_primary_cidr_block = "172.16.0.0/16"
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.0.4"

  context              = module.this.context
  availability_zones   = var.availability_zones
  vpc_id               = module.vpc.vpc_id
  igw_id               = [module.vpc.igw_id]
  ipv4_cidr_block      = [module.vpc.vpc_cidr_block]
  nat_gateway_enabled  = false
  nat_instance_enabled = false
}

module "ecs_cluster" {
  source = "../.."

  context = module.this.context

  container_insights_enabled      = true
  capacity_providers_fargate      = true
  capacity_providers_fargate_spot = true
  capacity_providers_ec2 = {
    ec2_default = {
      instance_type               = "t3.medium"
      security_group_ids          = [module.vpc.vpc_default_security_group_id]
      subnet_ids                  = module.subnets.private_subnet_ids
      associate_public_ip_address = false
      min_size                    = 0
      max_size                    = 2
    }
  }
  external_ec2_capacity_providers = {
    external_ec2_default = {
      autoscaling_group_arn          = join("", module.autoscale_group.*.autoscaling_group_arn)
      managed_termination_protection = false
      managed_scaling_status         = false
      instance_warmup_period         = 300
      maximum_scaling_step_size      = 1
      minimum_scaling_step_size      = 1
      target_capacity_utilization    = 100
    }
  }
}

locals {
  cluster_name = var.enabled ? module.ecs_cluster.name : ""
  user_data    = <<EOT
#!/bin/bash
echo ECS_CLUSTER="${local.cluster_name}" >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
echo ECS_POLL_METRICS=true >> /etc/ecs/ecs.config
EOT

}

data "aws_ssm_parameter" "ami" {
  count = var.enabled ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

module "autoscale_group" {
  count   = var.enabled ? 1 : 0
  source  = "cloudposse/ec2-autoscale-group/aws"
  version = "0.31.1"

  context = module.this.context

  image_id                    = join("", data.aws_ssm_parameter.ami.*.value)
  instance_type               = "t3.medium"
  security_group_ids          = [module.vpc.vpc_default_security_group_id]
  subnet_ids                  = module.subnets.private_subnet_ids
  health_check_type           = "EC2"
  desired_capacity            = 0
  min_size                    = 0
  max_size                    = 2
  wait_for_capacity_timeout   = "5m"
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.user_data)

  # Auto-scaling policies and CloudWatch metric alarms
  autoscaling_policies_enabled           = true
  cpu_utilization_high_threshold_percent = "70"
  cpu_utilization_low_threshold_percent  = "20"

  iam_instance_profile_name = module.ecs_cluster.role_name
}
