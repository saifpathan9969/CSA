# ─────────────────────────────────────────────────────────────
# Unit 1 – Internet-Facing EC2 Honeypot · Outputs
# ─────────────────────────────────────────────────────────────

output "honeypot_public_ip" {
  description = "Public IP of the honeypot EC2 instance"
  value       = aws_eip.honeypot.public_ip
}

output "honeypot_instance_id" {
  description = "Instance ID of the honeypot EC2"
  value       = aws_instance.honeypot.id
}

output "ssh_command" {
  description = "SSH command to connect to the honeypot"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_eip.honeypot.public_ip}"
}

output "analyze_command" {
  description = "Command to run the SSH attack analysis on the honeypot"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_eip.honeypot.public_ip} 'sudo /opt/honeypot/analyze_ssh.sh'"
}
