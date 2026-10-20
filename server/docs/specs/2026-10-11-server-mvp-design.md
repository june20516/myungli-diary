# server MVP 설계

* 상태: 확정, 구현 P1~P6 완료(계획은 `docs/plans/README.md`)
* 마일스톤: S1 (설계). 이 문서가 S2(구현)와 S3(REST API v1 freeze)의 기준입니다.
* 근거: `server/CLAUDE.md` 범위, Issue #3·#7·#29·#55, 결정 D26~D62, IA spec §10, 수익화 사이클(비공개 기록 `business/cycles/2026-10-11-launch-payment.md`, D74)
* server 결정 번호(S#)는 `server/docs/decisions.md`에 모읍니다(S1~S88). 이 문서의 각 절에 해당 번호를 붙입니다.

## 1. 목표와 범위

server는 app이 쓰는 유일한 API입니다. 다음을 맡습니다.

* 인증과 계정: 카카오·Apple 로그인, 자체 JWT, 약관 동의, 계정 삭제 (D50·D55)
* 프로필: 호칭, 출생 정보, 언어, 현재 시간대, 알림 설정 (D29·D30·D36·D41)
* 운세: 엔진(gRPC) 결과를 캐시하고, 메시지 키를 언어별 문장으로 렌더합니다 (D26·D27·D31·D59)
* 일기(하루 1편)와 기본 일정 (D47·D49)
* 로그인 없는 요청 두 가지: 미리보기 1회(D50)와 시진 확인(D58)
* 아침 운세 알림 (D18⑨)
* 광고 제거권 entitlement와 RevenueCat 연동 (D53·D54)
* 근거·해석 열람 권한: AdMob 보상형 광고 SSV 콜백으로 그날 자정까지 부여, 광고 제거권 기간에도 부여. 권한이 없으면 잠긴 내용을 응답에 담지 않음 (D60)
* 도시 목록, 최소 앱 버전 응답 (IA spec §10)

범위 밖: LLM 기능, 기기 간 일기 동기화(D47②), 반복 일정·일정 알림·외부 캘린더, 구독 결제, 반응을 쓴 적응형 문장 선택(Phase 2, D57③).

## 2. 실행 구조 (S1)

Go 바이너리 하나를 하위 명령으로 나눠 실행합니다.

| 하위 명령 | 실행 환경 | 하는 일 |
| --- | --- | --- |
| `serve` | Cloud Run service | REST API, webhook 수신 |
| `job precompute` | Cloud Run Job, Cloud Scheduler 30분마다 | 다음 날 결과 미리 계산 (§8.1) |
| `job notify` | Cloud Run Job, 5분마다 | 아침 알림 발송 (§8.2) |
| `job retention` | Cloud Run Job, 하루 1번 | 익명화와 정리 (§8.3) |
| `migrate` | Cloud Run Job, 배포 단계 | DB 스키마 적용 |
| `seed` | Cloud Run Job, 배포 단계 | 콘텐츠 시드 적재 (§6.1) |

Scheduler 호출 방식이 아니라 Cloud Run Jobs를 씁니다. 배치는 요청-응답 수명과 맞지 않고, Jobs는 실행 단위 재시도·타임아웃·실행 기록을 따로 줍니다. 모든 Job은 멱등이며, 실패하면 최대 3번 다시 실행합니다.

### 2.1 디렉터리

```
server/
  cmd/server/          하위 명령 진입점
  api/openapi.yaml     REST API v1 계약 (app에 제공하는 원본)
  internal/
    httpapi/           oapi-codegen 생성 인터페이스와 핸들러, 인증·App Check 미들웨어, 오류 변환
    auth/              카카오·Apple 토큰 검증, JWT 발급·갱신, 계정-제공자 연결
    account/           계정 상태, 약관 동의, 삭제 예약·복구·익명화
    profile/           호칭·출생 정보·알림 설정, 입력 검증
    diary/             일기, 태그 조회
    schedule/          일정
    fortune/           엔진 결과 조회 흐름(캐시 → 엔진 → 저장), 미리 계산
    engine/            gRPC 클라이언트 인터페이스, 실제 구현, 테스트 대역
    content/           템플릿 저장소, 렌더러(값 치환·조사·용어 토큰), 문장 선택·순환, 반응
    notify/            기기 토큰, FCM 발송
    billing/           entitlement(광고 제거·근거 열람), RevenueCat webhook·동기화, AdMob SSV 검증
    city/              도시 목록 (GeoNames 자료를 변환해 내장, S28)
    ratelimit/         PostgreSQL 기반 요청 한도
    platform/          DB, 설정, Clock, 로깅·추적
    gen/enginev1/      proto 생성 Go 코드 (buf, server 루트 `buf.gen.yaml`, commit). 실제 경로는 `internal/gen/enginev1/`
  db/migrations/       goose
  db/queries/          sqlc 원본 SQL
  seed/                writing 원고 변환 도구와 변환 결과(data/, commit)
  docs/                spec, 계획, 결정
```

### 2.2 의존 규칙

* `cmd`와 `httpapi`가 도메인 패키지를 조립합니다. 도메인 패키지끼리는 인터페이스로만 기댑니다. 단, 값 타입·sentinel 오류는 직접 import해도 됩니다(서비스는 인터페이스로). 예: fortune → profile 값 타입, profile → engine sentinel 오류.
* `fortune`은 `engine`과 `content`에 기대고, `content`는 다른 도메인을 모릅니다.
* 날짜·시간대 계산은 모두 주입한 `Clock`으로 합니다. 자정 경계와 시간대 테스트를 결정적으로 돌리기 위해서입니다.
* 외부 의존(엔진, FCM, 카카오·Apple, RevenueCat, AdMob 검증 키, App Check)은 모두 인터페이스 뒤에 두고 테스트 대역을 둡니다.

### 2.3 기술 선택 (S3)

| 영역 | 선택 |
| --- | --- |
| HTTP | 표준 `net/http` 라우터, OpenAPI 3.1 contract-first, `oapi-codegen` strict server |
| DB | PostgreSQL(Cloud SQL), `pgx`, `sqlc`, `goose` |
| 엔진 | `grpc-go`, buf로 생성 (`managed mode`의 `go_package_prefix`) |
| 로그·추적 | `log/slog` JSON → Cloud Logging, OpenTelemetry → Cloud Trace |
| 로컬 개발 | docker compose (PostgreSQL, 엔진 컨테이너) |

## 3. 데이터 모델

### 3.1 공통 원칙

* ID는 UUIDv7, 시각은 `timestamptz`, 날짜는 `date`입니다.
* **행을 물리적으로 지우지 않습니다 (S6·S7).** 계정은 익명화하고(§9), 사용자가 지우는 일기·일정은 soft delete합니다. 그래서 FK는 모두 `ON DELETE RESTRICT`로 두어 실수로 지우는 일을 DB가 막습니다. 예외는 사용자 데이터가 아닌 시스템 데이터(캐시, 만료된 refresh token, 요청 한도 카운터, 멱등 키 `idempotency_keys`, Apple 웹 로그인 교환 코드 `apple_web_logins`)로, 정리할 때 지웁니다.
* soft delete 행은 `deleted_at`으로 표시하고, 조회는 모두 `deleted_at IS NULL` 조건으로 합니다.

### 3.2 "모름"과 null (S5)

null은 "값이 없음"만 뜻하고 사용자의 선택을 담지 않습니다. 선택은 상태 열에 명시하고, 상태와 값 열이 짝이 맞는지는 CHECK 제약으로 DB가 보장합니다. "묻지 않음", "물었지만 입력하지 않음", "입력함"을 늘 구분합니다.

| 항목 | 상태 열 | 값 열 | 제약 |
| --- | --- | --- | --- |
| 출생 시각 | `birth_time_status`: `known` / `unknown`(사용자가 "모름"을 고름) | `birth_time` | `known`일 때만 값이 있음 |
| 출생지 | `birth_place_status`: `not_asked`(한국 기기라 묻지 않음, D29·D58) / `skipped`(물었지만 건너뜀) / `city` | `birth_city_id`, `longitude` | `city`일 때만 값이 있음. 앞의 둘은 대표 경도로 계산 |
| 윤달 | 달력 종류(`solar`/`lunar`) | `is_leap_month` | `solar`면 false |
| 알림 | `notify_status`: `not_asked` / `enabled` / `disabled` | `notify_time` | `enabled`일 때만 값이 있음 |
| 일정 시각 | `all_day` | `time` | `all_day = false`일 때만 값이 있음 |
| 익명화된 프로필 | `anonymized_at` | 출생 정보 열 전체, `birth_hash` | `anonymized_at`이 있을 때만 비어 있을 수 있음 |

* 나중에 선택 입력을 추가하면 기존 행의 상태는 `not_asked`로 채웁니다.
* PostgreSQL CHECK는 다른 테이블을 참조하지 못하므로, 익명화 여부는 `accounts.status`가 아니라 `profiles.anonymized_at`으로 검사합니다.
* API도 같은 원칙을 따릅니다(§5.1).

### 3.3 테이블

**계정과 인증**

| 테이블 | 주요 열 | 비고 |
| --- | --- | --- |
| `accounts` | id, status(`active`/`pending_deletion`/`deleted`), deletion_requested_at, anonymized_at, last_active_at, created_at | `last_active_at`은 인증된 요청마다 하루 1번까지 갱신 |
| `auth_identities` | account_id, provider(`kakao`/`apple`), subject, apple_refresh_token(암호화) | unique(provider, subject). 계정 하나에 제공자 여럿을 붙일 수 있는 구조(D55④)이며, MVP는 로그인한 제공자 하나만 붙입니다 |
| `refresh_tokens` | account_id, token_hash, family_id, expires_at, used_at, replaced_by_id, revoked_at | 쓸 때마다 교체하고, 이미 쓴 토큰을 다시 내밀면 family 전체를 폐기(30초 유예, S20). replaced_by_id는 그 토큰으로 발급한 다음 토큰이며 used_at과 함께 채워집니다 |
| `consents` | account_id, document(`terms`/`privacy`), version, agreed_at | 문서 버전이 바뀌면 다시 받음 |

Apple refresh token은 애플리케이션 단에서 AES-GCM으로 암호화합니다. 키는 Secret Manager에 둡니다.

**프로필 (`profiles`, 계정과 1:1)**

* honorific, language(`ko`/`en`/`ja`), current_timezone
* 출생 정보: 엔진 `BirthInfo`와 같은 모양. calendar, is_leap_month, 출생 날짜는 `birth_year`·`birth_month`·`birth_day`(smallint, 음력 30일 때문에 date 열을 쓰지 않음), birth_time_status·birth_time, gender, birth_timezone, birth_place_status·birth_city_id·longitude
* notify_status, notify_time(5분 단위, §8.2)
* birth_hash: 정규화한 출생 정보의 SHA-256(32바이트 CHECK, 정규형은 S26). 캐시 키에 쓰고, 출생 정보가 바뀌면 다시 계산
* anonymized_at

**일기·일정**

| 테이블 | 주요 열 | 비고 |
| --- | --- | --- |
| `diaries` | account_id, date, body, all_tags(text[]), featured_tags(jsonb `[{key, polarity}]`, 계약 키), guide_question(jsonb: 렌더된 조각 배열), ruleset_version, deleted_at, content_purged_at | partial unique(account_id, date) WHERE deleted_at IS NULL. all_tags에 GIN 인덱스. 날짜 내림차순 목록은 partial unique의 역방향 스캔이 덮으므로 목록 인덱스는 따로 두지 않음 (D47·D49·D59④) |
| `schedules` | account_id, date, all_day, time, title, memo, deleted_at, content_purged_at | |

**엔진 결과 캐시 (S4)**

| 테이블 | 키 | 값 |
| --- | --- | --- |
| `chart_cache` | birth_hash, ruleset_version, as_of_year | 엔진 응답 protobuf bytes, created_at |
| `daily_cache` | birth_hash, ruleset_version, date, current_timezone | 위와 같음 |
| `month_cache` | birth_hash, ruleset_version, year, month, current_timezone | 위와 같음 |

캐시에는 엔진 응답(메시지 키와 매개변수)만 둡니다. 문장은 사용자마다 언어·호칭·선택 기록이 달라 요청할 때 렌더합니다. 캐시 행은 계정과 연결되지 않습니다.

세 캐시 표의 `birth_hash`는 `profiles`와 같이 32바이트 CHECK가 있습니다.

**콘텐츠 (D57·D59)**

| 테이블 | 주요 열 | 비고 |
| --- | --- | --- |
| `content_seeds` | version, slots, applied_at, active | 시드 버전. slots는 그 버전의 슬롯 명세(jsonb, 호칭 사용·매개변수 값 종류·순환 방식)로, 옛 버전으로 고른 문장을 그 버전의 명세로 렌더하려고 버전마다 저장합니다(S45). active는 partial unique로 하나. 출처 commit 열은 두지 않습니다. 시드 파일에 commit을 적으면 commit마다 파일이 바뀌어 생성 차이 검사(§6.1)가 깨지고, 버전(내용 해시)이 출처를 대신합니다(S44) |
| `content_templates` | seed_version, slot, key, variant, lang, body | 기본 키 (seed_version, slot, key, variant, lang)(S33). 문장 틀 id = (slot, key, variant). 같은 식별자 키가 여러 슬롯에 있어 slot을 키에 넣습니다 |
| `content_hanja` | seed_version, term, hanja | 용어 id → 한자 표기. 언어와 무관한 한 벌(writing `content/hanja.yaml`, S43) |
| `daily_selections` | id, account_id, date, slot, birth_hash, message_key, variant, seed_version, created_at | unique(account_id, date, slot, birth_hash)(S34). D59②의 선택 기록. birth_hash는 값이 있으면 32바이트 CHECK이고, 익명화 때 비우므로 NULL을 허용합니다(§9) |
| `rotation_state` | account_id, message_key, next_variant | 키별 다음 차례 |
| `reactions` | selection_id(FK `daily_selections`), reaction, created_at, deleted_at | 반응 취소는 soft delete. partial unique(selection_id) WHERE deleted_at IS NULL(`reactions_one_active`)이라 취소한 이력은 남고 새 반응은 새 행입니다(S39) |

콘텐츠 표의 FK는 모두 `ON DELETE RESTRICT`입니다. 계정은 물리 삭제하지 않고 익명화하기 때문입니다(§9).

**알림·결제·기타**

| 테이블 | 주요 열 | 비고 |
| --- | --- | --- |
| `devices` | account_id, fcm_token(unique, nullable), platform, active, last_seen_at | 무효 토큰이면 active=false. 익명화 때 토큰을 지움 |
| `notification_log` | account_id, local_date, sent_at, result | unique(account_id, local_date) |
| `entitlement_grants` | account_id, entitlement(`ad_free`·`insight`), source(`ad_free_pass`·`rewarded_ad`·`subscription`), source_ref(구매 id·`transaction_id`), starts_at, expires_at, revoked_at | 권한 부여 한 건이 한 행입니다. 판정은 같은 entitlement의 유효한 행(`revoked_at`이 없고 `starts_at ≤ now < expires_at`)이 하나라도 있는지입니다. 출처를 기록하라는 D60④를 이 구조가 만족하고, 구독도 같은 모양으로 담습니다 (D53·D60) |
| `reward_events` | transaction_id(unique), account_id, ad_unit, reward_item, raw_query, received_at | AdMob SSV 원본. 같은 `transaction_id`는 한 번만 처리 (D60④) |
| `billing_events` | event_id(unique), account_id, payload(jsonb), received_at, processed_at | 전자상거래법에 따라 5년 보관 |
| `preview_usage` | device_hash(PK, 설치 id의 SHA-256 32바이트), used_at | 지우지 않음. 지우면 1회 제한이 풀림. 출생 정보는 저장하지 않음(S70) |
| `rate_limits` | key(`<operation>:<IP의 SHA-256 hex>`), window_start(분 단위 내림), count. PK (key, window_start) | 지난 창은 정리 대상(`window_start` 인덱스) |
| `idempotency_keys` | PK (account_id, key), request_hash(SHA-256), status, headers(jsonb), body, created_at, completed_at | 24시간 뒤 정리. `completed_at`이 NULL이면 처리 중 |

도시 목록은 읽기 전용 참조 데이터라 DB에 넣지 않고, 버전을 붙인 정적 파일로 바이너리에 포함합니다(`go:embed`). 원본은 GeoNames `cities15000`(CC BY 4.0)에서 이름(ko·en·ja), IANA 시간대, 경도를 뽑아 만들고, 출처 표기는 app의 오픈소스 고지에 넣도록 요청합니다.

## 4. 인증과 계정 (S8)

### 4.1 로그인

| 제공자 | app이 보내는 것 | server 검증 |
| --- | --- | --- |
| 카카오 | OIDC `id_token`, nonce 원문 | 카카오 JWKS로 서명, `iss`·`aud`(앱 키)·`exp`·nonce 확인. subject = `sub` |
| Apple (iOS) | `identity_token`, `authorization_code`, nonce 원문 | Apple JWKS로 검증. code를 `/auth/token`에 교환해 refresh token을 받아 암호화 저장(탈퇴 때 revoke용) |
| Apple (Android, D55①) | 웹 흐름: server 콜백이 Apple에서 받은 `code`, `id_token`. app은 일회용 교환 코드와 nonce 원문만 보냄 | 위와 같고, `client_id`는 Services ID. nonce 확인은 교환 단계에서 함(S22) |

* Android의 Apple 웹 흐름(S22, Issue #89): app이 Apple 인증 페이지를 열면 Apple이 `POST /v1/auth/apple/callback`(form_post)으로 결과를 보냅니다. server가 그 자리에서 id_token을 검증하고 code를 교환한 뒤, App Link로 **일회용 교환 코드와 state만** 넘깁니다. app은 `POST /v1/auth/apple/web`에 교환 코드와 nonce 원문을 보내 로그인을 마칩니다. 토큰은 URL에 실리지 않습니다. 상세: [`2026-10-13-apple-web-callback-design.md`](2026-10-13-apple-web-callback-design.md)
* 처음 보는 (provider, subject)면 계정을 새로 만들고 응답에 `isNewAccount`와 `consentRequired`를 담습니다.
* 이메일로 계정을 자동 연결하지 않습니다. Apple은 이메일을 숨길 수 있고, 이메일만 같다고 같은 사람이라 볼 수 없습니다.

### 4.2 토큰

* access token: JWT ES256, 15분, claim은 `sub`(계정 id)·`iat`·`exp`·`jti`. 서명 키는 Secret Manager에 두고 `kid`로 교체합니다.
* refresh token: 256비트 난수 문자열, 30일. DB에는 해시만 둡니다. 쓸 때마다 새 토큰을 주고 이전 토큰을 used로 표시합니다. used인 토큰이 다시 오면 탈취로 보고 family 전체를 폐기합니다. 단, 첫 사용 뒤 30초 안(경계 포함)이고 그 다음 토큰이 아직 쓰이지 않았으면 응답 유실 재시도로 보고, 다음 토큰을 폐기한 뒤 같은 family로 새 토큰 쌍을 줍니다(S20). 첫 사용 시각은 바꾸지 않으므로 유예 창은 늘어나지 않습니다. 유예로 대체된 토큰이 다시 오면 탈취로 보고 family 전체를 폐기합니다.

### 4.3 약관 동의

새 계정은 `POST /v1/me/consents`로 현재 버전 문서에 동의하기 전까지 `/v1/me`, 동의, 로그아웃, 계정 삭제 말고는 403 `consent.required`를 받습니다. 문서 버전이 바뀌어도 같습니다.

### 4.4 계정 삭제 (S7)

1. `DELETE /v1/me` → status `pending_deletion`, deletion_requested_at 기록.
2. 상태 변경을 commit한 뒤 바로 처리합니다.
   * Apple refresh token을 revoke합니다.
   * 카카오 연결 끊기(unlink, admin key + 대상 id)를 부릅니다.
   * refresh token을 모두 폐기합니다.
   * 기기를 비활성으로 바꿔 알림을 멈춥니다.

   외부 호출이 실패하면 `job retention`이 다시 시도합니다.
3. 30일 안에 같은 제공자로 로그인하면 `active`로 되돌립니다. Apple과 카카오는 다시 동의를 받으므로 새 토큰을 얻습니다.
4. 30일이 지나면 `job retention`이 익명화합니다(§9).

## 5. REST API v1 (S2)

계약 원본은 `server/api/openapi.yaml`입니다. 계약 표(`docs/contracts/README.md`)의 자기 행은 server가 계약을 바꾸는 PR에서 직접 고치고, S3에서 freeze합니다.

### 5.1 공통 규약

* 경로 버전 `/v1`. JSON 필드는 camelCase(Google API 가이드, proto JSON 매핑과 같음).
* 날짜 `YYYY-MM-DD`, 시각은 RFC 3339입니다. 시각은 기본이 UTC이고, 화면 표시용 시각(`FocusSlot.start`·`end`, `CalendarDay.solarTerm.at`)만 프로필 현재 시간대의 offset으로 보냅니다.
* 목록은 cursor 방식입니다(`cursor`, `limit`, 응답의 `nextCursor`). 기간(`from`·`to`)으로 받는 목록(`listSchedules`)은 예외로 범위 안을 한 번에 돌려줍니다.
* `Idempotency-Key` 헤더는 `createSchedule`·`registerDevice`(P8)만 받습니다(S60). 규격은 IETF `draft-ietf-httpapi-idempotency-key-header`를 따릅니다. 24시간 동안 같은 키에는 같은 응답을 돌려줍니다. 계약 검증 뒤 핸들러 앞에서 operation 단위로 처리하며(`httpapi.Idempotency`), 첫 요청이 행을 선점하고 2xx 응답만 저장합니다. 2xx가 아니면 행을 지워 같은 키로 다시 시도할 수 있습니다.
* 사용자의 선택은 상태 필드로 보냅니다(§3.2). 필드를 빼거나 `null`을 보내는 것으로 "모름"을 뜻하게 하지 않습니다. PATCH에서 필드가 없으면 "바꾸지 않음" 하나만 뜻합니다.
* 언어는 로그인 사용자면 프로필 값, 비로그인 요청이면 `Accept-Language`를 RFC 9110 q값 순서로 읽어 `ko`·`en`·`ja` 중 첫째를 씁니다. 없으면 `en`입니다(S65).
* 문장 필드는 조각 배열입니다(§6.4). 화면의 고정 UI 문구는 app 몫입니다(D59⑤).

### 5.2 엔드포인트

| 영역 | 메서드와 경로 | 비고 |
| --- | --- | --- |
| 인증 | `POST /v1/auth/kakao`, `POST /v1/auth/apple`, `POST /v1/auth/apple/callback`, `POST /v1/auth/apple/web`, `POST /v1/auth/refresh`, `POST /v1/auth/logout` | 로그아웃은 refresh token family 폐기. Android Apple 웹 로그인은 콜백이 교환 코드를 App Link로 넘기고 `apple/web`이 토큰을 발급(S22) |
| 정적(계약 밖) | `GET /auth/apple`, `GET /.well-known/assetlinks.json` | `/auth/apple`은 App Link가 앱을 열지 못했을 때 앱에서 이어서 로그인하라고 알리는 안내 페이지(문구는 활성 시드의 `system.apple_return` 원고를 `Accept-Language` 언어로 렌더, S75), `assetlinks.json`은 Android App Link 검증용(S22). `/v1` 밖이라 REST 계약에 넣지 않음 |
| 계정 | `GET /v1/me`, `DELETE /v1/me`, `POST /v1/me/consents` | `GET /v1/me`에 계정 상태, 동의 필요 여부, 프로필 유무, 광고 제거 상태 포함 |
| 프로필 | `GET /v1/me/profile`(읽기), `PUT /v1/me/profile`(생성 또는 교체, S25), `PATCH /v1/me/profile` | 출생 정보를 저장할 때 엔진으로 검증(§7.2). 호칭 경고는 200 응답의 `warnings` |
| 운세 | `GET /v1/daily/{date}`, `GET /v1/chart`, `GET /v1/calendar/{year}/{month}` | 프로필 없으면 409 `profile.required` |
| 반응 | `PUT /v1/daily/{date}/slots/{slot}/reaction`, `DELETE` 같은 경로 | 그날 선택 기록에 붙음 |
| 비로그인 | `POST /v1/preview`, `POST /v1/birth-hour`, `POST /v1/lunar-date`(음력→양력, 윤달 유무) | App Check 필수. 입력 저장 안 함 (D50·D58) |
| 일기 | `GET /v1/diaries?from&to&tag&cursor`, `GET`·`PUT`·`DELETE /v1/diaries/{date}`, `POST /v1/diaries/{date}/restore` | `PUT`은 멱등 upsert. 응답에 대표 태그 (Issue #31) |
| 일정 | `GET /v1/schedules?from&to`, `POST /v1/schedules`, `PATCH`·`DELETE /v1/schedules/{id}`, `POST /v1/schedules/{id}/restore` | |
| 알림 기기 | `POST /v1/devices`, `DELETE /v1/devices/{id}` | 같은 토큰이 다시 오면 소유 계정을 옮김 |
| 결제 | `GET /v1/me/entitlements`, `POST /v1/billing/restore`, `POST /webhooks/revenuecat`, `GET /webhooks/admob-ssv` | §10 |
| 참조 | `GET /v1/cities?q=&lang=`, `GET /v1/app-config`, `GET /v1/glossary` | 도시는 ETag. app-config는 플랫폼별 최소 앱 버전. glossary는 enum 값(오행·십성·태그 등)의 언어별 이름 사전(writing `glossary.value_name` 등)으로, 응답마다 이름을 싣는 대신 한 번 받아 둠(ETag) |
| 운영 | `GET /healthz` | |

### 5.3 동작 규칙

* **오늘(D30):** "오늘"은 프로필의 `current_timezone` 기준 날짜입니다. app은 기기 시간대가 바뀌면 `PATCH /v1/me/profile`로 알립니다.
* **일기 날짜(D49):** 오늘 이후 날짜는 422 `diary.future_date`입니다. 지운 일기를 되살리려는 날짜에 이미 새 일기가 있으면 409 `diary.date_taken`입니다.
* **일기 저장 시 함께 기록(D47·D59④):** 그날 엔진 결과의 `all_tags`·`featured_tags`·`ruleset_version`과 가이드 질문의 렌더된 조각 배열입니다. 그날 선택 기록이 없으면(예: 지난 날 일기) 저장할 때 선택합니다. 이미 있는 일기를 고칠 때는 본문만 바꾸고 이 기록은 처음 값을 유지합니다.
* **일기 동시 저장:** 기기 동기화는 MVP 범위 밖이라(D47②) 마지막 쓰기가 남습니다.
* **날짜 경로 검증:** `/calendar/{year}/{month}`는 정수가 아니거나 스키마 범위(1900~2099, 1~12) 밖이면 400 `request.invalid`, 그 안이지만 D41 범위를 벗어나면 422 `date.out_of_range`입니다. `/daily/{date}`의 날짜는 형식이 틀리거나 달력에 없는 날짜(예 `2026-02-30`, `format: date` 위반)면 400 `request.invalid`, 형식은 맞지만 D41 범위 밖이면 422 `date.out_of_range`입니다. 422 `date.invalid`는 정수 필드 객체 `LunarOrSolarDate`(예 양력 2월 31일)에만 씁니다.
* **미리보기(D50):** 출생 정보·현재 시간대를 받아 오늘의 데일리 중 surface만 돌려줍니다. 호칭을 받지 않으므로 호칭이 들어가는 슬롯은 호칭 없는 변주를 쓰도록 writing에 확인합니다(§13). 설치 id의 SHA-256(`device_hash`)마다 1번이며, 두 번째는 403 `preview.used`입니다. 설치 id는 재설치로 바뀔 수 있어 1회 제한은 최선 노력입니다. 엔진 결과 캐시는 읽지도 쓰지도 않습니다(S70).
* **시진 확인(D58):** 출생 날짜·시각을 받아 시진과 그 벽시계 범위를 돌려줍니다. 시간을 고칠 때마다 부르는 요청이라 1회 제한 대신 요청 한도를 둡니다(`convertLunarDate`도 같음). 키는 operation + 클라이언트 IP(SHA-256)이고 고정 1분 창에 30회, 넘으면 429 `rate_limited`와 `Retry-After`입니다. 클라이언트 IP는 `X-Forwarded-For` 오른쪽에서 `TRUSTED_PROXY_HOPS`번째이며 계산은 `GetBirthHour` RPC입니다(S68·S69).

## 6. 콘텐츠 모듈 (D27·D36·D40·D57·D59)

### 6.1 시드

* 원본은 `docs/identity/writing/content/<lang>/*.yaml`입니다(D59①).
* 이미지는 `server/`만으로 빌드하므로(D56④) 원고를 바로 읽지 않습니다. 변환 도구(`go run ./seed/cmd/convert`)가 원고를 시드 파일 `server/seed/data/content.json`으로 바꾸고, 이 파일을 commit합니다. proto 생성 코드(D33)와 같은 방식입니다. 시드 버전은 파일 내용의 해시입니다.
* 변환 도구는 `[[글자]]` 용어 토큰을 glossary로 역조회해 `[[글자|용어 id]]`로 바꿔 저장합니다. 실행 중에는 역조회하지 않습니다(S35). 시드 파일은 `go generate ./seed/`로 다시 만듭니다.
* `seed` Job은 이미지에 포함된 시드 파일을 `content_templates`의 새 `seed_version`으로 넣고 active로 바꿉니다. 그 버전의 슬롯 명세도 `content_seeds.slots`에 함께 저장합니다. 서버는 문장을 렌더하거나 고를 때 그 문장의 시드 버전 명세를 읽으므로(데일리는 선택 기록의 버전, 캘린더·사주 표·용어 사전은 active), 바이너리에 내장된 명세에 기대지 않습니다(S45). 같은 버전이 이미 있으면 아무것도 하지 않습니다. 이전 버전 행은 남깁니다. 선택 기록이 그 버전을 가리키기 때문입니다.
* `serve`는 시드를 넣지 않습니다. active 시드가 없으면 콘텐츠 operation은 503 `service.unavailable`과 Error 로그입니다(S37).
* 시드 CI(`server.yml`)는 다음을 확인합니다. 하나라도 실패하면 병합을 막습니다.
  1. `uv sync --frozen` 뒤 `uv run mlw check ../content --partial`(작업 디렉터리 `docs/identity/writing/tools`)이 0으로 끝나는지
  2. `core/message_keys.json`의 모든 키 × 3개 언어 × 필요한 변주가 있는지
  3. 매개변수 이름이 core가 제공할 매개변수 목록(`core/message_params.json`, Issue #38)과 맞는지. 1번의 `mlw check`가 함께 봅니다(슬롯 명세 `params` 대조). `--partial`은 빠진 원고 보고만 끄므로 이 검사는 늘 켜져 있습니다
  4. 원고를 다시 변환한 결과가 commit된 시드 파일과 같은지(`go generate ./...` 뒤 `git status --porcelain`이 비었는지)
* 원고가 W1로 다 오기 전까지는 1번을 `--partial`로 돌리고, 2번은 변환 도구가 빠진 (slot, key, variant, lang)을 `missing:` 줄로 출력만 합니다(S38). W1이 끝나면 `--partial`을 빼고 변환 도구에 `-strict`(빠진 원고가 있으면 실패)를 켭니다.

### 6.2 문장 선택 (D59②)

`GET /v1/daily/{date}`를 예로 듭니다. 알림 Job도 같은 함수를 씁니다(§8.2).

선택 기록은 `getDaily`의 문장 슬롯 전부(`daily.fortune.head`·`tag`, `daily.guide`, `daily.color`, `daily.direction`, `daily.number`, `daily.focus_time`, `character.reason`)에 남깁니다. 캘린더·사주 표는 기록하지 않고 active 시드로 렌더합니다. 순환이 없고, 기록하면 한 달에 60줄이 쌓이기 때문입니다.

1. 엔진 결과(§7)에서 슬롯마다 메시지 키를 얻습니다.
2. 슬롯마다 `daily_selections`를 (계정, 날짜, 슬롯, **사주 지문**)으로 봅니다(S23, Issue #92). 사주 지문은 엔진 입력이 되는 출생 정보(생년월일시, 달력·윤달, 시간 모름, 성별, 출생 시간대·경도)를 정규화한 SHA-256입니다. 호칭·현재 시간대처럼 엔진 결과를 바꾸지 않는 값은 넣지 않습니다.
   * 기록이 있고 메시지 키가 지금 결과와 같으면 그 (키, 변주, 시드 버전)을 씁니다. 두 기기와 다시 열기가 같은 문장을 봅니다.
   * 기록이 없거나 메시지 키가 달라졌으면 새로 고릅니다. 같은 지문에서 키만 달라졌으면(하루 중 ruleset 변경 등) 그 행을 고쳐 쓰고, 그 행의 반응은 soft delete합니다. 새 문장에 옛 반응이 붙지 않게 하려는 것입니다(S34). 사주 정보를 바꾸면 지문이 달라지므로 같은 날이라도 새로 고릅니다. app은 사주를 바꿀 때 "오늘·달력·나의 사주가 다시 계산된다"고 알립니다(#84).
   * 옛 지문의 기록은 지우지 않습니다. 그 기록에 붙은 문장 반응(D57)은 그대로 성향 자료로 씁니다. 일기는 그때 보인 질문의 원문을 따로 남기므로(D59④) 영향이 없습니다.
3. 새로 고르는 규칙
   * 총운 슬롯(D57①): `rotation_state`의 `advice → state → care` 차례. 새 사용자는 `advice`부터입니다.
   * 차례가 `care`인데 돌봄 상한(하루 2개, 최근 7일 7개, W14)에 걸리면 `care`를 건너뛰고 다음 차례를 씁니다. 상한은 `daily_selections`로 세되 (날짜, 슬롯)마다 한 번만 셉니다. 하루 안에 사주를 바꿔 같은 슬롯에 `care` 기록이 둘 생겨도 하나로 봅니다.
   * `rotation_state`는 사주를 바꿔 다시 고를 때도 한 칸 넘깁니다. 같은 날 다시 고른 문장이 앞 문장과 같은 유형이 되지 않게 하려는 것입니다.
   * 같은 (계정, 날짜, 슬롯)에 다른 지문의 기록이 있으면 그 유형과 같은 차례는 건너뜁니다.
   * 두 규칙이 부딪히면 돌봄 상한이 먼저입니다(S41). 차례부터 보아 상한에도 걸리지 않고 같은 날 유형과도 겹치지 않는 첫 후보를 씁니다. 그런 후보가 없으면 유형 회피만 풀고, 차례부터 상한에 걸리지 않는 첫 후보를 씁니다(`advice`·`state`는 상한이 없어 늘 있습니다).
   * 가이드 질문: 변주 1 → 2.
   * 정보 슬롯과 식별자 문구: 변주 하나, 순환 없음.
4. 새로 고른 결과를 기록하고 `rotation_state`를 실제로 고른 것의 다음 차례로 넘깁니다. 같은 트랜잭션에서 하고, 트랜잭션 처음에 계정 단위 advisory lock(`pg_advisory_xact_lock`, int4 키 둘)을 겁니다(S40). 날짜·지문이 다른 동시 요청도 같은 계정이면 차례로 처리해, 순환을 잃거나 돌봄 상한을 넘지 않습니다. unique 제약은 그 위의 마지막 방어입니다.
5. 언어를 바꿔도 선택은 그대로 두고, 같은 (키, 변주, 시드 버전)을 새 언어로 렌더합니다.

### 6.3 렌더 (계약 "호칭·조사 처리 규칙", 버전은 계약 표 참조)

1. NFC 정규화
2. `[[용어]]` 토큰 위치를 기억하고 괄호를 뗌
3. `{param}`, `{param:category}`를 값 종류별로 치환. 호칭은 프로필 값을 그대로 넣고, 접미사("님"·「さん」)는 원고에 쓰인 대로 둡니다
4. 병기형 조사 6쌍을 렌더
5. 토큰 위치를 다시 계산해 조각 배열로 만듦

* 판정은 `docs/identity/writing/rules/josa.yaml`과 기준 구현 `tools/src/mlw/josa.py`·`placeholders.py`를 따릅니다. 테스트가 `examples`와 `name_rules.examples`를 그대로 읽어 씁니다.
* 식별자의 언어별 이름도 콘텐츠 모듈이 만듭니다: `score_items[].id`, `FocusSlot.reasons`, `SolarTerm.kind`. `SolarTerm.name`(간체 한자)은 쓰지 않습니다.
* 시각(`FocusSlot.start/end`, `SolarTerm.at`)은 사용자의 `current_timezone`으로 바꿔 보냅니다.
* `ResponseMeta.notices`도 메시지 키이므로 같은 렌더 경로를 씁니다.

### 6.4 문장 응답 형식 (S9)

용어 토큰은 위치 숫자 대신 조각 배열로 보냅니다.

```json
{"segments": [{"text": "오늘은 "}, {"text": "편관", "term": "ten_god.pyeongwan"}, {"text": "의 기운이…"}]}
```

위치 숫자는 Dart(UTF-16)와 Go(UTF-8)가 글자를 세는 방식이 달라 어긋나기 쉽습니다. `term`은 용어 id(`<범주>.<값>` 또는 `tag.<키>`, #129)이고, app은 이것으로 `Glossary`의 뜻·한자를 찾습니다. 응답에 `[[`·`]]`·`|용어 id`는 남지 않습니다.

* 데일리 응답에는 세 깊이(surface / explain / evidence)를 한 번에 담습니다. 크기가 작고, 펼칠 때마다 다시 부르지 않게 하려는 것입니다.
* **잠긴 내용 (D60, S14):** 근거 열람 권한(`insight`)이 없으면 evidence 깊이의 해석(판정 근거 문장, 원전 인용, 원국 개인 해석, `saju-chart.yongsin.basis`)을 응답에 담지 않습니다. 대신 응답마다 `evidenceAccess`(`unlocked`·`locked`)를 명시해, 근거가 원래 없는 것과 잠겨서 빠진 것을 app이 구분하게 합니다(§3.2 원칙). 사주 표·만세력·대운 표의 데이터와 surface·explain은 잠그지 않습니다(D60①). 그래서 판정 근거·원전 문장(`Evidence.basis`·`source`)은 `evidence[]`와 함께 빠지고, 오늘 그런 이유(`SlotText.todayReason`, writing `explain.today_reason`)와 용어 뜻·한자(`Glossary.meanings`·`hanja`)는 남습니다.
* 잠긴 응답은 근거 문장을 아예 렌더하지 않습니다(S42). 버릴 문장을 만들지 않고, 원고가 없을 때의 오류 로그도 줄입니다.
* 실행 중에 템플릿이 없으면(CI가 막으므로 원래 일어나지 않음) 그 슬롯(선택 필드)만 빼고 Error 로그를 남깁니다. 필수 문장 필드는 빈 `segments`로 채우고 같은 로그를 남깁니다. 빠진 언어를 다른 언어로 대신하지 않습니다.
* `Notice.text`는 활성 시드의 `system.notice` 문장이고(S49), 원고가 없으면 빈 `segments`입니다. 빈 `text`면 app은 배너를 그리지 않습니다(S78).

## 7. 엔진 연동과 캐시 (D26·D31)

### 7.1 조회 흐름

1. 캐시 키를 만듭니다: `birth_hash` + 현재 `ruleset_version` + 요청 값.
2. 캐시에 있으면 씁니다.
3. 없으면 엔진을 부르고 결과를 저장합니다. 같은 키의 동시 요청은 프로세스 안에서 `singleflight`로 한 번만 부릅니다.

* **현재 `ruleset_version` 알기:** 캐시에 결과가 있으면 엔진을 부르지 않으므로, 엔진 응답만 봐서는 버전이 바뀐 것을 알 수 없습니다. 그래서 server는 시작할 때와 10분마다 엔진 `GetInfo`(계산 없이 `engine_version`·`ruleset_version`만 돌려줌, Issue #49)로 버전을 갱신합니다. 엔진을 배포한 직후 최대 10분 동안은 이전 버전 캐시가 쓰일 수 있습니다. 이전 버전 캐시는 `job retention`이 지웁니다.
* 연결: 엔진은 Cloud Run internal ingress로만 받고, server는 Direct VPC egress와 ID token으로 부릅니다(D56①). deadline은 호출마다 3초입니다. 설정은 `ENGINE_ADDR`(필수)와 `ENGINE_AUDIENCE`(https URL)이며, audience가 있으면 TLS + ID token, 없으면 h2c입니다. 시작 때 `GetInfo`가 실패해도 시작은 계속하고 버전을 알기 전 엔진 요청은 503입니다(S27). 버전을 모르는 동안에는 2초부터 두 배씩(상한 10분) 늘려 다시 시도하고, 알게 되면 10분 주기로 돌아갑니다.
* 캐시 흐름: 조회 키는 `Versions.Current()`, 저장 키는 응답 `meta.ruleset_version`입니다. singleflight를 기다린 호출자는 자기 ctx가 취소되면 바로 돌아오고, 공유 응답은 호출자마다 `proto.Clone`합니다. 캐시 읽기·쓰기 오류(쓰기 1초 timeout)는 Warn 로그 후 엔진 결과로 계속합니다(S30).

### 7.2 프로필 저장 때의 검증

음력 → 양력 변환과 윤달이 실제로 있는지 판정하는 일은 엔진만 할 수 있습니다. 그래서 출생 정보를 저장할 때 `GetChart`를 한 번 부르고, 이 단계에서 엔진이 돌려준 `INVALID_ARGUMENT`·`OUT_OF_RANGE`를 422로 바꿉니다(§11). 양력 범위(D41)와 형식은 엔진을 부르기 전에 server가 먼저 검증합니다. 호출 결과는 캐시에 넣어 나의 사주 화면에서 다시 씁니다. 이 검증은 저장된 출생 해시와 달라질 때만 합니다. 시간대·호칭·알림만 바꾸는 수정은 엔진 장애 중에도 됩니다(S29). 출생 정보를 보내지 않은 Patch는 저장된 출생 정보와 해시를 그대로 쓰고 재검증하지 않습니다.

### 7.3 캐시 저장소 (S4)

MVP는 PostgreSQL 테이블에 캐시를 두고 `ResultCache` 인터페이스 뒤에 숨깁니다. 다음 중 하나가 2주 넘게 이어지면 Memorystore(Redis)로 바꿉니다.

| 지표 | 기준 |
| --- | --- |
| 캐시 읽기 p95 지연 | 20ms 초과 |
| Cloud SQL CPU 중 캐시 쿼리 비중 | 지속 사용률 60% 이상에서 캐시 쿼리가 절반 이상 |
| 요청 한도 카운터 쓰기 | 초당 200회 초과 |

## 8. Job

### 8.1 `job precompute` (30분마다)

* 대상: 현재 시간대의 현지 시각이 22:00~22:29이고 `last_active_at`이 14일 안인 사용자.
* 다음 날 데일리를 미리 계산합니다. 다음 날이 1일이면 다음 달 캘린더도 계산합니다.
* 엔진 동시 호출은 8개로 제한합니다.
* 실패한 사용자는 건너뜁니다. 요청 시점 계산으로 넘어가므로 사용자에게는 보이지 않습니다.

### 8.2 `job notify` (5분마다, S13)

* 알림 시각은 5분 단위로 받습니다. 계약의 `pattern`으로 표현되므로 REST에서 분이 5의 배수가 아니면 `pattern` 위반 400 `request.invalid`입니다(§11.2).
* 대상: `notify_status = enabled`이고, 현재 시간대의 현지 알림 시각이 [지금−60분, 지금]이며, 그 현지 날짜의 `notification_log`가 없는 사용자. Job이 멈췄다 돌아와도 1시간 안의 누락분만 보냅니다.
* 내용: 그날 데일리를 §6.2로 선택(알림이 그날 첫 요청이면 여기서 선택이 정해짐)하고, 알림 슬롯 문장을 호칭 없이 렌더합니다. 알림 슬롯은 IA content 슬롯 `system-push.morning.body`입니다(D62).
* 발송: FCM HTTP v1. 일괄 발송 API가 없으므로 메시지를 하나씩 동시에 보냅니다(동시 50개).
  * `UNREGISTERED`, 토큰 관련 `INVALID_ARGUMENT`는 기기를 비활성으로 바꿉니다.
  * `QUOTA_EXCEEDED`, `UNAVAILABLE`, `INTERNAL`은 지수 backoff로 3번까지 재시도합니다.
* 한 번 실행에서 실패율이 5%를 넘으면 Job을 실패로 끝내 경보를 받습니다.
* **큐 도입 기준:** 한 번 실행이 5분 안에 끝나지 않거나 한 창의 대상이 5만 명을 넘으면, 대상 선정과 발송을 나눠 Cloud Tasks로 발송합니다.

### 8.3 `job retention` (하루 1번)

* 삭제 요청 뒤 30일이 지난 계정을 익명화합니다(§9). 실패했던 Apple revoke·카카오 unlink도 다시 시도합니다.
* soft delete 뒤 30일이 지난 일기·일정의 내용을 비웁니다. 일기는 body·guide_question, 일정은 title·memo를 비우고 `content_purged_at`을 기록합니다. 행은 남깁니다.
* 지우는 것: 이전 `ruleset_version` 캐시, 30일 지난 `daily_cache`·`month_cache`, 만료된 refresh token, 지난 `rate_limits`, 24시간 지난 `idempotency_keys`.

## 9. 익명화 (S7)

행은 남기고 민감 정보만 바꿉니다. FK와 통계가 그대로 남습니다.

| 대상 | 처리 |
| --- | --- |
| `accounts` | status `deleted`, anonymized_at 기록 |
| `auth_identities` | subject를 `deleted:<uuid>`로 바꾸고 Apple 토큰을 비움. 원래 제공자 계정과 연결이 끊겨 로그인할 수 없고, 같은 제공자 계정으로 가입하면 새 계정이 됨 |
| `profiles` | 호칭, 출생 정보, `birth_hash`를 비움(anonymized_at 기록) |
| `diaries`, `schedules` | 본문·가이드 질문·제목·메모를 비움. 날짜와 태그는 남김 |
| `devices` | 토큰을 지우고 비활성 |
| `daily_selections` | 행은 남기고 `birth_hash`만 비움(NULL) |
| 남기는 것 | `consents`, `daily_selections`(birth_hash 제외), `rotation_state`, `reactions`, `entitlement_grants`, `billing_events`, `reward_events`, `notification_log` |

* **출생 정보는 가짜 값으로 채우지 않고 비웁니다.** 더미 생일은 통계에서 진짜 값과 섞입니다. 왜 비었는지는 `anonymized_at`이 설명합니다.
* **`birth_hash`도 비웁니다.** 생년월일시는 경우의 수가 작아서 해시만 남아도 원래 값을 되찾을 수 있습니다. `daily_selections.birth_hash`도 같은 이유로 비웁니다. 그 열은 계정과 연결돼 있어 남기면 익명화한 계정의 생년월일시를 되찾을 수 있기 때문입니다. 선택 기록의 나머지(날짜·슬롯·메시지 키·변주)와 반응은 성향 자료라 남깁니다. 캐시 행은 계정과 연결되지 않으므로 그대로 두었다가 보존 기간이 지나면 지웁니다.
* **일기 본문을 남기지 않습니다.** 개인정보보호법은 다른 정보와 합쳐도 개인을 알아볼 수 없을 때만 익명 정보로 봅니다. 자유 서술인 본문과 호칭이 들어간 가이드 질문은 그 기준을 넘기 어렵습니다.
* **남기는 태그·메시지 키에 대한 판단:** 이 값들은 원국에서 나오므로, 날짜별로 쌓이면 원국을 어느 정도 거꾸로 짐작할 수 있습니다. 하지만 원국이 같은 사람은 많아서, 이것만으로는 생년월일시도 개인도 특정하지 못합니다. 그래서 남깁니다.
* RevenueCat의 고객 기록은 지우지 않습니다. app_user_id가 계정 UUID라 개인을 가리키지 않고, 결제 기록 보관 의무가 있기 때문입니다.

## 10. 결제와 권한 (D53·D54·D60, S11·S14)

* app은 RevenueCat `app_user_id`를 계정 id로 맞춥니다(`Purchases.logIn`).
* **webhook은 신호로만 씁니다.**
  1. RevenueCat에 설정한 Authorization 헤더 값을 검증합니다.
  2. 원본 이벤트를 `billing_events`에 저장합니다. 같은 `event_id`는 한 번만 처리합니다.
  3. RevenueCat REST API로 그 고객의 구매 내역을 다시 조회해 `entitlement_grants`를 맞춥니다.
  4. 2xx로 응답합니다. 이벤트 순서가 뒤바뀌거나 중복돼도 결과가 같습니다.
* `POST /v1/billing/restore`도 3번의 같은 동기화 함수를 씁니다. 비갱신 상품은 스토어가 복원해 주지 않으므로 server가 복원합니다.
* **만료일 계산:** 광고 제거권 구매를 구매일 순으로 보며 `만료일 = max(직전 만료일, 구매일) + 1개월`로 이어 붙입니다.
  * 만료 전 재구매를 이어 붙이는 규칙은 D61로 확정됐습니다.
  * 환불된 구매는 빼고 다시 계산합니다. 동기화는 RevenueCat REST v2 구매 목록을 쓰며 환불은 `status: refunded`로 표시됩니다(P7-1). 없는 고객은 404이고 구매 없음으로 봅니다.
  * "1개월"은 UTC 달력 기준이고 달의 날이 없으면 그 달 마지막 날로 맞춥니다(1월 31일 → 2월 28·29일, 시각 유지, P7-3).
* **조정:** 계정의 `ad_free_pass` 행을 원하는 집합과 비교해 없는 행은 넣고 기간이 다른 행은 고치고, 집합에서 빠진 행은 `revoked_at`을 찍습니다. 행을 지우지 않습니다(P7-5).
* **동시성:** 동기화는 트랜잭션 안에서 계정 advisory lock(저장소 관례의 int4 키 쌍, 구분 'bil')을 잡은 뒤 RevenueCat을 조회하고 조정합니다. 동시에 온 webhook·복원이 오래된 조회 결과로 새 결과를 덮지 않게 하려는 것입니다(P7-6).
* **webhook 계정 찾기:** `app_user_id`, `original_app_user_id`, `aliases`, `transferred_from`, `transferred_to`에서 UUID 형식이고 `accounts`에 있는 id를 모두 모아 각각 동기화합니다. 하나도 없으면 기록만 하고 200(Warn 로그)이며 `TEST` 이벤트도 기록만 합니다(P7-7).
* **transfer:** 같은 구매 id가 다른 계정 행에 있으면 지금 목록의 주인으로 행을 옮깁니다(RevenueCat 구매 목록이 권위입니다). 오래된 목록으로 늦게 조정한 이전 주인이 행을 되찾는 경합은 받아들입니다. TRANSFER가 양쪽 계정에 webhook을 보내 다음 동기화에서 수렴합니다.
* 광고 제거권 구매를 동기화할 때 같은 기간의 `insight` 권한도 출처 `ad_free_pass`로 함께 부여합니다(D60③). 환불로 광고 제거권이 줄면 이 권한도 같이 줄입니다.
* 광고 제거 여부와 근거 열람 권한은 `GET /v1/me`와 `GET /v1/me/entitlements`로 알려 줍니다. 근거 열람 권한은 만료 시각과 출처를 함께 보냅니다.

### 10.1 보상형 광고 SSV (D60, S14)

1. app은 보상형 광고를 띄울 때 SSV 옵션의 `user_id`에 계정 id를 넣습니다.
2. AdMob이 `GET /webhooks/admob-ssv?...&signature=…&key_id=…`로 부릅니다. server는 서명 대상 문자열(쿼리에서 `signature` 앞까지)을 AdMob 공개 키(`https://www.gstatic.com/admob/reward/verifier-keys.json`, `key_id`로 고름)로 ECDSA 검증합니다. 공개 키는 24시간 캐시하되, 모르는 `key_id`가 오면 마지막 조회 뒤 1분이 지났을 때만 다시 받습니다. 캐시가 없거나 만료된 상태에서 받기에 실패하면 10초 동안은 키 서버를 부르지 않고 바로 503입니다(장애 중 호출 억제, P7-11).
3. 검증에 실패하면 401로 응답하고 아무것도 부여하지 않습니다.
4. `transaction_id`로 `reward_events`에 한 번만 저장하고, 같은 트랜잭션에서 `insight` 권한을 출처 `rewarded_ad`로 부여합니다. 만료는 그 계정의 **현재 시간대 기준 다음 자정**입니다(D60③). 같은 `transaction_id`가 다시 오면 아무것도 하지 않고 200을 돌려줍니다.
5. `user_id`가 없거나 존재하지 않는 계정이면 이벤트만 기록하고 200을 돌려줍니다. AdMob이 재시도하지 않게 하기 위해서이며, 로그에 경고를 남깁니다.
6. 쿼리의 `timestamp`가 현재보다 1시간 넘게 오래됐으면 재전송 공격으로 보고 부여하지 않습니다(401). 서명 검증이 먼저이고, 단위는 숫자 13자리 이하면 ms, 16자리면 µs로 읽습니다(P7-13). 실제 단위는 staging에서 콘솔 테스트 콜백으로 확인합니다.
7. 보상 기록·부여는 계정 상태(`pending_deletion`·`deleted`)와 무관하게 합니다. 다음 자정을 구할 `profiles.current_timezone`을 못 읽으면 UTC 자정으로 부여하고 Error 로그를 남깁니다(저장 때 검증하므로 버그 신호, P7-14).

## 11. 오류 (S10)

### 11.1 형식

RFC 9457 `application/problem+json`을 씁니다.

```json
{"type": "https://api.myungli.app/problems/diary.future_date",
 "title": "Diary date is in the future", "status": 422,
 "code": "diary.future_date", "traceId": "…",
 "errors": [{"field": "date", "code": "diary.future_date"}]}
```

* 사용자에게 보이는 문구는 server가 보내지 않습니다. app이 `code`를 보고 자기 UI 문구(ARB)로 보여 줍니다(D59⑤). `title`은 개발자용 영어입니다.
* `traceId`는 문의가 왔을 때 로그를 찾는 데 씁니다.
* `type`의 도메인은 실제 도메인이 정해지면 바꿉니다. 그 전까지는 문서 안의 식별자로만 씁니다.

### 11.2 요청 처리

400과 422의 경계: 스키마로 표현되는 형식·범위 위반(타입, 필수 필드, `enum`, `pattern`, 길이, `minimum`·`maximum`, `format`)은 모두 400 `request.invalid`이고 `errors[].code`(위반한 keyword)로 구분합니다. 422는 스키마로 표현할 수 없는 의미 검사(D41 범위 밖, `LunarOrSolarDate`의 없는 날짜, 상태-값 짝 위반, 엔진 판정과 업무 규칙)에만 씁니다. `format: date` 문자열의 없는 날짜(예 `2026-02-30`)는 형식 위반이라 400입니다.

기계 판독 목록은 계약 `Problem.code`의 `x-problem-codes`입니다. code를 더하거나 바꾸면 이 표와 계약을 함께 고칩니다. server는 `internal/httpapi/problem/codes.go`의 상수로만 code를 내보냅니다(S21).

| 상황 | 상태 | `code` 예 |
| --- | --- | --- |
| JSON 문법 오류, 값 뒤에 데이터가 더 있음 | 400 | `request.malformed` |
| 스키마로 표현되는 형식·범위 위반(타입, 필수 필드, `enum`, `pattern`, 길이, 최솟값·최댓값, `format`). 예 알림 시각의 분이 5의 배수가 아님, `format: date`의 없는 날짜 `2026-02-30` | 400 | `request.invalid` (`errors[].code`는 위반한 keyword) |
| 경로에 등록된 라우트가 없음, 경로 정리가 필요한 경로(예 `/v1//me`) | 404 | `route.not_found` |
| 라우트는 있지만 메서드가 다름 (`Allow` 헤더) | 405 | `method.not_allowed` |
| 요청 본문이 1 MiB를 넘음 | 413 | `request.too_large` |
| 지원하지 않는 요청 Content-Type | 415 | `request.unsupported_media_type` |
| 형식은 맞지만 D41 지원 범위(양력 1900-01-31 ~ 2099-12-31) 밖 | 422 | `date.out_of_range`, 출생 정보는 `birth.out_of_range` |
| 정수 필드 객체 `LunarOrSolarDate`가 달력에 없는 날짜(예 양력 2월 31일). `format: date` 문자열의 없는 날짜는 위 400 행 | 422 | `date.invalid` |
| 상태-값 짝 위반: `BirthTime`(`status`·`value`), `BirthPlace`(`status`·`cityId`), 양력인데 `isLeapMonth` true, `NotificationSetting`(`status`·`time`), `ScheduleInput`·`SchedulePatch`(`allDay`·`time`) | 422 | `request.inconsistent` (`errors[].field`는 JSON Pointer, `errors[].code`는 `required_by_status`·`forbidden_by_status`) |
| 의미상 불가: 미래 날짜, 엔진 판정, 호칭 규칙 위반 | 422 | `diary.future_date`, `birth.invalid` |
| 시간대 이름이 IANA가 아님 | 422 | `timezone.invalid` (`errors[].field`는 `/currentTimezone` 또는 `/birth/timezone`) |
| `cityId`가 도시 목록에 없음 | 422 | `city.not_found` (`errors[].field`는 `/birth/place/cityId`) |
| 일정 조회 범위(`from`~`to`)가 62일 초과 | 422 | `range.too_long` |
| 호칭 거부. 기준은 josa.yaml `name_rules`의 기준 구현(`normalize_name`): 비어 있음, 언어별 길이 초과, 이모지, 제어 문자, 받지 않는 글자. 스키마 길이(1~20) 위반은 400 `request.invalid`가 먼저 | 422 | `name.empty`, `name.too_long`, `name.emoji`, `name.control`, `name.invalid_char` |
| access token 없음·만료·위조 (`WWW-Authenticate: Bearer error="invalid_token"`, RFC 6750) | 401 | `auth.token_expired`, `auth.token_invalid` |
| refresh token 재사용 감지 | 401 | `auth.refresh_reused` |
| 제공자 토큰 검증 실패 | 401 | `auth.provider_token_invalid` |
| App Check 실패 | 401 | `app_check.invalid` |
| 약관 미동의, 문서 버전 변경 | 403 | `consent.required` |
| 미리보기를 이미 씀 | 403 | `preview.used` |
| 없는 리소스, 남의 리소스 | 404 | `diary.not_found`, `schedule.not_found` (남의 것도 404로 보내 존재 여부를 숨김). 반응할 선택 기록이 없거나 반응할 수 없는 슬롯은 `reaction.not_found` |
| 프로필 없이 운세 요청, 프로필 읽기 | 409 | `profile.required` |
| 되살리려는 날짜에 이미 일기가 있음 | 409 | `diary.date_taken` |
| 같은 `Idempotency-Key`가 처리 중 | 409 | `idempotency.in_progress` |
| 같은 `Idempotency-Key`에 다른 본문 | 422 | `idempotency.mismatch` |
| 동의한 문서 버전이 현재 버전과 다름 | 422 | `consent.version_mismatch` (`errors[].field`는 `/documents/<i>/version`) |
| 제공자(카카오·Apple) 장애 | 503 | `auth.provider_unavailable` |
| 요청 한도 초과 (`Retry-After`) | 429 | `rate_limited` |
| 계약에는 있지만 아직 구현하지 않은 operation | 501 | `not_implemented` |

예외: 언어만 바꾼 PATCH로 저장된 호칭이 새 언어 규칙에 걸리면, 요청 본문에 없는 `/honorific`을 `errors[].field`로 둡니다(원인 필드 안내).

`name.suffix_stripped`, `name.suffix_warning`은 오류가 아닙니다. 저장한 값과 함께 200 응답의 `warnings`에 담습니다. 호칭 오류 코드는 계약 `josa.yaml`의 `name_rules`를 따릅니다.

### 11.3 외부 의존

| 상대 | 상황 | 처리 |
| --- | --- | --- |
| 엔진 | `UNAVAILABLE` | 한 번 재시도한 뒤 503 + `Retry-After`, `engine.unavailable` |
| 엔진 | `DEADLINE_EXCEEDED` | 504, `engine.timeout` |
| 엔진 | 호출자 취소(`context.Canceled`) | 엔진 오류가 아니라 ctx 오류로 돌려줍니다. 현재 500 로그로 남으며 P8에서 정리합니다 |
| 엔진 | `INTERNAL` | 502, `engine.error`. 재시도해도 같을 가능성이 커서 503이 아님 |
| 엔진 | 프로필 저장 중 `INVALID_ARGUMENT`·`OUT_OF_RANGE` | 422, `birth.invalid`·`birth.out_of_range` (§7.2) |
| 엔진 | 그 밖의 요청에서 `INVALID_ARGUMENT`·`OUT_OF_RANGE` | 저장된 입력은 이미 검증했으므로 server 버그. 500 + 경보 |
| 카카오·Apple | 제공자 장애 | 503, `auth.provider_unavailable` |
| RevenueCat webhook | 인증 헤더 불일치 | 401, 기존 code `auth.token_invalid`(challenge 헤더 없음) |
| RevenueCat webhook | 저장·동기화 실패 | 500. RevenueCat이 2xx가 아니면 다시 보내므로 재처리에 맡김 |
| RevenueCat REST (`restore`) | 장애 | 503, `billing.provider_unavailable` |
| AdMob SSV | 서명 검증 실패, 오래된 timestamp | 401, `reward.invalid_signature`·`reward.expired` |
| AdMob 검증 키 | 키 목록을 받지 못함 | 503. AdMob이 다시 보냄 |
| DB | serialization 실패, deadlock | server 안에서 트랜잭션을 최대 3번 재시도 |
| DB | unique 위반(경합) | 도메인 결과로 바꿈. 예: 선택 기록 경합은 다시 읽음 |
| DB | 연결 실패 | 503, `service.unavailable` |
| 그 밖 | 예상하지 못한 오류 | 500, `internal`. 상세는 로그에만 |

### 11.4 로그

* `slog` JSON으로 남기고 요청마다 trace id를 붙입니다.
* 출생 정보, 호칭, 일기·일정 본문, 토큰, 제공자 응답 원문은 로그에 남기지 않습니다.

## 12. 테스트와 CI

| 층 | 방법 |
| --- | --- |
| 단위 | 렌더러는 `josa.yaml`의 `examples`·`name_rules.examples`를 읽어 돌림. 선택·순환·돌봄 상한·자정 경계·시간대는 가짜 `Clock`으로 확인 |
| DB | testcontainers-go로 PostgreSQL을 띄우고 migration을 적용해 sqlc 쿼리, CHECK 제약, partial unique, 익명화를 확인 |
| API | `httptest`로 요청을 보내고 요청·응답이 `openapi.yaml`과 맞는지 kin-openapi로 검증 |
| 엔진 | 평소에는 가짜 엔진. CI에서 실제 엔진 컨테이너와 맞물려 보는 계약 테스트 하나 |
| Job | 가짜 FCM·엔진·Clock으로 대상 선정, 중복 방지, 누락분 처리, 실패율 판정을 확인 |

CI(`.github/workflows/server.yml`, ci-gate가 `workflow_call`로 부르는 전용 workflow이며 직접 `push`·`pull_request`로는 돌지 않습니다. 경로 필터는 ci-gate가 갖습니다. 수동 실행은 `workflow_dispatch`, #102):

* `go vet`, golangci-lint, `go test`
* 생성 코드 차이 검사: sqlc, oapi-codegen, buf
* migration up → down → up
* 시드 검사(§6.1)

## 13. 배포와 외부 준비 (D56, S12)

### 13.1 배포

* distroless 이미지 하나를 `server/`만으로 빌드해 Artifact Registry에 올립니다. GitHub Actions는 WIF로 인증합니다.
* 환경은 staging과 prod 두 GCP 프로젝트로 나눕니다. main에 병합되면 staging에 자동 배포하고, prod는 GitHub environment 승인을 거칩니다.
* 순서: `migrate` Job → `seed` Job → service 배포 → Job 이미지 갱신.
* migration은 expand/contract 방식으로 써서 이전 버전 코드와 함께 돌아도 깨지지 않게 합니다.
* DB 연결은 Cloud SQL Go connector와 IAM 인증을 씁니다. 비밀값은 Secret Manager에 둡니다.

### 13.2 staging E2E 지원 (S24, Issue #93)

app E2E를 staging에서 사람 손 없이 돌리기 위한 장치입니다. prod에는 코드 자체가 없게 합니다.

* **테스트 로그인:** `POST /test/v1/auth/login`(REST 계약 밖). Go build tag `staging`이 붙은 파일에만 라우트와 핸들러가 있어 prod 바이너리에는 컴파일되지 않습니다. staging 배포 workflow만 `-tags staging`으로 빌드합니다.
  * 요청 헤더 `X-Test-Login-Secret`이 Secret Manager의 `TEST_LOGIN_SECRET`과 같아야 합니다(상수 시간 비교). 다르면 404로 라우트가 없는 것처럼 답합니다.
  * 본문 `{label}`(영숫자 32자 이하)로 provider `test`, subject `<label>`인 계정을 찾거나 만들고, 정상 로그인과 같은 `LoginResponse`를 돌려줍니다. 약관 동의·삭제 흐름은 실제와 같게 거칩니다.
  * `auth_identities.provider` CHECK에 `test`를 더하는 migration은 staging과 prod가 같습니다. prod에는 발급 경로가 없으므로 `test` 행이 생기지 않고, 테스트가 이를 확인합니다(prod 빌드에 라우트가 없음).
* **App Check debug token:** App Check 검증(P6)은 Firebase가 debug token을 정식으로 받습니다. E2E 기기·에뮬레이터의 debug token은 staging Firebase 프로젝트 콘솔에만 등록하고 prod에는 등록하지 않습니다. server 코드는 바꾸지 않습니다. 등록 절차는 배포 단계 안내(§13.3)에 넣습니다.

### 13.3 사용자가 준비할 것

설정 값과 상세 절차는 배포 단계에서 server가 단계별로 안내합니다. 여기서는 무엇이 필요한지만 적습니다.

| 대상 | 준비할 것 |
| --- | --- |
| GCP (staging·prod 각각) | 프로젝트와 결제 계정. Cloud Run·Cloud SQL·Artifact Registry·Secret Manager·Cloud Scheduler·IAM Credentials API 사용 설정. GitHub 저장소용 Workload Identity pool·provider |
| Firebase (GCP 프로젝트에 연결) | iOS·Android 앱 등록. FCM용 APNs 인증 키 업로드. App Check: iOS App Attest, Android Play Integrity |
| Kakao Developers | 앱 등록, 카카오 로그인과 OpenID Connect 사용 설정, 플랫폼(번들 ID·패키지명·키 해시), admin key |
| Apple Developer | App ID에 Sign in with Apple. Android 웹 흐름용 Services ID와 Return URL(`/v1/auth/apple/callback`). Sign in with Apple 키(.p8), Team ID, Key ID |
| RevenueCat | 프로젝트와 상품. webhook URL과 Authorization 헤더 값, REST v2 secret API key, 프로젝트 id, 광고 제거권 상품 id 목록. 설정 이름은 `REVENUECAT_PROJECT_ID`·`REVENUECAT_API_KEY`·`REVENUECAT_WEBHOOK_AUTH`·`AD_FREE_PRODUCT_IDS`(쉼표 목록)이고 `APP_ENV`가 local이 아니면 모두 필수입니다 |
| AdMob | 보상형 광고 단위와 SSV 콜백 URL(`/webhooks/admob-ssv`) 등록 |

## 14. 다른 쪽에 보낼 요청

| 받는 쪽 | 내용 |
| --- | --- |
| root (계약) | REST API v1 계약 등록: `server/api/openapi.yaml`. proto 생성 코드 위치 `server/internal/gen/enginev1/`. 계약 표의 자기 행은 server가 계약 PR에서 직접 고침 |
| root (IA) | 알림 문장 슬롯 추가 요청(개인화하되 호칭 없음). 완료: D62 |
| root (제품 결정) | 광고 제거권 만료 전 재구매를 이어 붙일지 확인. 완료: D61 |
| root → app·design | 문장 조각 배열 형식(§6.4)과 `term` 표시 방식 |
| root → writing | 미리보기에서 호칭이 들어가는 슬롯을 호칭 없이 보이는 방법 |
| root → app | GeoNames 출처 표기를 오픈소스 고지에 넣기 |
| core (완료) | `core/message_params.json`(Issue #38), D58 시진 RPC `GetBirthHour` |
| core (요청) | 시진 확인에 성별 미지정을 허용(#304). 반영되면 `GENDER_UNSPECIFIED`로 되돌림(S69) |
| core (요청) | `ruleset_version` 조회 RPC (§7.1). 완료: `GetInfo`, PR #67 |

## 15. 구현 순서 (계획의 큰 줄기)

1. 뼈대: 하위 명령, 설정, DB·migration, `Clock`, 로깅, CI
2. OpenAPI 초안 → 계약 등록 요청
3. 인증·계정·약관
4. 프로필과 엔진 클라이언트(가짜 엔진), 캐시
5. 콘텐츠: 시드 도구, 렌더러, 선택·순환, 데일리·나의 사주·캘린더 응답
6. 일기·일정·반응
7. 비로그인 요청(미리보기·시진), 도시, app-config
8. 결제
9. Job: precompute, notify, retention과 익명화
10. 배포 파이프라인(staging·prod)
