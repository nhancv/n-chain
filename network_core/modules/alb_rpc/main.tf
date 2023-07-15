resource "aws_lb" "rpc" {
  name               = "${var.env}-${var.project}-rpc"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group" "rpc" {
  name     = "${var.env}-${var.project}-rpc"
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = "8545"
  lifecycle {
    create_before_destroy = true
  }
  health_check {
    protocol            = "HTTP"
    port                = 8545
    path                = "/liveness"
    matcher             = "200,201,405"
    timeout             = 20
    healthy_threshold   = 2
    unhealthy_threshold = 10
    interval            = 30
  }
  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 86400
  }
}

### CONFIG LOAD BALANCER WITH SSL/HTTPS ###
# Requires certificate_arn which created by ACM
resource "aws_lb_listener" "rpc_https" {
  depends_on = [
    aws_lb.rpc,
    aws_lb_target_group.rpc
  ]

  load_balancer_arn = aws_lb.rpc.arn
  protocol          = "HTTPS"
  port              = "443"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.domain_rpc_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.rpc.arn
  }
}
resource "aws_lb_listener" "rpc_http" {
  depends_on = [aws_lb.rpc]

  load_balancer_arn = aws_lb.rpc.arn
  protocol          = "HTTP"
  port              = "80"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}
#### CONFIG LOAD BALANCER WITHOUT SSL/HTTPS ###
#resource "aws_lb_listener" "rpc_http" {
#  load_balancer_arn = aws_lb.rpc.arn
#  protocol          = "HTTP"
#  port              = "80"
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.rpc.arn
#  }
#}
# Register public domain
resource "aws_route53_record" "rpc_record" {
  depends_on = [aws_lb.rpc, aws_lb_listener.rpc_http]

  zone_id = var.domain_zone_id
  name    = var.domain_rpc
  type    = "A"

  alias {
    name                   = aws_lb.rpc.dns_name
    zone_id                = aws_lb.rpc.zone_id
    evaluate_target_health = true
  }
}
