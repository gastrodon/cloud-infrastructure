resource "aws_ssm_parameter" "discord_token" {
  name  = "/robot/looker/DISCORD_TOKEN"
  value = var.discord_token
  type  = "SecureString"
}
