output "name" {
  description = "Cluster name"
  value       = module.connected-kubernetes.name
}

output "project_number" {
  description = "project number where the private cluster is"
  value       = try(module.connected-kubernetes.project_number, null)
}

output "bastion_instance_id" {
  description = "bastion host instance_id"
  value       = try(module.connected-kubernetes.bastion_instance_id, null)
}

output "ssm_tunnel_command" {
  description = "aws cli command to start an ssm port forwarding session to the bastion host"
  value       = try(module.connected-kubernetes.ssm_tunnel_command, null)
}

output "ssh_tunnel_command" {
  description = "gcloud command to ssh and port forward to the bastion host command without starting a shell"
  value       = try(module.connected-kubernetes.ssh_tunnel_command, null)
}

output "iap_tunnel_command" {
  description = "gcloud command to iap tunnel and port forward to the bastion host"
  value       = try(module.connected-kubernetes.iap_tunnel_command, null)
}

output "internal_oci_registry" {
  description = "internal OCI registry"
  value       = module.connected-kubernetes.internal_oci_registry
}

output "internal_oci_registry_key" {
  description = "internal OCI registry key"
  value       = module.connected-kubernetes.internal_oci_registry_key
  sensitive   = true
}

output "kubeconfig_context" {
  description = "kubeconfig context of the private cluster"
  value       = module.connected-kubernetes.kubeconfig_context
}

output "kubeconfig_generate_command" {
  description = "gcloud get-credentials command to generate kubeconfig for the private cluster"
  value       = module.connected-kubernetes.kubeconfig_generate_command
}

output "kubeconfig_set_proxy_command" {
  description = "kubectl config set command to add proxy-url via the IAP tunnel for the private cluster"
  value       = module.connected-kubernetes.kubeconfig_set_proxy_command
}

output "cluster_describe_command" {
  description = "gcloud container clusters describe command"
  value       = module.connected-kubernetes.cluster_describe_command
}
