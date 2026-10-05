mock_provider "aws" {}

variables {
  project     = "bla-demo"
  environment = "test"
  vpc_id      = "vpc-0123456789abcdef0"
  database_subnet_ids = [
    "subnet-db-a",
    "subnet-db-b",
    "subnet-db-c",
  ]
  availability_zones = [
    "us-east-2a",
    "us-east-2b",
    "us-east-2c",
  ]
  primary_availability_zone  = "us-east-2b"
  read_replica_count         = 2
  allowed_security_group_ids = ["sg-0123456789abcdef0"]
}

run "writer_and_two_readers" {
  command = plan

  assert {
    condition     = aws_db_instance.primary.publicly_accessible == false
    error_message = "The writer must not be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.primary.availability_zone == "us-east-2b"
    error_message = "The writer belongs in the middle Availability Zone."
  }

  assert {
    condition     = aws_db_instance.primary.multi_az == false
    error_message = "Availability comes from the read replicas, not a Multi-AZ standby."
  }

  assert {
    condition     = length(aws_db_instance.replica) == 2
    error_message = "Prod places one read replica in each of the other two zones."
  }

  assert {
    condition     = toset([for replica in aws_db_instance.replica : replica.availability_zone]) == toset(["us-east-2a", "us-east-2c"])
    error_message = "Read replicas must occupy the zones that are not the writer zone."
  }

  assert {
    condition     = alltrue([for replica in aws_db_instance.replica : replica.publicly_accessible == false])
    error_message = "Read replicas must not be publicly accessible."
  }
}

run "rejects_replica_count_past_remaining_zones" {
  command = plan

  variables {
    read_replica_count = 3
  }

  expect_failures = [terraform_data.replica_layout]
}

run "rejects_writer_zone_outside_the_list" {
  command = plan

  variables {
    primary_availability_zone = "us-east-2d"
  }

  expect_failures = [terraform_data.replica_layout]
}
