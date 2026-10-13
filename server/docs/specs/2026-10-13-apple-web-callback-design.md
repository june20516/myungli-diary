# Apple 웹 로그인 콜백 재설계 (Android) — spec

* 날짜: 2026-10-13
* 요청: Issue #89 (app→server, accepted), 지휘 검토 코멘트(토큰 URL 노출, 앱이 안 열릴 때 페이지, 도메인 미정)
* 기준: server spec §4.1, D55, app 결정 A12(App Link), RFC 8252
* 결정 번호: S22

## 1. 문제

지금 `appleCallback`은 Apple이 form_post로 보낸 `code`·`id_token`·`user`를 그대로 app deep link의 query에 붙여 303으로 넘깁니다. 그러면 세 가지 문제가 생깁니다.

1. App Link가 앱을 열지 못하고 브라우저로 떨어지면 토큰이 브라우저 기록과 접근 로그에 남습니다.
2. custom scheme을 쓰면 다른 앱이 같은 scheme을 등록해 가로챌 수 있습니다.
3. 앱이 열리지 않을 때 사용자가 볼 화면이 없습니다.

## 2. 결정: server가 콜백에서 교환하고, app에는 일회용 교환 코드만 넘깁니다

### 2.1. 흐름

1. **app → Apple:** app이 Apple authorize URL을 엽니다(`client_id`=Services ID, `redirect_uri`=server 콜백, `response_mode=form_post`, `response_type=code id_token`, `scope` 없음). 이때 `nonce`=SHA-256(원문) hex, `state`=app이 만든 무작위 값을 보냅니다. 카카오·iOS Apple과 같은 S15 규칙입니다.
2. **Apple → server (`POST /v1/auth/apple/callback`, form):**
   * `error`가 있으면(사용자 취소 등) 아래 4번의 실패 경로로 넘깁니다.
   * 없으면 다음을 합니다.
     1. `id_token`의 서명·iss·aud(Services ID)·exp를 검증합니다. nonce는 아직 확인하지 않습니다. 원문은 app에만 있기 때문입니다.
     2. `code`를 Apple `/auth/token`으로 교환하고, 응답 id_token의 sub가 같은지 대조합니다(기존 규칙).
     3. 결과를 `apple_web_logins`에 저장합니다. 저장 내용은 subject, id_token의 nonce claim, 암호화한 Apple refresh token과 키 id, client_id, 만료 시각입니다.
     4. 무작위 일회용 교환 코드(256비트, base64url)를 만들고 DB에는 SHA-256만 둡니다.
   * 303 `Location: <APP_LINK_BASE>/auth/apple?exchange=<교환 코드>&state=<state>`
3. **app (App Link로 열림):**
   * `state`가 자기가 만든 값과 같은지 확인합니다.
   * `POST /v1/auth/apple/web {exchangeCode, nonce(원문)}`를 부릅니다.
   * server는 교환 코드 해시로 행을 잠그고 다음을 확인합니다: 만료 전, 미사용, SHA-256(nonce 원문) hex == 저장한 nonce claim.
   * 확인을 통과하면 사용 표시를 하고, 기존 Apple 로그인 트랜잭션(계정 찾기·만들기·복구, 토큰 발급)을 그대로 실행합니다. 응답은 `loginApple`과 같은 `LoginResponse`입니다.
4. **실패 경로:**
   * 사용자 취소, Apple 오류, 검증 실패, 제공자 장애일 때는 303 `Location: <APP_LINK_BASE>/auth/apple?error=<값>&state=<state>`로 보냅니다.
   * `error` 값: `user_cancelled_authorize`(Apple 값 그대로), `token_invalid`, `provider_unavailable`, `invalid_request`, `server_error`(예상하지 못한 server 오류). Apple이 보낸 `error`는 `user_cancelled_authorize`만 그대로 넘기고 그 밖은 `invalid_request`로 바꿉니다.
   * `state`가 없으면 돌려보낼 곳이 없으므로 400 `request.invalid`입니다(지금과 같음).

### 2.2. 왜 안전한가

* URL에는 교환 코드와 state만 실립니다. 토큰은 server 밖으로 나가지 않습니다.
* 교환 코드를 가로채도 쓸 수 없습니다.
  * nonce 원문은 app 메모리에만 있고, 교환 코드만으로는 로그인할 수 없습니다.
  * 교환 코드는 일회용이고 짧게(2분) 삽니다.
* 그래서 App Link가 실패해 URL이 브라우저 기록에 남아도 피해가 없습니다.

### 2.3. 앱이 열리지 않을 때

* `<APP_LINK_BASE>/auth/apple`은 server가 내주는 `GET` 페이지입니다. App Link가 동작하면 OS가 앱을 열어 이 요청은 오지 않습니다.
* 요청이 오면, 앱이 없거나 링크 검증이 안 된 경우입니다. 이때 "앱에서 계속하기" 안내 HTML을 돌려줍니다.
  * Android intent 링크와 스토어 링크를 담고, 교환 코드는 그대로 intent에 넘깁니다.
  * 페이지는 query 값을 로그에 남기지 않고, `Referrer-Policy: no-referrer`, `Cache-Control: no-store`를 겁니다.
* 문구는 writing 슬롯이 필요합니다. 첫 구현은 고정 한국어 한 문장으로 하고, writing에 요청합니다.
* `/.well-known/assetlinks.json`도 server가 내줍니다. 값은 설정 `ANDROID_APP_PACKAGE`, `ANDROID_CERT_SHA256`(여러 개 가능)에서 만듭니다.

### 2.4. 계약 변경 (REST API v1)

* **새 operation `completeAppleWebLogin`:** `POST /v1/auth/apple/web`, 보안 없음(로그인 전), 요청 `{exchangeCode, nonce}`, 응답 200 `LoginResponse`.
  * 401 `auth.exchange_invalid`: 없음·만료·이미 씀·nonce 불일치를 구분하지 않습니다.
  * 503 `auth.provider_unavailable`는 해당 없음(교환은 콜백에서 끝남).
* **`appleCallback` 303 설명:** Location 형식을 위 2·4번으로 바꿉니다. `code`·`id_token`·`user`를 더는 넘기지 않습니다.
* **`loginApple`의 `clientType: web` 제거:** web은 새 operation만 씁니다. 하위 호환이 깨지는 변경입니다.
  * app의 실제 adapter가 아직 없으므로(A1은 대역) 영향은 계약 문서뿐입니다.
  * §5.1 절차를 따릅니다: notice, `info.version` `1.0.0-draft` → `1.0.0-draft.2`, 지휘에 계약 목록 갱신 요청.
* **새 code:** `auth.exchange_invalid`(401). `x-problem-codes`(#88)에 더합니다.
* **새 GET 경로 두 개:** `/auth/apple`(안내 HTML), `/.well-known/assetlinks.json`. 둘 다 계약 밖의 정적 응답이지만 라우트 표에 적습니다. `/v1` 밖이라 REST 계약에는 넣지 않습니다.

### 2.5. 저장

* 테이블 `apple_web_logins`: `id uuid PK`, `exchange_hash bytea UNIQUE NOT NULL`, `subject text NOT NULL`, `nonce_hash text NOT NULL`, `apple_refresh_token bytea NOT NULL`, `apple_token_key_id text NOT NULL`, `apple_client_id text NOT NULL`, `expires_at timestamptz NOT NULL`, `consumed_at timestamptz`, `created_at`.
* 암호화 aad는 이 행의 id입니다. 로그인 트랜잭션에서 identity로 옮길 때 identity id로 다시 암호화합니다.
* 만료되거나 쓰인 행의 정리는 P8 retention이 맡습니다(물리 삭제 예외에 추가).
* 교환 코드 TTL은 2분입니다. Apple code 교환은 콜백에서 끝나므로 Apple의 5분 제한과 상관없습니다.
* 콜백에서 교환까지 성공했지만 app이 2분 안에 오지 않은 경우: 행은 만료되고, 받은 Apple refresh token은 S19 규칙대로 처리합니다(연결 행이 없으면 revoke). 이 처리는 P8 retention이 만료 행을 정리할 때 합니다.

### 2.6. 설정 (추가)

`APP_LINK_BASE`(https URL, 필수, `APPLE_CALLBACK_DEEPLINK`를 대체), `ANDROID_APP_PACKAGE`, `ANDROID_CERT_SHA256`(쉼표 구분), `ANDROID_STORE_URL`. 도메인은 아직 없으므로(지휘 외부 준비물) 배포 전까지는 개발 값으로 둡니다.

## 3. 테스트 관점

* 정상 흐름: 콜백 → 303 Location에 교환 코드와 state만 있음(id_token·code 없음) → `completeAppleWebLogin` 200 → 같은 교환 코드를 다시 쓰면 401.
* nonce 원문이 틀리면 401이고, 그 교환 코드는 소진되지 않습니다. 맞는 nonce로 재시도하면 성공합니다(아래 4-1).
* 만료(2분+1초) → 401.
* 취소·검증 실패·제공자 장애는 `error` 값을 담아 303.
* 안내 페이지와 assetlinks.json의 헤더와 내용, 로그에 query가 없음.
* e2e: Android Apple 흐름 전체, 기존 iOS(native) 흐름은 그대로.

## 4. 정한 점 (2026-10-13 사용자 승인)

1. **nonce가 틀려도 교환 코드를 소진하지 않습니다.** 소진하면 코드를 가로챈 쪽이 한 번 틀리게 시도하는 것만으로 정상 사용자의 로그인을 망칠 수 있습니다. 소진하지 않아도 nonce 원문(16자 이상 무작위)을 2분 안에 맞히는 것은 사실상 불가능합니다.
2. 안내 페이지 문구는 첫 구현에서 고정 한국어 한 문장으로 두고, writing에 슬롯을 요청합니다.
3. `loginApple`의 `clientType: web` 제거는 하위 호환이 깨지므로 `info.version`을 `1.0.0-draft.2`로 올리고, app에 notice, 지휘에 계약 목록 갱신을 요청합니다.
