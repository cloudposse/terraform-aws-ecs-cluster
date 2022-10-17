locals {
  policies_to_attach = toset([
    "AmazonECSTaskExecutionRolePolicy",
    "AmazonEC2ContainerServiceforEC2Role",
    "AmazonSSMManagedInstanceCore"
  ])
}

resource "aws_iam_instance_profile" "default" {
  count = local.enabled ? 1 : 0
  name  = module.this.id
  role  = module.this.id
}

data "aws_iam_policy_document" "assume" {
  count = local.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    effect = "Allow"
  }
}

resource "aws_iam_role" "default" {
  count = local.enabled ? 1 : 0

  name = module.this.id
  path = "/"

  assume_role_policy = join("", data.aws_iam_policy_document.assume.*.json)
}

data "aws_partition" "current" {
  count = local.enabled ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "default" {
  for_each   = local.enabled ? local.policies_to_attach : []
  role       = join("", aws_iam_role.default.*.name)
  policy_arn = format("arn:%s:iam::aws:policy/%s", join("", data.aws_partition.current.*.partition), each.value)
  depends_on = [
    aws_iam_role.default
  ]
}
