resource "aws_ecs_task_definition" "looker" {
  family                   = "robot-looker"
  cpu                      = var.task_cpu
  memory                   = var.task_ram
  execution_role_arn       = data.terraform_remote_state.execution_role.outputs.task_execution_role_arn
  container_definitions    = module.container.json_map_encoded_list
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
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
      valueFrom = aws_ssm_parameter.discord_token.arn
    }
  ]
}
