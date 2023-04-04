resource "aws_ecs_task_definition" "looker" {
  family                   = "robot-looker"
  cpu                      = var.task_cpu
  memory                   = var.task_ram
  execution_role_arn       = data.terraform_remote_state.execution_role.outputs.task_execution_role_arn
  container_definitions    = module.container.json_map_encoded_list
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
}

resource "aws_cloudwatch_log_group" "looker" {
  name              = "looker"
  retention_in_days = 3
}

module "container" {
  source                   = "cloudposse/ecs-container-definition/aws"
  version                  = "~> 0"
  readonly_root_filesystem = false
  container_image          = "gastrodon/looker:latest"
  container_name           = "looker"
  container_cpu            = var.task_cpu
  container_memory         = var.task_ram

  log_configuration = {
    logDriver = "awslogs",
    options = {
      "awslogs-group" : aws_cloudwatch_log_group.looker.name,
      "awslogs-region" : "us-east-1",
      "awslogs-create-group" : "true",
    }
  }

  secrets = [
    {
      name      = "IFUNNY_BEARER"
      valueFrom = aws_ssm_parameter.ifunny_bearer.arn
    },
    {
      name      = "IFUNNY_ADMIN_ID"
      valueFrom = aws_ssm_parameter.ifunny_admin.arn
    },
    {
      name      = "IFUNNY_STATS_CONNECTION"
      valueFrom = data.terraform_remote_state.looker_database.outputs.database_connection
    },
  ]
}
