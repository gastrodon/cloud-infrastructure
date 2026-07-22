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
