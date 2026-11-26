terraform {
  required_version = ">= 1.9"

  # state 원본은 그 프로젝트의 state bucket(server bootstrap이 만든 `<프로젝트>-tfstate`) 안 `web/` prefix입니다(D98).
  # bucket과 prefix는 init 때 넘깁니다(web/deploy/README.md).
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
