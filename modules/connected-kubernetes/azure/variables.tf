variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription id (eg 00000000-0000-0000-0000-000000000000)"
}

variable "azure_resourcegroup_name" {
  type        = string
  description = "Azure resource group name (eg sandbox-azure)"
}

variable "azure_region" {
  type        = string
  description = "Azure region (eg UK South)"
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
