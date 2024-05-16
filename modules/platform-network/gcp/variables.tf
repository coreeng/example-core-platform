variable "gcp_project_id" {
  type        = string
  description = "GCP project id"
}

variable "gcp_region" {
  type        = string
  description = "GCP region (eg europe-west2)"
}

variable "environment" {
  type        = string
  description = "The name of the environment"
  default     = "sandbox-gcp"
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

variable "ip_range_tenants_infra" {
  type        = string
  description = "The cidr of the ip range to use for tenants infrastructure subnets"
}

variable "ip_range_private_service_access" {
  type        = string
  description = "The cidr of the ip range to use for private service access"
}
