data "aws_ami" "ubuntu" {
  most_recent = true

  // http://cloud-images.ubuntu.com/locator/ec2/
  // https://www.kisphp.com/terraform/terraform-find-ubuntu-and-amazon-linux-2-amis
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self", "amazon", "099720109477"]
}

###########
## ALB PROJECT
###########
# This alb places at public subnet and forward traffic internet to project subnet
resource "aws_lb" "explorer" {
  #  name               = "${var.env}-${var.project}-explorer-${substr(uuid(), 0, 3)}"
  name               = "${var.env}-${var.project}-explorer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups_lb
  subnets            = var.subnets_lb
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
}

resource "aws_lb_target_group" "explorer" {
  #  name     = "${var.env}-${var.project}-explorer-${substr(uuid(), 0, 3)}"
  name     = "${var.env}-${var.project}-explorer"
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = "8888"
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
  health_check {
    port                = 8888
    protocol            = "HTTP"
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

### CONFIG LOAD BALANCER WITH SSL/HTTPS ###
# Requires certificate_arn which created by ACM
resource "aws_lb_listener" "explorer_https" {
  depends_on = [
    aws_lb.explorer,
    aws_lb_target_group.explorer
  ]

  load_balancer_arn = aws_lb.explorer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.domain_explore_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.explorer.arn
  }
}
resource "aws_lb_listener" "explorer_http" {
  depends_on = [aws_lb.explorer]

  load_balancer_arn = aws_lb.explorer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
# Register domain
resource "aws_route53_record" "lb_explorer_record" {
  depends_on = [aws_lb.explorer, aws_lb_listener.explorer_https]

  zone_id = var.domain_zone_id
  name    = var.domain_explore
  type    = "A"

  alias {
    name                   = aws_lb.explorer.dns_name
    zone_id                = aws_lb.explorer.zone_id
    evaluate_target_health = true
  }
}
resource "aws_route53_record" "ethernal_app_record" {
  depends_on = [aws_lb.explorer, aws_lb_listener.explorer_https]

  zone_id = var.domain_zone_id
  name    = "app.${var.domain_explore}"
  type    = "A"

  alias {
    name                   = aws_lb.explorer.dns_name
    zone_id                = aws_lb.explorer.zone_id
    evaluate_target_health = true
  }
}

### CONFIG LOAD BALANCER WITHOUT SSL/HTTPS ###
#resource "aws_lb_listener" "explorer_http" {
#  load_balancer_arn = aws_lb.explorer.arn
#  port              = "80"
#  protocol          = "HTTP"
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.explorer.arn
#  }
#}

###########
## APP PROJECT
###########
resource "aws_iam_role" "explorer" {
  name = "${var.env}-${var.project}-iam-role-explorer"

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
    tag-key = "${var.env}-${var.project}-explorer"
  }
}
resource "aws_iam_role_policy" "explorer" {
  name = "${var.env}-${var.project}-iam-role-pl-explorer"
  role = aws_iam_role.explorer.id

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

resource "aws_iam_instance_profile" "explorer" {
  name = "${var.env}-${var.project}-iam-profile-explorer"
  role = aws_iam_role.explorer.name
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
}

resource "aws_launch_template" "explorer" {
  name                   = "${var.env}-${var.project}-explorer"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_conf.type
  vpc_security_group_ids = var.security_groups_app
  key_name               = var.access_key_id
  update_default_version = true
  user_data = base64encode(templatefile("scripts/ethernal.sh", {
    ENV               = var.env
    ETHERNAL_USER     = var.ethernal_user
    ETHERNAL_PASSWORD = var.ethernal_password
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.explorer.name
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
    tags = {
      Name = "${var.env}-${var.project}-explorer"
    }
  }

  tags = {
    Name = "${var.env}-${var.project}-lt-explorer"
  }
}

resource "aws_autoscaling_group" "explorer" {
  name                = "${var.env}-${var.project}-explorer"
  vpc_zone_identifier = var.subnets_app
  min_size            = var.instance_conf.min_size
  max_size            = var.instance_conf.max_size
  desired_capacity    = var.instance_conf.desired_capacity
  health_check_type   = "EC2"
  termination_policies = ["OldestInstance"]
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"
  target_group_arns = [aws_lb_target_group.explorer.arn]
  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.explorer.id
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
