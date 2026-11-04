# 부하 생성기 Job입니다(L1-2b, D104). 같은 region에서 k6를 돌려, 로컬에서 보낼 때 더해지는 왕복 지연을 뺍니다.
# 이미지(server/load/Dockerfile)와 TEST_LOGIN_SECRET은 배포 workflow가 붙입니다(S121과 같은 이유). 실행은 README "생성기 Job"입니다.
locals {
  # bootstrap이 부하 프로젝트에만 만드는 결과 bucket입니다(bootstrap 출력 load_results_bucket).
  load_results_bucket = "${var.project_id}-load-results"
  # grafana/k6 이미지는 uid, gid 12345로 돕니다. GCS volume을 그 사용자로 걸어 root 없이 씁니다.
  k6_uid = "12345"
}

resource "google_service_account" "load_generator" {
  count = var.load_generator_enabled ? 1 : 0

  account_id   = "load-generator"
  display_name = "부하 생성기 k6 (테스트 로그인 비밀과 결과 bucket만)"
}

resource "google_secret_manager_secret_iam_member" "load_generator" {
  count = var.load_generator_enabled ? 1 : 0

  secret_id = google_secret_manager_secret.server["TEST_LOGIN_SECRET"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.load_generator[0].email}"
}

# gcsfuse가 파일을 만들고 덮어쓰므로 객체 읽기, 쓰기, 지우기가 필요합니다.
resource "google_storage_bucket_iam_member" "load_generator" {
  count = var.load_generator_enabled ? 1 : 0

  bucket = local.load_results_bucket
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.load_generator[0].email}"
}

resource "google_cloud_run_v2_job" "load_k6" {
  count = var.load_generator_enabled ? 1 : 0

  name                = "load-k6"
  location            = var.region
  deletion_protection = var.deletion_protection

  template {
    template {
      service_account = google_service_account.load_generator[0].email
      max_retries     = 0
      # 기본 8단계(단계마다 3분 30초)와 setup 로그인을 넉넉히 덮습니다.
      timeout = "5400s"
      # GCS volume은 2세대 실행 환경에서만 됩니다.
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = local.placeholder_image

        # 기본 STAGES의 VU 3,185개를 모두 미리 만들고 마지막 단계에서 초당 3,000건쯤 보냅니다. 생성기가 먼저 막히지 않게 크게 둡니다.
        # 막히면 k6의 dropped_iterations와 Monitoring의 이 Job CPU로 드러납니다.
        resources {
          limits = {
            cpu    = "8"
            memory = "16Gi"
          }
        }

        volume_mounts {
          name       = "results"
          mount_path = "/results"
        }
      }

      volumes {
        name = "results"

        gcs {
          bucket        = local.load_results_bucket
          read_only     = false
          mount_options = ["uid=${local.k6_uid}", "gid=${local.k6_uid}"]
        }
      }
    }
  }

  depends_on = [google_storage_bucket_iam_member.load_generator]

  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image, template[0].template[0].containers[0].env, client, client_version]
  }
}
