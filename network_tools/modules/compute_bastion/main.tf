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
## BASTION
###########
resource "aws_iam_role" "bastion" {
  name = "${var.env}-${var.project}-iam-role-bastion"

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
    tag-key = "${var.env}-${var.project}-bastion"
  }
}

resource "aws_iam_role_policy" "bastion" {
  name = "${var.env}-${var.project}-iam-role-pl-bastion-secretmanager"
  role = aws_iam_role.bastion.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": "secretsmanager:GetSecretValue",
        "Resource": "arn:aws:secretsmanager:*:*:secret:${var.env}-${var.project}-project-*"
    }]
}
EOF
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.env}-${var.project}-iam-profile-bastion"
  role = aws_iam_role.bastion.name
  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
}

resource "aws_launch_template" "project_bastion_lt" {
  name                   = "${var.env}-${var.project}-bastion"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_conf.type
  vpc_security_group_ids = var.security_groups_app
  key_name               = var.access_key_id
  update_default_version = true
  user_data              = base64encode(templatefile("scripts/bastion.sh", {
    KEY_PRIVATE = "${var.env}-${var.project}-project"
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.bastion.name
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.env}-${var.project}-bastion"
    }
  }

  tags = {
    Name = "${var.env}-${var.project}-bastion-lt"
  }
}

resource "aws_autoscaling_group" "bastion" {
  name                = "${var.env}-${var.project}-asg-bastion"
  vpc_zone_identifier = var.subnets_app
  min_size            = var.instance_conf.min_size
  max_size            = var.instance_conf.max_size
  desired_capacity    = var.instance_conf.desired_capacity

  launch_template {
    id      = aws_launch_template.project_bastion_lt.id
    version = "$Latest"
  }
}

