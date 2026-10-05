output "firewall_arn" {
  description = "Network Firewall ARN."
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_subnet_ids" {
  description = "Firewall subnet that holds each endpoint, keyed by Availability Zone."
  value       = var.network.firewall_subnet_ids
}
