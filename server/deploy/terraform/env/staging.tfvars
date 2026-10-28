# staging (#607). ANDROID_CERT_SHA256에는 Play 앱 서명 지문과 debug 지문을 함께 둡니다(#607, debug는 staging만).
project_id          = "myungli-diary-staging"
project_number      = "1056563158649"
environment         = "staging"
sql_tier            = "db-f1-micro"
deletion_protection = false
test_login_enabled  = true

# 공개 값만 둡니다(spec §5). 빈 값은 아직 오지 않은 값이고, 필수 값이 비어 있으면 server 배포를 건너뜁니다.
# TRUSTED_PROXY_HOPS는 Firebase Hosting 앞단의 X-Forwarded-For 위치를 staging에서 확인해 정합니다(S117).
server_settings = {
  AD_FREE_PRODUCT_IDS     = ""
  ANDROID_APP_PACKAGE     = "app.myungli.diary"
  ANDROID_CERT_SHA256     = "69:6D:33:B9:F7:41:1A:76:9A:70:23:C3:EC:F0:D6:36:B1:17:33:DC:D7:BC:7D:DB:78:FA:43:9B:4F:B3:9A:93,E2:FA:71:8C:F4:CD:F1:4C:E4:7E:C7:38:32:FA:F3:86:D0:E7:BD:EF:5B:E9:EE:CC:E6:8C:CD:DC:60:E0:F5:DE"
  ANDROID_STORE_URL       = "https://play.google.com/store/apps/details?id=app.myungli.diary"
  APPLE_BUNDLE_ID         = "app.myungli.diary"
  APPLE_KEY_ID            = ""
  APPLE_SERVICES_ID       = ""
  APPLE_TEAM_ID           = ""
  APPLE_WEB_REDIRECT_URI  = ""
  APP_LINK_BASE           = ""
  APP_MIN_VERSION_ANDROID = ""
  APP_MIN_VERSION_IOS     = ""
  GOOGLE_CLIENT_IDS       = ""
  JWT_SIGNING_KEY_ID      = "jwt-2026-1"
  KAKAO_APP_KEY           = "8229ec22910b377c40ea71b1081c2a66"
  LINE_CHANNEL_ID         = ""
  LOG_LEVEL               = "info"
  REVENUECAT_PROJECT_ID   = ""
  TOKEN_ENCRYPTION_KEY_ID = "tok-2026-1"
  TRUSTED_PROXY_HOPS      = ""
}
