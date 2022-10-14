resource "aws_iam_instance_profile" "default" {
  count = local.enabled ? 1 : 0
  name  = module.this.id
  role  = module.this.id
}

resource "aws_iam_role" "default" {
  count = local.enabled ? 1 : 0

  name = module.this.id
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed_policy" {
  count      = local.enabled ? 1 : 0
  role       = join("", aws_iam_role.default.*.name)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role" {
  role       = join("", aws_iam_role.default.*.name)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm_core_role" {
  role       = join("", aws_iam_role.default.*.name)
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
