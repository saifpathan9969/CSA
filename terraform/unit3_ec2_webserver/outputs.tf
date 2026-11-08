###############################################################################
# Unit 3 – EC2 Web Application Deployment
# outputs.tf
###############################################################################

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web_server.id
}

output "public_ip" {
  description = "Elastic IP – use this to SSH and browse"
  value       = aws_eip.web_server.public_ip
}

output "public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.web_server.public_dns
}

output "web_url" {
  description = "URL to view the deployed web application"
  value       = "http://${aws_eip.web_server.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/csa-unit3-key ec2-user@${aws_eip.web_server.public_ip}"
}

output "security_group_id" {
  description = "Web server security group ID"
  value       = aws_security_group.web_server.id
}

output "ami_used" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.amazon_linux_2023.id
}
