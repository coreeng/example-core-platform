variable "release_buildtime" {
  type        = string
  description = "Release buildtime"
}

variable "release_revision" {
  type        = string
  description = "Release revision"
}

variable "release_version" {
  type        = string
  description = "Release version"
}

variable "vendor" {
  type        = string
  description = "Cloud vendor (ie aws, azure, or gcp)"
  validation {
    condition     = contains(["aws", "azure", "gcp"], var.vendor)
    error_message = "Invalid vendor - must be aws, azure, or gcp"
  }
}

variable "github_sa" {
  type        = string
  description = "GitHub Actions service account name (eg github-actions-sa)"
  default     = "github-actions-sa"
}

variable "bastion_members" {
  type        = list(string)
  description = "List of IAM resources that need access to the bastion host"
  default     = []
}

variable "environment" {
  type        = string
  description = "Environment name (eg sandbox)"
}

variable "ip_range_k8s_control_plane" {
  type        = string
  description = "The cidr of the ip range to use for the k8s control plane"
}

variable "ip_range_k8s_nodes" {
  type        = string
  description = "The cidr of the ip range to use for the k8s nodes"
}

variable "ip_range_k8s_pods" {
  type        = string
  description = "The cidr of the ip range to use for the k8s pods"
}

variable "ip_range_k8s_services" {
  type        = string
  description = "The cidr of the ip range to use for the k8s services"
}
