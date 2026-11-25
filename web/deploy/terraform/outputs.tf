output "site_id" {
  value = google_firebase_hosting_site.landing.site_id
}

output "default_url" {
  value = google_firebase_hosting_site.landing.default_url
}

output "web_deployer_email" {
  value = google_service_account.web_deployer.email
}

# Cloudflare에 넣을 기록입니다(프록시 끔). 도메인마다 Firebase가 요구하는 기록 목록입니다.
output "dns_records" {
  value = { for name, domain in google_firebase_hosting_custom_domain.landing : name => domain.required_dns_updates }
}
