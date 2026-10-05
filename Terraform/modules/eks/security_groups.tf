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
  description       = "Nodes reach the Kubernetes API and anything without a VPC endpoint"

  tags = local.common_tags
}

