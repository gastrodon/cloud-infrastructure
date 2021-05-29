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

resource "aws_launch_configuration" "cluster_node" {
  image_id             = jsondecode(data.aws_ssm_parameter.cluster_node_ami.value)["image_id"]
  iam_instance_profile = aws_iam_instance_profile.cluster_node.name
  security_groups      = [data.terraform_remote_state.security.outputs.group_robots_id]
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config"
  instance_type        = "t2.micro"
}

resource "aws_autoscaling_group" "cluster_node" {
  name                 = "robot-nodes"
  vpc_zone_identifier  = [data.terraform_remote_state.network.outputs.subnet_ids[0]]
  launch_configuration = aws_launch_configuration.cluster_node.name

  desired_capacity          = 1
  min_size                  = 1
  max_size                  = 2
  health_check_grace_period = 180
  health_check_type         = "EC2"
}
