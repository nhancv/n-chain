output "target_group" {
  value = aws_lb_target_group.rpc.arn
}

output "lb_dns_url" {
  value = aws_lb.rpc.dns_name
}
