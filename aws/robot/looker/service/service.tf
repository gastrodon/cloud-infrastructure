resource "aws_ecs_service" "looker" {
  name = "looker"

  task_definition      = data.terraform_remote_state.definition.outputs.task_definition_family
  cluster              = data.terraform_remote_state.cluster.outputs.cluster_name
  desired_count        = 1
  launch_type          = "EC2"
  force_new_deployment = true
}
