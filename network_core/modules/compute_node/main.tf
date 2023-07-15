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
# Enode P2P LB
resource "aws_lb" "p2p" {
  name               = "${var.env}-${var.project}-p2p-${var.node_id}"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_node_lb_p2p
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group" "p2p" {
  name     = "${var.env}-${var.project}-p2p-${var.node_id}"
  vpc_id   = var.vpc_id
  protocol = "TCP_UDP"
  port     = "30303"
  lifecycle {
    create_before_destroy = true
  }
}
# Register internal listener & domain
resource "aws_lb_listener" "p2p_http" {
  load_balancer_arn = aws_lb.p2p.arn
  protocol          = "TCP_UDP"
  port              = "30303"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.p2p.arn
  }
}
resource "aws_route53_record" "p2p_record" {
  depends_on = [aws_lb.p2p, aws_lb_listener.p2p_http]

  zone_id = var.domain_zone_id
  name    = var.domain_node
  type    = "A"

  alias {
    name                   = aws_lb.p2p.dns_name
    zone_id                = aws_lb.p2p.zone_id
    evaluate_target_health = true
  }
}


###########
## APP PROJECT
###########
resource "aws_iam_role" "node" {
  name = "${var.env}-${var.project}-iam-role-node-${var.node_id}"

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
    tag-key = "${var.env}-${var.project}-node-${var.node_id}"
  }
}
resource "aws_iam_role_policy" "node" {
  name = "${var.env}-${var.project}-iam-role-pl-node-${var.node_id}"
  role = aws_iam_role.node.id

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
resource "aws_iam_instance_profile" "node" {
  name = "${var.env}-${var.project}-iam-profile-node-${var.node_id}"
  role = aws_iam_role.node.name
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_launch_template" "node" {
  name                   = "${var.env}-${var.project}-node-${var.node_id}"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_conf.type
  vpc_security_group_ids = var.security_groups_private
  key_name               = var.access_key_id
  update_default_version = true
  user_data              = base64encode(templatefile("scripts/networkcore.sh", {
    ENV             = var.env
    NODE_ID         = var.node_id
    ENCRYPT_KEY     = var.encrypt_key
    ETHSTATS_SECRET = var.ethstats_secret
    ETHSTATS_PUSH   = var.ethstats_push
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.node.name
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
      Name = "${var.env}-${var.project}-node-${var.node_id}"
    }
  }

  tags = {
    Name = "${var.env}-${var.project}-lt-node-${var.node_id}"
  }
}
resource "aws_autoscaling_group" "node" {
  name                 = "${var.env}-${var.project}-node-${var.node_id}"
  vpc_zone_identifier  = var.subnet_node_compute
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
  target_group_arns    = [aws_lb_target_group.p2p.arn, var.rpc_target_group_arn]
  lifecycle {
    create_before_destroy = true
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }
}
