resource "google_cloud_run_v2_job_iam_member" "scheduler_retention" {
  name     = google_cloud_run_v2_job.server["server-retention"].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# 하루 1번 보관 기간 정리(S120). 엔진 배포 직후와 겹치지 않는 새벽 시각입니다.
# 실제 이미지와 설정이 붙기 전에는 placeholder가 끝나지 않으므로 멈춘 채 만들고, 배포 workflow가 첫 server 배포 뒤 다시 켭니다.
resource "google_cloud_scheduler_job" "retention" {
  name      = "retention-daily"
  region    = var.region
  schedule  = "30 4 * * *"
  time_zone = "Asia/Seoul"
  paused    = true

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.server["server-retention"].name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  lifecycle {
    ignore_changes = [paused]
  }
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_precompute" {
  name     = google_cloud_run_v2_job.server["server-precompute"].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# 30분마다 현지 22:00~22:29 사용자의 다음 날 결과를 미리 계산합니다(spec §8.1, S128).
# UTC 매시 0분, 30분이라 30분 단위가 아닌 시간대(예: +05:45)도 하루 한 번은 창에 듭니다. 멈춘 채 만드는 이유는 retention과 같습니다.
resource "google_cloud_scheduler_job" "precompute" {
  name      = "precompute-half-hourly"
  region    = var.region
  schedule  = "0,30 * * * *"
  time_zone = "Etc/UTC"
  paused    = true

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.server["server-precompute"].name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  lifecycle {
    ignore_changes = [paused]
  }
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_notify" {
  name     = google_cloud_run_v2_job.server["server-notify"].name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# 5분마다 보낼 시각(알림 시각 + 계정 오프셋 0~10분, D109)이 지난 60분과 다음 5분 안인 사용자에게 아침 알림을 보냅니다(spec §8.2, S13, S129, S144).
# 주기를 바꾸면 internal/notify의 lookahead도 같이 바꿉니다.
# 실행이 겹쳐도 notification_log claim이 두 번 발송을 막습니다. 멈춘 채 만드는 이유는 retention과 같습니다.
resource "google_cloud_scheduler_job" "notify" {
  name      = "notify-every-5m"
  region    = var.region
  schedule  = "*/5 * * * *"
  time_zone = "Etc/UTC"
  paused    = true

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.server["server-notify"].name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  lifecycle {
    ignore_changes = [paused]
  }
}
