# Same pipeline as aws/minecraft/ami.tf, but the image comes from lab/nix-modules at a pinned rev.

locals {
  img = jsondecode(data.local_file.ami_image.content)
}

resource "null_resource" "ami_build" {
  triggers = {
    rev = var.nix_modules_rev
  }

  provisioner "local-exec" {
    command = "${path.module}/build-ami.sh"
    environment = {
      OUT_JSON = "${path.module}/ami-image.json"
      REV      = var.nix_modules_rev
    }
  }
}

data "local_file" "ami_image" {
  filename   = "${path.module}/ami-image.json"
  depends_on = [null_resource.ami_build]
}

resource "aws_s3_bucket" "ami" {
  bucket = var.ami_bucket
}

resource "aws_s3_bucket_public_access_block" "ami" {
  bucket = aws_s3_bucket.ami.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keeps only the newest staged images; the snapshots are what the AMIs need.
resource "aws_s3_bucket_lifecycle_configuration" "ami" {
  bucket = aws_s3_bucket.ami.id

  rule {
    id     = "expire-staged-images"
    status = "Enabled"
    filter {}
    expiration {
      days = 7
    }
  }
}

resource "aws_iam_role" "vmimport" {
  name = "edge-vmimport"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vmie.amazonaws.com" }
      Condition = { StringEquals = { "sts:ExternalId" = "vmimport" } }
    }]
  })
}

resource "aws_iam_role_policy" "vmimport" {
  name = "import"
  role = aws_iam_role.vmimport.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.ami.arn, "${aws_s3_bucket.ami.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_s3_object" "image" {
  bucket      = aws_s3_bucket.ami.id
  key         = "ami/${local.img.hash}.${local.img.ext}"
  source      = local.img.file
  source_hash = local.img.hash
}

resource "aws_ebs_snapshot_import" "edge" {
  disk_container {
    description = "edge-nixos-${local.img.hash}"
    format      = local.img.format
    user_bucket {
      s3_bucket = aws_s3_bucket.ami.id
      s3_key    = aws_s3_object.image.key
    }
  }

  role_name  = aws_iam_role.vmimport.name
  tags       = { Name = "edge-nixos-${local.img.hash}" }
  depends_on = [aws_iam_role_policy.vmimport]

  timeouts {
    create = "60m"
  }
}

resource "aws_ami" "edge" {
  name                = "edge-nixos-${local.img.hash}"
  architecture        = "x86_64"
  virtualization_type = "hvm"
  boot_mode           = local.img.boot_mode
  ena_support         = true
  sriov_net_support   = "simple"
  imds_support        = "v2.0"
  root_device_name    = "/dev/xvda"

  ebs_block_device {
    device_name           = "/dev/xvda"
    snapshot_id           = aws_ebs_snapshot_import.edge.id
    volume_type           = "gp3"
    delete_on_termination = true
  }
}
