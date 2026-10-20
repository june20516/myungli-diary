# server 구현 계획 목록

spec: [`../specs/2026-10-11-server-mvp-design.md`](../specs/2026-10-11-server-mvp-design.md)

spec이 서브시스템 9개를 다루므로 계획을 나눕니다. 각 계획은 그 자체로 동작하고 테스트할 수 있는 결과로 끝납니다. 다음 계획은 앞 계획이 병합된 뒤 실제 코드를 보고 씁니다(rolling wave). 앞 계획에서 정한 인터페이스가 다음 계획의 입력이기 때문입니다.

| 순서 | 계획 | spec 절 | 상태 |
| --- | --- | --- | --- |
| P1 | [기반과 REST 계약 초안](2026-10-11-p1-foundation.md): 모듈, 하위 명령, 설정, Clock, 로깅, DB·migration, HTTP 뼈대, 오류 형식, `openapi.yaml` 초안, 생성 코드, CI, 이미지 | §2, §5, §11.1, §12, §13.1 일부 | **완료** |
| P2 | [인증·계정·약관](2026-10-13-p2-auth-account.md): 카카오·Apple 검증, JWT, refresh rotation, 동의, 삭제 예약·복구 | §3.3 계정, §4 | **완료** |
| P2a | [Apple 웹 로그인 복귀](2026-10-13-apple-web-login.md): 일회용 교환 코드, `completeAppleWebLogin`, App Link 안내 페이지·assetlinks (Issue #89, S22) | §4 | **완료** |
| P3 | [프로필·엔진·캐시](2026-10-15-p3-profile-engine-cache.md): 프로필 검증(호칭 규칙, D41, 엔진 검증), proto 생성, 엔진 클라이언트·대역, `ResultCache`, `ruleset_version` 확인 (S25~S31). 음력 변환(`convertLunarDate`)은 core RPC(#164) 병합 뒤 #170으로 구현 | §3.2, §3.3 프로필·캐시, §7 | **완료** |
| P4 | [콘텐츠](2026-10-16-p4-content.md): 시드 변환·적재, 렌더러(조사·호칭·토큰), 선택·순환·돌봄 상한, 값 이름 사전, 데일리·나의 사주·캘린더 응답, 반응, 시드 CI (#55·#129, 계약 draft.5, S33~S44) | §6 | **완료** |
| P5 | [일기·일정](2026-10-20-p5-diary-schedule.md): soft delete, 복구, 태그 조회, 저장 시 태그·가이드 질문 기록, `Idempotency-Key`(계약 draft.7, S50~S64) | §5.3, §3.3 일기, §11.2 | **완료** |
| P6 | 비로그인·참조: 미리보기, 시진 확인, App Check, 요청 한도, 도시, app-config | §5.3, §3.3 기타 | 대기 |
| P7 | 결제와 권한: RevenueCat webhook·동기화, entitlement 부여 기록, 복원, AdMob SSV 검증과 근거 열람 권한(D60) | §10 | 대기 |
| P8 | Job: precompute, notify(FCM), retention과 익명화 | §8, §9 | 대기 |
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

**P6 (비로그인·참조)**
* `listCities`는 `city.All()`·`DataVersion()`(ETag)과 `Name/CountryName/RegionName`을 씁니다. `City` 변환은 `birthCity`(httpapi `profile_handlers.go`)와 같은 형태라 함께 쓸 수 있게 뽑아냅니다. `City.longitude`도 이때 채웁니다.
* `convertLunarDate`에도 App Check·요청 한도를 겁니다.

**P7 (결제와 권한)**
* `getMe.adFree`·`insight`를 채웁니다.
* AdMob SSV 서명은 원본 쿼리 문자열로 검증합니다. 요청 검증 미들웨어는 RawQuery를 바꾸지 않도록 설정되어 있고(`SkipSettingDefaults`) 테스트로 고정되어 있습니다.

**P8 (Job)**
* 계정 익명화 때 일기 본문·일정 제목·메모를 지우고 `content_purged_at`을 기록합니다(열은 P5에서 만듦).
* `job retention`이 24시간 지난 `idempotency_keys`를 지웁니다. `completed_at IS NULL`이고 오래된 행(프로세스가 죽어 남은 선점)도 정리 대상입니다. FK가 `ON DELETE RESTRICT`라 계정을 물리적으로 지우는 경로가 생기면 이 표를 먼저 지워야 합니다.
* `registerDevice`를 멱등 대상(`Idempotency(..., "createSchedule", "registerDevice")`)에 더합니다.
* 계정 삭제 때 기기 비활성: `devices`가 생기면 `RequestDeletion`에 추가합니다.
* `apple_web_logins` 만료·소진 행을 정리합니다. 만료됐는데 소진되지 않은 행은 그 subject의 연결 행이 없을 때만 Apple refresh token을 revoke합니다(S19와 같은 규칙). 소진된 행도 암호화한 Apple refresh token과 subject를 담으므로, 계정 익명화보다 먼저(또는 같은 작업에서) 지웁니다.
* `job retention`이 `DisconnectProviders`를 재시도하고 만료된 refresh token을 지웁니다. `DisconnectProviders`는 계정이 `pending_deletion`일 때만 외부 호출과 기록을 하고, 그 밖의 상태(active·deleted)에서는 아무것도 하지 않습니다. 그래서 retention은 **연결 해제 재시도를 익명화(`deleted` 전환)보다 먼저** 해야 합니다. 익명화한 뒤에는 남은 연결을 더 이상 끊을 수 없습니다.
* 만료된 refresh token 정리는 "행을 물리적으로 지우지 않는다"(S6·S7, spec §2)의 예외입니다(시스템 데이터). 다만 `refresh_tokens.replaced_by_id`가 같은 테이블을 `ON DELETE RESTRICT`로 참조하므로(S20), 앞 토큰이 남아 있는 동안 그 다음 토큰은 지울 수 없습니다. family의 모든 토큰이 만료됐을 때 family 단위로 지우되 참조하는 행(앞 토큰)부터 지워야 합니다. RESTRICT는 한 DELETE 문 안에서도 행마다 즉시 검사하므로 한 문장에 몰아 지울 때의 순서에 기대지 않습니다(필요하면 FK를 `NO ACTION`으로 바꾸는 것을 검토).
* 클라이언트가 연결을 끊은 요청과 엔진 호출자 취소(`context.Canceled`)가 500과 오류 로그로 남는 잡음을 정리합니다.
* 이전 `ruleset_version` 캐시 행을 정리합니다.
* 익명화 때 `daily_selections`·`rotation_state`·`reactions`는 남깁니다(spec §9 "남기는 것"). 콘텐츠 표의 FK가 `ON DELETE RESTRICT`인 것도 이 때문입니다. 다만 `daily_selections.birth_hash`는 `profiles.birth_hash`를 비우는 이유(생년월일시를 되찾을 수 있음)가 같이 해당하므로 P8 retention이 익명화 때 비웁니다(spec §9, S34). 열은 P4에서 이미 NULL을 허용합니다(값이 있으면 32바이트 CHECK).
* 프로필 익명화 전용 쿼리를 둡니다. 출생 열·호칭·해시를 비우고 `anonymized_at`을 기록하며, CHECK `profiles_complete_until_anonymized`에 맞춥니다.
* 인증 엔드포인트에 rate limit을 둡니다. 처음 보는 kid의 `id_token`을 반복해 JWKS 재조회를 일으키는 경우도 막습니다.

**P9 (배포)**
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
