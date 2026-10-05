output "state_bucket_names" {
  description = "State bucket name per environment. These are the values used in each root module's backend block."
  value       = { for env, bucket in aws_s3_bucket.state : env => bucket.id }
}

output "state_bucket_arns" {
  description = "State bucket ARN per environment."
  value       = { for env, bucket in aws_s3_bucket.state : env => bucket.arn }
}

output "region" {
  description = "Region hosting the state buckets."
  value       = var.region
}
