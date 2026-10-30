# prod (#607). ANDROID_CERT_SHA256은 Play 앱 서명 지문만 둡니다.
project_id          = "myungli-diary"
project_number      = "21526308173"
environment         = "prod"
sql_tier            = "db-custom-1-3840"
deletion_protection = true
test_login_enabled  = false
billing_enabled     = true # AD_FREE_PRODUCT_IDS는 App Store, Play 상품의 RevenueCat 상품 id(prod…)입니다(S124).

# 공개 값만 둡니다(spec §5). 빈 값은 아직 오지 않은 값이고, 필수 값이 비어 있으면 server 배포를 건너뜁니다.
# TRUSTED_PROXY_HOPS는 Firebase Hosting 앞단의 X-Forwarded-For 위치를 staging에서 확인해 정합니다(S117).
server_settings = {
  AD_FREE_PRODUCT_IDS     = ""
  ANDROID_APP_PACKAGE     = "app.myungli.diary"
  ANDROID_CERT_SHA256     = "69:6D:33:B9:F7:41:1A:76:9A:70:23:C3:EC:F0:D6:36:B1:17:33:DC:D7:BC:7D:DB:78:FA:43:9B:4F:B3:9A:93"
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
