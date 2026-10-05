variable "enabled" {
  description = "Create the dev VPC and EKS cluster. Set to false to destroy them on the next apply while keeping this root module and its state."
  type        = bool
  default     = false
}

variable "project" {
  description = "Project identifier used for naming and tagging."
  type        = string
  default     = "bla-demo"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "Dev VPC CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones for the dev VPC."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "subnet_cidrs" {
  description = "Explicit per-AZ subnet allocation inside 10.0.0.0/16. See Terraform/README.md for the full plan."
  type = map(object({
    public   = string
    app      = string
    firewall = string
    database = string
  }))

  default = {
    "us-east-2a" = {
      app      = "10.0.0.0/20"
      public   = "10.0.64.0/24"
      firewall = "10.0.80.0/28"
      database = "10.0.96.0/24"
    }
    "us-east-2b" = {
      app      = "10.0.16.0/20"
      public   = "10.0.65.0/24"
      firewall = "10.0.80.16/28"
      database = "10.0.97.0/24"
    }
    "us-east-2c" = {
      app      = "10.0.32.0/20"
      public   = "10.0.66.0/24"
      firewall = "10.0.80.32/28"
      database = "10.0.98.0/24"
    }
  }
}

variable "tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default = {
    Application = "appointment-booking"
    CostCenter  = "platform-dev"
  }
}
