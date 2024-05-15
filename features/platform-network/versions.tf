terraform {
  required_version = ">= 1.7.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.48"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.103"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.28"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.28"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
