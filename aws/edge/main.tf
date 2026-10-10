# dc `public`: shared network, storage and AMI; one module block per edge box.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "edge" {
  name   = "edge"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "edge_tcp" {
  for_each          = toset(["25", "80", "443"])
  security_group_id = aws_security_group.edge.id
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "edge_wireguard" {
  security_group_id = aws_security_group.edge.id
  ip_protocol       = "udp"
  from_port         = 51820
  to_port           = 51820
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "edge_ssh" {
  for_each          = toset(var.ssh_cidrs)
  security_group_id = aws_security_group.edge.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "edge_all" {
  security_group_id = aws_security_group.edge.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "efs" {
  name   = "edge-efs"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "efs_nfs" {
  security_group_id            = aws_security_group.efs.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.edge.id
}

# Small identity-bearing state (acme.json), one directory per box; any AZ can mount it.
resource "aws_efs_file_system" "edge" {
  encrypted = true
  tags      = { Name = "edge" }
}

resource "aws_efs_mount_target" "edge" {
  for_each        = toset(data.aws_subnets.default.ids)
  file_system_id  = aws_efs_file_system.edge.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

module "edge1" {
  source = "./node"

  name              = "edge1"
  tunnel_ip         = "10.77.0.101"
  ami_id            = aws_ami.edge.id
  instance_types    = var.instance_types
  subnet_ids        = data.aws_subnets.default.ids
  security_group_id = aws_security_group.edge.id
  efs_id            = aws_efs_file_system.edge.id
  home_peers        = var.home_peers

  depends_on = [aws_efs_mount_target.edge]
}
