output "vpc_id" {
  value = aws_vpc.project.id
}

output "subnet_public" {
  value = aws_subnet.public[*].id
}

output "subnet_node_core" {
  value = aws_subnet.node_core[*].id
}

output "subnet_node_lb_p2p" {
  value = aws_subnet.node_lb_p2p[*].id
}

output "subnet_node_stats" {
  value = aws_subnet.node_stats[*].id
}
