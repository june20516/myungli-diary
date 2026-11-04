terraform {
  required_version = ">= 1.9"

  # state 원본은 이 module이 만드는 그 프로젝트의 state bucket `bootstrap/` 아래입니다(D98, #662).
  # bucket과 prefix는 init 때 넘깁니다. bucket이 아직 없는 새 프로젝트는 README "새 프로젝트"를 따릅니다.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Billing Budgets API는 사용자 ADC로 부를 때 quota project가 있어야 합니다(없으면 403, provider google_billing_budget 문서).
# 다른 자원에는 quota project 헤더를 붙이지 않도록 예산만 이 alias를 씁니다.
provider "google" {
  alias                 = "billing"
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
