terraform_binary             = "tofu"
terraform_version_constraint = ">= 1.7.1"

locals {
  config = yamldecode(file("../config.yaml"))
}

inputs = {
  vendor                     = local.config.platform.vendor
  gcp_project_id             = local.config.platform.projectId
  gcp_region                 = local.config.platform.region
  environment                = local.config.environment
  ip_range_k8s_control_plane = local.config.network.subnets.kubernetes.controlPlane
  ip_range_k8s_nodes         = local.config.network.subnets.kubernetes.nodes
  ip_range_k8s_pods          = local.config.network.subnets.kubernetes.pods
  ip_range_k8s_services      = local.config.network.subnets.kubernetes.services
}

remote_state {
  backend = "gcs"

  config = {
    project  = local.config.bucket.projectId
    location = local.config.bucket.location
    bucket   = local.config.bucket.name
    prefix   = "${local.config.platform.projectId}/environments/${local.config.environment}/connected-kubernetes/terraform/state"

    enable_bucket_policy_only = true

    gcs_bucket_labels = {
      owner = "terragrunt"
      name  = "terraform_state"
    }
  }
}
