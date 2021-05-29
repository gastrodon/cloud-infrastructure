output "group_listener_database_ingress" {
  value = aws_security_group.listener_database_ingress.id
}

output "group_robots_id" {
  value = aws_security_group.robot.id
}
