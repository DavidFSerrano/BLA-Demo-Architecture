variable "project" {
  description = "Project identifier used for resource naming and tagging."
  type        = string
}

variable "environment" {
  description = "Environment identifier used for resource naming and tagging."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}

variable "network" {
  description = "The VPC module firewall_integration output."
  type = object({
    vpc_id                   = string
    vpc_cidr_block           = string
    firewall_subnet_ids      = map(string)
    app_route_table_ids      = map(string)
    app_subnet_cidrs         = map(string)
    firewall_route_table_ids = map(string)
    public_route_table_ids   = map(string)
    nat_gateway_ids          = map(string)
    nat_gateway_az_by_app    = map(string)
    single_nat_gateway       = bool
    internet_gateway_id      = string
  })
}
