output "sg_ssh_public" {
  value = aws_security_group.ssh_public.id
}

output "sg_ssh_private" {
  value = aws_security_group.ssh_private.id
}

output "sg_http_public" {
  value = aws_security_group.http_public.id
}

output "sg_project_ethernal" {
  value = aws_security_group.project_ethernal.id
}

output "sg_project_blockscout" {
  value = aws_security_group.project_blockscout.id
}
