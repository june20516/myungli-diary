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
# 런타임(serve, retention, precompute, notify) DB 사용자입니다. cloudsqlsuperuser가 없고, migrate가 읽기와 쓰기
# 권한 묶음 myungli_app의 구성원으로 둡니다(S137). database_roles는 provider가 다시 읽지 않는 쓰기 전용 값이라
# 예전에 준 cloudsqlsuperuser는 목록에서 빼는 것만으로 거둬진다고 보지 않습니다. 사용자를 지우고 다시 만들어 없앱니다(README).
resource "google_sql_user" "server" {
  name     = local.db_user
  instance = google_sql_database_instance.main.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# migration과 seed를 적용하는 DB 사용자입니다. 표의 주인이라 DDL 권한(cloudsqlsuperuser)을 갖습니다.
resource "google_sql_user" "migrator" {
  name           = local.migrator_db_user
  instance       = google_sql_database_instance.main.name
  type           = "CLOUD_IAM_SERVICE_ACCOUNT"
  database_roles = ["cloudsqlsuperuser"]
}
