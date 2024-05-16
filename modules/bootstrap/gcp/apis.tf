module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 15.0.0"

  project_id = var.gcp_project_id

  disable_dependent_services  = false
  disable_services_on_destroy = false

  # minimum services required to generate a plan against a new project
  activate_apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
  ]
}
