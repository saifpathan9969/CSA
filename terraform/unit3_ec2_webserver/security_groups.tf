###############################################################################
# Unit 3 – EC2 Web Application Deployment
# security_groups.tf  –  SSH (22) from own IP + HTTP (80) public
###############################################################################

# ── Web Server Security Group ─────────────────────────────────────────────────
resource "aws_security_group" "web_server" {
  name        = "csa-unit3-webserver-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  # SSH – restricted to operator IP only (CIS recommendation)
  ingress {
    description = "SSH from operator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # HTTP – public web access
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS – optional but good practice
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound – allow all (for yum/apt updates)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "csa-unit3-webserver-sg" }
}
