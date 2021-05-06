data "aws_secretsmanager_secret" "discord_token" {
  name = "looker/DISCORD_TOKEN" // TODO this is stupid
}

resource "aws_secretsmanager_secret_version" "discord_token" {
  secret_id     = data.aws_secretsmanager_secret.discord_token.id
  secret_string = var.discord_token
}
