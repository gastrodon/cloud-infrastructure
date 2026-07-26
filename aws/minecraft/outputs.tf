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

# Stable public URL for the server artefact zip (config source for glade-pack.nix).
output "modpack_url" {
  value = "https://${aws_s3_bucket.modpack.bucket}.s3.amazonaws.com/${var.modpack_key}"
}

# Stable public URL for the Prism-importable client pack, refreshed on every
# apply alongside the server build.
output "client_pack_url" {
  value = "https://${aws_s3_bucket.modpack.bucket}.s3.amazonaws.com/${aws_s3_object.client_pack.key}"
}
