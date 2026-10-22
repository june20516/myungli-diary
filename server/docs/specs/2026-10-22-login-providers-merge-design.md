# 로그인 제공자 넷과 계정 연결·합치기 (D82) — spec

* 날짜: 2026-10-22
* 요청: Issue #386 (root→server, accepted), app nonce 규칙 코멘트(#387 쪽), 지휘 정정(D83 ④, PR #411)
* 기준: D82(D55 개정), D83 ④, D53·D60·D61, server spec §4(인증)·§9(삭제), S20·S24·S60·S95
* 결정 번호: S99~S104

## 1. 목표

LINE·Google 로그인을 더하고, 한 계정에 여러 제공자를 붙이고 떼고, 두 계정을 합칠 수 있게 합니다. S3 REST v1 freeze 전에 계약에 들어가야 합니다. 모두 operation 추가라 하위 호환입니다.

### 1.1. 용어

| 용어 | 뜻 | 어디에 있나 |
| --- | --- | --- |
| 연결 | 우리 계정과 제공자 사용자 id(`provider`, `subject`)의 짝 | `auth_identities` 행 |
| 붙이기·떼기 | 우리 계정에 연결을 더하거나 빼는 일. 떼면 그 제공자로는 이 계정에 들어오지 못합니다 | 우리 DB |
| 제공자 허가 | 사용자가 제공자에게 준 "명리일기 로그인 허용". 제공자 설정의 앱 목록에 보입니다 | 제공자 서버 |
| 허가 취소 | 제공자 허가를 없애는 호출(Apple revoke, 카카오 unlink, LINE deauthorize, Google revoke). D82 ⑤의 "제공자 쪽 연결 해제" | 제공자 서버 |
| 제공자 token | 제공자가 그 사용자에 대해 발급한 access·refresh token | 기기의 제공자 SDK(Apple만 우리 DB에 refresh token 암호화 저장) |
| 우리 세션 | server가 발급한 refresh token family | `refresh_tokens` |
| 현재 계정 | 붙이기·합치기를 요청한 bearer 계정 | |
| 다른 계정 | 붙이려는 연결을 이미 가진 계정 | |
| 남길 계정·없앨 계정 | 합치기에서 사용자가 고른 쪽과 반대쪽. 현재 계정이 어느 쪽이든 될 수 있습니다 | |
| 합치기 토큰 | 붙이기에서 통과한 제공자 인증(소유 확인)을 합치기 확인까지 이어 주는 일회용 값 | `account_merge_tickets`(해시) |

## 2. 제공자 로그인 (S99)

### 2.1. 검증

공용 OIDC 검증(`provider/oidc.go`)을 넓혀 서명 알고리즘 목록과 audience 여러 개를 받게 합니다. 카카오·Apple은 지금 값(RS256, audience 하나)을 그대로 씁니다.

| 제공자 | iss | 서명·JWKS | aud |
| --- | --- | --- | --- |
| LINE | `https://access.line.me` | ES256, `https://api.line.me/oauth2/v2.1/certs` | channel ID(`LINE_CHANNEL_ID`) |
| Google | `https://accounts.google.com` 또는 `accounts.google.com` | RS256, `https://www.googleapis.com/oauth2/v3/certs` | `GOOGLE_CLIENT_IDS`(쉼표 목록) 중 하나 |

* nonce는 네 제공자 모두 `id_token nonce = hex(SHA-256(원문))`입니다. 어느 제공자도 nonce를 일회용으로 기록하지 않습니다. Google은 app 프로세스마다 nonce가 하나라 같은 원문이 여러 번 올 수 있고(`google_sign_in` 7.x), 계약에 그렇게 적습니다.
* 오류 분류는 지금 규칙(`ErrTokenInvalid` → 401 `auth.provider_token_invalid`, `ErrUnavailable` → 503 `auth.provider_unavailable`)을 따릅니다.
* 설정이 비었을 때의 처리(시작 실패 여부)는 지금 카카오·Apple 설정 처리를 따릅니다.

### 2.2. 로그인 operation

* `loginLine`: `POST /v1/auth/line`, 본문 `{idToken, nonce}`, 응답 `LoginResponse`
* `loginGoogle`: `POST /v1/auth/google`, 본문 `{idToken, nonce}`, 응답 `LoginResponse`

둘 다 `security: []`이고 흐름은 `loginKakao`와 같습니다(처음 보는 연결이면 계정 생성, 삭제 대기면 복구).

### 2.3. 저장 (migration `00014`)

* `auth_identities.provider` CHECK에 `line`·`google`을 더합니다(`kakao`·`apple`·`test`·`line`·`google`).
* LINE·Google 연결에는 Apple 토큰 열이 없습니다(카카오와 같은 CHECK).
* UNIQUE `(account_id, provider)`를 더합니다. 한 계정에 같은 제공자 연결은 하나입니다. 지금 데이터는 계정마다 연결이 하나라 걸리는 행이 없습니다.

## 3. 연결 관리 (S100)

| operation | 경로 | 응답 |
| --- | --- | --- |
| `listIdentities` | `GET /v1/me/identities` | 200 `[{provider, linkedAt}]`, 붙인 순. `subject`는 내보내지 않습니다 |
| `linkIdentity` | `POST /v1/me/identities/{provider}` | 201 연결 생성, 200 그 연결이 이미 현재 계정에 있음 |
| `unlinkIdentity` | `DELETE /v1/me/identities/{provider}` | 204 |

`{provider}`는 닫힌 enum(`kakao`·`apple`·`line`·`google`)입니다. 응답의 제공자 값(`LoginProvider`)은 열린 enum입니다. `test`는 계약에 없습니다.

### 3.1. 붙이기

* 본문은 그 제공자의 로그인 증명과 같습니다.
  * 카카오·LINE·Google: `{idToken, nonce}`
  * Apple(iOS): `{idToken, authorizationCode, nonce}`. 로그인과 같이 code를 교환해 refresh token을 받고, 새 연결에 암호화해 저장합니다.
  * Apple(Android 웹 흐름): `{exchangeCode, nonce}`. `appleCallback`이 만든 교환 코드를 `completeAppleWebLogin`과 같은 규칙(일회용, 2분, nonce가 틀려도 소진하지 않음)으로 씁니다.
  * 경로의 제공자와 본문 조합이 맞지 않으면 400 `request.invalid`입니다(없는 필드는 `code: required`, 그 제공자가 쓰지 않는 필드는 `code: additionalProperties`, field는 JSON Pointer).
* 결과
  * 연결이 어디에도 없음: 현재 계정에 연결을 만들고 201
  * 연결이 이미 현재 계정에 있음: 바꾸지 않고 200(Apple이면 refresh token만 새 값으로)
  * 현재 계정에 같은 제공자의 다른 사용자 연결이 있음: 409 `auth.provider_taken`
  * 연결이 다른 active 계정에 있음: 409 `auth.identity_in_use`, 합치기 토큰 발급(§4.1)
  * 연결이 삭제 대기 계정에 있음: 409 `auth.identity_pending_deletion`. 그 제공자로 로그인하면 복구되므로 복구한 뒤 다시 시도합니다
* 연결이 다른 계정에 있는 409(`auth.identity_in_use`·`auth.identity_pending_deletion`)에서는 새로 교환한 Apple refresh token을 저장하지 않고 버립니다. revoke하지 않습니다. Apple revoke는 그 사용자의 앱 승인 전체를 끊어 다른 계정에 저장된 연결까지 무효로 만들기 때문입니다. `auth.provider_taken`은 그 Apple ID 연결이 어디에도 없으므로, 로그인과 같이 저장하지 못한 grant로 보고 revoke합니다.
* 같은 연결을 두 계정이 동시에 붙이면 한쪽이 `(provider, subject)` unique 위반을 받습니다. 그쪽은 트랜잭션을 한 번 다시 실행해 409 `auth.identity_in_use`가 됩니다(지금 로그인의 동시 첫 로그인 처리와 같은 방식). 다른 계정이 그 연결을 떼는 중이어서 합치기 토큰 저장이 `identity_id` FK 위반을 받아도 한 번 다시 실행하며, 그때는 연결이 없으므로 201입니다.
* 관문(동의·상태 확인)과 트랜잭션 사이에 삭제 요청이 끼어든 경합에서는 붙이기·떼기가 500입니다(드문 일시 오류, 다시 시도하면 403 계열).

### 3.2. 떼기

* 마지막 연결이면 409 `auth.last_identity`, 현재 계정에 그 제공자 연결이 없으면 404 `auth.identity_not_found`입니다.
* 트랜잭션에서 계정 행을 잠그고 연결 수를 확인한 뒤 연결 행을 물리적으로 지웁니다. 표시만 남기면 그 제공자 사용자가 나중에 새 계정을 만들 때 unique에 걸리기 때문입니다. Apple이면 지우기 전에 암호화된 refresh token을 읽어 둡니다.
* commit한 뒤 허가 취소를 한 번 시도합니다. 카카오는 unlink, Apple은 revoke입니다. 실패하면 경고 로그만 남기고 떼기는 성공입니다(계정 삭제 뒤 정리 `endSessions`와 같은 방식). 요청이 취소돼도 끝까지 하도록 `context.WithoutCancel`을 씁니다.
* LINE·Google은 server가 허가 취소를 부르지 않습니다. 허가 취소에 그 사용자의 제공자 token이 필요한데 server는 갖고 있지 않습니다(LINE `POST /user/v1/deauthorize`의 `userAccessToken`, Google revoke의 token). app이 떼기 직전에 그 기기의 SDK에 제공자 token이 있으면 SDK로 허가 취소를 하고, 없으면 생략합니다(제공자 허가가 남음, 사용자 결정 2026-10-22). D82 ⑤에 이 단서를 더해 달라고 지휘에 요청합니다(§7).

### 3.3. 계정 삭제

> 이 절은 2026-10-23 spec(`2026-10-23-account-delete-merge-purchases-design.md`) §3·§4이 대체합니다.

`DisconnectProviders`는 LINE·Google 연결을 외부 호출 없이 해제된 것으로 기록합니다(지금 `test` 연결과 같음). app은 계정 삭제 직전에 §3.2와 같이 SDK로 허가 취소를 합니다.

## 4. 합치기 (S101·S102)

> 이 절은 2026-10-23 spec(`2026-10-23-account-delete-merge-purchases-design.md`) §5~§6이 대체합니다.

### 4.1. 합치기 토큰 (S101)

* `linkIdentity`의 409 `auth.identity_in_use` 본문은 Problem 확장 필드 `mergeToken`(랜덤 32바이트, base64url 패딩 없음)과 `expiresAt`(발급 + 10분)을 담습니다.
* 새 표 `account_merge_tickets`

| 열 | 타입 | 비고 |
| --- | --- | --- |
| `id` | uuid PK | |
| `token_hash` | bytea NOT NULL UNIQUE | 토큰 원문의 SHA-256 |
| `account_id` | uuid NOT NULL | 현재 계정(토큰을 쓸 수 있는 bearer), FK |
| `other_account_id` | uuid NOT NULL | 다른 계정, FK |
| `identity_id` | uuid NOT NULL | 붙이려던 연결, FK `auth_identities(id)` ON DELETE CASCADE(떼거나 합쳐 지워지면 토큰도 무효) |
| `expires_at` | timestamptz NOT NULL | |
| `consumed_at` | timestamptz | 합치기 실행 때 채움 |
| `created_at` | timestamptz NOT NULL DEFAULT now() | |

* 토큰이 없거나, 만료됐거나, 이미 썼거나, bearer가 `account_id`가 아니면 422 `merge.token_invalid`입니다. 이 경우들을 구분하지 않습니다. 401은 app이 다시 로그인하라는 뜻으로 읽으므로 쓰지 않습니다.
* 토큰은 URL에 넣지 않습니다(접근 로그에 남음). 그래서 요약 조회도 `POST`입니다.
* 지난 행 정리는 retention 작업 몫입니다(만료 + 1일 뒤 물리 삭제).

### 4.2. 요약 (`previewMerge`)

`POST /v1/me/merge/preview`, 본문 `{mergeToken}`, 200 `MergePreview`. 토큰을 소진하지 않으므로 몇 번이든 부를 수 있습니다(dry run).

* `MergePreview`: `{current: MergeAccountSummary, other: MergeAccountSummary, overlapDayCount}`
* `MergeAccountSummary`
  * `honorific`: `saju.status`가 `saved`일 때만 있음
  * `saju`: `{status: saved, calendar, date: LunarOrSolarDate, isLeapMonth, birthTime: BirthTime}`(`Birth`와 같은 모양) 또는 `{status: none}`. 시각을 모르면 `birthTime.status`가 `unknown`입니다(design `ui.account-merge.saju`의 세 경우)
  * `diaryCount`: 살아 있는 일기 수. 그 계정이 없앨 계정이 되면 옮겨질 일기 수와 같습니다
  * `providers`: 연결된 제공자, 붙인 순
* `overlapDayCount`: 두 계정 모두 살아 있는 일기가 있는 날짜 수입니다. 0이면 app은 겹치는 날 안내를 보이지 않습니다.

### 4.3. 실행 (`mergeAccounts`, S102)

`POST /v1/me/merge`, 본문 `{mergeToken, keep: current|other}`, 200 `{accountId, tokens: TokenPair}`(남길 계정과 그 계정의 새 토큰 쌍).

트랜잭션 하나에서 다음 순서로 합니다.

1. 토큰 행을 해시로 찾아 잠그고(`FOR UPDATE`) §4.1의 조건을 확인합니다.
2. 두 계정 행을 id 순서로 잠급니다(교착 방지). 둘 다 active인지, 연결이 아직 다른 계정에 있는지 다시 확인합니다. 아니면 422 `merge.token_invalid`입니다.
3. 토큰을 소진합니다.
4. 남길 계정으로 옮깁니다.

| 대상 | 규칙 |
| --- | --- |
| 연결 | 없앨 계정의 연결을 모두 `account_id`만 바꿔 옮깁니다. Apple 암호화는 연결 id에 묶여 있어 그대로 유효합니다. 같은 제공자 연결이 양쪽에 있으면 남길 계정의 것을 남기고, 없앨 계정의 것은 지운 뒤 commit 뒤에 §3.2처럼 허가 취소를 시도합니다(LINE·Google은 생략) |
| 일기 | 전부 옮깁니다(S95). 남길 계정에 그 날짜의 날짜 기록이 없으면 없앨 계정의 날짜 기록을 남길 계정으로 복사하고, 있으면 남길 계정의 날짜 기록을 씁니다. 그다음 일기 행의 `account_id`를 바꿉니다(`diaries_day_fk`가 `(account_id, date)`를 참조해 날짜 기록 행의 키를 바꿀 수 없으므로 복사). 없앨 계정의 날짜 기록은 남아 P8이 정리합니다. 지운 일기도 옮깁니다. 10편 상한은 검사하지 않습니다(D83 ④) |
| 일정 | 전부 옮깁니다(지운 일정 포함). 확인 없이 데이터를 지우지 않는다는 D82 ⑥을 따릅니다 |
| 광고 제거권 | §4.4 |

5. 남길 계정 것을 그대로 씁니다: 프로필(사주 정보·호칭·설정), 약관 동의, 오늘 문장 선택 기록·변주 상태·반응. 없앨 계정의 이 행들은 그대로 두고 P8 익명화가 처리합니다.
6. 없앨 계정을 정리합니다.
   * 우리 세션을 모두 폐기합니다.
   * 멱등 키를 지웁니다(응답이 없앨 계정의 자원을 가리킴).
   * status를 `pending_deletion`(요청 시각 = 지금)으로 바꿉니다. 연결이 하나도 남지 않아 로그인으로 복구되지 않고, 30일 뒤 P8 익명화가 계정 삭제와 같이 처리합니다.
   * `account_merges`(`id`, `kept_account_id`, `removed_account_id`, `merged_at`)에 기록을 남깁니다. 문의 대응과 §4.4 webhook 처리에 씁니다.
7. 남길 계정에 새 refresh family를 만들고 토큰 쌍을 발급합니다. 남길 계정의 기존 세션은 그대로 둡니다.

commit한 뒤 허가 취소(4의 중복 연결)와 남길 계정의 결제 동기화(§4.4)를 시도합니다. 실패는 경고 로그만 남깁니다.

* **기기:** 기기 표는 아직 없습니다. 생기면(P8 `registerDevice`) 합치기에서 없앨 계정의 기기도 남길 계정으로 옮깁니다.
* **`Idempotency-Key`를 받지 않습니다.** 응답에 refresh token 원문이 있어 멱등 저장소(응답 본문을 저장)에 남기지 않습니다. 합치기 자체는 토큰이 일회용이라 두 번 일어나지 않습니다. 응답을 잃은 재시도는 422이고, app은 로그인 화면으로 가면 됩니다. 연결이 모두 남길 계정에 있어 어느 제공자로 로그인해도 남길 계정입니다(사용자 결정 2026-10-22).

### 4.4. 광고 제거권 (S103)

광고 제거권 행은 RevenueCat 구매 목록(고객 id = 계정 id)으로 다시 계산하므로, 없앨 계정의 행을 옮기면 남길 계정을 동기화할 때 취소됩니다. 그래서 행이 아니라 **구매**를 옮깁니다.

* 새 표 `merged_purchases`

| 열 | 타입 | 비고 |
| --- | --- | --- |
| `account_id` | uuid NOT NULL | 남길 계정, FK |
| `purchase_id` | text NOT NULL | RevenueCat 구매 id(= `entitlement_grants.source_ref`) |
| `product_id` | text NOT NULL | |
| `purchased_at` | timestamptz NOT NULL | |
| `production` | boolean NOT NULL | |
| `refunded` | boolean NOT NULL | |
| `from_account_id` | uuid NOT NULL | 없앤 계정, FK |
| | | PK `(account_id, purchase_id)` |

* 구매일·상품·환불 값은 권한 행에 없고 RevenueCat 구매 목록에만 있습니다. 그래서 없앨 계정에 광고 제거권 출처 행이나 `merged_purchases` 행이 하나라도 있으면, 합치기 트랜잭션 전에 없앨 계정의 구매 목록을 조회합니다. 조회가 실패하면 합치지 않고 503 `billing.provider_unavailable`이며 토큰도 소진하지 않습니다(다시 시도하면 됨). 남은 기간을 조용히 잃지 않게 하려는 것입니다. 어느 쪽이 없앨 계정인지는 요청의 `keep`으로 정해지므로 조회 대상도 그것으로 정합니다.
* 합치기 트랜잭션에서 조회한 목록 중 광고 제거권 상품 구매(동기화와 같은 상품·production 조건)와 없앨 계정의 `merged_purchases`를 남길 계정의 `merged_purchases`로 넣습니다(같은 구매 id는 한 행).
* 동기화(`Syncer.Sync`)는 RevenueCat 구매 목록과 그 계정의 `merged_purchases`를 구매 id로 중복을 없애고 합친 뒤 D61 규칙(`max(직전 만료일, 구매일) + 1개월`)으로 다시 이어 붙입니다. 같은 구매가 양쪽에 있으면 RevenueCat 쪽 값을 씁니다. 그래서 남은 기간이 더해지고, 나중에 구매 복원으로 RevenueCat이 그 구매를 남길 계정에 transfer해도 두 번 세지 않습니다.
* 옮긴 구매의 행은 출처 `ad_free_pass`, `source_ref` = 구매 id 그대로입니다. 같은 키의 행이 없앨 계정에 있으면 `UpsertGrant`가 남길 계정으로 옮깁니다(지금 transfer 처리).
* webhook이 없앤 계정(`account_merges.removed_account_id`)을 가리키면, 그 계정의 구매 목록으로 `merged_purchases`의 환불 값만 갱신하고 남길 계정을 동기화합니다. 없앤 계정 자신은 동기화(행 조정)하지 않습니다. 하면 행이 없앤 계정으로 되돌아가기 때문입니다.
* 보상형 광고 권한(그날 끝까지)과 구독(MVP 밖)은 옮기지 않습니다.

## 5. 오류 코드 (S104)

> 이 절은 2026-10-23 spec(`2026-10-23-account-delete-merge-purchases-design.md`) §8이 대체합니다.

| 상황 | 응답 |
| --- | --- |
| 제공자 증명이 틀림 | 401 `auth.provider_token_invalid`(기존) |
| 제공자 장애 | 503 `auth.provider_unavailable`(기존) |
| Android Apple 붙이기의 교환 코드 무효 | 401 `auth.exchange_invalid`(기존) |
| 현재 계정에 같은 제공자의 다른 사용자 연결이 있음 | 409 `auth.provider_taken` |
| 연결이 다른 active 계정에 있음 | 409 `auth.identity_in_use`(확장 필드 `mergeToken`·`expiresAt`) |
| 연결이 삭제 대기 계정에 있음 | 409 `auth.identity_pending_deletion` |
| 마지막 연결 떼기 | 409 `auth.last_identity` |
| 현재 계정에 없는 제공자 떼기 | 404 `auth.identity_not_found` |
| 합치기 토큰 무효, 또는 확인 시점에 조건이 바뀜 | 422 `merge.token_invalid` |
| 합치기 전 없앨 계정의 구매 목록 조회 실패 | 503 `billing.provider_unavailable`(기존, 토큰 소진 안 함) |

* 409·404·422에는 `errors[]`가 없습니다.
* 약관 동의 전에는 새 bearer operation이 모두 403 `consent.required`입니다(지금 규칙).

## 6. REST 계약 (draft.14)

* `info.version` `1.0.0-draft.14`. 모두 추가라 하위 호환입니다.
* 새 operation 7개: `loginLine`, `loginGoogle`, `listIdentities`, `linkIdentity`, `unlinkIdentity`, `previewMerge`, `mergeAccounts`
* 새 스키마: `LineLoginRequest`, `GoogleLoginRequest`, `Identity`, `IdentityList`, `LinkIdentityRequest`(필드 `idToken`·`authorizationCode`·`exchangeCode`는 선택, `nonce`만 필수. 제공자별 조합은 server가 검사해 어긋나면 400 `request.invalid`. 계약에 `additionalProperties: false`가 없어 oneOf로 나누면 Apple iOS 증명이 두 갈래에 다 맞으므로 쓰지 않음), `IdentityInUseProblem`(Problem + `mergeToken`·`expiresAt`), `MergePreviewRequest`, `MergePreview`, `MergeAccountSummary`, `MergeSaju`, `MergeRequest`, `MergeResult`, `LoginProvider` enum
* 계약 머리말에 nonce 규칙(네 제공자 공통, 일회용 기록 없음, Google 반복 가능)을 적습니다.

## 7. 계약 변경 알림

* app: `kind:request` Issue로 계약 차이, 붙이기 증명 모양(Android Apple 교환 코드), LINE·Google 허가 취소를 app SDK가 떼기·계정 삭제 직전에 함, 응답을 잃은 합치기는 로그인 화면으로 보냄을 알립니다.
* 지휘: #386에 진행 코멘트, D82 ⑤ 단서("LINE·Google은 app이 허가 취소하고, 그 기기에 제공자 token이 없으면 생략") 요청 Issue(`to:root`).
* 외부 준비물: LINE 로그인 채널 ID, Google OAuth client ID(iOS·web). 설정 이름 `LINE_CHANNEL_ID`·`GOOGLE_CLIENT_IDS`.

## 8. PR 나누기

1. **PR A (계약):** 이 spec, 계획, openapi draft.14, 새 operation 7개의 `Unimplemented` 501, 계약 테스트, problem code, 계약 표 REST 행, app Issue·지휘 Issue
2. **PR B (제공자·연결):** migration `00014`(provider CHECK·UNIQUE·`account_merge_tickets`), OIDC 검증 확장과 LINE·Google verifier, 로그인 2개, 연결 목록·붙이기·떼기와 409 `auth.identity_in_use`의 합치기 토큰 발급(계약의 409 본문이 토큰을 요구하므로 PR B에 둠), `DisconnectProviders` 확장
3. **PR C (합치기):** migration `00015`(`account_merges`·`merged_purchases`), `previewMerge`·`mergeAccounts`, billing 동기화 확장. `Closes #386`

## 9. 테스트

* provider: 가짜 JWKS에 ES256 키를 더함. LINE 서명·iss·aud, Google iss 두 형태, audience 목록 밖 거절, JWKS 장애 → `ErrUnavailable`, nonce 불일치
* 연결(testcontainers): 붙이기 201·200(Apple refresh token 갱신)·`provider_taken`·`identity_in_use`·`identity_pending_deletion`, 동시 붙이기 경합, 마지막 연결 떼기 거절, 떼기 commit 뒤 허가 취소 실패가 성공, LINE·Google 떼기는 외부 호출 없음, 계정 삭제의 LINE·Google 해제 기록
* 합치기: `keep` current·other, 겹치는 날 일기가 남길 계정 날짜 기록 아래로 모두 옮겨지고 10편을 넘어도 됨, 지운 일기·일정도 옮겨짐, 같은 제공자가 양쪽에 있음, 없앨 계정 세션 폐기·`pending_deletion`·멱등 키 삭제, 토큰 재사용·만료·남의 토큰 → 422, 같은 토큰 동시 두 번 → 한 번만 성공, preview는 소진하지 않음, 요약 값(사주 세 경우·일기 수·겹치는 날 수)
* billing: `merged_purchases`가 D61 체인에 들어가 남은 기간이 더해짐, transfer된 같은 구매 id를 두 번 세지 않음, 없앤 계정 webhook의 환불 반영
* HTTP: handler 오류 매핑, 조립 흐름(로그인 → 붙이기 409 → preview → merge → 다른 제공자로 로그인하면 남길 계정)

## 10. 결정

| 번호 | 내용 |
| --- | --- |
| S99 | LINE(ES256, iss `https://access.line.me`, aud channel ID)·Google(RS256, iss 두 형태, aud client ID 목록) id_token을 공용 OIDC 검증으로 확인합니다. nonce는 네 제공자 모두 `hex(SHA-256(원문))`이고 일회용으로 기록하지 않습니다(Google은 프로세스마다 nonce 하나) |
| S100 | 한 계정에 같은 제공자 연결은 하나(UNIQUE `(account_id, provider)`)입니다. `{provider}` 경로는 닫힌 enum이고 응답의 제공자 값(`LoginProvider`)은 열린 enum입니다. 떼기는 연결 행을 물리적으로 지우고 commit 뒤 허가 취소를 한 번 시도합니다(실패해도 성공). LINE·Google 허가 취소는 server가 아니라 app SDK가 하고, 그 기기에 제공자 token이 없으면 생략합니다(사용자 결정 2026-10-22, D82 ⑤ 단서 요청) |
| S101 | 합치기 토큰은 `linkIdentity`의 409 본문으로 주고, 해시만 저장하며 10분·일회용·bearer 계정에 묶입니다. 요약은 토큰을 소진하지 않는 `POST /v1/me/merge/preview`입니다(토큰을 URL에 넣지 않음, 사용자 선택 2026-10-22: 요약 조회 분리) |
| S102 | 합치기는 연결·일기(지운 것 포함, 상한 무시)·일정을 남길 계정으로 옮기고, 프로필·동의·문장 선택 기록은 남길 계정 것을 씁니다. 없앨 계정은 세션 폐기·멱등 키 삭제 뒤 `pending_deletion`으로 두어 P8이 익명화합니다. 삭제 대기 계정과는 합치지 않습니다. `Idempotency-Key`는 받지 않습니다(응답의 refresh token 원문을 저장하지 않음, 사용자 결정 2026-10-22) |
| S103 | 광고 제거권은 구매를 `merged_purchases`로 옮기고 동기화가 RevenueCat 목록과 합쳐 D61로 다시 이어 붙입니다(구매 id로 중복 제거). 없앤 계정의 webhook은 환불 값만 갱신하고 남길 계정을 동기화합니다 |
| S104 | 새 problem code: `auth.provider_taken`·`auth.identity_in_use`·`auth.identity_pending_deletion`·`auth.last_identity`(409), `auth.identity_not_found`(404), `merge.token_invalid`(422) |
