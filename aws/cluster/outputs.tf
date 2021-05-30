output "cluster_arn" {
  value = aws_ecs_cluster.cluster.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "node_subnet" {
  value = aws_autoscaling_group.cluster_node.vpc_zone_identifier
}
