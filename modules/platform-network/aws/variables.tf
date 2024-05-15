variable "aws_account_id" {
  type        = string
  description = "AWS account id (eg 012345678901)"
}

variable "aws_region" {
  type        = string
  description = "AWS region (eg eu-west-2)"
}

variable "environment" {
  type        = string
  description = "The name of the environment"
  default     = "sandbox-aws"
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

variable "ip_range_nat_gateways" {
  type        = string
  description = "The cidr of the ip range to use for nat gateways"
}
