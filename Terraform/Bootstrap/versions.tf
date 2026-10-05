terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap intentionally keeps local state: it creates the buckets that every
  # other root module stores its state in, so it cannot store state in them.
  # Commit bootstrap/terraform.tfstate only if you accept it in Git; it is
  # gitignored here and the resources are recoverable by import.
}
