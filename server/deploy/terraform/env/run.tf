resource "google_cloud_run_v2_service" "engine" {
  name                = "engine"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = var.deletion_protection

  template {
    service_account = google_service_account.engine.email

    # 엔진은 동기 gRPC 서버라 한 인스턴스가 한 번에 MAX_WORKERS개만 처리합니다(core grpc_api/server.py).
    # 기본 80을 두면 나머지 요청이 엔진 안에서 줄을 서고, 증설 기준(동시 요청 수의 60%)에도 늦게 닿습니다(L1 1회차, #817 ②).
    # 값은 MAX_WORKERS와 같아야 하며 internal/engine의 TestEngineConcurrency_MatchesCoreWorkers가 대조합니다.
    max_instance_request_concurrency = 8

    # 아침 몰림의 첫 증설 지연을 줄이려고 prod(와 같은 용량으로 재는 load)는 하나를 늘 띄워 둡니다(#817 ④).
    scaling {
      min_instance_count = var.min_instances
    }

    containers {
      image = local.engine_image

      # cold start는 늘 일어나므로(인스턴스 0개까지 줄어듦) 시작 중에 CPU를 더 받아 뜨는 시간을 줄입니다(S132).
      # limits는 지금 적용된 기본값 그대로입니다. 용량 값은 L1에서 정합니다.
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        startup_cpu_boost = true
      }

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

  # 직접 주소(run.app)는 끄지 않습니다. Firebase Hosting rewrite가 이 주소로 보내므로 끄면 공개 주소도 404가 됩니다(S135).

  template {
    service_account = google_service_account.server.email

    # 아침 몰림의 첫 증설 지연을 줄이려고 prod(와 같은 용량으로 재는 load)는 하나를 늘 띄워 둡니다(#817 ④).
    scaling {
      min_instance_count = var.min_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.run.id
      }
    }

    containers {
      image = local.placeholder_image

      # cold start는 늘 일어나므로(인스턴스 0개까지 줄어듦) 시작 중에 CPU를 더 받아 뜨는 시간을 줄입니다(S132).
      # limits는 지금 적용된 기본값 그대로입니다. 용량 값은 L1에서 정합니다.
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        startup_cpu_boost = true
      }
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
