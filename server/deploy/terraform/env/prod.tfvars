# prod (#607). ANDROID_CERT_SHA256은 Play 앱 서명 지문만 둡니다.
# GOOGLE_CLIENT_IDS는 web, iOS, Android client입니다. debug Android client는 staging에만 둡니다(#607).
project_id          = "myungli-diary"
project_number      = "21526308173"
environment         = "prod"
sql_tier            = "db-custom-1-3840"
deletion_protection = true
# db-custom-1-3840(3.75GB)은 Cloud SQL max_connections 표의 3.75~6GB 행 100입니다(S133).
sql_max_connections = 100
# 공개 주소가 아직 server에 연결되지 않아(GET /health 404, 2026-11-04) uptime check는 출시 연결 때 켭니다(S133).
uptime_check_enabled = false
test_login_enabled   = false
billing_enabled      = true # AD_FREE_PRODUCT_IDS는 App Store, Play 상품의 RevenueCat 상품 id(prod…)입니다(S124).

# 공개 값만 둡니다(spec §5). 빈 값은 아직 오지 않은 값이고, 필수 값이 비어 있으면 server 배포를 건너뜁니다.
# TRUSTED_PROXY_HOPS=2: 공개 주소(Firebase Hosting)로 온 요청의 X-Forwarded-For가 [보낸 사람, Hosting]이라 오른쪽 두 번째가
# 보낸 사람입니다. Hosting은 보낸 사람이 붙인 값을 버리고 새로 씁니다. 직접 주소(run.app)는 꺼 둡니다(run.tf, S135).
# 문의 메일(S134): Secret RESEND_API_KEY에 값을 넣은 뒤 true로 바꿉니다. 그 전에는 createInquiry가 503입니다.
support_mail_enabled = false

server_settings = {
  AD_FREE_PRODUCT_IDS     = ""
  ANDROID_APP_PACKAGE     = "app.myungli.diary"
  ANDROID_CERT_SHA256     = "69:6D:33:B9:F7:41:1A:76:9A:70:23:C3:EC:F0:D6:36:B1:17:33:DC:D7:BC:7D:DB:78:FA:43:9B:4F:B3:9A:93"
  ANDROID_STORE_URL       = "https://play.google.com/store/apps/details?id=app.myungli.diary"
  APPLE_BUNDLE_ID         = "app.myungli.diary"
  APPLE_KEY_ID            = "34D2V94KFV"
  APPLE_SERVICES_ID       = "app.myungli.diary.web"
  APPLE_TEAM_ID           = "7JGP3D7B3Z"
  APPLE_WEB_REDIRECT_URI  = "https://api.myungli-diary.app/v1/auth/apple/callback"
  APP_LINK_BASE           = "https://api.myungli-diary.app"
  APP_MIN_VERSION_ANDROID = ""
  APP_MIN_VERSION_IOS     = ""
  GOOGLE_CLIENT_IDS       = "21526308173-7h0jo5hbrvdulc3o7n6g66q817b93cuf.apps.googleusercontent.com,21526308173-u42i6abek48hvbg5grd8lvj8leoutj6p.apps.googleusercontent.com,21526308173-c3ekmpn76t26bv9j8hnohcsh2990di7q.apps.googleusercontent.com"
  JWT_SIGNING_KEY_ID      = "jwt-2026-1"
  KAKAO_APP_KEY           = "8229ec22910b377c40ea71b1081c2a66"
  LINE_CHANNEL_ID         = "2012273411"
  LOG_LEVEL               = "info"
  REVENUECAT_PROJECT_ID   = ""
  SUPPORT_MAIL_FROM       = "명리일기 <noreply@myungli-diary.app>"
  SUPPORT_MAIL_TO         = "support@myungli-diary.app"
  TOKEN_ENCRYPTION_KEY_ID = "tok-2026-1"
  TRUSTED_PROXY_HOPS      = "2"
}
