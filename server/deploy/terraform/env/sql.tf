# Cloud SQL은 public IP지만 승인된 네트워크가 없어 Cloud SQL connector(IAM 인증)로만 붙습니다(spec §3, S121).
resource "google_sql_database_instance" "main" {
  name                = "myungli-pg"
  database_version    = "POSTGRES_17"
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    tier                        = var.sql_tier
    edition                     = "ENTERPRISE"
    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }

    # 자동 백업 7개와 PITR 7일(S113: 지운 데이터가 백업에 최대 7일).
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
      }
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}

resource "google_sql_database" "main" {
  name     = "myungli"
  instance = google_sql_database_instance.main.name
}

# server-runtime이 migration(DDL)도 돌리므로 cloudsqlsuperuser 역할을 줍니다. Cloud SQL의 이 역할은 PostgreSQL superuser가 아닙니다.
resource "google_sql_user" "server" {
  name           = local.db_user
  instance       = google_sql_database_instance.main.name
  type           = "CLOUD_IAM_SERVICE_ACCOUNT"
  database_roles = ["cloudsqlsuperuser"]
}
