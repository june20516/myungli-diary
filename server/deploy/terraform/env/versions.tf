terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
  }

  # bucket은 init 때 -backend-config=bucket=<project_id>-tfstate로 넘깁니다(bootstrap 출력 state_bucket).
  backend "gcs" {
    prefix = "env"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
