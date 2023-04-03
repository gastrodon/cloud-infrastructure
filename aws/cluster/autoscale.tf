data "aws_region" "current" {}

data "aws_ssm_parameter" "cluster_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

data "aws_iam_policy_document" "cluster_node" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_node" {
  name               = "robot-nodes"
  assume_role_policy = data.aws_iam_policy_document.cluster_node.json
}

resource "aws_iam_role_policy_attachment" "cluster_node" {
  role       = aws_iam_role.cluster_node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "cluster_node" {
  name = "robot-nodes"
  role = aws_iam_role.cluster_node.name
}

resource "aws_key_pair" "cluster_node" {
  key_name   = "cluster-node"
  public_key = var.public_key
  lifecycle {
    ignore_changes = [public_key]
  }
}

locals {
  node_user_data = templatefile("${path.module}/documents/user_data.sh", {
    cluster_name = aws_ecs_cluster.cluster.name,
    region       = data.aws_region.current.name
  })
}

resource "aws_launch_configuration" "cluster_node" {
  image_id             = jsondecode(data.aws_ssm_parameter.cluster_node_ami.value)["image_id"]
  iam_instance_profile = aws_iam_instance_profile.cluster_node.name
  user_data            = local.node_user_data
  instance_type        = "t3.small"
  key_name             = aws_key_pair.cluster_node.key_name

  security_groups = [
    data.terraform_remote_state.security.outputs.group_robots_id,
    data.terraform_remote_state.security.outputs.group_listener_database_ingress,
  ]
}

resource "aws_autoscaling_group" "cluster_node" {
  name                 = "robot-nodes"
  launch_configuration = aws_launch_configuration.cluster_node.name

  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 2
  health_check_grace_period = 180
  health_check_type         = "EC2"

  vpc_zone_identifier = [
    data.terraform_remote_state.network.outputs.subnet_ids[0],
    data.terraform_remote_state.network.outputs.subnet_ids[2],
  ]
}
