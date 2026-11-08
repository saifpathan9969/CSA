###############################################################################
# Unit 3 – EC2 Web Application Deployment
# compute.tf  –  Key Pair, EC2 Instance, Elastic IP
###############################################################################

# ── Latest Amazon Linux 2023 AMI ──────────────────────────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Key Pair ──────────────────────────────────────────────────────────────────
# Generate key locally: ssh-keygen -t rsa -b 4096 -f ~/.ssh/csa-unit3-key
resource "aws_key_pair" "web_server" {
  key_name   = "csa-unit3-key"
  public_key = file(var.public_key_path)
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_server.id]
  key_name               = aws_key_pair.web_server.key_name

  # IMDSv2 enforced – prevents SSRF credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypted root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # Bootstrap: install Nginx + deploy web app
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    student_name = var.owner
  }))

  tags = { Name = "csa-unit3-webserver" }
}

# ── Elastic IP ────────────────────────────────────────────────────────────────
resource "aws_eip" "web_server" {
  instance = aws_instance.web_server.id
  domain   = "vpc"

  tags = { Name = "csa-unit3-eip" }
}
