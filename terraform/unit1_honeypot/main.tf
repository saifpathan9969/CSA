# ─────────────────────────────────────────────────────────────
# Unit 1 – Internet-Facing EC2 Honeypot · Main
# Deliberately exposes SSH (22) and HTTP (80) to 0.0.0.0/0
# for empirical threat-landscape analysis.
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "pbl-honeypot"
      ManagedBy   = "terraform"
    }
  }
}

# ──────────────────────────────────────────────────────────────
# VPC & Networking
# ──────────────────────────────────────────────────────────────

resource "aws_vpc" "honeypot" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.honeypot.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.honeypot.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags                    = { Name = "${var.project_name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.honeypot.id
  tags   = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────────────────────────
# Security Group – INTENTIONALLY OPEN (Honeypot)
# ──────────────────────────────────────────────────────────────

resource "aws_security_group" "honeypot" {
  name        = "${var.project_name}-sg"
  description = "HONEYPOT: SSH and HTTP open to 0.0.0.0/0 for attack analysis"
  vpc_id      = aws_vpc.honeypot.id

  # SSH – open to the entire Internet (for brute-force observation)
  ingress {
    description = "SSH from anywhere (honeypot)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP – open to the entire Internet (for scanner observation)
  ingress {
    description = "HTTP from anywhere (honeypot)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

# ──────────────────────────────────────────────────────────────
# EC2 Honeypot Instance
# ──────────────────────────────────────────────────────────────

resource "aws_instance" "honeypot" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.honeypot.id]
  key_name               = var.key_name

  user_data = file("${path.module}/user_data.sh")

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project_name}-instance" }
}

# Elastic IP for stable public address
resource "aws_eip" "honeypot" {
  instance = aws_instance.honeypot.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}
