# Cloud Run 요청 로그(run.googleapis.com/requests)는 주소를 query까지 그대로 남깁니다. App Link 안내 페이지
# GET /auth/apple은 query에 Apple 웹 로그인의 일회용 교환 코드가 있으므로(S22) 그 요청 로그를 받지 않습니다(S136).
# server 자체 요청 로그는 경로 패턴만 남겨 이 경로도 그대로 보입니다. 제외는 로그 설정 권한이 필요해 deployer에 주지 않고
# 사용자가 apply하는 bootstrap에 둡니다. 물음표는 escape가 중간에 풀리지 않게 문자 클래스 [?]로 씁니다.
resource "google_logging_project_exclusion" "apple_return_query" {
  name        = "cloud-run-auth-apple-query"
  description = "GET /auth/apple의 query(일회용 교환 코드)가 든 Cloud Run 요청 로그를 받지 않습니다(S136)"
  filter      = "logName=\"projects/${var.project_id}/logs/run.googleapis.com%2Frequests\" AND httpRequest.requestUrl=~\"/auth/apple[?]\""
}

# 요청 로그를 포함한 `_Default` bucket의 보관 기간입니다. 기본 30일을 처리방침의 접속 기록 3개월(S113)에 맞춰 90일로 둡니다(D137 ①, S164).
# bucket 설정 권한도 로그 설정 권한이라 bootstrap에 둡니다(S136과 같은 이유). 30일을 넘는 보관분은 Cloud Logging 보관 요금이 붙습니다.
# 이 자원을 state에서 지워도 `_Default` bucket은 지워지지 않고 설정만 그대로 남습니다.
resource "google_logging_project_bucket_config" "default" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = 90
}
