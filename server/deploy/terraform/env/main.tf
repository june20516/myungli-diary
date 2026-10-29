# 환경 하나의 실행 자원입니다(spec 2026-10-28-p9-deploy-design §3~§5, S121). 이미지는 배포 workflow가 바꿉니다.

locals {
  image_repo = "${var.region}-docker.pkg.dev/${var.project_id}/myungli"
  # 엔진은 h2c·gRPC probe라 placeholder로 뜨지 않으므로 deploy-engine이 먼저 push한 이미지로 만듭니다.
  engine_image = "${local.image_repo}/engine:current"
  # server와 Job은 처음 만들 때만 공개 placeholder를 쓰고, 배포 workflow가 실제 이미지로 바꿉니다.
  placeholder_image = "us-docker.pkg.dev/cloudrun/container/hello"

  db_user = trimsuffix(google_service_account.server.email, ".gserviceaccount.com")

  # 비밀은 Secret Manager에 두고 환경 변수 이름을 Secret id로 씁니다(spec §5).
  secret_ids = concat(
    ["JWT_SIGNING_KEY", "TOKEN_ENCRYPTION_KEY", "KAKAO_ADMIN_KEY", "APPLE_PRIVATE_KEY", "REVENUECAT_API_KEY", "REVENUECAT_WEBHOOK_AUTH"],
    var.test_login_enabled ? ["TEST_LOGIN_SECRET"] : [],
    var.jwt_previous_key_id != "" ? ["JWT_PREVIOUS_KEY"] : [],
    var.token_previous_key_id != "" ? ["TOKEN_PREVIOUS_KEY"] : [],
  )

  # serve가 APP_ENV non-local에서 요구하는 비밀이 아닌 설정입니다(config.LoadAuth·LoadBilling·LoadAppCheck).
  # 하나라도 비어 있으면 workflow가 server 배포를 건너뜁니다.
  required_server_settings = [
    "AD_FREE_PRODUCT_IDS", "ANDROID_APP_PACKAGE", "ANDROID_CERT_SHA256", "ANDROID_STORE_URL", "APP_LINK_BASE",
    "APPLE_BUNDLE_ID", "APPLE_KEY_ID", "APPLE_SERVICES_ID", "APPLE_TEAM_ID", "APPLE_WEB_REDIRECT_URI",
    "GOOGLE_CLIENT_IDS", "JWT_SIGNING_KEY_ID", "KAKAO_APP_KEY", "LINE_CHANNEL_ID", "REVENUECAT_PROJECT_ID",
    "TOKEN_ENCRYPTION_KEY_ID",
  ]

  server_env = merge(
    { for name, value in var.server_settings : name => value if value != "" },
    {
      APP_ENV                 = var.environment
      GOOGLE_CLOUD_PROJECT    = var.project_id
      FIREBASE_PROJECT_NUMBER = var.project_number
      ENGINE_ADDR             = "${trimprefix(google_cloud_run_v2_service.engine.uri, "https://")}:443"
      ENGINE_AUDIENCE         = google_cloud_run_v2_service.engine.uri
      CLOUD_SQL_INSTANCE      = google_sql_database_instance.main.connection_name
      DATABASE_URL            = "user=${local.db_user} dbname=${google_sql_database.main.name} sslmode=disable"
    },
    var.jwt_previous_key_id != "" ? { JWT_PREVIOUS_KEY_ID = var.jwt_previous_key_id } : {},
    var.token_previous_key_id != "" ? { TOKEN_PREVIOUS_KEY_ID = var.token_previous_key_id } : {},
  )
}

resource "google_service_account" "server" {
  account_id   = "server-runtime"
  display_name = "server 실행 (serve, Job)"
}

resource "google_service_account" "engine" {
  account_id   = "engine-runtime"
  display_name = "엔진 실행 (권한 없음)"
}

resource "google_service_account" "scheduler" {
  account_id   = "scheduler-invoker"
  display_name = "Cloud Scheduler의 Job 실행"
}

resource "google_project_iam_member" "server" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
    "roles/firebasecloudmessaging.admin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.server.email}"
}

resource "google_secret_manager_secret" "server" {
  for_each = toset(local.secret_ids)

  secret_id = each.value

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_iam_member" "server" {
  for_each = google_secret_manager_secret.server

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.server.email}"
}
