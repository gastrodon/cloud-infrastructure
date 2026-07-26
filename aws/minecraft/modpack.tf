# Public bucket hosting the modpack zip so the server (and clients) can pull it
# over a stable URL. Public read is intentional — see the plan.
resource "aws_s3_bucket" "modpack" {
  bucket = var.modpack_bucket
}

resource "aws_s3_bucket_public_access_block" "modpack" {
  bucket = aws_s3_bucket.modpack.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "modpack_public_read" {
  bucket = aws_s3_bucket.modpack.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.modpack.arn}/*"
      }
    ]
  })

  # Policy can only be applied once public access is unblocked.
  depends_on = [aws_s3_bucket_public_access_block.modpack]
}

# --- Publish the client pack alongside the server build ---------------------
# The public bucket also serves the Glade *client* pack (a Prism-importable
# instance zip) so players always download a client that matches the deployed
# server. It's built from the SAME manifest (minecraft/pack/glade-mods.*) as the
# server mod set, in lockstep with the AMI: this reuses local.ami_src_hash (which
# already fingerprints minecraft/**) as the trigger, so any server-mod change
# re-runs the client build and re-uploads on the same apply.
#
# Published under its own key (the zip's own filename), NOT the server artefact
# key (var.modpack_key / glade-pack.zip), which glade-pack.nix still pins for the
# config tree — the two objects are independent.
resource "null_resource" "client_build" {
  triggers = {
    src = local.ami_src_hash
  }

  provisioner "local-exec" {
    command = "${path.module}/build-client.sh"
    environment = {
      OUT_JSON = "${path.module}/client-pack.json"
    }
  }
}

data "local_file" "client_pack" {
  filename   = "${path.module}/client-pack.json"
  depends_on = [null_resource.client_build]
}

locals {
  client = jsondecode(data.local_file.client_pack.content)
}

resource "aws_s3_object" "client_pack" {
  bucket      = aws_s3_bucket.modpack.id
  key         = local.client.name
  source      = local.client.file
  source_hash = local.client.hash

  # Public read is granted by the bucket policy above.
  depends_on = [aws_s3_bucket_policy.modpack_public_read]
}
