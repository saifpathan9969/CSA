###############################################################################
# Unit 3 – EC2 Web Application Deployment
# variables.tf
###############################################################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Project owner"
  type        = string
  default     = "Saif Pathan"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation for SSH access (e.g. 203.0.113.5/32)"
  type        = string
  default     = "0.0.0.0/0" # CHANGE THIS to your IP for production
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/csa-unit3-key.pub"
}
