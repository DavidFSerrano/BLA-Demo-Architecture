terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Prod state lives in its own bucket, fully independent of dev.
  # Bucket is created by ../../Bootstrap; backend blocks cannot use variables, so
  # the name (including the account ID) is written out literally.
  backend "s3" {
    bucket       = "bla-demo-tfstate-prod-637423617446"
    key          = "vpc/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
