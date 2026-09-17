# ─────────────────────────────────────────────────────────────
# Unit 1 – 3-Tier Web Application · Outputs
# ─────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the 3-tier VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "web_instance_public_ips" {
  description = "Public IPs of the web-tier EC2 instances"
  value       = aws_instance.web[*].public_ip
}

output "app_instance_private_ips" {
  description = "Private IPs of the app-tier EC2 instances"
  value       = aws_instance.app[*].private_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (host:port)"
  value       = aws_db_instance.db.endpoint
}

output "rds_database_name" {
  description = "Name of the RDS database"
  value       = aws_db_instance.db.db_name
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the private app-tier subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "IDs of the isolated database-tier subnets"
  value       = aws_subnet.private_db[*].id
}
