resource "aws_vpc" "project" {
  cidr_block           = var.cidr_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags                 = {
    Name = "${var.env}-${var.project}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.cidrs_public)
  vpc_id                  = aws_vpc.project.id
  cidr_block              = var.cidrs_public[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zones[count.index]
  tags                    = {
    Name = "${var.env}-${var.project}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "node_core" {
  count             = length(var.cidrs_compute)
  vpc_id            = aws_vpc.project.id
  cidr_block        = var.cidrs_compute[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = {
    Name = "${var.env}-${var.project}-core-${count.index + 1}"
  }
}

resource "aws_subnet" "node_lb_p2p" {
  count             = length(var.cidrs_lb_p2p)
  vpc_id            = aws_vpc.project.id
  cidr_block        = var.cidrs_lb_p2p[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = {
    Name = "${var.env}-${var.project}-lb_p2p-${count.index + 1}"
  }
}

resource "aws_subnet" "node_stats" {
  count             = length(var.cidrs_stats)
  vpc_id            = aws_vpc.project.id
  cidr_block        = var.cidrs_stats[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = {
    Name = "${var.env}-${var.project}-stats-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "project" {
  vpc_id = aws_vpc.project.id
  tags   = {
    Name = "${var.env}-${var.project}-igw"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "project" {
  tags = {
    Name = "${var.env}-${var.project}-nat-eip"
  }
}

resource "aws_nat_gateway" "project" {
  allocation_id = aws_eip.project.id
  subnet_id     = aws_subnet.public[1].id
  tags          = {
    Name = "${var.env}-${var.project}-natgw"
  }

  depends_on = [aws_internet_gateway.project]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project.id

  tags = {
    Name = "${var.env}-${var.project}-rt-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.project.id

  tags = {
    Name = "${var.env}-${var.project}-rt-private"
  }
}

resource "aws_route" "default_public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project.id
}

resource "aws_route" "default_private" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.project.id
}

resource "aws_default_route_table" "project" {
  default_route_table_id = aws_vpc.project.default_route_table_id

  tags = {
    Name = "${var.env}-${var.project}-rt-default"
  }
}

resource "aws_route_table_association" "public" {
  depends_on     = [aws_route_table.public]
  count          = length(var.cidrs_public)
  subnet_id      = aws_subnet.public.*.id[count.index]
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "compute" {
  depends_on     = [aws_route_table.private]
  count          = length(var.cidrs_compute)
  subnet_id      = aws_subnet.node_core.*.id[count.index]
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "lb_p2p" {
  depends_on     = [aws_route_table.private]
  count          = length(var.cidrs_lb_p2p)
  subnet_id      = aws_subnet.node_lb_p2p.*.id[count.index]
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "stats" {
  depends_on     = [aws_route_table.private]
  count          = length(var.cidrs_stats)
  subnet_id      = aws_subnet.node_stats.*.id[count.index]
  route_table_id = aws_route_table.private.id
}
