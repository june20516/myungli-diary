# server 이미지의 하위 명령을 실행하는 Job입니다(S1). VPC는 server 서비스와 같고, env·Secret은 server 서비스처럼
# 배포 workflow가 붙입니다(run.tf의 설명).
# precompute·notify는 P8-3·P8-4에서 더합니다.
locals {
  server_jobs = {
    "server-migrate"   = ["migrate", "up"]
    "server-seed"      = ["seed"]
    "server-retention" = ["job", "retention"]
  }
}

resource "google_cloud_run_v2_job" "server" {
  for_each = local.server_jobs

  name                = each.key
  location            = var.region
  deletion_protection = var.deletion_protection

  template {
    template {
      service_account = google_service_account.server.email
      max_retries     = 0
      timeout         = "900s"

      vpc_access {
        egress = "PRIVATE_RANGES_ONLY"

        network_interfaces {
          network    = google_compute_network.main.id
          subnetwork = google_compute_subnetwork.run.id
        }
      }

      containers {
        image = local.placeholder_image
        args  = each.value
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image, template[0].template[0].containers[0].env, client, client_version]
  }
}
