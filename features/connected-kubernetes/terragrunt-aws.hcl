terraform_binary             = "tofu"
terraform_version_constraint = ">= 1.7.1"

locals {
  config = yamldecode(file("../config.yaml"))
}

inputs = {
  vendor                     = local.config.platform.vendor
  aws_account_id             = local.config.platform.accountId
  aws_region                 = local.config.platform.region
  environment                = local.config.environment
  cluster_access_entries     = local.config.platform.clusterAccessEntries
  ip_range_k8s_control_plane = local.config.network.subnets.kubernetes.controlPlane
  ip_range_k8s_nodes         = local.config.network.subnets.kubernetes.nodes
  ip_range_k8s_pods          = local.config.network.subnets.kubernetes.pods
  ip_range_k8s_services      = local.config.network.subnets.kubernetes.services
}

remote_state {
  backend = "s3"

  config = {
    region         = local.config.bucket.location
    bucket         = local.config.bucket.name
    key            = "${local.config.platform.accountId}/environments/${local.config.environment}/connected-kubernetes/terraform/state/terraform.tfstate"
    dynamodb_table = "${local.config.platform.accountId}_environments_${local.config.environment}_connected-kubernetes_terraform_state_terraform.tfstate"
    encrypt        = true
  }
}
