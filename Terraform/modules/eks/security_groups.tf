# One security group shared by every worker node. It is also attached as an
# additional cluster security group so control-plane ENIs can use the same
# self-referential rules to reach kubelet.

resource "aws_security_group" "nodes" {
  name        = "${local.name_prefix}-eks-nodes"
  description = "Shared security group for all EKS worker nodes and control-plane ENIs"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-nodes"
  })
}

resource "aws_vpc_security_group_ingress_rule" "nodes_self" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
  description                  = "Node-to-node and control-plane-to-node traffic"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "nodes_all" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Nodes reach the API, ECR, and the internet through NAT"

  tags = local.common_tags
}

resource "aws_security_group" "eks_auth_endpoint" {
  name        = "${local.name_prefix}-eks-auth-vpce"
  description = "HTTPS to the EKS Auth VPC endpoint used by Pod Identity"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-auth-vpce"
  })
}

resource "aws_vpc_security_group_ingress_rule" "eks_auth_from_nodes" {
  security_group_id            = aws_security_group.eks_auth_endpoint.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Pod Identity agent on the nodes calls EKS Auth"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "eks_auth_all" {
  security_group_id = aws_security_group.eks_auth_endpoint.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Interface endpoint egress"

  tags = local.common_tags
}
