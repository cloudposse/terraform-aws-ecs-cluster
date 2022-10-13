terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 4.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "> 2.2"
    }
    # Update these to reflect the actual requirements of your module
    random = {
      source  = "hashicorp/random"
      version = ">= 2.2"
    }
  }
}
