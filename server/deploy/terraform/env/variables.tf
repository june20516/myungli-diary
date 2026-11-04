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

variable "sql_max_connections" {
  description = "Cloud SQL PostgreSQL max_connections(tier 메모리의 기본값, S133). 연결 수 알림은 이 값의 80%입니다"
  type        = number
}

variable "uptime_check_enabled" {
  description = "공개 주소 GET /health uptime check와 그 알림을 둘지(S133). 공개 주소가 server에 연결된 환경만 true"
  type        = bool
  default     = false
}

variable "support_mail_enabled" {
  description = "문의 메일(Resend) 키를 server에 붙일지(S134). Secret RESEND_API_KEY에 값을 넣은 뒤 true로 바꿉니다. false면 createInquiry가 503입니다"
  type        = bool
  default     = false
}

variable "scheduler_enabled" {
  description = "배포 workflow가 server 배포 뒤 Scheduler(retention, precompute, notify)를 켤지. 부하 환경은 측정 중 배치가 끼지 않게 false입니다(D104)"
  type        = bool
  default     = true
}

variable "load_generator_enabled" {
  description = "부하 생성기 Job load-k6를 둡니다(L1-2b, D104). 부하 프로젝트만 true이고, bootstrap이 만든 결과 bucket을 씁니다"
  type        = bool
  default     = false

  validation {
    condition     = !var.load_generator_enabled || var.test_login_enabled
    error_message = "load_generator_enabled는 test_login_enabled가 true일 때만 켭니다(k6가 테스트 로그인으로 계정을 씀)."
  }
}
