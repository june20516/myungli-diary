# 프로젝트마다 사용자가 로컬에서 한 번 apply하는 기반 자원입니다(spec 2026-10-28-p9-deploy-design §2·§4, S121).
# state는 로컬에 남습니다. 이 자원을 바꿀 일이 드물고, env state bucket을 이 module이 만들기 때문입니다.

locals {
  services = [
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "firebasehosting.googleapis.com",
    "fcm.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "sts.googleapis.com",
  ]

  # deployer가 env 자원을 만들고 바꾸는 데 필요한 프로젝트 역할입니다.
  deployer_roles = [
    "roles/artifactregistry.writer",
    "roles/cloudscheduler.admin",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/dns.admin",
    "roles/firebasehosting.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageConsumer",
  ]

  # planner는 PR에서 plan만 돌리므로 env 자원의 읽기 역할만 가집니다. 같은 저장소 PR 브랜치 코드가 쓰므로
  # 로그를 읽을 수 있는 roles/viewer는 주지 않습니다(앱 로그에 개인정보가 섞일 수 있음).
  planner_roles = [
    "roles/cloudscheduler.viewer",
    "roles/cloudsql.viewer",
    "roles/compute.networkViewer",
    "roles/dns.reader",
    "roles/iam.securityReviewer",
    "roles/iam.serviceAccountViewer",
    "roles/run.viewer",
    "roles/secretmanager.viewer",
  ]
}

resource "google_project_service" "enabled" {
  for_each = toset(local.services)

  service            = each.value
  disable_on_destroy = false
}

# env module의 Terraform state입니다. 지운 state를 되살릴 수 있게 버전을 남깁니다.
resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}

# 엔진·server 이미지 저장소입니다. 엔진은 placeholder 이미지로 뜨지 않으므로 env보다 먼저 있어야 합니다(spec §3).
resource "google_artifact_registry_repository" "images" {
  repository_id = "myungli"
  location      = var.region
  format        = "DOCKER"

  depends_on = [google_project_service.enabled]
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.enabled]
}

# 이 저장소의 토큰만 받습니다. 계정별로 더 좁히는 조건은 아래 바인딩에 있습니다.
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"
  attribute_condition                = "assertion.repository == \"${var.github_repository}\""

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.ref"         = "assertion.ref"
    "attribute.environment" = "assertion.environment"
    "attribute.event_name"  = "assertion.event_name"
    # environment가 붙은 job의 sub에는 ref가 없으므로 environment와 ref를 묶은 속성으로 deployer를 main에만 허용합니다.
    "attribute.env_ref" = "has(assertion.environment) ? assertion.environment + '@' + assertion.ref : 'none'"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deployer" {
  account_id   = "deployer"
  display_name = "GitHub Actions 배포"

  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "planner" {
  account_id   = "planner"
  display_name = "GitHub Actions plan (읽기 전용)"

  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.deployer.email}"

  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_member" "planner" {
  for_each = toset(local.planner_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.planner.email}"

  depends_on = [google_project_service.enabled]
}

resource "google_storage_bucket_iam_member" "deployer_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_storage_bucket_iam_member" "planner_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.planner.email}"
}

# deployer는 main에서 이 프로젝트의 environment로 도는 job만 씁니다(attribute.env_ref). 다른 environment의 job은
# 이 프로젝트에 들어오지 못합니다(#644). GitHub environment의 "Deployment branches = main" 제한은 이중 장치입니다(README).
# for_each key를 environment 이름으로 두어, 두 environment를 모두 연결하던 state에서 맞는 연결은 그대로 남습니다.
resource "google_service_account_iam_member" "deployer_wif" {
  for_each = toset([var.environment])

  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.env_ref/${each.value}@refs/heads/main"
}

# planner는 같은 저장소의 pull_request 토큰만 씁니다.
resource "google_service_account_iam_member" "planner_wif" {
  service_account_id = google_service_account.planner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.event_name/pull_request"
}
