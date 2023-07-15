output "sg_ssh_public" {
  value = aws_security_group.ssh_public.id
}

output "sg_ssh_private" {
  value = aws_security_group.ssh_private.id
}

output "sg_http_public" {
  value = aws_security_group.http_public.id
}

output "sg_project_private" {
  value = aws_security_group.project_private.id
}
