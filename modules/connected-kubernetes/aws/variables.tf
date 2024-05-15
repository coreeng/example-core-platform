variable "aws_account_id" {
  type        = string
  description = "AWS account id (eg 012345678901)"
}

variable "aws_region" {
  type        = string
  description = "AWS region (eg eu-west-2)"
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
