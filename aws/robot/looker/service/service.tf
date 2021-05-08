resource "aws_ecs_service" "looker" {
  name = "looker"

  task_definition      = data.terraform_remote_state.definition.outputs.task_definition_family
  cluster              = data.terraform_remote_state.cluster.outputs.cluster_name
  desired_count        = 1
  launch_type          = "FARGATE"
  force_new_deployment = true

  network_configuration {
    assign_public_ip = true
    security_groups  = [data.terraform_remote_state.security.outputs.group_robots_id]
    subnets          = data.terraform_remote_state.network.outputs.subnet_ids
  }
}
