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
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.28"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.28"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
