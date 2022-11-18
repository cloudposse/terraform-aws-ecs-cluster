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
    default = {
      instance_type               = "t3.medium"
      security_group_ids          = [module.vpc.vpc_default_security_group_id]
      subnet_ids                  = module.subnets.private_subnet_ids
      associate_public_ip_address = false
      min_size                    = 0
      max_size                    = 2
    }
  }
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

module "autoscale_group" {
  source  = "cloudposse/ec2-autoscale-group/aws"
  version = "0.31.1"

  name    = "external-capacity-provider"
  context = module.this.context

  image_id                    = data.aws_ssm_parameter.ami.value
  instance_type               = "t3.medium"
  security_group_ids          = [module.vpc.vpc_default_security_group_id]
  subnet_ids                  = module.subnets.private_subnet_ids
  health_check_type           = "EC2"
  min_size                    = 0
  max_size                    = 2
  wait_for_capacity_timeout   = "5m"
  associate_public_ip_address = false
  user_data_base64            = ""

  # Auto-scaling policies and CloudWatch metric alarms
  autoscaling_policies_enabled           = true
  cpu_utilization_high_threshold_percent = "70"
  cpu_utilization_low_threshold_percent  = "20"
}
