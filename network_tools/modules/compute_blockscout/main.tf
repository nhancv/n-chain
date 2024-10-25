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
resource "aws_lb" "blockscout" {
  #  name               = "${var.env}-${var.project}-blockscout-${substr(uuid(), 0, 3)}"
  name               = "${var.env}-${var.project}-blockscout"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups_lb
  subnets            = var.subnets_lb
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
}

resource "aws_lb_target_group" "blockscout" {
  # name     = "${var.env}-${var.project}-blockscout-${substr(uuid(), 0, 3)}"
  name     = "${var.env}-${var.project}-blockscout"
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = "80"
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
  health_check {
    port                = 80
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
resource "aws_lb_target_group" "blockscout_stats" {
  name     = "${var.env}-${var.project}-blockscout2"
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = "8080"
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
  health_check {
    port                = 8080
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
resource "aws_lb_target_group" "blockscout_visualize" {
  name     = "${var.env}-${var.project}-blockscout3"
  vpc_id   = var.vpc_id
  protocol = "HTTP"
  port     = "8081"
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
  health_check {
    port                = 8081
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
resource "aws_lb_listener" "blockscout_https" {
  depends_on = [
    aws_lb.blockscout,
    aws_lb_target_group.blockscout
  ]

  load_balancer_arn = aws_lb.blockscout.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.domain_blockscout_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blockscout.arn
  }
}
resource "aws_lb_listener" "blockscout_http" {
  depends_on = [aws_lb.blockscout]

  load_balancer_arn = aws_lb.blockscout.arn
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
resource "aws_lb_listener" "blockscout_https_stats" {
  depends_on = [
    aws_lb.blockscout,
    aws_lb_target_group.blockscout_stats
  ]

  load_balancer_arn = aws_lb.blockscout.arn
  port              = "8080"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.domain_blockscout_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blockscout_stats.arn
  }
}
resource "aws_lb_listener" "blockscout_https_visualize" {
  depends_on = [
    aws_lb.blockscout,
    aws_lb_target_group.blockscout_visualize
  ]

  load_balancer_arn = aws_lb.blockscout.arn
  port              = "8081"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.domain_blockscout_cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blockscout_visualize.arn
  }
}
# Register domain
resource "aws_route53_record" "lb_blockscout_record" {
  depends_on = [
    aws_lb.blockscout, aws_lb_listener.blockscout_https, aws_lb_listener.blockscout_https_stats,
    aws_lb_listener.blockscout_https_visualize
  ]

  zone_id = var.domain_zone_id
  name    = var.domain_blockscout
  type    = "A"

  alias {
    name                   = aws_lb.blockscout.dns_name
    zone_id                = aws_lb.blockscout.zone_id
    evaluate_target_health = true
  }
}

### CONFIG LOAD BALANCER WITHOUT SSL/HTTPS ###
#resource "aws_lb_listener" "blockscout_http" {
#  load_balancer_arn = aws_lb.blockscout.arn
#  port              = "80"
#  protocol          = "HTTP"
#
#  default_action {
#    type             = "forward"
#    target_group_arn = aws_lb_target_group.blockscout.arn
#  }
#}

###########
## APP PROJECT
###########
resource "aws_iam_role" "blockscout" {
  name = "${var.env}-${var.project}-iam-role-blockscout"

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
    tag-key = "${var.env}-${var.project}-blockscout"
  }
}
resource "aws_iam_role_policy" "blockscout" {
  name = "${var.env}-${var.project}-iam-role-pl-blockscout"
  role = aws_iam_role.blockscout.id

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

resource "aws_iam_instance_profile" "blockscout" {
  name = "${var.env}-${var.project}-iam-profile-blockscout"
  role = aws_iam_role.blockscout.name
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
}

resource "aws_launch_template" "blockscout" {
  name                   = "${var.env}-${var.project}-blockscout"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_conf.type
  vpc_security_group_ids = var.security_groups_app
  key_name               = var.access_key_id
  update_default_version = true
  user_data = base64encode(templatefile("scripts/blockscout.sh", {
    ENV                 = var.env
    BLOCKSCOUT_RPC      = var.blockscout_rpc
    BLOCKSCOUT_CHAINID  = var.blockscout_chainid
    BLOCKSCOUT_URL      = var.domain_blockscout
    BLOCKSCOUT_PROTOCOL = "https"
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.blockscout.name
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
      Name = "${var.env}-${var.project}-blockscout"
    }
  }

  tags = {
    Name = "${var.env}-${var.project}-lt-blockscout"
  }
}

resource "aws_autoscaling_group" "blockscout" {
  name                = "${var.env}-${var.project}-blockscout"
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
  target_group_arns = [
    aws_lb_target_group.blockscout.arn, aws_lb_target_group.blockscout_stats.arn,
    aws_lb_target_group.blockscout_visualize.arn
  ]
  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.blockscout.id
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
