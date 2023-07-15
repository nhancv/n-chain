output "vpc_id" {
  value = aws_vpc.project.id
}

output "subnet_public" {
  value = aws_subnet.public[*].id
}

output "subnet_project" {
  value = aws_subnet.project[*].id
}
