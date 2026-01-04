terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Deploy primary stack
module "cloudformation_stack_primary" {
  source = "./cloudformation_module"

  region           = var.region
  stack_name       = var.stack_name
  ubuntu_ami       = var.ubuntu_ami
  cf_parameters    = var.cf_parameters
}

# Deploy secondary stack (identical setup)
module "cloudformation_stack_secondary" {
  source = "./cloudformation_module"

  region           = var.region
  stack_name       = "${var.stack_name}-secondary"
  ubuntu_ami       = var.ubuntu_ami
  cf_parameters    = var.cf_parameters
}
