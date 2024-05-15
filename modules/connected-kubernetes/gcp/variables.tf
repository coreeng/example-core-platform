variable "gcp_project_id" {
  type        = string
  description = "GCP project id (eg my-sandbox-4b1d)"
}

variable "gcp_region" {
  type        = string
  description = "GCP region (eg europe-west2)"
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster"
  default     = "default-core-platform"
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
