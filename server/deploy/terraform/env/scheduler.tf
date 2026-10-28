resource "google_cloud_run_v2_job_iam_member" "scheduler_retention" {
  name     = google_cloud_run_v2_job.server["server-retention"].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# 하루 1번 보관 기간 정리(S120). 엔진 배포 직후와 겹치지 않는 새벽 시각입니다.
resource "google_cloud_scheduler_job" "retention" {
  name      = "retention-daily"
  region    = var.region
  schedule  = "30 4 * * *"
  time_zone = "Asia/Seoul"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.server["server-retention"].name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}
