# modules/eks

Reusable EKS module: one cluster, one managed node group in the private application
subnets, a single shared node security group, and the add-ons the cluster needs to
run pods with VPC addresses, DNS, kube-proxy, EBS volumes, and IAM via Pod Identity.

It deploys no application workloads and no RDS.

## What it creates

- EKS cluster with API access entries (no `aws-auth` ConfigMap).
- Cluster IAM role and node IAM role.
- One managed node group (`app`) in the three private application subnets.
- One launch template so every worker node receives the same security group, IMDSv2, and a gp3 root volume.
- EKS add-ons: `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`, `aws-ebs-csi-driver`.
- An IAM role for the EBS CSI controller, granted through EKS Pod Identity (not IRSA).
- An EKS Auth interface VPC endpoint so the Pod Identity agent on private nodes can call `eks-auth` without the public internet.

## Instance type

EKS does not support `*.nano` or `*.micro` instance types: kubelet plus the system
DaemonSets do not fit in 0.5–1 GiB. The smallest current-generation type EKS allows
is `t3.small`. This module defaults to **`t3.medium`**, the next size up.

## Node placement and security group

The node group is given all three private application subnet IDs and a desired size
of 3, so the ASG places one node in each AZ. Every node is launched with only
`aws_security_group.nodes`. That same group is attached to the cluster as an
additional security group, so control-plane ENIs and nodes share a self-referential
allow-all rule for kubelet and pod networking.

Pods do not get instance-role credentials: the launch template sets the IMDS hop
limit to 1. Workloads obtain IAM credentials through EKS Pod Identity instead.

VPC CNI still uses the node role (`AmazonEKS_CNI_Policy`) because it must work at
node boot, before the Pod Identity agent is running.

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project      = "bla-demo"
  environment  = "dev"
  cluster_name = "bla-demo-dev"
  tags         = { Application = "appointment-booking" }

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.subnet_id_lists_by_role.app

  node_instance_type = "t3.medium"
  node_desired_size  = 3
  node_min_size      = 1
  node_max_size      = 3
}
```

Pass `cluster_name` into the VPC module as `eks_cluster_name` so public and
application subnets get the `kubernetes.io/cluster/<name> = shared` discovery tag.

## Tests

```sh
cd Terraform/modules/eks
terraform init
terraform test
```

The AWS provider is mocked. `tests/variables.tftest.hcl` covers input validation.
`tests/cluster.tftest.hcl` covers subnet placement, the shared security group,
add-ons, Pod Identity on EBS CSI, and the EKS Auth endpoint.
