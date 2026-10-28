output "workload_identity_provider" {
  description = "GitHub 변수 GCP_WIF_PROVIDER_<ENV>에 넣을 값"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_email" {
  description = "GitHub 변수 GCP_DEPLOYER_<ENV>에 넣을 값"
  value       = google_service_account.deployer.email
}

output "planner_email" {
  description = "GitHub 변수 GCP_PLANNER_<ENV>에 넣을 값"
  value       = google_service_account.planner.email
}

output "state_bucket" {
  description = "env module의 backend bucket"
  value       = google_storage_bucket.tfstate.name
}
