terraform_binary             = "tofu"
terraform_version_constraint = ">= 1.7.1"

locals {
  config = yamldecode(file("../config.yaml"))
}

inputs = {
  vendor                     = local.config.platform.vendor
  azure_subscription_id      = local.config.platform.subscriptionId
  azure_resourcegroup_name   = local.config.platform.resourceGroupName
  azure_region               = local.config.platform.region
  environment                = local.config.environment
  ip_range_k8s_control_plane = local.config.network.subnets.kubernetes.controlPlane
  ip_range_k8s_nodes         = local.config.network.subnets.kubernetes.nodes
  ip_range_k8s_pods          = local.config.network.subnets.kubernetes.pods
  ip_range_k8s_services      = local.config.network.subnets.kubernetes.services
}

remote_state {
  backend = "azurerm"

  config = {
    resource_group_name  = local.config.bucket.resourceGroupName
    storage_account_name = local.config.bucket.storageAccountName
    container_name       = local.config.bucket.name
    key                  = "${local.config.platform.subscriptionId}/${local.config.platform.resourceGroupName}/environments/${local.config.environment}/connected-kubernetes/terraform/state/terraform.tfstate"
  }
}
