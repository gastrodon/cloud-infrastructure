resource "aws_security_group" "robot" {
  name   = "robot-security-group"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_security_group_rule" "robot_outbound" {
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.robot.id
}
