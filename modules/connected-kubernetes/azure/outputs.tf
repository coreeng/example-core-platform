output "name" {
  description = "Cluster name"
  value       = "placeholder"
}

output "internal_oci_registry" {
  description = "internal OCI registry"
  value       = "placeholder"
}

output "internal_oci_registry_key" {
  description = "internal OCI registry key"
  value       = "placeholder"
  sensitive   = true
}

output "kubeconfig_context" {
  description = "kubeconfig context of the private cluster"
  value       = "placeholder"
}

output "kubeconfig_generate_command" {
  description = "az aks get-credentials command to generate kubeconfig for the private cluster"
  value       = "placeholder"
}

output "kubeconfig_set_proxy_command" {
  description = "kubectl config set command to add proxy-url via the IAP tunnel for the private cluster"
  value       = "placeholder"
}

output "cluster_describe_command" {
  description = "az aks show command"
  value       = "placeholder"
}
