resource "google_cloud_run_v2_service" "engine" {
  name                = "engine"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = var.deletion_protection

  template {
    service_account = google_service_account.engine.email

    containers {
      image = local.engine_image

      # 엔진은 TLS 없는 h2c gRPC입니다. 포트 이름 h2c가 HTTP/2 end-to-end를 켭니다(#79).
      ports {
        name           = "h2c"
        container_port = 8080
      }

      # 근거 데이터 검증·캐시 예열이 끝나야 SERVING입니다(#79). 종료 grace 8초는 컨테이너가 SIGTERM에서 처리합니다.
      startup_probe {
        period_seconds    = 10
        timeout_seconds   = 5
        failure_threshold = 30

        grpc {
          port    = 8080
          service = "myungli.engine.v1.MyungliEngine"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
}

# 엔진은 internal ingress와 IAM 인증을 함께 요구하고, server-runtime만 부를 수 있습니다.
resource "google_cloud_run_v2_service_iam_member" "engine_invoker" {
  name     = google_cloud_run_v2_service.engine.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.server.email}"
}

# env와 Secret 연결은 Terraform이 두지 않습니다. 값이 없는 Secret을 연결하면 revision이 뜨지 않아 apply가 실패하고,
# 설정 변경이 준비 확인 없이 새 revision을 만들기 때문입니다. 배포 workflow가 준비를 확인한 뒤 이미지와 함께
# Terraform 출력(server_env, secret_ids)으로 붙입니다(S121).
resource "google_cloud_run_v2_service" "server" {
  name                = "server"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    service_account = google_service_account.server.email

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.run.id
      }
    }

    containers {
      image = local.placeholder_image
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, template[0].containers[0].env, client, client_version]
  }
}

resource "google_cloud_run_v2_service_iam_member" "server_public" {
  name     = google_cloud_run_v2_service.server.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
