output "alb_dns_name" {
  description = "The public URL of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "ec2_instance_id" {
  description = "The EC2 instance ID for GitHub Actions secrets"
  value       = aws_instance.app.id
}

output "db_endpoint" {
  description = "The internal connection string for the RDS database"
  value       = aws_db_instance.main.endpoint
}

output "db_password" {
  description = "The dynamically generated database password"
  value       = random_password.db_password.result
  sensitive   = true
}