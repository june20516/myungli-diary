# server와 Job이 internal ingress 엔진을 부르는 경로입니다(spec §3). private ranges만 VPC로 보내고,
# 비공개 DNS가 run.app을 private.googleapis.com 대역으로 풀어 그 요청만 VPC(Private Google Access)를 거칩니다.
# 외부 호출은 그대로 인터넷으로 나가므로 Cloud NAT가 없습니다.

resource "google_compute_network" "main" {
  name                    = "myungli"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "run" {
  name                     = "myungli-run"
  network                  = google_compute_network.main.id
  region                   = var.region
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true
}

resource "google_dns_managed_zone" "run_app" {
  name       = "run-app"
  dns_name   = "run.app."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.main.id
    }
  }
}

resource "google_dns_record_set" "run_app" {
  managed_zone = google_dns_managed_zone.run_app.name
  name         = "*.run.app."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"]
}
