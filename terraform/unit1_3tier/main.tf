# ─────────────────────────────────────────────────────────────
# Unit 1 – 3-Tier Web Application Architecture · Main
# Cloud Security PBL – VPC, Subnets, Gateways, Route Tables
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
      Environment = "pbl"
      ManagedBy   = "terraform"
    }
  }
}

# ──────────────────────────────────────────────────────────────
# 1. VPC
# ──────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

# ──────────────────────────────────────────────────────────────
# 2. Internet Gateway (public / web tier)
# ──────────────────────────────────────────────────────────────

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ──────────────────────────────────────────────────────────────
# 3. Public Subnets – Web / ALB Tier
# ──────────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${var.availability_zones[count.index]}" }
}

# ── Public Route Table ───────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────────────────────────
# 4. NAT Gateway (outbound Internet for private tiers)
# ──────────────────────────────────────────────────────────────

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = "${var.project_name}-nat-gw" }

  depends_on = [aws_internet_gateway.igw]
}

# ──────────────────────────────────────────────────────────────
# 5. Private Subnets – Application Tier
# ──────────────────────────────────────────────────────────────

resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "${var.project_name}-app-${var.availability_zones[count.index]}" }
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-app-rt" }
}

resource "aws_route" "private_app_nat" {
  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# ──────────────────────────────────────────────────────────────
# 6. Isolated Subnets – Database Tier (NO Internet access)
# ──────────────────────────────────────────────────────────────

resource "aws_subnet" "private_db" {
  count             = length(var.private_db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "${var.project_name}-db-${var.availability_zones[count.index]}" }
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-db-rt" }
}

# No route to 0.0.0.0/0 → fully isolated from the Internet.

resource "aws_route_table_association" "private_db" {
  count          = length(aws_subnet.private_db)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}

# ──────────────────────────────────────────────────────────────
# 7. Security Groups
# ──────────────────────────────────────────────────────────────

# ── ALB / Web Tier SG ────────────────────────────────────────
resource "aws_security_group" "web_alb" {
  name        = "${var.project_name}-web-alb-sg"
  description = "Allow inbound HTTP/HTTPS from the Internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
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

  tags = { Name = "${var.project_name}-web-alb-sg" }
}

# ── Application Tier SG ─────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow traffic from ALB SG on app port only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_alb.id]
  }

  egress {
    description = "All outbound (patches, API calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

# ── Database Tier SG ─────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow MySQL traffic only from the App tier SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from App tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # No egress to Internet – fully isolated
  egress {
    description = "All outbound within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project_name}-db-sg" }
}
