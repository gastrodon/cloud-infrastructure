# AMI pipeline, entirely in Terraform.
#
# There is no official NixOS AMI, and no single resource turns a local disk
# image into an AMI — VM Import inherently goes image → S3 → snapshot → register.
# So the chain is:
#
#   null_resource.ami_build   nix build → ami-image.json + result-ami symlink
#   data.local_file           read that metadata back
#   aws_s3_object.image       stage the image in a private bucket
#   aws_ebs_snapshot_import   VM Import it into an EBS snapshot
#   aws_ami.mc                register the snapshot as an AMI
#
# Everything downstream is keyed on the image's content hash, so an unchanged
# config rebuilds to the same AMI (no churn) while a real change rolls a new one
# automatically. To force a fresh build:  tofu apply -replace=null_resource.ami_build

locals {
  repo_root = abspath("${path.module}/../..")

  # Hash the inputs to the image so the build re-runs whenever the shared server
  # config or flake pins change. Cheap to compute at plan time; the null_resource
  # only re-runs when this value moves.
  ami_src_hash = sha256(join("", concat(
    [
      filesha256("${local.repo_root}/flake.nix"),
      filesha256("${local.repo_root}/flake.lock"),
    ],
    [
      for f in sort(tolist(fileset("${local.repo_root}/minecraft", "**"))) :
      filesha256("${local.repo_root}/minecraft/${f}")
    ],
  )))

  img = jsondecode(data.local_file.ami_image.content)
}

# Runs the nix build. Kept (not tainted each apply): the source hash trigger
# rebuilds only when the config changes, and `-replace` forces it on demand.
resource "null_resource" "ami_build" {
  triggers = {
    src = local.ami_src_hash
  }

  provisioner "local-exec" {
    command = "${path.module}/build-ami.sh"
    environment = {
      OUT_JSON = "${path.module}/ami-image.json"
    }
  }
}

# Read the metadata the build wrote. depends_on defers the read to apply time,
# so on the first run (before ami-image.json exists) plan doesn't choke.
data "local_file" "ami_image" {
  filename   = "${path.module}/ami-image.json"
  depends_on = [null_resource.ami_build]
}

# Private staging bucket for the disk image. Only the VM Import service role
# reads it; nothing here is public (unlike the modpack bucket).
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

# The role AWS's VM Import service assumes to do the import. import-snapshot is
# async — the actual image→snapshot conversion runs as vmie.amazonaws.com, not
# as the tofu caller — so AWS requires a role for it to assume. We create it here
# (own name, not the account-wide "vmimport") so the whole pipeline is
# self-contained: no out-of-band prerequisite. The ExternalId is the fixed
# "vmimport" value AWS's service passes, regardless of the role's actual name.
resource "aws_iam_role" "vmimport" {
  name = "minecraft-vmimport"

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

# Read the staged image from the private bucket + write the snapshot back.
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

# Stage the built image. source_hash re-uploads on content change without
# fighting S3's own etag (the source is a multi-GB store path).
resource "aws_s3_object" "image" {
  bucket      = aws_s3_bucket.ami.id
  key         = "ami/${local.img.hash}.${local.img.ext}"
  source      = local.img.file
  source_hash = local.img.hash
}

resource "aws_ebs_snapshot_import" "mc" {
  disk_container {
    description = "minecraft-nixos-${local.img.hash}"
    format      = local.img.format
    user_bucket {
      s3_bucket = aws_s3_bucket.ami.id
      s3_key    = aws_s3_object.image.key
    }
  }

  role_name = aws_iam_role.vmimport.name
  tags      = { Name = "minecraft-nixos-${local.img.hash}" }

  # The role must exist (and its policy be attached) before the service can
  # assume it. Fresh IAM roles can lag propagation; if import fails on assume,
  # a re-apply picks up where it left off.
  depends_on = [aws_iam_role_policy.vmimport]

  timeouts {
    create = "60m"
  }
}

resource "aws_ami" "mc" {
  name                = "minecraft-nixos-${local.img.hash}"
  architecture        = "x86_64"
  virtualization_type = "hvm"
  boot_mode           = local.img.boot_mode
  ena_support         = true
  sriov_net_support   = "simple"
  imds_support        = "v2.0"
  root_device_name    = "/dev/xvda"

  ebs_block_device {
    device_name           = "/dev/xvda"
    snapshot_id           = aws_ebs_snapshot_import.mc.id
    volume_type           = "gp3"
    delete_on_termination = true
  }
}
