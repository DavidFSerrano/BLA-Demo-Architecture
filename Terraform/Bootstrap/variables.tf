variable "project" {
  description = "Project identifier used for naming and tagging."
  type        = string
  default     = "bla-demo"
}

variable "region" {
  description = "Region that hosts the state buckets."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_prefix" {
  description = "Prefix for the per-environment state bucket names. Final name is <prefix>-<environment>-<account_id>."
  type        = string
  default     = "bla-demo-tfstate"
}

variable "environments" {
  description = "Environments that get their own state bucket and therefore their own independent state."
  type        = set(string)
  default     = ["dev", "prod"]
}

variable "noncurrent_version_retention_days" {
  description = "Days to retain noncurrent state file versions before expiring them."
  type        = number
  default     = 90
}
