data "aws_ami" "ubuntu" {
  most_recent = true

  // http://cloud-images.ubuntu.com/locator/ec2/
  // https://www.kisphp.com/terraform/terraform-find-ubuntu-and-amazon-linux-2-amis
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self", "amazon", "099720109477"]
}

###########
## ALB PROJECT
###########
# Public HTTPs load balancer for stats monitoring
#region stats_view
resource "aws_lb" "stats_view" {
  name               = "${var.env}-${var.project}-stats-view"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups_lb
  subnets            = var.subnets_lb
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group" "stats_view" {
  name     = "${var.env}-${var.project}-stats-view"
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = "3000"
  lifecycle {
    create_before_destroy = true
  }
  health_check {
    protocol            = "HTTP"
    port                = 3000
    path                = "/"
    matcher             = "200,202,404"
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
resource "aws_lb_listener" "stats_view_https" {
  depends_on = [
    aws_lb.stats_view,
    aws_lb_target_group.stats_view
  ]

  load_balancer_arn = aws_lb.stats_view.arn
  protocol          = "HTTPS"
  port              = "443"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.domain_stats_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stats_view.arn
  }
}
resource "aws_lb_listener" "stats_view_http" {
  depends_on = [aws_lb.stats_view]

  load_balancer_arn = aws_lb.stats_view.arn
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
resource "aws_route53_record" "stats_view_record" {
  depends_on = [aws_lb.stats_view, aws_lb_listener.stats_view_https]

  zone_id = var.domain_zone_id
  name    = var.domain_stats_https
  type    = "A"

  alias {
    name                   = aws_lb.stats_view.dns_name
    zone_id                = aws_lb.stats_view.zone_id
    evaluate_target_health = true
  }
}
# endregion

# Private HTTP load balancer for stats pushing data
#region stats_push
resource "aws_lb" "stats_push" {
  name               = "${var.env}-${var.project}-stats-push"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnets_app
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group" "stats_push" {
  #name     = "${var.env}-${var.project}-stats-push-${substr(uuid(), 0, 2)}"
  name     = "${var.env}-${var.project}-stats-push"
  vpc_id   = var.vpc_id
  protocol = "TCP_UDP"
  port     = "3000"
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_listener" "stats_push_http" {
  load_balancer_arn = aws_lb.stats_push.arn
  protocol          = "TCP_UDP"
  port              = "3000"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stats_push.arn
  }
}
resource "aws_route53_record" "stats_push_record" {
  depends_on = [aws_lb.stats_push, aws_lb_listener.stats_push_http]

  zone_id = var.domain_zone_id
  name    = var.domain_stats_push
  type    = "A"

  alias {
    name                   = aws_lb.stats_push.dns_name
    zone_id                = aws_lb.stats_push.zone_id
    evaluate_target_health = true
  }
}
# endregion

###########
## APP PROJECT
###########
resource "aws_iam_role" "stats" {
  name = "${var.env}-${var.project}-iam-role-stats"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    tag-key = "${var.env}-${var.project}-stats"
  }
}
resource "aws_iam_role_policy" "stats" {
  name = "${var.env}-${var.project}-iam-role-pl-stats"
  role = aws_iam_role.stats.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GetSecretValue",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:${var.env}-${var.project}-*"
      ]
    },
    {
      "Sid": "AttachEBSVolume",
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:DetachVolume"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:instance/*"
      ],
      "Condition": {
        "ArnEquals": {"ec2:SourceInstanceARN": "arn:aws:ec2:*:*:instance/*"}
      }
    }
  ]
}
EOF

}

resource "aws_iam_instance_profile" "stats" {
  name = "${var.env}-${var.project}-iam-profile-stats"
  role = aws_iam_role.stats.name
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "project" {
  name                   = "${var.env}-${var.project}-stats"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_conf.type
  vpc_security_group_ids = var.security_groups_app
  key_name               = var.access_key_id
  update_default_version = true
  user_data              = base64encode(templatefile("scripts/networkstats.sh", {
    ENV             = var.env
    ETHSTATS_SECRET = var.ethstats_secret
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.stats.name
  }

  monitoring {
    enabled = true
  }

  // Root: Ubuntu Server 20.04 LTS (HVM)
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 50
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = {
      Name = "${var.env}-${var.project}-stats"
    }
  }

  tags = {
    Name = "${var.env}-${var.project}-lt-stats"
  }
}

resource "aws_autoscaling_group" "project" {
  name                 = "${var.env}-${var.project}-stats"
  vpc_zone_identifier  = var.subnets_app
  min_size             = var.instance_conf.min_size
  max_size             = var.instance_conf.max_size
  desired_capacity     = var.instance_conf.desired_capacity
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]
  enabled_metrics      = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity  = "1Minute"
  target_group_arns    = [aws_lb_target_group.stats_view.arn, aws_lb_target_group.stats_push.arn]
  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.project.id
    version = "$Latest"
  }

  tag {
    key                 = "Key"
    value               = "Value"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }
}
