output "engine_url" {
  value = google_cloud_run_v2_service.engine.uri
}

output "server_url" {
  value = google_cloud_run_v2_service.server.uri
}

output "secret_ids" {
  description = "값(버전)이 있어야 server가 시작하는 Secret. workflow가 버전 유무를 확인한 뒤 latest로 붙입니다"
  value       = sort(local.secret_ids)
}

output "missing_server_settings" {
  description = "비어 있는 필수 설정 이름. 비어 있지 않으면 workflow가 server 배포를 건너뜁니다"
  value       = sort([for name in local.required_server_settings : name if lookup(var.server_settings, name, "") == ""])
}

output "server_env" {
  description = "배포 workflow가 server 서비스와 Job에 붙이는 비밀이 아닌 환경 변수"
  value       = local.server_env
}
