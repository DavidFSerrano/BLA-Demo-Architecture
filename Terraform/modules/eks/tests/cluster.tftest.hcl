# Cluster, node group, add-ons, and the shared node security group.
#
# These runs use `command = apply` because resource IDs and some cluster
# attributes are only known after apply. The provider is mocked, so nothing is
# created in AWS and no credentials are needed.

mock_provider "aws" {}

override_data {
  target = data.aws_region.current
  values = { region = "us-east-2" }
}

override_data {
  target = data.aws_partition.current
  values = { partition = "aws" }
}

override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "637423617446" }
}

override_resource {
  target = aws_iam_role.cluster
  values = { arn = "arn:aws:iam::637423617446:role/bla-demo-test-eks-cluster" }
}

override_resource {
  target = aws_iam_role.node
  values = { arn = "arn:aws:iam::637423617446:role/bla-demo-test-eks-node" }
}

override_resource {
  target = aws_iam_role.ebs_csi
  values = { arn = "arn:aws:iam::637423617446:role/bla-demo-test-ebs-csi" }
}

override_resource {
  target = aws_launch_template.nodes
  values = { id = "lt-0123456789abcdef0" }
}

override_resource {
  target = aws_eks_cluster.this
  values = {
    certificate_authority = [{ data = "LS0t" }]
  }
}

variables {
  project            = "bla-demo"
  environment        = "test"
  cluster_name       = "bla-demo-test"
  vpc_id             = "vpc-0123456789abcdef0"
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
}

run "cluster_uses_private_subnets_and_api_auth" {
  command = apply

  assert {
    condition     = aws_eks_cluster.this.name == "bla-demo-test"
    error_message = "Cluster name must match the requested value."
  }

  assert {
    condition     = aws_eks_cluster.this.version == "1.33"
    error_message = "Default Kubernetes version should be 1.33."
  }

  assert {
    condition     = aws_eks_cluster.this.bootstrap_self_managed_addons == false
    error_message = "Default add-ons must be managed as aws_eks_addon resources."
  }

  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "Cluster auth must use the access-entry API, not the aws-auth ConfigMap."
  }

  assert {
    condition     = toset(aws_eks_cluster.this.vpc_config[0].subnet_ids) == toset(var.private_subnet_ids)
    error_message = "Control-plane ENIs must sit in the three private application subnets."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access == true
    error_message = "The private API endpoint must be enabled."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].security_group_ids == toset([aws_security_group.nodes.id])
    error_message = "The shared node security group must also be attached to the cluster."
  }
}

run "managed_node_group_spans_three_private_subnets" {
  command = apply

  assert {
    condition     = length(aws_eks_node_group.app.instance_types) == 1 && contains(aws_eks_node_group.app.instance_types, "t3.medium")
    error_message = "Node group must use t3.medium, the second-smallest type EKS allows."
  }

  assert {
    condition     = aws_eks_node_group.app.ami_type == "AL2023_x86_64_STANDARD"
    error_message = "Nodes must use the AL2023 EKS-optimized AMI."
  }

  assert {
    condition     = aws_eks_node_group.app.capacity_type == "ON_DEMAND"
    error_message = "Nodes must be on-demand."
  }

  assert {
    condition     = toset(aws_eks_node_group.app.subnet_ids) == toset(var.private_subnet_ids)
    error_message = "Worker nodes must be deployed in all three private application subnets."
  }

  assert {
    condition     = aws_eks_node_group.app.scaling_config[0].desired_size == 3
    error_message = "Desired size of 3 places a node in each AZ."
  }

  assert {
    condition     = aws_launch_template.nodes.vpc_security_group_ids == toset([aws_security_group.nodes.id])
    error_message = "The launch template must attach only the shared node security group."
  }

  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "IMDS hop limit 1 keeps instance credentials off the pod network; pods use Pod Identity instead."
  }
}

run "all_worker_nodes_share_one_security_group" {
  command = apply

  assert {
    condition     = aws_security_group.nodes.name == "bla-demo-test-eks-nodes"
    error_message = "There must be a single shared worker-node security group."
  }

  assert {
    condition     = aws_security_group.nodes.vpc_id == var.vpc_id
    error_message = "The node security group must live in the cluster VPC."
  }

  assert {
    condition     = aws_launch_template.nodes.vpc_security_group_ids == toset([aws_security_group.nodes.id])
    error_message = "Every node launched by the group must receive the shared security group."
  }

  assert {
    condition     = output.node_security_group_id == aws_security_group.nodes.id
    error_message = "The shared node security group must be exposed as an output."
  }
}

run "required_addons_are_installed" {
  command = apply

  assert {
    condition     = aws_eks_addon.vpc_cni.addon_name == "vpc-cni"
    error_message = "VPC CNI must be installed as an EKS add-on."
  }

  assert {
    condition     = aws_eks_addon.kube_proxy.addon_name == "kube-proxy"
    error_message = "kube-proxy must be installed as an EKS add-on."
  }

  assert {
    condition     = aws_eks_addon.coredns.addon_name == "coredns"
    error_message = "CoreDNS must be installed as an EKS add-on."
  }

  assert {
    condition     = aws_eks_addon.pod_identity.addon_name == "eks-pod-identity-agent"
    error_message = "EKS Pod Identity agent must be installed as an EKS add-on."
  }

  assert {
    condition     = aws_eks_addon.ebs_csi.addon_name == "aws-ebs-csi-driver"
    error_message = "EBS CSI must be installed as an EKS add-on."
  }

  assert {
    condition = toset(output.addon_names) == toset([
      "vpc-cni",
      "kube-proxy",
      "coredns",
      "eks-pod-identity-agent",
      "aws-ebs-csi-driver",
    ])
    error_message = "The add-on output must list exactly the five required add-ons."
  }
}

run "ebs_csi_uses_pod_identity" {
  command = apply

  assert {
    condition = one([
      for assoc in aws_eks_addon.ebs_csi.pod_identity_association : assoc.service_account
    ]) == "ebs-csi-controller-sa"
    error_message = "EBS CSI must associate Pod Identity with ebs-csi-controller-sa."
  }

  assert {
    condition = one([
      for assoc in aws_eks_addon.ebs_csi.pod_identity_association : assoc.role_arn
    ]) == aws_iam_role.ebs_csi.arn
    error_message = "EBS CSI Pod Identity must use the dedicated CSI IAM role."
  }

  assert {
    condition     = strcontains(aws_iam_role.ebs_csi.assume_role_policy, "pods.eks.amazonaws.com")
    error_message = "The EBS CSI role must trust the Pod Identity service."
  }
}

run "eks_auth_endpoint_is_created_for_pod_identity" {
  command = apply

  assert {
    condition     = aws_vpc_endpoint.eks_auth.service_name == "com.amazonaws.us-east-2.eks-auth"
    error_message = "Pod Identity on private nodes needs the EKS Auth interface endpoint."
  }

  assert {
    condition     = aws_vpc_endpoint.eks_auth.vpc_endpoint_type == "Interface"
    error_message = "EKS Auth must be an interface endpoint."
  }

  assert {
    condition     = toset(aws_vpc_endpoint.eks_auth.subnet_ids) == toset(var.private_subnet_ids)
    error_message = "The EKS Auth endpoint must sit in the same private subnets as the nodes."
  }
}
