# staging (#607). ANDROID_CERT_SHA256에는 Play 앱 서명 지문과 debug 지문을 함께 둡니다(#607, debug는 staging만).
# GOOGLE_CLIENT_IDS는 web, iOS, Android, debug Android client입니다. Android token의 azp까지 받으려면 Android ID도 있어야 합니다(#607).
project_id          = "myungli-diary-staging"
project_number      = "1056563158649"
environment         = "staging"
sql_tier            = "db-f1-micro"
deletion_protection = false
# db-f1-micro(공유 코어, 약 0.6GB)는 Cloud SQL max_connections 표의 tiny 행 25로 봅니다(S133, L1에서 SHOW max_connections로 확인).
sql_max_connections = 25
# 공개 주소 api-staging이 server에 연결돼 있어 uptime check를 둡니다(S133).
uptime_check_enabled = true
test_login_enabled   = true

# staging 결제는 RevenueCat Test Store(sandbox) 구매로 켭니다(D99, #683). APP_ENV가 prod가 아니라 sandbox 구매도 장부에 적습니다.
# AD_FREE_PRODUCT_IDS는 Test Store 상품(식별자 ad_free_1m, consumable)의 RevenueCat 상품 id입니다(S124).
# Secret REVENUECAT_API_KEY, REVENUECAT_WEBHOOK_AUTH는 staging Secret Manager에 있습니다(K8).
billing_enabled = true

# 공개 값만 둡니다(spec §5). 빈 값은 아직 오지 않은 값이고, 필수 값이 비어 있으면 server 배포를 건너뜁니다.
# TRUSTED_PROXY_HOPS=2: 공개 주소(Firebase Hosting)로 온 요청의 X-Forwarded-For가 [보낸 사람, Hosting]이라 오른쪽 두 번째가
# 보낸 사람입니다. Hosting은 보낸 사람이 붙인 값을 버리고 새로 씁니다. 직접 주소(run.app)는 꺼 둡니다(run.tf, S135).
# 문의 메일(S134): Secret RESEND_API_KEY 버전 1이 들어 있습니다(2026-11-04, #767). 키를 지우면 false로 되돌립니다.
support_mail_enabled = true

server_settings = {
  AD_FREE_PRODUCT_IDS     = "prod0bc032dedf"
  ANDROID_APP_PACKAGE     = "app.myungli.diary"
  ANDROID_CERT_SHA256     = "69:6D:33:B9:F7:41:1A:76:9A:70:23:C3:EC:F0:D6:36:B1:17:33:DC:D7:BC:7D:DB:78:FA:43:9B:4F:B3:9A:93,E2:FA:71:8C:F4:CD:F1:4C:E4:7E:C7:38:32:FA:F3:86:D0:E7:BD:EF:5B:E9:EE:CC:E6:8C:CD:DC:60:E0:F5:DE"
  ANDROID_STORE_URL       = "https://play.google.com/store/apps/details?id=app.myungli.diary"
  APPLE_BUNDLE_ID         = "app.myungli.diary"
  APPLE_KEY_ID            = "34D2V94KFV"
  APPLE_SERVICES_ID       = "app.myungli.diary.web"
  APPLE_TEAM_ID           = "7JGP3D7B3Z"
  APPLE_WEB_REDIRECT_URI  = "https://api-staging.myungli-diary.app/v1/auth/apple/callback"
  APP_LINK_BASE           = "https://api-staging.myungli-diary.app"
  APP_MIN_VERSION_ANDROID = ""
  APP_MIN_VERSION_IOS     = ""
  GOOGLE_CLIENT_IDS       = "21526308173-7h0jo5hbrvdulc3o7n6g66q817b93cuf.apps.googleusercontent.com,21526308173-u42i6abek48hvbg5grd8lvj8leoutj6p.apps.googleusercontent.com,21526308173-c3ekmpn76t26bv9j8hnohcsh2990di7q.apps.googleusercontent.com,21526308173-epl92mnn601mi0guc05odkfnj2h9bdp4.apps.googleusercontent.com"
  JWT_SIGNING_KEY_ID      = "jwt-2026-1"
  KAKAO_APP_KEY           = "8229ec22910b377c40ea71b1081c2a66"
  LINE_CHANNEL_ID         = "2012273411"
  LOG_LEVEL               = "info"
  REVENUECAT_PROJECT_ID   = "proj43a24b27"
  SUPPORT_MAIL_FROM       = "명리일기 <noreply@myungli-diary.app>"
  SUPPORT_MAIL_TO         = "support@myungli-diary.app"
  TOKEN_ENCRYPTION_KEY_ID = "tok-2026-1"
  TRUSTED_PROXY_HOPS      = "2"
}
