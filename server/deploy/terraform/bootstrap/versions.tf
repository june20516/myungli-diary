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
