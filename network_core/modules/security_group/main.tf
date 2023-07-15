resource "aws_security_group" "ssh_public" {
  name        = "${var.env}-${var.project}-ssh-public"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.access_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_private" {
  #name_prefix = "${var.env}-${var.project}-sg-ssh-private"
  name        = "${var.env}-${var.project}-ssh-private"
  description = "Allow SSH inbound traffic from Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ssh_public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
    #ignore_changes        = [name]
  }
}

resource "aws_security_group" "http_public" {
  name        = "${var.env}-${var.project}-http-public"
  description = "Allow all inbound HTTP[s] traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "node_p2p" {
  name        = "${var.env}-${var.project}-node_p2p"
  description = "P2P Wire & Discovery inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = [var.cidr_vpc]
  }

  ingress {
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    cidr_blocks = [var.cidr_vpc]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "node_rpc" {
  name        = "${var.env}-${var.project}-node_rpc"
  description = "RPC inbound traffic"
  vpc_id      = var.vpc_id

  // RPC
  ingress {
    from_port       = 8545
    to_port         = 8545
    protocol        = "tcp"
    security_groups = [aws_security_group.http_public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "node_stats" {
  name        = "${var.env}-${var.project}-node_stats"
  description = "Stats inbound traffic"
  vpc_id      = var.vpc_id

  // Stats read
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.http_public.id]
  }

  // Stats pushing data
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.cidr_vpc]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "udp"
    cidr_blocks = [var.cidr_vpc]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
