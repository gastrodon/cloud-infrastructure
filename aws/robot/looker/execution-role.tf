# TODO this should be it's own thing
# it should be used by any other robots I may deploy

data "aws_iam_policy_document" "looker_execution" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "looker_execution" {
  name               = "looker-task-execution"
  assume_role_policy = data.aws_iam_policy_document.looker_execution.json
}

resource "aws_iam_role_policy_attachment" "get_containers" {
  role       = aws_iam_role.looker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "get_secrets" {
  role       = aws_iam_role.looker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}
