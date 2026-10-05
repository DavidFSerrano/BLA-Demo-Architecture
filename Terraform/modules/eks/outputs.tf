output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = try(aws_eks_cluster.this.certificate_authority[0].data, null)
}

output "cluster_security_group_id" {
  description = "Security group EKS creates and attaches to the control-plane ENIs."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Shared security group attached to every worker node."
  value       = aws_security_group.nodes.id
}

output "node_role_arn" {
  description = "IAM role ARN used by every worker node."
  value       = aws_iam_role.node.arn
}

output "node_group_arn" {
  description = "Managed node group ARN."
  value       = aws_eks_node_group.app.arn
}

output "node_group_subnet_ids" {
  description = "Subnet IDs the managed node group deploys into."
  value       = aws_eks_node_group.app.subnet_ids
}

output "addon_names" {
  description = "EKS add-ons managed by this module."
  value = toset([
    aws_eks_addon.vpc_cni.addon_name,
    aws_eks_addon.kube_proxy.addon_name,
    aws_eks_addon.coredns.addon_name,
    aws_eks_addon.pod_identity.addon_name,
    aws_eks_addon.ebs_csi.addon_name,
  ])
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN associated with the EBS CSI controller via EKS Pod Identity."
  value       = aws_iam_role.ebs_csi.arn
}
