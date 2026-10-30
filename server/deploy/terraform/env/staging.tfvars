# staging (#607). ANDROID_CERT_SHA256에는 Play 앱 서명 지문과 debug 지문을 함께 둡니다(#607, debug는 staging만).
# GOOGLE_CLIENT_IDS는 web, iOS, Android, debug Android client입니다. Android token의 azp까지 받으려면 Android ID도 있어야 합니다(#607).
project_id          = "myungli-diary-staging"
project_number      = "1056563158649"
environment         = "staging"
sql_tier            = "db-f1-micro"
deletion_protection = false
test_login_enabled  = true

# RevenueCat 값은 사업자등록(E15) 뒤에 만들 수 있어, 그때까지 staging server는 결제를 끈 채 배포합니다(#654, #632).
# 값이 오면 결제 설정 둘과 Secret 둘을 채우고 true로 바꿉니다. AD_FREE_PRODUCT_IDS는 Test Store 상품의 RevenueCat 상품 id(prod…)입니다(#683, S124).
billing_enabled = false

# 공개 값만 둡니다(spec §5). 빈 값은 아직 오지 않은 값이고, 필수 값이 비어 있으면 server 배포를 건너뜁니다.
# TRUSTED_PROXY_HOPS는 Firebase Hosting 앞단의 X-Forwarded-For 위치를 staging에서 확인해 정합니다(S117).
server_settings = {
  AD_FREE_PRODUCT_IDS     = ""
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
  REVENUECAT_PROJECT_ID   = ""
  TOKEN_ENCRYPTION_KEY_ID = "tok-2026-1"
  TRUSTED_PROXY_HOPS      = ""
}
