# Instance role. The only thing the box does through the AWS API is claim its
# Elastic IP on boot; EFS is mounted over plain NFS, so it needs no IAM.
resource "aws_iam_role" "mc" {
  name = "minecraft-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# AssociateAddress/DescribeAddresses don't support useful resource scoping, so
# they're granted on "*". This account runs one EIP, so the blast radius is nil.
resource "aws_iam_role_policy" "mc_eip" {
  name = "associate-eip"
  role = aws_iam_role.mc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:AssociateAddress", "ec2:DescribeAddresses"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "mc" {
  name = "minecraft-instance"
  role = aws_iam_role.mc.name
}
