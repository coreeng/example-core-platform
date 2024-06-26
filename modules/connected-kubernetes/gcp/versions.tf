terraform {
  required_version = ">= 1.7.1"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.28.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.28.0"
    }
  }
}
