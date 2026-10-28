# 외부 준비물

사용자만 할 수 있는 외부 계정·설정·서류의 대장입니다(D91 ②). 무엇을 언제까지 준비하는지, 끝나면 어떤 값을 어디로 넘기는지를 여기 하나로 관리합니다. 고치는 쪽은 지휘 세션입니다.

## 절차

1. **등록:** 단위가 외부 값이나 계정이 필요해지면 `to:root`·`kind:prep` Issue로 올립니다. 지휘가 아래 대장에 행을 더합니다. 지휘가 결정·로드맵에서 찾은 것도 같습니다.
2. **안내:** 지휘는 정기 일과마다 대장을 보고, "막는 것"이 다음 두 박자 안에 닿거나 "오래 걸림"이 있는 항목을 사용자에게 알립니다. 알릴 항목마다 `to:user`·`kind:prep` Issue를 열고 절차를 적습니다. 절차는 Issue를 열 때 공식 문서로 다시 확인하고 출처를 붙입니다(콘솔 화면은 자주 바뀝니다).
3. **수집:**
   * **공개 값**(ID, 번들 ID, client ID, 채널 ID, 인증서 지문, 주소)은 사용자가 그 Issue에 코멘트로 남깁니다.
   * **비밀 값**(개인 키, Admin 키, API secret, webhook 인증 값)은 저장소·Issue·대화 어디에도 붙이지 않습니다. 사용자가 Issue에 적힌 곳(GCP Secret Manager의 이름 등)에 직접 넣고 "넣음"만 남깁니다. 지휘는 그 이름이 있는지만 확인합니다.
   * **파일:** 비밀 파일(Apple `.p8` 키, 서비스 계정 JSON)은 비밀 값과 같이 다룹니다. 공개 설정 파일은 받는 단위가 알려 준 경로로 넘깁니다.
4. **전달:** 지휘가 값을 쓰는 단위의 Issue(없으면 새 `kind:request`)에 공개 값과 비밀 이름을 적습니다. 대장의 상태를 "완료"로 바꾸고 `kind:prep` Issue를 닫습니다.
5. **공개 저장소(D74):** 비용은 "유료·무료"까지만 적고 금액은 적지 않습니다.

## server 배포와의 관계

server는 `APP_ENV`가 `staging`·`prod`이면 E7~E12의 값이 하나라도 비었을 때 시작하지 않습니다(`server/internal/platform/config/config.go`의 `LoadAuth`·`LoadBilling`). 그래서 server 배포(P9)와 그 뒤의 I1·I2는 이 묶음이 모두 끝나야 합니다. `local`에서는 이 값 없이 돌아가므로 app의 REST 연동(A2)은 먼저 시작할 수 있습니다(D91 ①).

## 알아 둘 사실 (2026-10-23 조사, 출처는 각 Issue)

* **앱 내 결제를 팔려면 두 스토어 모두 사업자등록이 사실상 전제입니다.** Apple은 세금 양식에 사업자등록번호와 영문 사업자등록증명을, Google은 사업자등록번호·통신판매업 신고번호를 요구합니다(E15). 사업자등록은 앱을 받아 본 뒤에 하므로(D92 개정), 그때까지 출시와 스토어 판매 설정이 필요한 결제 시험은 기다립니다. 결제 시험에 판매 설정이 꼭 필요한지는 E12 차례에 공식 문서로 확인합니다.
* **개인사업자는 Apple에 Individual로만 가입하고 판매자 이름이 실명입니다.** Google 개인 계정으로 판매하면 전체 주소와 전화번호가 공개됩니다(D92).
* **Google Play 새 개인 계정은 출시 전 비공개 테스트 의무가 있습니다.** 테스터 12명 이상이 14일 연속 참여하고, 그 뒤 production 심사가 보통 7일입니다(E3).
* **외부 서비스에 등록하는 Android 지문은 Play가 보관한 앱 서명 키의 것입니다**(로컬 upload key 아님). 카카오는 SHA-1을 Base64로 바꾼 키 해시를 씁니다(E8~E11).
* Cloud Run 커스텀 도메인 연결은 Preview이고 서울 리전을 지원하지 않습니다. 연결 방식은 server가 정합니다(#540, E6).
* LINE 로그인의 서비스 지역에 한국이 없어 Japan을 고릅니다(E10). Android 1개월 이용권의 상품 유형은 server가 정합니다(#540, E12).

## 대장

상태: 준비 전 · 진행 중 · 완료 · 보류. "막는 것"이 이르고 "오래 걸림"이 있는 순서로 적습니다.

| id | 항목 | 막는 것 | 전제 | 오래 걸림 | 넘길 값 (공개 / 비밀) | 받는 단위 | 상태 | Issue |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | **개인·사업자(조직) 중 어느 이름으로 낼지 정하기.** Apple·Google Play 판매자 이름, 사업자등록과 묶입니다 | E2·E3·E15 | - | - | 결정 | 지휘(결정으로 적음) | 완료: 개인사업자(D92) | - |
| E15 | 사업자등록, 통신판매업 신고, 스토어 세금·정산 정보 (D53) | E2·E3의 판매 설정(세금·정산), E12, I4 | E1 | 처리 기간(확인 못 함) | - | - | 보류: 앱을 받아 본 뒤(D92 개정) | #534 |
| E2 | Apple Developer Program 가입 | E7·E12, P9, I4 | E1 | 본인 확인·심사 | 공개: Team ID | server, app | 진행 중 | #536 |
| E3 | Google Play Console 개발자 계정과 앱 만들기 | E8·E11·E12, P9, T1(비공개 테스트 트랙, 새 개인 계정의 출시 전 비공개 테스트 의무), I4 | E1 | 본인 확인, 비공개 테스트(테스터 12명 이상 14일 연속 + 심사 약 7일) | 공개: 패키지 이름 확인 | server, app | 진행 중 | #535 |
| E4 | GCP 프로젝트: 결제 계정, Cloud Run·Cloud SQL·Artifact Registry·Secret Manager API, GitHub Actions용 Workload Identity Federation (D56) | P9 → I1·I2 | - | - | 공개: 프로젝트 id, 리전 | server(절차는 server가 함께 안내) | 진행 중 | #537 |
| E5 | Firebase(같은 GCP 프로젝트): App Check, FCM, Crashlytics, iOS APNs 키 (D64) | P9, 아침 알림, A2 | E2·E4 | - | 공개: `FIREBASE_PROJECT_NUMBER`, 앱 설정 파일 / 비밀: APNs 키 | server, app | 준비 전 | - |
| E6 | 서비스 도메인 구입과 DNS: API 주소, Android App Link(`APP_LINK_BASE`)·`assetlinks.json`, Apple 웹 로그인 복귀 주소 (#89, S22) | E7, P9 | - | DNS 전파 | 공개: 도메인 | server, app | 진행 중 | #538 |
| E7 | Apple 로그인 설정: App ID(Sign in with Apple), Services ID, 웹 복귀 주소, 로그인 키 | P9, A2 실제 로그인 | E2·E6 | - | 공개: `APPLE_TEAM_ID`·`APPLE_BUNDLE_ID`·`APPLE_SERVICES_ID`·`APPLE_KEY_ID`·`APPLE_WEB_REDIRECT_URI` / 비밀: `APPLE_PRIVATE_KEY`(.p8) | server, app | 준비 전 | - |
| E8 | Android 앱 서명 지문과 스토어 URL (#311, #114 ④) | P9, App Link | E3 | - | 공개: `ANDROID_APP_PACKAGE`·`ANDROID_CERT_SHA256`·`ANDROID_STORE_URL` | server, app | 준비 전 | - |
| E9 | Kakao Developers 앱과 카카오 로그인 (D55) | P9, A2 실제 로그인 | - | - | 공개: `KAKAO_APP_KEY`(id_token audience), 앱에 넣는 네이티브 앱 키 / 비밀: `KAKAO_ADMIN_KEY` | server, app | 준비 전 | - |
| E10 | LINE Developers 로그인 채널(이메일 권한 신청 없음, D82) | P9, A2 실제 로그인 | E2·E3(앱 식별자) | - | 공개: `LINE_CHANNEL_ID` | server, app | 준비 전 | - |
| E11 | Google OAuth client(iOS·Android·Web)와 동의 화면 (D82) | P9, A2 실제 로그인 | E3(Android 서명 지문) | 동의 화면 검증이 필요할 때 | 공개: `GOOGLE_CLIENT_IDS` | server, app | 준비 전 | - |
| E12 | RevenueCat 프로젝트, App Store Connect·Google Play 연결, 광고 제거권 상품 (D53) | P9, A2 결제 | E2·E3 | 스토어 상품 심사 | 공개: `REVENUECAT_PROJECT_ID`·`AD_FREE_PRODUCT_IDS`, 앱 공개 SDK 키 / 비밀: `REVENUECAT_API_KEY`·`REVENUECAT_WEBHOOK_AUTH` | server, app | 준비 전 | - |
| E13 | AdMob 계정, 앱 등록, 보상형 광고 단위, SSV 콜백 URL(server가 주소 안내) (D53·D60) | A2 광고, I4 | E6 | 계정 검증(보통 하루, 최대 2주), 앱 검토 | 공개: AdMob 앱 ID, 광고 단위 ID | server, app | 진행 중(계정) | #539 |
| E14 | 문의 전용 메일 주소(앱 문의하기와 스토어 지원 연락처, D89) | A2 문의하기, 스토어 등록 | - | - | 공개: 주소 | app, writing | 준비 전 | - |
| E16 | 이용약관·개인정보 처리방침 ko·en·ja 원문(D80·D86 ⑥). 수집·보관 항목은 `docs/legal/data-inventory.md` | I4 | E14·E15 | - | 원문 `docs/legal/<언어>/` (초안은 지휘) | server | 준비 전 | - |
| E17 | 출시 전 정책 검토: AdMob 보상형 광고 고지 문구(`evidence-sheet.lock.reward`), 스토어 심사 기준 | I4 | E13 | - | - | writing, design | 준비 전 | - |
| E18 | 영어·일본어 원어민 검수 | W1 | - | - | - | writing | 준비 전 | - |

### 끝난 것

| 항목 | 끝난 때 |
| --- | --- |
| 한국천문연구원 API 키(data.go.kr: 24절기·음양력) | core KASI 골든 테스트에 씀 |
| KASI 자료의 저장소 재배포 허용 범위 확인 | 2026-10-10: 공공데이터포털 음양력 정보(15012679)·특일 정보(15012690) 모두 "이용허락범위 제한 없음", 무료. 출처 표기는 core에 요청 |
| 배포 플랫폼 선정(서버·엔진) | D56: GCP Cloud Run + Cloud SQL |
| `buf` 설치 | core 세션 |
