terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix      = var.name_prefix
  ssh_ingress_cidr = var.ssh_ingress_cidr != null ? var.ssh_ingress_cidr : var.grafana_ingress_cidr

  docker_compose_yml = templatefile("${path.module}/docker-compose.yml.tpl", {})
  prometheus_yml = templatefile("${path.module}/prometheus.yml.tpl", {
    target_private_ip = aws_instance.target.private_ip
  })
  target_user_data = templatefile("${path.module}/user_data_target.sh.tpl", {})
  monitor_user_data = templatefile("${path.module}/user_data_monitor.sh.tpl", {
    docker_compose_yml = local.docker_compose_yml
    prometheus_yml     = local.prometheus_yml
    grafana_admin_user = var.grafana_admin_user
    grafana_admin_pass = var.grafana_admin_password
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${local.name_prefix}-private"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${local.name_prefix}-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "monitor" {
  name        = "${local.name_prefix}-monitor-sg"
  description = "Monitor host access (SSH, Grafana, optional Prometheus)"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.ssh_ingress_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.grafana_ingress_cidr]
  }

  ingress {
    description = "Prometheus UI (optional)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [local.ssh_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-monitor-sg"
  }
}

resource "aws_security_group" "target" {
  name        = "${local.name_prefix}-target-sg"
  description = "Target host monitored by Prometheus"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description     = "Node exporter from monitor"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitor.id]
  }

  ingress {
    description     = "SSH from monitor (for jump host use)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.monitor.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-target-sg"
  }
}

resource "aws_instance" "target" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.target_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.target.id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  user_data = local.target_user_data

  tags = {
    Name = "${local.name_prefix}-target"
    Role = "target"
  }

  # Ensure private subnet egress is ready before apt/docker installs run in user-data.
  depends_on = [aws_route_table_association.private]
}

resource "aws_instance" "monitor" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.monitor_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.monitor.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = local.monitor_user_data

  tags = {
    Name = "${local.name_prefix}-monitor"
    Role = "monitor"
  }

  # Ensure public routing exists before bootstrap, and wait for target IP for Prometheus config.
  depends_on = [aws_route_table_association.public, aws_instance.target]
}
