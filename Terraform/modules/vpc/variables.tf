variable "project" {
  description = "Project identifier used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Environment identifier used for resource naming and tagging (for example dev or prod)."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Ordered list of Availability Zone names to build into. One subnet of each role is created per zone."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two Availability Zones are required."
  }

  validation {
    condition     = length(var.availability_zones) == length(distinct(var.availability_zones))
    error_message = "availability_zones must not contain duplicates."
  }
}

variable "subnet_cidrs" {
  description = <<-EOT
    Explicit per-Availability-Zone CIDR allocation, keyed by AZ name. Every key in
    availability_zones must be present. Roles:
      public   - internet-facing ALBs (future) and NAT gateways (current)
      app      - private EKS nodes and VPC CNI pod IPs (future)
      firewall - reserved for AWS Network Firewall endpoints (future, nothing deployed yet)
      database - isolated subnets for RDS (future)
  EOT

  type = map(object({
    public   = string
    app      = string
    firewall = string
    database = string
  }))

  validation {
    condition = alltrue([
      for cidrs in values(var.subnet_cidrs) : alltrue([
        for cidr in [cidrs.public, cidrs.app, cidrs.firewall, cidrs.database] : can(cidrhost(cidr, 0))
      ])
    ])
    error_message = "Every subnet CIDR must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = setunion(keys(var.subnet_cidrs), var.availability_zones) == setintersection(keys(var.subnet_cidrs), var.availability_zones)
    error_message = "subnet_cidrs keys must match availability_zones exactly."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    When true a single zonal NAT gateway is created and shared by the application subnets
    in every AZ. Cheaper, but a zone failure or NAT failure removes egress for all zones.
    When false one NAT gateway is created per AZ and each AZ egresses through its own.
  EOT

  type    = bool
  default = false
}

variable "nat_gateway_az" {
  description = "Availability Zone that hosts the shared NAT gateway when single_nat_gateway is true. Defaults to the first entry in availability_zones."
  type        = string
  default     = null

  validation {
    condition     = var.nat_gateway_az == null || contains(var.availability_zones, coalesce(var.nat_gateway_az, "unset"))
    error_message = "nat_gateway_az must be one of availability_zones."
  }
}

variable "enable_s3_gateway_endpoint" {
  description = "Create an S3 gateway endpoint and associate it with the application subnet route tables."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Create interface endpoints for EKS Auth, ECR, STS, and EC2 in the application subnets."
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "Optional future EKS cluster name. When set, shared cluster discovery tags are added to the public and application subnets."
  type        = string
  default     = null
}
