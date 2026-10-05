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

variable "cluster_name" {
  description = "EKS cluster name. Must match the kubernetes.io/cluster/<name> tags on the VPC public and application subnets."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane and managed node group."
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "VPC that hosts the cluster and its nodes."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR, used for security-group descriptions and the EKS Auth endpoint ingress."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private application subnet IDs for control-plane ENIs and worker nodes. Must span at least two Availability Zones; three are expected so nodes land in every zone."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two Availability Zones."
  }

  validation {
    condition     = length(var.private_subnet_ids) == length(distinct(var.private_subnet_ids))
    error_message = "private_subnet_ids must not contain duplicates."
  }
}

variable "endpoint_private_access" {
  description = "Enable the private Kubernetes API endpoint inside the VPC."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable the public Kubernetes API endpoint. Required for CI and local kubectl without VPN or a bastion."
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Control-plane log types to send to CloudWatch. Empty disables logging to keep cost down."
  type        = list(string)
  default     = []
}

variable "node_instance_type" {
  description = <<-EOT
    EC2 instance type for the managed node group. EKS does not support nano or micro
    sizes (insufficient memory for kubelet plus system pods). t3.small is the smallest
    current-generation type EKS allows; the default is t3.medium, the next size up.
  EOT
  type        = string
  default     = "t3.medium"

  validation {
    condition     = !can(regex("\\.(nano|micro)$", var.node_instance_type))
    error_message = "EKS does not support nano or micro instance types because they do not have enough memory."
  }
}

variable "node_ami_type" {
  description = "EKS-optimized AMI type for the managed node group."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes. Use 3 so the group can place one node in each AZ."
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Root volume size in GiB for each worker node."
  type        = number
  default     = 20
}

variable "cluster_admin_principal_arns" {
  description = "IAM principals granted AmazonEKSClusterAdminPolicy via EKS access entries, in addition to the principal that creates the cluster."
  type        = list(string)
  default     = []
}
