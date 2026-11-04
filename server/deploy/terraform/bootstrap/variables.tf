variable "project_id" {
  description = "GCP 프로젝트 ID (staging: myungli-diary-staging, prod: myungli-diary)"
  type        = string
}

variable "environment" {
  description = "이 프로젝트에 배포하는 GitHub environment. deployer는 이 environment의 main job만 씁니다(#644)"
  type        = string

  validation {
    condition     = contains(["staging", "prod", "load"], var.environment)
    error_message = "environment는 staging, prod, load(부하 전용 프로젝트, D104) 중 하나입니다."
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

# 아래 넷은 공개 저장소에 적지 않는 로컬 값입니다(D74, D98 L3). `$MYUNGLI_LOCAL_DIR/server/<환경>/observability.tfvars`에 두고
# apply 때 -var-file로 넘깁니다(README, docs/local-values.md K14).

variable "alert_email" {
  description = "알림을 받는 메일 주소(O1, S133). 로컬 값"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email은 메일 주소입니다."
  }
}

variable "billing_account_id" {
  description = "이 프로젝트가 연결된 결제 계정 id(XXXXXX-XXXXXX-XXXXXX). 로컬 값"
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account_id))
    error_message = "billing_account_id는 XXXXXX-XXXXXX-XXXXXX 형식입니다."
  }
}

variable "budget_amount" {
  description = "이 프로젝트의 월 예산(결제 계정 통화의 정수 단위). 로컬 값(D74)"
  type        = number

  validation {
    condition     = var.budget_amount > 0 && floor(var.budget_amount) == var.budget_amount
    error_message = "budget_amount는 양의 정수입니다."
  }
}

variable "budget_currency" {
  description = "결제 계정 통화(ISO 4217, 예 KRW, USD). 결제 계정 통화와 같아야 합니다. 로컬 값"
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.budget_currency))
    error_message = "budget_currency는 ISO 4217 세 글자입니다."
  }
}
