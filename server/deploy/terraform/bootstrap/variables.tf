variable "project_id" {
  description = "GCP 프로젝트 ID (staging: myungli-diary-staging, prod: myungli-diary)"
  type        = string
}

variable "environment" {
  description = "이 프로젝트에 배포하는 GitHub environment. deployer는 이 environment의 main job만 씁니다(#644)"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment는 staging 또는 prod입니다."
  }
}

variable "region" {
  description = "리전 (S117)"
  type        = string
  default     = "asia-northeast3"
}

variable "github_repository" {
  description = "WIF 토큰을 받을 GitHub 저장소 (owner/name)"
  type        = string
  default     = "june20516/myungli-diary"
}
