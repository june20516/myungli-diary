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

    # 최소 인스턴스는 환경 값입니다. I4 전까지는 모든 환경이 0이고, prod를 다시 1로 둘지는 I4 2주 전 점검(#903)에서 정합니다(S163).
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
        # 요청을 처리하는 동안에만 CPU를 받고 과금합니다(S163). 응답 뒤에 도는 작업이 없어야 하므로 그런 작업은 Job으로 둡니다.
        # resources를 두면 provider 기본값이 상시 할당이라 명시합니다.
        cpu_idle          = true
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

    # 최소 인스턴스는 환경 값입니다. I4 전까지는 모든 환경이 0이고, prod를 다시 1로 둘지는 I4 2주 전 점검(#903)에서 정합니다(S163).
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
        # 요청을 처리하는 동안에만 CPU를 받고 과금합니다(S163). 응답 뒤에 도는 작업이 없어야 하므로 그런 작업은 Job으로 둡니다.
        # resources를 두면 provider 기본값이 상시 할당이라 명시합니다.
        cpu_idle          = true
        startup_cpu_boost = true
      }
    }
  }

  # 최소 인스턴스가 있으면 갱신 때 새 리비전이 바로 떠서 DB에 붙습니다. load처럼 Cloud SQL을 새로 만드는 apply에서
  # 인스턴스와 DB 사용자가 먼저 생기도록 기다립니다(환경 변수는 workflow가 넣어 Terraform이 이 관계를 모릅니다).
  depends_on = [google_sql_database.main, google_sql_user.server]

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

# 내부 운영 API입니다(#1321). Cloud Run 직접 IAP가 Google 계정으로 막고, 앱은 IAP가 서명한 JWT를 다시 검증합니다.
# server처럼 env와 Secret(OPS_OPERATORS, 볼륨 마운트)은 배포 workflow가 준비를 확인한 뒤 붙입니다(S121).
# Secret 볼륨은 workflow가 정하므로 Terraform이 지우지 않도록 volumes와 volume_mounts를 무시합니다.
resource "google_cloud_run_v2_service" "server_ops" {
  name                = "server-ops"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  iap_enabled         = true
  deletion_protection = var.deletion_protection

  template {
    service_account = google_service_account.ops.email

    # 운영 호출은 사람 몇 명이 드물게 부르므로 인스턴스 둘이면 충분합니다. 상한을 두어 잘못 반복된 호출이나
    # 키를 가진 쪽의 과도한 요청이 인스턴스를 늘려 DB 연결과 비용을 키우지 않게 합니다.
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    # vpc_access를 두지 않습니다. server가 VPC를 쓰는 까닭은 internal ingress 엔진 호출(network.tf)인데 운영 API는 엔진을 부르지 않고,
    # Cloud SQL은 public IP에 Cloud SQL connector(IAM 인증)로 붙으므로(sql.tf) VPC 없이 연결됩니다. IAP 공개키도 인터넷으로 받습니다.

    containers {
      image = local.placeholder_image
      args  = ["ops-serve"]

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # 요청을 처리하는 동안에만 CPU를 받고 과금합니다(S163). resources를 두면 provider 기본값이 상시 할당이라 명시합니다.
        cpu_idle          = true
        startup_cpu_boost = true
      }
    }
  }

  # server와 같은 까닭으로 DB와 DB 사용자가 먼저 생기도록 기다립니다.
  depends_on = [google_sql_database.main, google_sql_user.ops]

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, template[0].containers[0].env, template[0].containers[0].volume_mounts, template[0].volumes,
      client, client_version,
    ]
  }
}

# IAP가 통과시킨 요청만 들어오도록 IAP 서비스 에이전트에게만 호출 권한을 줍니다. allUsers는 두지 않습니다.
# 사람(운영자)의 IAP 접근 권한(roles/iap.httpsResourceAccessor)은 메일이 저장소에 남지 않도록 Terraform 밖에서 줍니다(runbook, D74).
resource "google_cloud_run_v2_service_iam_member" "server_ops_iap" {
  name     = google_cloud_run_v2_service.server_ops.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${var.project_number}@gcp-sa-iap.iam.gserviceaccount.com"
}
