# ─────────────────────────────────────────────────────────────
# Unit 1 – 3-Tier Web Application · Compute & Database
# ALB ➜ Web EC2 (public) ➜ App EC2 (private) ➜ RDS (isolated)
# ─────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────
# 1. Application Load Balancer (Internet-facing)
# ──────────────────────────────────────────────────────────────

resource "aws_lb" "web" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = { Name = "${var.project_name}-app-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ──────────────────────────────────────────────────────────────
# 2. Web Tier – EC2 Instances (public subnets, serve static)
# ──────────────────────────────────────────────────────────────

resource "aws_instance" "web" {
  count                  = length(var.public_subnet_cidrs)
  ami                    = var.ami_id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web_alb.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>CSA 3-Tier – Web Tier (AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone))</h1>" > /var/www/html/index.html
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 enforced
  }

  tags = { Name = "${var.project_name}-web-${count.index + 1}" }
}

# ──────────────────────────────────────────────────────────────
# 3. Application Tier – EC2 Instances (private subnets)
# ──────────────────────────────────────────────────────────────

resource "aws_instance" "app" {
  count                  = length(var.private_app_subnet_cidrs)
  ami                    = var.ami_id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.private_app[count.index].id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y java-17-amazon-corretto
    # Placeholder: start Spring Boot / Node.js application on port 8080
    # java -jar /opt/app/myapp.jar --server.port=8080
    # For demo, run a simple Python HTTP server
    mkdir -p /opt/app
    echo '{"status":"healthy","tier":"application"}' > /opt/app/health.json
    cd /opt/app
    nohup python3 -m http.server 8080 &
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = { Name = "${var.project_name}-app-${count.index + 1}" }
}

# Register app instances with the ALB target group
resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 8080
}

# ──────────────────────────────────────────────────────────────
# 4. Database Tier – RDS MySQL (isolated subnets, Multi-AZ)
# ──────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "db" {
  identifier             = "${var.project_name}-db"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = { Name = "${var.project_name}-db" }
}
