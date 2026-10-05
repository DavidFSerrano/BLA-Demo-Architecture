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

variables {
  project            = "bla-demo"
  environment        = "test"
  cluster_name       = "bla-demo-test"
  vpc_id             = "vpc-0123456789abcdef0"
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
}

run "valid_inputs_are_accepted" {
  command = plan
}

run "rejects_single_subnet" {
  command = plan

  variables {
    private_subnet_ids = ["subnet-aaa"]
  }

  expect_failures = [var.private_subnet_ids]
}

run "rejects_duplicate_subnets" {
  command = plan

  variables {
    private_subnet_ids = ["subnet-aaa", "subnet-aaa", "subnet-ccc"]
  }

  expect_failures = [var.private_subnet_ids]
}

run "rejects_micro_instance_type" {
  command = plan

  variables {
    node_instance_type = "t3.micro"
  }

  expect_failures = [var.node_instance_type]
}

run "rejects_nano_instance_type" {
  command = plan

  variables {
    node_instance_type = "t3.nano"
  }

  expect_failures = [var.node_instance_type]
}
