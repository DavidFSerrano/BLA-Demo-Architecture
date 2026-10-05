provider "aws" {
  region = var.region

  # Credentials come from the environment (profile, SSO, instance role) and are
  # never written into this repository.
}
