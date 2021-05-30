resource "aws_security_group" "database" {
  name   = "listener-database"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_security_group_rule" "database_mysql_inbound" {
  to_port                  = 3306
  from_port                = 3306
  protocol                 = "TCP"
  type                     = "ingress"
  source_security_group_id = data.terraform_remote_state.security.outputs.group_listener_database_ingress
  security_group_id        = aws_security_group.database.id
}

resource "aws_security_group_rule" "database_outbound" {
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.database.id
}
