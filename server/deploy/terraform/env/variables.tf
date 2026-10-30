variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "project_number" {
  description = "GCP 프로젝트 번호. FIREBASE_PROJECT_NUMBER와 같습니다(#607)"
  type        = string
}

variable "environment" {
  description = "APP_ENV 값"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment는 staging 또는 prod입니다."
  }
}

variable "billing_enabled" {
  description = "결제(RevenueCat) 설정을 server에 붙이는지. false면 결제 설정 둘과 결제 Secret 둘을 필수에서 빼고 붙이지 않아 server가 결제를 끈 채 시작합니다(#654). prod는 true만 됩니다"
  type        = bool
  default     = true

  validation {
    condition     = var.billing_enabled || var.environment != "prod"
    error_message = "prod는 billing_enabled = true여야 합니다."
  }
}

variable "region" {
  description = "리전 (S117)"
  type        = string
  default     = "asia-northeast3"
}

variable "sql_tier" {
  description = "Cloud SQL machine tier"
  type        = string
}

variable "deletion_protection" {
  description = "Cloud SQL·Cloud Run 삭제 보호"
  type        = bool
}

variable "test_login_enabled" {
  description = "staging 테스트 로그인(S24)의 TEST_LOGIN_SECRET을 만들고 연결할지"
  type        = bool
  default     = false
}

variable "server_settings" {
  description = "server의 비밀이 아닌 설정(환경 변수 이름 그대로). 빈 값은 넣지 않습니다"
  type        = map(string)
}

variable "jwt_previous_key_id" {
  description = "JWT 키 교체 중일 때 이전 키 id. 있으면 JWT_PREVIOUS_KEY Secret을 만들고 연결합니다"
  type        = string
  default     = ""
}

variable "token_previous_key_id" {
  description = "token 암호화 키 교체 중일 때 이전 키 id. 있으면 TOKEN_PREVIOUS_KEY Secret을 만들고 연결합니다"
  type        = string
  default     = ""
}
