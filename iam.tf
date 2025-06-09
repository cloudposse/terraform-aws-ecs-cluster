module "role" {
  source  = "SevenPicoForks/iam-role/aws"
  version = "2.0.2"
  context = module.context.self

  instance_profile_enabled = true
  max_session_duration     = 3600
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  ]
  path                  = "/"
  permissions_boundary  = ""
  policy_description    = "Policy for EC2 Capacity providers"
  policy_document_count = length(var.policy_document)
  policy_documents      = var.policy_document
  principals = {
    Service = ["ec2.amazonaws.com"]
  }
  role_description = "IAM role for EC2 test instances in ${each.key} layer"
  use_fullname     = true
}
