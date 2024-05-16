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
