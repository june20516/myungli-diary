# O1 관측의 알림 정책과 uptime check입니다(S133). 받는 곳(메일 channel)과 예산은 bootstrap이 만들고(observability.tf),
# 여기서는 display_name으로 찾기만 합니다. 대응 절차는 server/docs/runbook/alerts.md입니다.
#
# 임계값은 cold start가 늘 일어난다는 전제(S132)로 잡았습니다. 요청이 드문 동안 cold start 한 번이 그 창의 지연을
# 끌어올리므로, 지연 알림은 15분 동안 이어질 때만 울립니다. 오류는 비율 대신 5분 동안의 개수로 봅니다.
# 요청이 적을 때 한두 건이 비율을 크게 흔들기 때문이고, 비율 기준은 L1에서 사용량을 본 뒤 다시 정합니다.

data "google_monitoring_notification_channel" "alerts" {
  display_name = "myungli-alerts"
}

locals {
  alert_channels = [data.google_monitoring_notification_channel.alerts.name]
  runbook        = "대응 절차: server/docs/runbook/alerts.md"

  # Cloud Run 서비스는 max_instance_count를 두지 않아 기본 상한 100입니다(용량 값은 L1). 그 80%에서 알립니다.
  default_max_instances = 100

  # 서비스별 5xx와 지연 기준입니다. 엔진은 server만 부르는 내부 gRPC라 server보다 짧게 둡니다.
  services = {
    server = { latency_p95_ms = 3000 }
    engine = { latency_p95_ms = 2000 }
  }

  public_host = trimprefix(var.server_settings["APP_LINK_BASE"], "https://")
}

resource "google_monitoring_alert_policy" "service_5xx" {
  for_each = local.services

  display_name          = "${each.key}: 5분 동안 5xx 5건 이상"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "${each.key} 5xx 개수"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${each.key}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 4
      duration        = "0s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "${each.key} 서비스가 5분 동안 5xx를 5건 넘게 냈습니다. ${local.runbook} (5xx)"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "service_latency" {
  for_each = local.services

  display_name          = "${each.key}: 지연 p95가 15분 동안 ${each.value.latency_p95_ms}ms 넘음"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "${each.key} 지연 p95"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${each.key}\" AND metric.type = \"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = each.value.latency_p95_ms
      duration        = "900s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "${each.key} 응답 지연 p95가 15분 동안 ${each.value.latency_p95_ms}ms를 넘었습니다. ${local.runbook} (지연)"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "service_instances" {
  for_each = local.services

  display_name          = "${each.key}: 인스턴스 수가 상한의 80%"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "${each.key} 인스턴스 수"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${each.key}\" AND metric.type = \"run.googleapis.com/container/instance_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = local.default_max_instances * 0.8
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MAX"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "${each.key} 인스턴스가 5분 동안 기본 상한 ${local.default_max_instances}의 80%를 넘었습니다. 상한에 닿으면 새 요청이 거절됩니다. ${local.runbook} (인스턴스)"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "sql_cpu" {
  display_name          = "Cloud SQL: CPU 10분 동안 80% 넘음"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "Cloud SQL CPU"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${google_sql_database_instance.main.name}\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Cloud SQL CPU가 10분 동안 80%를 넘었습니다. ${local.runbook} (Cloud SQL)"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "sql_connections" {
  display_name          = "Cloud SQL: 연결 수가 max_connections의 80%"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "Cloud SQL 연결 수"
    condition_threshold {
      # 데이터베이스(label database)마다 나뉜 연결 수를 더해 인스턴스 전체로 봅니다.
      filter          = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${google_sql_database_instance.main.name}\" AND metric.type = \"cloudsql.googleapis.com/database/postgresql/num_backends\""
      comparison      = "COMPARISON_GT"
      threshold_value = floor(var.sql_max_connections * 0.8)
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MAX"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Cloud SQL 연결 수가 5분 동안 max_connections ${var.sql_max_connections}의 80%를 넘었습니다. ${local.runbook} (Cloud SQL)"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "job_failed" {
  display_name          = "Cloud Run Job 실행 실패"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "Job 실패 실행"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_job\" AND metric.type = \"run.googleapis.com/job/completed_execution_count\" AND metric.labels.result = \"failed\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.job_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "Cloud Run Job 실행이 실패했습니다(job_name label). ${local.runbook} (Job)"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_uptime_check_config" "health" {
  count = var.uptime_check_enabled ? 1 : 0

  display_name = "공개 주소 GET /health"
  timeout      = "10s"
  period       = "300s"
  # 지역마다 checker가 있고 최소 3곳이어야 합니다. USA는 checker 3곳이라 아시아와 유럽을 더해 5곳입니다.
  selected_regions = ["ASIA_PACIFIC", "EUROPE", "USA"]

  http_check {
    path         = "/health"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = local.public_host
    }
  }
}

resource "google_monitoring_alert_policy" "uptime" {
  count = var.uptime_check_enabled ? 1 : 0

  display_name          = "공개 주소 GET /health 실패"
  combiner              = "OR"
  notification_channels = local.alert_channels

  conditions {
    display_name = "uptime check 실패"
    condition_threshold {
      # 공식 예시(policies-in-json)와 같은 형식입니다. checker 두 곳 넘게 실패한 상태가 10분 이어지면 울립니다.
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.health[0].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "600s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.*"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content   = "공개 주소 https://${local.public_host}/health가 여러 지역에서 실패합니다. ${local.runbook} (uptime)"
    mime_type = "text/markdown"
  }
}
