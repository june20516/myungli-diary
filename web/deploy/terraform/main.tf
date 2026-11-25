# 랜딩 배포 자리(WB1, 준비 메모 docs/specs/2026-11-25-web-landing-design.md §5).
# WIF pool `github`은 server bootstrap(server/deploy/terraform/bootstrap)이 만든 것을 이름으로만 가리킵니다.

locals {
  # GitHub environment와 배포 브랜치의 짝입니다(D136). WIF 속성 env_ref가 둘을 함께 봅니다.
  deploy_branch = var.environment == "web-prod" ? "main" : "staging"

  # Hosting 배포에 필요한 것만 줍니다. server deployer(Cloud Run, SQL 등)와 계정을 나눕니다.
  # Hosting 권한은 프로젝트 단위라 같은 프로젝트의 다른 Hosting 사이트(api)도 배포할 수 있습니다(README "한계").
  web_deployer_roles = [
    "roles/firebasehosting.admin",
    "roles/serviceusage.serviceUsageConsumer",
  ]
}

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_firebase_hosting_site" "landing" {
  provider = google-beta
  project  = var.project_id
  site_id  = var.site_id
}

# 본 도메인을 먼저 붙이고, 그 도메인으로 보내기만 하는 도메인(www)은 뒤에 붙입니다(redirect_target이 사이트에 있어야 함).
resource "google_firebase_hosting_custom_domain" "landing" {
  provider = google-beta
  for_each = { for domain in var.domains : domain.name => domain if domain.redirect_target == null }

  project       = var.project_id
  site_id       = google_firebase_hosting_site.landing.site_id
  custom_domain = each.value.name

  # DNS는 사용자가 Cloudflare에 넣으므로 apply가 검증을 기다리지 않습니다. 넣을 값은 output dns_records입니다.
  wait_dns_verification = false
}

resource "google_firebase_hosting_custom_domain" "redirect" {
  provider = google-beta
  for_each = { for domain in var.domains : domain.name => domain if domain.redirect_target != null }

  project               = var.project_id
  site_id               = google_firebase_hosting_site.landing.site_id
  custom_domain         = each.value.name
  redirect_target       = each.value.redirect_target
  wait_dns_verification = false

  depends_on = [google_firebase_hosting_custom_domain.landing]
}

resource "google_service_account" "web_deployer" {
  account_id   = "web-deployer"
  display_name = "GitHub Actions 랜딩 배포(web)"
}

resource "google_project_iam_member" "web_deployer" {
  for_each = toset(local.web_deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.web_deployer.email}"
}

# 이 프로젝트의 web environment가 배포 브랜치에서 도는 job만 씁니다. server의 staging, prod environment job은 쓸 수 없고,
# 반대로 web job은 server deployer를 쓸 수 없습니다(두 계정의 env_ref가 다름).
resource "google_service_account_iam_member" "web_deployer_wif" {
  service_account_id = google_service_account.web_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/github/attribute.env_ref/${var.environment}@refs/heads/${local.deploy_branch}"
}
