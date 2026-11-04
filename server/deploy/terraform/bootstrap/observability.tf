# O1 관측의 bootstrap 몫입니다(S133). 받는 곳과 예산은 로컬 값(메일 주소, 결제 계정, 금액)과 결제 계정 권한이 필요해
# GitHub Actions가 apply하는 env가 아니라 사용자가 로컬에서 apply하는 이 module에 둡니다. 알림 정책은 env에 있고,
# env는 아래 channel을 display_name(alert_channel_name)으로 찾습니다.

locals {
  # env/monitoring.tf가 같은 이름으로 찾습니다. 바꾸면 두 곳을 함께 바꿉니다.
  alert_channel_name = "myungli-alerts"
}

resource "google_monitoring_notification_channel" "email" {
  display_name = local.alert_channel_name
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.enabled]
}

data "google_project" "this" {
  project_id = var.project_id
}

# 이 프로젝트 하나의 월 비용이 예산의 50%, 90%, 100%에 닿거나 100%를 넘을 것으로 예측되면 메일을 보냅니다.
# 결제 계정 관리자에게 가는 기본 메일도 그대로 둡니다.
resource "google_billing_budget" "project" {
  provider = google.billing

  billing_account = var.billing_account_id
  display_name    = "${var.project_id} 월 예산"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
  }

  depends_on = [google_project_service.enabled]
}
