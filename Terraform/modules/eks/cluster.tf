resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  # Add-ons are managed below as aws_eks_addon resources so Terraform owns
  # their lifecycle rather than adopting the cluster-created defaults.
  bootstrap_self_managed_addons = false

  enabled_cluster_log_types = var.enabled_cluster_log_types

  access_config {
    authentication_mode = "API"

    # Off so access does not depend on who runs apply. CI and laptop users are
    # both granted through cluster_admin_principal_arns. Leaving this on would
    # also collide with that list when the creator is already in it.
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.nodes.id]
  }

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_eks_access_entry" "admin" {
  for_each = local.cluster_admin_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = local.common_tags
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = local.cluster_admin_arns

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}
