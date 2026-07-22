resource "aws_security_group" "mc" {
  name   = "minecraft"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "mc_java" {
  to_port           = 25565
  from_port         = 25565
  protocol          = "TCP"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mc.id
}

resource "aws_security_group_rule" "mc_ssh" {
  to_port           = 22
  from_port         = 22
  protocol          = "TCP"
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mc.id
}

resource "aws_security_group_rule" "mc_outbound" {
  to_port           = 0
  from_port         = 0
  protocol          = "-1"
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mc.id
}

# EFS mount targets live behind their own group; only the instance may talk NFS
# to them. Stateful SG lets the response back, so no egress rule is needed.
resource "aws_security_group" "efs" {
  name   = "minecraft-efs"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "efs_nfs" {
  to_port                  = 2049
  from_port                = 2049
  protocol                 = "TCP"
  type                     = "ingress"
  source_security_group_id = aws_security_group.mc.id
  security_group_id        = aws_security_group.efs.id
}
