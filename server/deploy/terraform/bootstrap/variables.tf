variable "project_id" {
  description = "GCP 프로젝트 ID (staging: myungli-diary-staging, prod: myungli-diary)"
  type        = string
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
