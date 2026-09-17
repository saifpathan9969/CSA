# ─────────────────────────────────────────────────────────────
# Unit 1 – Internet-Facing EC2 Honeypot · Variables
# ─────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for honeypot deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "csa-honeypot"
}

variable "vpc_cidr" {
  description = "CIDR block for the honeypot VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the honeypot"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID (Amazon Linux 2)"
  type        = string
  default     = "ami-0c02fb55956c7d316"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "csa-keypair"
}
