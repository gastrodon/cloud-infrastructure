data "aws_iam_policy_document" "nomad" {
  statement {
    actions = [
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:Decrypt",
      "s3:*",
      "ec2:*",
      "ecr:*",
      "iam:*",
      "kms:*",
      "iam:*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags_all
}

resource "aws_iam_role_policy" "describe_instance" {
  name   = "${var.name}-describe-instance"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.nomad.json
}

resource "aws_iam_instance_profile" "instance" {
  name = aws_iam_role_policy.describe_instance.name
  role = aws_iam_role.instance.id
  tags = local.tags_all
}
