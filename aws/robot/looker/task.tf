resource "aws_ecs_task_definition" "looker" {
  family                   = local.robot_name
  cpu                      = var.task_cpu
  memory                   = var.task_ram
  execution_role_arn       = aws_iam_role.looker_execution.arn
  container_definitions    = module.container.json_map_encoded_list
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

module "container" {
  source                   = "cloudposse/ecs-container-definition/aws"
  version                  = "~> 0"
  readonly_root_filesystem = false
  container_image          = "gastrodon/looker:latest"
  container_name           = "looker"
  container_cpu            = var.task_cpu
  container_memory         = var.task_ram
  secrets = [
    {
      name      = "DISCORD_TOKEN"
      valueFrom = data.aws_secretsmanager_secret.discord_token.arn
    }
  ]

  depends_on = [aws_secretsmanager_secret_version.discord_token]
}
