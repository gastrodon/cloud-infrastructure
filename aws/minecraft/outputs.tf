output "server_address" {
  value = aws_eip.mc.public_ip
}

output "autoscaling_group" {
  value = aws_autoscaling_group.mc.name
}

output "efs_id" {
  value = aws_efs_file_system.mc.id
}

output "ami_id" {
  value = aws_ami.mc.id
}

output "modpack_bucket" {
  value = aws_s3_bucket.modpack.bucket
}

# Stable public URL for the modpack once the zip is uploaded to the bucket.
output "modpack_url" {
  value = "https://${aws_s3_bucket.modpack.bucket}.s3.amazonaws.com/${var.modpack_key}"
}
