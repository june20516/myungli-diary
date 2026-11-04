# 부하 전용 프로젝트(L1, D104, 외부 준비물 E21). staging 빌드(테스트 로그인)를 prod와 같은 SQL 크기로 띄웁니다.
# APP_ENV는 staging입니다(environment 변수는 APP_ENV 값이고, GitHub environment 이름 load와 다름).
# 측정 회차가 끝나면 deploy-server의 load-teardown이 Cloud SQL만 지웁니다. Secret 틀과 값, 나머지 자원은 남깁니다.
project_id = "myungli-diary-load"
# project_number는 Firebase 콘솔의 Project number이고 FIREBASE_PROJECT_NUMBER가 됩니다(2026-11-04 gcloud projects describe로 대조).
project_number      = "244522770563"
environment         = "staging"
sql_tier            = "db-custom-1-3840"
deletion_protection = false
# prod와 같은 tier라 max_connections 표의 3.75~6GB 행 100입니다(S133). 첫 회차에 SHOW max_connections로 확인합니다.
sql_max_connections = 100
# 측정 중 배치가 끼지 않게 Scheduler를 켜지 않습니다. precompute는 warm 회차 전에 손으로 돌립니다(L1 plan §3).
scheduler_enabled    = false
uptime_check_enabled = false
test_login_enabled   = true
# 같은 region에서 k6를 돌리는 생성기 Job입니다(L1-2b). 결과 bucket은 bootstrap이 만듭니다.
load_generator_enabled = true
# 결제와 문의 메일은 측정 흐름에 없어 끕니다. REVENUECAT_*, RESEND_API_KEY 값이 없어도 배포합니다.
billing_enabled      = false
support_mail_enabled = false

# 공개 값은 staging과 같습니다. 외부 로그인(Kakao, LINE, Apple, Google)은 테스트 로그인만 쓰므로 불리지 않습니다.
# 공개 주소는 Firebase Hosting 기본 도메인입니다. TRUSTED_PROXY_HOPS=2는 staging과 같은 Hosting 구조이기 때문입니다(S135).
server_settings = {
  AD_FREE_PRODUCT_IDS     = ""
  ANDROID_APP_PACKAGE     = "app.myungli.diary"
  ANDROID_CERT_SHA256     = "69:6D:33:B9:F7:41:1A:76:9A:70:23:C3:EC:F0:D6:36:B1:17:33:DC:D7:BC:7D:DB:78:FA:43:9B:4F:B3:9A:93"
  ANDROID_STORE_URL       = "https://play.google.com/store/apps/details?id=app.myungli.diary"
  APPLE_BUNDLE_ID         = "app.myungli.diary"
  APPLE_KEY_ID            = "34D2V94KFV"
  APPLE_SERVICES_ID       = "app.myungli.diary.web"
  APPLE_TEAM_ID           = "7JGP3D7B3Z"
  APPLE_WEB_REDIRECT_URI  = "https://myungli-diary-load.web.app/v1/auth/apple/callback"
  APP_LINK_BASE           = "https://myungli-diary-load.web.app"
  APP_MIN_VERSION_ANDROID = ""
  APP_MIN_VERSION_IOS     = ""
  GOOGLE_CLIENT_IDS       = "21526308173-7h0jo5hbrvdulc3o7n6g66q817b93cuf.apps.googleusercontent.com"
  JWT_SIGNING_KEY_ID      = "jwt-load-1"
  KAKAO_APP_KEY           = "8229ec22910b377c40ea71b1081c2a66"
  LINE_CHANNEL_ID         = "2012273411"
  LOG_LEVEL               = "info"
  REVENUECAT_PROJECT_ID   = ""
  SUPPORT_MAIL_FROM       = "명리일기 <noreply@myungli-diary.app>"
  SUPPORT_MAIL_TO         = "support@myungli-diary.app"
  TOKEN_ENCRYPTION_KEY_ID = "tok-load-1"
  TRUSTED_PROXY_HOPS      = "2"
}
