output "endpoint" {
  description = "Writer hostname."
  value       = aws_db_instance.primary.address
}

output "port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.primary.port
}

output "db_name" {
  description = "Database name."
  value       = aws_db_instance.primary.db_name
}

output "username" {
  description = "Master username."
  value       = aws_db_instance.primary.username
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master password."
  value       = aws_db_instance.primary.master_user_secret[0].secret_arn
}

output "reader_endpoints" {
  description = "Read replica hostnames keyed by Availability Zone."
  value       = { for az, replica in aws_db_instance.replica : az => replica.address }
}

output "security_group_id" {
  description = "Security group attached to the writer and the read replicas."
  value       = aws_security_group.this.id
}

output "primary_availability_zone" {
  description = "Availability Zone of the read/write instance."
  value       = aws_db_instance.primary.availability_zone
}
