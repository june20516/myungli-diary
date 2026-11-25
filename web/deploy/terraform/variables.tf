variable "project_id" {
  description = "Firebase(GCP) 프로젝트 id"
  type        = string
}

variable "region" {
  description = "기본 리전(Hosting은 리전이 없고 provider 기본값으로만 씀)"
  type        = string
  default     = "asia-northeast3"
}

variable "environment" {
  description = "이 프로젝트에 배포하는 GitHub environment. web-staging은 staging 브랜치, web-prod는 main 브랜치에서만 배포합니다"
  type        = string

  validation {
    condition     = contains(["web-staging", "web-prod"], var.environment)
    error_message = "environment는 web-staging 또는 web-prod입니다."
  }
}

variable "site_id" {
  description = "Firebase Hosting 사이트 id(전역 유일, 기본 주소 <site_id>.web.app)"
  type        = string
}

variable "domains" {
  description = "사이트에 붙이는 커스텀 도메인. redirect_target이 있으면 그 도메인으로 보내기만 합니다(www → 본 도메인)"
  type = list(object({
    name            = string
    redirect_target = optional(string)
  }))
}
