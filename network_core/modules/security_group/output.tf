output "sg_ssh_public" {
  value = aws_security_group.ssh_public.id
}

output "sg_ssh_private" {
  value = aws_security_group.ssh_private.id
}

output "sg_http_public" {
  value = aws_security_group.http_public.id
}

output "sg_node_p2p" {
  value = aws_security_group.node_p2p.id
}

output "sg_node_rpc" {
  value = aws_security_group.node_rpc.id
}

output "sg_node_stats" {
  value = aws_security_group.node_stats.id
}
