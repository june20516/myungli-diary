# server 구현 계획 목록

spec: [`../specs/2026-10-11-server-mvp-design.md`](../specs/2026-10-11-server-mvp-design.md)

spec이 서브시스템 9개를 다루므로 계획을 나눕니다. 각 계획은 그 자체로 동작하고 테스트할 수 있는 결과로 끝납니다. 다음 계획은 앞 계획이 병합된 뒤 실제 코드를 보고 씁니다(rolling wave). 앞 계획에서 정한 인터페이스가 다음 계획의 입력이기 때문입니다.

| 순서 | 계획 | spec 절 | 상태 |
| --- | --- | --- | --- |
| P1 | [기반과 REST 계약 초안](2026-10-11-p1-foundation.md): 모듈, 하위 명령, 설정, Clock, 로깅, DB·migration, HTTP 뼈대, 오류 형식, `openapi.yaml` 초안, 생성 코드, CI, 이미지 | §2, §5, §11.1, §12, §13.1 일부 | **완료** |
| P2 | [인증·계정·약관](2026-10-13-p2-auth-account.md): 카카오·Apple 검증, JWT, refresh rotation, 동의, 삭제 예약·복구(S105로 즉시 삭제로 바뀜) | §3.3 계정, §4 | **완료** |
| P2a | [Apple 웹 로그인 복귀](2026-10-13-apple-web-login.md): 일회용 교환 코드, `completeAppleWebLogin`, App Link 안내 페이지·assetlinks (Issue #89, S22) | §4 | **완료** |
| P3 | [프로필·엔진·캐시](2026-10-15-p3-profile-engine-cache.md): 프로필 검증(호칭 규칙, D41, 엔진 검증), proto 생성, 엔진 클라이언트·대역, `ResultCache`, `ruleset_version` 확인 (S25~S31). 음력 변환(`convertLunarDate`)은 core RPC(#164) 병합 뒤 #170으로 구현 | §3.2, §3.3 프로필·캐시, §7 | **완료** |
| P4 | [콘텐츠](2026-10-16-p4-content.md): 시드 변환·적재, 렌더러(조사·호칭·토큰), 선택·순환·돌봄 상한, 값 이름 사전, 데일리·나의 사주·캘린더 응답, 반응, 시드 CI (#55·#129, 계약 draft.5, S33~S44) | §6 | **완료** |
| P5 | [일기·일정](2026-10-20-p5-diary-schedule.md): soft delete, 복구, 태그 조회, 저장 시 태그·가이드 질문 기록, `Idempotency-Key`(계약 draft.7, S50~S64) | §5.3, §3.3 일기, §11.2 | **완료** |
| P6 | [비로그인·참조](2026-10-20-p6-public-reference.md): 미리보기, 시진 확인, App Check, 요청 한도, 도시, app-config, staging 테스트 로그인(#93), 계약 draft.8, S65~S78 | §5.3, §3.3 기타, §13.2 | **완료** |
| P7 | [결제와 권한](2026-10-20-p7-billing.md): RevenueCat webhook·동기화(REST v2), entitlement 부여 기록, 복원, AdMob SSV 검증과 근거 열람 권한(D60), 계약 draft.9, S79~S89 | §10 | **완료** |
| P8 | Job: precompute, notify(FCM), retention(허가 취소 재시도 S106은 구현됨, 보관 기간 정리 S113). 익명화는 없어짐(S105) | §8 | 대기 |
| P9 | 배포: staging·prod, Cloud Run service·Jobs·Scheduler, Cloud SQL 연결, OpenTelemetry, 외부 준비 안내 | §13 | 대기 |

P2~P8의 순서는 의존 순서입니다. P2·P3 다음부터는 P5·P6·P7이 서로 기다리지 않습니다.

## 다음 계획에 넘길 메모

P1 실행 중 정한 것 가운데 다음 계획이 알아야 할 것입니다. 근거는 commit 메시지와 코드 주석에 있습니다.

**P4 (콘텐츠)** — 완료. 실행 중 정한 것은 S33~S44와 spec §3.3·§6에 옮겼습니다.
* 참고(엔진 판정): 엔진 `OUT_OF_RANGE`는 범위에 일부만 걸친 달(`GetMonthCalendar(1900,1)`)과, 출생 정보에서는 상한 쪽 음력(음력 2099년 12월이 양력 2099-12-31을 넘는 날)에서 납니다. 음력 1900-01-01은 범위 안입니다.

**콘텐츠 후속 (조건이 오면)**
* writing W1 원고가 다 오면 `server.yml`의 `mlw check ... --partial`에서 `--partial`을 빼고, 변환 도구(`seed/generate.go`의 `go:generate`)에 `-strict`를 켭니다(S38).

**P4 후속** — 완료(브랜치 `server/p4-followups`). notice 렌더(#232, S49), `Profile.birthCity`(#199, S46), 계약 draft.6(달력 범위 #248·S47, 409 `profile.required` 명시), 용어 id 대조 기준(S48).

**P5 (일기·일정)** — 완료. 실행 중 정한 것은 S50~S64와 spec §3.3·§5.1·§5.3에 옮겼습니다.
* 422 `request.inconsistent`·`date.invalid` 구현은 P3에서 끝났습니다(프로필). 일정에도 같은 코드를 씁니다.

**P6 (비로그인·참조)** — 완료. 실행 중 정한 것은 S65~S78과 spec §3.3·§5·§6.4·§9·§14에 옮겼습니다.
* 참고(계획 때 메모): `listCities`는 `city.All()`·`DataVersion()`(ETag)과 `Name/CountryName/RegionName`을 씁니다. `City` 변환은 `birthCity`(httpapi `profile_handlers.go`)와 같은 형태라 함께 쓸 수 있게 뽑아냅니다. `City.longitude`도 이때 채웁니다.
* `convertLunarDate`에도 App Check·요청 한도를 겁니다(구현됨).

**P7 (결제와 권한)** — 완료. 실행 중 정한 것은 S79~S89와 spec §10·§10.1·§11.3·§13.3에 옮겼습니다.

**P8 (Job)**
* 계정 삭제(S105)는 `reward_events`·`billing_events`·`entitlement_grants`를 남기고 계정 행을 껍데기로 둡니다(2026-10-23 spec §3.2). 세 표의 계정 FK는 `ON DELETE RESTRICT`이고 결제 기록 보관 의무가 있어 계정 행을 물리적으로 지우는 경로가 없습니다. 보관 기간이 지난 행의 정리는 S113입니다.
* 인증 엔드포인트에 rate limit을 둡니다. 처음 보는 kid의 `id_token`을 반복해 JWKS 재조회를 일으키는 경우도 막습니다. 처음 보는 `kid`로 서명한 위조 토큰이 공개 라우트(App Check)와 로그인 경로에서 JWKS 재조회를 매번 일으키므로 App Check도 이 제한에 포함합니다.
* 요청 한도(S68)의 키 IP 해시를 서버 비밀 HMAC으로 바꿀지 재검토합니다(salt 없는 SHA-256은 IPv4 전수 대입으로 되찾을 수 있음).
* soft delete 30일 뒤 일기·일정 내용 비우기(spec §8)는 `content_purged_at`을 찍습니다. 복원은 이미 비워진 행을 제외합니다(P5에서 쿼리에 반영).
* 멱등 선점 lease: 프로세스가 죽어 남은 `completed_at IS NULL` 선점은 24시간 동안 409가 됩니다. 요청 상한 시간(서버 WriteTimeout의 몇 배)이 지난 미완료 선점을 `ClaimIdempotencyKey`가 덮어쓸지(커밋 직후 죽은 극소수 경우 중복 가능, S61 확장 결정 필요)와, app이 409 `idempotency.in_progress`에 백오프 재시도할지를 계약에 적을지 정합니다.
* `job retention`이 24시간 지난 `idempotency_keys`를 지웁니다. `completed_at IS NULL`이고 오래된 행(프로세스가 죽어 남은 선점)도 정리 대상입니다. FK가 `ON DELETE RESTRICT`라 계정을 물리적으로 지우는 경로가 생기면 이 표를 먼저 지워야 합니다.
* `registerDevice`를 멱등 대상(`Idempotency(..., "createSchedule", "registerDevice")`)에 더합니다.
* 계정 삭제 때 기기: `devices`가 생기면 `account.DeleteAccountTx`의 지움 목록(`deleteSteps`)과 그 trigger(migration 00015의 `reject_deleted_account_write`)에 더합니다.
* `apple_web_logins` 만료·소진 행을 정리합니다. 만료됐는데 소진되지 않은 행은 그 subject의 연결 행이 없을 때만 Apple refresh token을 revoke합니다(S19와 같은 규칙). 소진된 행도 암호화한 Apple refresh token과 subject를 담으므로 만료 뒤 지웁니다.
* `job retention`이 허가 취소 대기 행(`provider_revocations`)을 재시도하는 것은 S106으로 구현했습니다(`auth.Revocations.RetryDue`). 남은 일은 만료된 refresh token을 지우는 것입니다.
* 만료된 refresh token 정리는 "행을 물리적으로 지우지 않는다"(S6·S7, spec §2)의 예외입니다(시스템 데이터). 다만 `refresh_tokens.replaced_by_id`가 같은 테이블을 `ON DELETE RESTRICT`로 참조하므로(S20), 앞 토큰이 남아 있는 동안 그 다음 토큰은 지울 수 없습니다. family의 모든 토큰이 만료됐을 때 family 단위로 지우되 참조하는 행(앞 토큰)부터 지워야 합니다. RESTRICT는 한 DELETE 문 안에서도 행마다 즉시 검사하므로 한 문장에 몰아 지울 때의 순서에 기대지 않습니다(필요하면 FK를 `NO ACTION`으로 바꾸는 것을 검토).
* 클라이언트가 연결을 끊은 요청과 엔진 호출자 취소(`context.Canceled`)가 500과 오류 로그로 남는 잡음을 정리합니다.
* 이전 `ruleset_version` 캐시 행을 정리합니다.
* 계정 삭제(S105)는 `daily_selections`·`rotation_state`·`reactions`·`profiles`도 지우고, 반응은 지우기 전에 `reaction_tallies`에 더합니다(D57). 그래서 익명화 때 `birth_hash`를 비우는 일과 프로필 익명화 쿼리는 없어졌습니다. `profiles.anonymized_at` 열과 CHECK `profiles_complete_until_anonymized`도 migration 00015가 없애고, 출생 정보가 모두 있어야 한다는 조건은 CHECK `profiles_complete`로 남겼습니다.
* 지난 `rate_limits` 창을 정리합니다(`window_start` 인덱스 있음). `preview_usage`는 지우지 않습니다(1회 제한).

**P9 (배포)**
* 결제 설정 4개를 Secret Manager에 둡니다(`config.LoadBilling`의 이름 그대로): `REVENUECAT_PROJECT_ID`, `REVENUECAT_API_KEY`(REST v2 secret key), `REVENUECAT_WEBHOOK_AUTH`(대시보드에 적은 Authorization 값 전체), `AD_FREE_PRODUCT_IDS`(쉼표 목록). `APP_ENV`가 local이 아니면 모두 필수이고 없으면 시작에 실패합니다.
* staging에서 확인할 것(문서로 확정되지 않은 외부 사실): AdMob 테스트 콜백의 `timestamp` 단위(ms/µs), RevenueCat webhook Authorization 헤더의 실제 형식(값 그대로인지), v2 구매 목록의 `next_page` 형태, Apple 비갱신 구독이 v2 구매 목록에 일회성 구매로 오는지.
* `billing_events`는 5년 보관하므로 `job retention`이 지우지 않습니다.
* 앞단에 Load Balancer를 두면 `TRUSTED_PROXY_HOPS`=2입니다. 실제 요청의 `X-Forwarded-For` 개수를 로그로 한 번 확인합니다(IP 원문은 남기지 않음).
* 배포 설정: `FIREBASE_PROJECT_NUMBER`, `TRUSTED_PROXY_HOPS`(Cloud Run 앞단 수를 확인합니다. 실제보다 크거나 0이면 모든 클라이언트가 한 키를 공유합니다), `APP_MIN_VERSION_IOS`·`APP_MIN_VERSION_ANDROID`, `TEST_LOGIN_SECRET`(staging만, `openssl rand -base64 32` 같은 난수). staging 이미지는 `-tags staging`으로 빌드합니다(Dockerfile·deploy workflow). App Check debug token은 staging Firebase 콘솔에만 둡니다.
* Cloud Run 엔진 서비스를 h2c end-to-end로 확인하고, gRPC startup probe(`myungli.engine.v1.MyungliEngine`), internal ingress, 8초 grace를 설정합니다(#79).
* server의 `ENGINE_ADDR`·`ENGINE_AUDIENCE`를 배포 설정에 넣고, `APP_ENV`가 local이 아니면 `ENGINE_AUDIENCE` 필수 검사를 추가합니다. CI 엔진 이미지 빌드 캐시도 검토합니다.
* 인증 설정 20개를 Secret Manager에 둡니다(`config.LoadAuth`의 이름 그대로). 필수 16개: `JWT_SIGNING_KEY_ID`, `JWT_SIGNING_KEY`, `TOKEN_ENCRYPTION_KEY_ID`, `TOKEN_ENCRYPTION_KEY`, `KAKAO_APP_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_BUNDLE_ID`, `APPLE_SERVICES_ID`, `APPLE_WEB_REDIRECT_URI`, `APP_LINK_BASE`, `ANDROID_APP_PACKAGE`, `ANDROID_CERT_SHA256`, `ANDROID_STORE_URL`. 선택 4개(키 교체 때만, ID와 값이 짝): `JWT_PREVIOUS_KEY_ID`, `JWT_PREVIOUS_KEY`, `TOKEN_PREVIOUS_KEY_ID`, `TOKEN_PREVIOUS_KEY`.
* 시작 때 키·설정을 파싱하고 실패하면 종료 코드 1입니다. 키 ID가 중복되거나 비어 있어도 시작에 실패합니다.
* Apple refresh token은 AES-GCM(secretbox)으로 암호화하고 associated data로 `auth_identities` 행 id를 묶습니다.
* `APPLE_CALLBACK_DEEPLINK`는 없어졌습니다(S22). 대신 `APP_LINK_BASE`(https, path 없음)의 도메인이 정해져야 하고, 그 도메인이 `/auth/apple`과 `/.well-known/assetlinks.json`을 내줍니다. `ANDROID_CERT_SHA256`은 Play 앱 서명 키 지문과 맞춥니다.
* Cloud Run은 `GOOGLE_CLOUD_PROJECT`를 자동으로 넣지 않으므로 배포 설정에 명시해야 로그의 trace 상관관계가 켜집니다. `X-Cloud-Trace-Context`만 오는 경로가 있는지 확인합니다.
* Cloud Run 요청 로그에서 `/auth/apple` query 제외(로그 제외 필터)를 검토합니다. 위험 수용 근거는 S22 설계 §2.3입니다.
* Cloud SQL Go connector를 쓰려면 `postgres.Open`이 `*pgxpool.Config`나 dial 옵션을 받도록 바꿉니다.
* `server.yml`은 ci-gate가 부르는 전용(`workflow_call`·`workflow_dispatch`)입니다. 직접 push·PR 트리거는 지웠습니다(#102).
* 요청 검증은 kin-openapi가 3.1 문서에서 format을 검사하지 않아 버전만 3.0.3으로 낮춘 계약 사본으로 합니다. 계약 테스트가 3.0 Schema 키워드 allowlist로 이 전제를 지킵니다.
