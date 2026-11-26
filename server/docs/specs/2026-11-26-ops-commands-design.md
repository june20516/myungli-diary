# 운영 API: 계정 조회, 권한 부여와 회수, 콘텐츠 열람, 감사 기록 (#1321, D145 ⑦)

> 2026-11-26 개정: 처음 안(운영자 컴퓨터에서 운영자 본인의 Cloud SQL IAM 사용자로 DB에 붙음, PR #1381 첫 판)은 사람이 `psql`로 감사 없이 표를 읽고 쓰는 길이 되어(#1381 보안 점검 High) 쓰지 않습니다. 사용자 결정 D145 ⑦로 **IAP로 막은 내부 운영 API**로 바꿉니다. 조회, 부여와 회수, 열람, 감사 표와 trigger, retention 로직은 첫 판을 그대로 쓰고 접속 부분과 보안 점검의 나머지 지적을 고칩니다.

## 1. 목적

출시 뒤 사용자 지원(결제 반영 누락, 환불 대응, 오류 문의)과 장애, 정책 위반, 법령 요청에 대응할 때 **prod DB에 사람이 붙지 않고** 정해진 운영 API로만 데이터를 보고 고칩니다. 모든 호출은 감사 기록을 남깁니다. 출시 뒤 어드민 웹(D145 ③)도 같은 API를 씁니다.

성공 기준:
* 문의 메일의 계정 id 하나로 지원에 필요한 상태(가입, 로그인 수단, 최근 접속, 권한, 구매)를 한 번에 봅니다.
* 광고 제거권과 근거 열람을 기간을 정해 주고, 운영자가 준 것과 보상 광고 권한을 거둡니다.
* 일기, 일정, 프로필을 목적과 사유를 밝히고 좁혀서 열람하며, 본문은 HTTPS 응답으로만 갑니다.
* 모든 조회, 변경, 열람이 언제, 누가(IAP가 확인한 Google 계정), 무엇을, 왜, 전후 값과 함께 고칠 수 없는 표에 남습니다.
* **사람 DB 계정이 없습니다.** DB에는 운영 API의 서비스 계정만 붙습니다.
* 앱 런타임과 앱 사용자는 운영 API에 닿지 못합니다.
* app에 나가는 계약(REST v1)은 바뀌지 않습니다.

## 2. 확인한 사실

| 사실 | 출처 |
| --- | --- |
| Cloud Run에 IAP를 직접 켤 수 있습니다(로드밸런서 없음). gcloud `--iap`, Terraform `google_cloud_run_v2_service`의 `iap_enabled = true`. IAP는 `run.app` 주소를 포함한 모든 진입 경로에 적용됩니다. | Cloud Run 문서 "Configure IAP for Cloud Run" |
| 켤 때 IAP 서비스 에이전트 `service-<프로젝트 번호>@gcp-sa-iap.iam.gserviceaccount.com`에 `roles/run.invoker`가 필요합니다. 사용자 접근은 `roles/iap.httpsResourceAccessor`이고 문서의 바인딩 예시는 서비스 단위(`gcloud iap web add-iam-policy-binding ... --resource-type=cloud-run --service=<서비스>`)입니다. | 같은 문서 |
| 같은 서비스에 로드밸런서 IAP와 서비스 IAP를 함께 둘 수 없습니다. | 같은 문서 Known limitations |
| IAP는 앱에 서명된 헤더 `x-goog-iap-jwt-assertion`을 넘깁니다. ES256, 공개키 `https://www.gstatic.com/iap/verify/public_key-jwk`(키 교체가 있어 캐시 갱신), `iss`는 `https://cloud.google.com/iap`, Cloud Run 직접 IAP의 `aud`는 `/projects/<프로젝트 번호>/locations/<리전>/services/<서비스 이름>`, 사용자는 `email`과 `sub` 클레임입니다. `x-goog-authenticated-user-email` 헤더 대신 이 JWT를 검증하라고 권합니다. | IAP 문서 "Securing your app with signed headers" |
| 사람 계정으로 프로그램에서 IAP 뒤를 부르려면 데스크톱 OAuth 클라이언트로 받은 OAuth ID token을 `Authorization: Bearer`(앱이 Authorization을 쓰면 `Proxy-Authorization`)로 보냅니다. 그 클라이언트는 IAP 설정 `programmatic_clients`에 넣어야 하고(`gcloud iap settings set`), Google 관리 기본 클라이언트로는 안 됩니다. 이 방식이 Cloud Run 직접 IAP에서 사람 계정으로 되는지는 문서에 명시가 없어 staging spike(Task 0)로 확인했습니다(아래 행). | IAP 문서 "Programmatic authentication" |
| **spike 결과(staging, 2026-11-26):** Cloud Run 직접 IAP에서 사람 계정의 CLI 접근이 됩니다. 데스크톱 OAuth 클라이언트로 루프백 로그인(PKCE)해 받은 OAuth ID token(`aud`는 그 데스크톱 클라이언트 id, `email_verified` 참)을 `Authorization: Bearer`와 `Proxy-Authorization: Bearer` 어느 쪽으로 보내도 200입니다. 조건은 그 클라이언트가 `programmatic_clients`에 있는 것입니다. refresh token으로 다시 로그인하지 않고 ID token을 받습니다. | #1321 spike 기록 |
| 운영자 계정이 프로젝트의 조직 밖(gmail)이면 IAP의 Google 관리 OAuth 클라이언트로는 브라우저 로그인이 거절됩니다. 조직 밖 사용자를 넣으려면 OAuth 동의 화면을 외부(External)로 두고 맞춤 OAuth 클라이언트를 IAP 설정 `access_settings.oauth_settings.client_id`, `client_secret`에 지정해야 합니다. staging은 spike 때 이렇게 해서 브라우저 로그인을 확인했습니다. | Cloud Run 문서 "Configure IAP for Cloud Run" https://docs.cloud.google.com/run/docs/securing/identity-aware-proxy-cloud-run, #1321 spike 기록 |
| IAP 서비스 에이전트가 프로젝트에 없으면 `gcloud services identity create --service=iap.googleapis.com --project=<프로젝트>`로 만듭니다. | IAP 문서 "Enable IAP for Cloud Run" https://docs.cloud.google.com/iap/docs/enabling-cloud-run |
| 서비스 계정 토큰 발급(`iamcredentials.googleapis.com`의 `GenerateAccessToken`, `GenerateIdToken`, `SignBlob`, `SignJwt`)은 **데이터 접근 감사 로그**(`DATA_READ`)이고 관리 활동 로그가 아닙니다. 이 서비스만 따로 켤 수 없고 IAM API(`iam.googleapis.com`)나 모든 서비스의 데이터 접근 로그를 켜야 남습니다. 데이터 접근 로그는 BigQuery 일부 말고는 기본으로 꺼져 있습니다. | IAM 문서 "Service Account Credentials audit logging" https://docs.cloud.google.com/iam/docs/audit-logging/audit-logging-iamcreds, Logging 문서 "Enable Data Access audit logs" https://docs.cloud.google.com/logging/docs/audit/configure-data-access |
| 서비스 계정 키 만들기(`CreateServiceAccountKey`, `UploadServiceAccountKey`)와 IAM 정책 바꾸기는 관리 활동 로그(항상 켜짐)입니다. Cloud SQL 연결(`cloudsql.instances.connect`)도 관리 활동이고, IAM DB 로그인(`cloudsql.instances.login`)과 Cloud SQL 사용자 만들기, 고치기, 지우기(`cloudsql.users.*`)는 데이터 접근(`DATA_WRITE`)입니다. | IAM 문서 "IAM audit logging" https://docs.cloud.google.com/iam/docs/audit-logging, Cloud SQL 문서 "Cloud SQL audit logging" https://docs.cloud.google.com/sql/docs/postgres/audit-logging |
| IAP 데이터 접근 감사 로그(`iap.googleapis.com`)는 실행자 메일(`principalEmail`, 인증 안 된 요청은 없음), 요청 IP(`callerIp`), 요청 메서드와 URL(`requestMetadata.requestAttributes`), 대상 자원, 허용 여부(`authorizationInfo.granted`)를 남깁니다. 문서의 항목에 요청 본문과 헤더는 없습니다. URL의 query를 빼는지는 문서에 없으므로, 운영 API는 URL에 값을 두지 않는 규칙(§3.3)으로 막습니다. | IAP 문서 "IAP audit logging" https://docs.cloud.google.com/iap/docs/audit-log-howto |
| Cloud Run 요청 로그(플랫폼이 남기는 `httpRequest`)는 요청 URL을 query까지 남깁니다. server `accessLog`는 등록 패턴(route)만 남깁니다. 그래서 사유, 목적, 날짜, 거래 id를 URL에 두면 Cloud Logging에 90일 남습니다(S164). | Cloud Run 요청 로그 형식, `internal/httpapi/middleware.go` |
| 요청 로그(`accessLog`)에는 계정 id가 없어 계정별로 찾을 수 없고, 앱 버전은 저장하지 않습니다. 최근 접속 흔적은 `accounts.last_active_at`과 `devices.last_seen_at`(플랫폼 포함)뿐입니다. | `internal/httpapi/middleware.go`, `db/migrations/00002`, `00020` |
| 런타임 계정은 `myungli_app` 역할의 구성원으로만 표에 닿고, migrate가 `DB_RUNTIME_USER`로 구성원을 지정합니다(S137). | `db/migrations/00024_app_role.sql`, `internal/cli/cli.go` |
| 권한 출처 DB 값은 `ad_free_pass`, `rewarded_ad`, `subscription`, `test_grant`이고 취소는 `revoked_at`입니다. 광고 제거권 구간은 구매 장부에서 다시 잇기로 만들어집니다. 계약 `Insight.source`는 셋이고 staging `test_grant`는 `ad_free_pass`로 보냅니다(S125). | `00012`, `00022`, `internal/billing/ledger.go`, `api/openapi.yaml` |
| 계정 삭제는 즉시 익명화이고 `accounts.status`는 `active`, `deleted`뿐입니다(S105). | `db/migrations` |
| Cloud Run의 Secret을 볼륨으로 마운트하면 읽을 때마다 Secret Manager에서 값을 가져와 버전 `latest`가 쓰입니다("When reading a volume, Cloud Run always fetches the secret value from the Secret Manager to use the value with the latest version"). 환경 변수는 인스턴스 시작 때 한 번 정해집니다. 반영 지연이나 캐시는 문서에 없습니다. `/dev`, `/proc`, `/sys` 아래에는 마운트할 수 없고 한 경로에 secret 하나입니다. 그래서 운영자 목록은 볼륨(`latest`)으로 붙이고 ops-serve가 1분 TTL로 다시 읽습니다(지휘 2차 감사 M1, 2026-11-26 확인). | Cloud Run 문서 "Configure secrets for services" https://docs.cloud.google.com/run/docs/configuring/services/secrets |
| Cloud SQL for PostgreSQL의 기본 사용자는 `postgres`(`cloudsqlsuperuser` 구성원, `CREATEROLE`, `CREATEDB`, `LOGIN`)이고, Cloud SQL로 만든 IAM이 아닌 사용자는 `cloudsqlsuperuser`에 속합니다. 시스템 role은 `cloudsqliamgroup`, `cloudsqlinactiveuser`, `cloudsqliamgroupserviceaccount`, `cloudsqliamgroupuser`, `cloudsqliamserviceaccount`, `cloudsqliamuser`, `cloudsqlsuperuser`, 시스템 사용자는 `cloudsqladmin`, `cloudsqlagent`, `cloudsqlconnpooladmin`, `cloudsqlimportexport`, `cloudsqllogical`, `cloudsqlobservability`, `cloudsqlreplica`입니다. 문서는 role마다 로그인 가능 여부를 밝히지 않아 둘 다 로그인 role 검사의 허용 이름으로 둡니다(2026-11-26 확인). | Cloud SQL 문서 "About PostgreSQL users and roles" https://docs.cloud.google.com/sql/docs/postgres/users |
| staging과 prod의 Cloud SQL 사용자는 `postgres`(BUILT_IN), `server-migrator`, `server-runtime`뿐이고 `server-ops`는 이 작업의 배포로 생깁니다(2026-11-26 지휘 확인). | #1321 진행 기록 |
| `roles/cloudsql.editor`의 사용자 관련 권한은 `cloudsql.users.get`, `cloudsql.users.list`뿐이라 DB 사용자를 만들 수 없습니다. 세 프로젝트 모두 커스텀 역할이 없고, deployer는 역할 정의를 읽을 권한이 없습니다. 조직 정책에는 사람 소유자만 있고 폴더는 없습니다(2026-11-26 지휘 확인). | `gcloud iam roles describe`, #1321 진행 기록 |
| 사용자가 Google 계정의 연결된 앱 페이지(https://myaccount.google.com/linkedapps)에서 앱의 "Remove access"를 고르면 그 앱은 계정에 접근할 수 없고, 사용자가 앱 접근을 거두면 refresh token이 더는 쓰이지 않습니다. OAuth 클라이언트는 secret을 둘까지 둘 수 있고 "Add Secret"으로 새로 만든 뒤 옛 secret을 "Disable"하면 OAuth 흐름에서 거절되며, 클라이언트를 지우면 그 클라이언트의 access token과 refresh token 호출이 실패합니다. secret 사용 중지가 이미 발급된 refresh token을 막는지는 문서에 명시가 없습니다(refresh 요청에 secret이 들어가므로 막힐 것으로 보지만 확인 안 함). | Google 계정 도움말 https://support.google.com/accounts/answer/13533235, Google OAuth 2.0 문서 "Refresh token expiration" https://developers.google.com/identity/protocols/oauth2, Google Cloud 도움말 "Manage OAuth clients" https://support.google.com/cloud/answer/15549257 |

## 3. 실행 방식

### 3.1 운영 API 서비스

* **별도 Cloud Run 서비스 `server-ops`**를 둡니다. 이미지는 server와 같고 명령만 `server ops-serve`입니다. IAP는 서비스 단위로 켜지므로, 앱이 쓰는 공개 서비스 `server`와 나눠야 운영 API만 막을 수 있습니다.
  * `iap_enabled = true`, `ingress = INGRESS_TRAFFIC_ALL`(IAP가 앞에서 막음), `allUsers` invoker 없음, IAP 서비스 에이전트에만 `roles/run.invoker`.
  * 최소 인스턴스 0, 요청을 처리하는 동안에만 CPU(D135 비용 원칙, S163).
* **서비스 계정 `server-ops`**(새로 만듦). Cloud SQL IAM 서비스 계정 사용자로 DB에 붙고 `myungli_ops` 역할의 구성원입니다. `roles/cloudsql.client`, `roles/cloudsql.instanceUser`만 가집니다. 엔진, FCM, Secret(아래 하나 말고) 권한이 없습니다.
* **앱 런타임과 분리:**
  * `server serve`는 운영 경로를 등록하지 않고, `server ops-serve`는 앱 경로를 등록하지 않습니다(두 라우터를 따로 만들고 테스트로 확인).
  * 런타임 서비스 계정 `server-runtime`은 `myungli_ops` 구성원이 아니어야 하고, `server-ops`는 `myungli_app` 구성원이 아니어야 합니다. migrate가 배포마다, `ops-serve`가 기동할 때마다 확인하고 어긋나면 배포나 기동을 멈춥니다(#1381 점검 Medium 3, 지휘 2차 감사 L8).
  * 앱 런타임에는 `server-ops` 호출 권한(IAP 접근, run.invoker)이 없습니다.
* **사람 DB 계정은 만들지 않습니다.** 첫 판의 사람 IAM 사용자 자동 편입(`GrantOpsRole`)은 지웁니다. migrate는 `DB_OPS_USER`(ops 서비스 계정의 DB 사용자 이름, 비밀 아님, Terraform이 넘김)를 `myungli_ops` 구성원으로 지정하고, 그 밖의 `myungli_ops` 구성원이 있으면 실패합니다.
* **로그인 가능한 role 전체 검사(지휘 2차 감사 M2, L8):** `gcloud sql users create`로 만든 사용자는 `cloudsqlsuperuser`가 되어 `myungli_ops` 없이 표를 읽으므로, 구성원 검사만으로는 사람 DB 계정을 잡지 못합니다. `postgres.CheckLoginRoles`가 `pg_roles`의 `rolcanlogin` 전체를 열거해 예상 집합(migrator, `DB_RUNTIME_USER`, `DB_OPS_USER`, 현재 접속 사용자, Cloud SQL 기본 `postgres`, §2의 Cloud SQL 시스템 role 이름) 밖이 있으면 `ErrUnexpectedLoginRole`(이름 없이 개수만)로 실패합니다. 시스템 role은 이름이 정확히 같을 때만 허용하고 접두로 허용하지 않습니다. migrate(배포마다)와 `ops-serve` 기동이 이 검사와 역할 분리 검사를 돌립니다. `ops-serve`는 Terraform이 넘기는 `DB_MIGRATOR_USER`, `DB_RUNTIME_USER`, `DB_OPS_USER`를 쓰고, 배포 환경에서는 셋이 필수입니다. `pg_roles`, `pg_auth_members`, `pg_has_role`은 superuser가 아닌 `server-ops` 사용자로도 읽고 부를 수 있습니다(PostgreSQL 17 컨테이너에서 `SET ROLE`로 시험).

### 3.2 운영자 인증과 허용 목록

두 겹으로 막습니다.
1. **IAP 접근 주체:** 운영자 Google 계정에 `server-ops` 서비스의 `roles/iap.httpsResourceAccessor`를 줍니다. 운영자 메일은 개인정보라 저장소 tfvars와 CI 로그에 둘 수 없으므로(env는 CI가 apply) runbook의 `gcloud iap web add-iam-policy-binding` 명령으로 사람이 줍니다. Terraform은 이 서비스의 IAP IAM 정책을 관리하지 않습니다(덮어쓰지 않게).
2. **API 안의 허용 목록:** Secret Manager `OPS_OPERATORS`(쉼표로 나눈 메일, 운영자 메일은 여기에만)를 `server-ops`만 읽습니다. IAP 바인딩이 실수로 넓어져도(프로젝트 단위 부여 등) 목록 밖 계정은 API가 403으로 거절합니다. 값이 비어 있으면 모든 요청을 거절합니다.
   * **다시 읽기(지휘 2차 감사 M1):** 환경 변수 Secret은 기동 때 한 번만 읽혀, 운영자를 빼도 떠 있는 인스턴스가 옛 목록을 씁니다. 그래서 배포 workflow가 Secret을 볼륨(버전 `latest`)으로 `OPS_OPERATORS_FILE`(`/secrets/ops/operators`) 경로에 붙이고, `opsapi.FileOperators`가 1분(TTL)마다 파일을 다시 읽습니다(§2). 운영자 빼기는 1분 뒤 떠 있는 인스턴스에도 반영되고 재배포가 필요 없습니다.
   * **fail-closed:** 파일을 읽지 못하면(없음, 64 KiB 초과) 마지막 목록을 쓰지 않고 503 `unavailable`로 거절하며, 로그에는 kind(`operators_unavailable`)만 남깁니다. 403이 아니라 503인 것은 권한 판단이 아니라 서버 쪽 문제임을 알리려는 것입니다. 실패는 캐시하지 않습니다. 기동 때도 한 번 읽어 마운트 설정 오류면 뜨지 않습니다.
   * 배포 환경은 `OPS_OPERATORS_FILE`만 받고 `OPS_OPERATORS` 환경 변수가 있으면 기동하지 않습니다. local은 둘 중 하나만 씁니다.

요청마다:
* `x-goog-iap-jwt-assertion`을 검증합니다(ES256, 공개키 캐시와 `kid`, `iss`, 위 `aud`, `exp`, `iat`). `aud`의 프로젝트 번호, 리전, 서비스 이름은 Terraform이 env로 넘깁니다. 헤더가 없거나 검증에 실패하면 401입니다. `x-goog-authenticated-user-email` 헤더는 쓰지 않습니다.
* 실행자(`Actor`)는 검증한 JWT의 `email`(소문자로 정규화)이고, 감사 기록 `actor`에 남깁니다. `sub`는 감사 칸 `actor_sub`에 따로 남깁니다(메일이 바뀌어도 같은 사람을 찾게).
* 허용 목록 밖으로 거절한 요청은 `ops_audit`에 `denied`(§5)로 남깁니다(지휘 2차 감사 L2). IAP 실패(401)와 CSRF 거절(403)은 신원이 없거나 형식 문제라 남기지 않습니다.
* 콘텐츠 열람 세 경로(`content:diary`, `content:schedule`, `content:profile`)는 합쳐서 운영자(`sub`)마다 1분에 30건까지이고, 넘으면 429 `rate_limited`입니다(지휘 2차 감사 L5). 상한은 인스턴스 메모리 기준이라 인스턴스 둘(`max_instance_count`)이면 많아야 60건입니다. 대량 열람을 늦추는 장치이고, 로그 기반 알림은 deployer에 logging 설정 권한이 없어 두지 않았습니다.
* `OPS_DEV_IDENTITY`(local 고정 신원)는 `APP_ENV`가 local이 아니거나 Cloud Run이 넣는 `K_SERVICE`가 있으면 기동 실패입니다(지휘 2차 감사 L6).

### 3.3 API 모양

* 경로는 `/ops/v1/...` 아래이고 **모두 `POST`와 JSON 본문**입니다. 사유, 목적, 날짜, 계정 id, 거래 id가 URL에 들어가지 않게 해서 Cloud Run 요청 로그에는 경로만 남깁니다(§2, S164).
  * `POST /ops/v1/accounts:show` `{accountId | storeTransaction, reason}`
  * `POST /ops/v1/grants` `{accountId, entitlement, days | until, reason}`
  * `POST /ops/v1/grants:revoke` `{accountId, grantId, reason}`
  * `POST /ops/v1/content:diary` `{accountId, date | id, purpose, reason}`, `content:schedule`, `content:profile`
  * `POST /ops/v1/audit:list` `{accountId | since, limit, reason}`
* 응답은 Service 결과 타입의 JSON(첫 판의 camelCase 태그 그대로)입니다. 오류는 `{"code": "...", "message": "..."}`와 상태 코드(400 입력, 401 인증, 403 허용 목록과 CSRF 검사, 404 계정이나 프로필 없음, 405 POST 밖, 409 회수 불가, 이미 끝남, 지운 계정 부여, 모호한 거래 조회, 413 본문 64 KiB 초과(`invalid_input`, 인증과 허용 목록 뒤 본문을 읽을 때), 429 콘텐츠 열람 상한(`rate_limited`), 503 IAP 공개키나 운영자 목록을 구할 수 없음, 500)입니다. 응답에 `Cache-Control: no-store`.
* 요청 본문 상한 64 KiB. 응답 본문과 요청 본문은 로그에 남기지 않습니다(`accessLog`는 route, status, latency만).
* 운영 API 계약은 지금 server 안에 둡니다(어드민 웹이 생길 때 web과의 계약 파일로 올립니다).

### 3.4 CLI

* `server ops <하위 명령>`은 이제 DB에 붙지 않고 운영 API를 부르는 클라이언트입니다. 인자, 출력(표와 `--json`, 터미널 제어문자 치환), 종료 코드는 첫 판 그대로입니다.
* 인증: 데스크톱 OAuth 클라이언트로 브라우저 로그인(루프백 리디렉션) 한 번 뒤 받은 refresh token으로 ID token을 얻어 `Authorization: Bearer`로 보냅니다. 클라이언트 id와 secret, refresh token은 로컬 값(D98) `server/<환경>/ops-oauth.json`(600)에만 둡니다. 운영 API 주소도 같은 파일에 둡니다.
* **spike(Task 0) 결과:** 됩니다(§2). 그래서 CLI 경로로 구현했습니다. `server ops login --env <환경> --api-url <주소>`가 로컬 값 `ops-oauth-client.json`(Google 콘솔에서 내려받은 데스크톱 OAuth 클라이언트)을 읽어 로그인하고 `ops-oauth.json`(600, `apiUrl`, `clientId`, `clientSecret`, `refreshToken`)을 씁니다. 다른 명령은 `--env`로 그 파일을 쓰고, 호출마다 refresh token으로 ID token을 받습니다.
* **브라우저 경로는 열지 않습니다.** 운영 API는 사용자 정의 헤더 `X-Myungli-Ops: 1`과 JSON `Content-Type`을 요구하고, `Origin` 헤더가 있거나 `Sec-Fetch-Site`가 `none`이 아니면 403으로 거절합니다(쿠키로 인증된 브라우저 요청을 막음, 지휘 검토 2). 어드민 웹을 만들 때 CSRF 방어를 다시 설계합니다.

## 4. 기능

공통: `accountId`(대상), `reason`(필수, 앞뒤 공백을 뗀 뒤 1~500자). 사유에 `\n`, `\r`, U+0085, U+2028, U+2029, NUL, 잘못된 UTF-8, **`@`**, **7자리 이상 숫자열**이 있으면 거절합니다. 숫자열은 숫자와 그 사이의 하이픈, 공백, 괄호, `+`를 이어서 세므로(전각 숫자 포함) 전화번호 형태(`010-1234-5678`, `(02) 123 4567`, `+82 10 ...`)도 걸리고, `#`, 점, 글자는 구간을 끊습니다(지휘 2차 감사 L3). 하이픈으로 이은 날짜(`2026-11-26`)도 8자리라 거절되므로 날짜는 점으로 씁니다. 사유는 2년 보관되므로 이름이나 메일 같은 개인정보를 쓰지 않고 문의 번호나 Issue 번호만 적습니다(예 `문의 #1234`, `Issue #1321`, runbook에 명시, #1381 점검 Medium 4).

### 4.1 계정 조회 `accounts:show`

`accountId` 또는 `storeTransaction` 중 하나. `storeTransaction`은 1~128자, `[A-Za-z0-9._-]`만 허용합니다(#1381 점검 Medium 4).

보이는 것(첫 판과 같음):
* 계정: 상태(`active`, `deleted`), 가입 시각, 삭제 시각, 최근 활동
* 로그인 수단: 제공자 종류와 연결 시각(subject와 토큰 없음)
* 기기: 플랫폼, 활성 여부, 등록 시각, 마지막 접속(token 없음)
* 권한: 지금 상태와 부여 행 전부
* 구매 장부: 상품, 스토어, 스토어 거래 id, 구매 시각, 환불 시각, 환경, 합치기로 옮겨 온 구매인지

보이지 않는 것: 호칭, 출생 정보, 일기와 일정 본문, 메일 주소(저장하지 않음). 최근 접속은 위 두 시각뿐입니다(요청 로그에는 계정 id가 없음, D145 ⑤ 보충).

### 4.2 권한 부여 `grants`

`entitlement` `ad_free|insight`, 기간은 `days`(1~366) 또는 `until`(RFC 3339) 중 하나. 첫 판과 같습니다: `ad_free`는 두 행, 출처 `operator`, `source_ref`는 감사 기록 id, 지운 계정 거절, 계약은 S125처럼 `ad_free_pass`/`rewarded_ad`로 보냄. 기간 기준 시각은 트랜잭션 안 DB `now()`입니다.

### 4.3 권한 회수 `grants:revoke`

`grantId`. 거둘 수 있는 출처는 `operator`, `rewarded_ad`(묶음은 함께)이고 `ad_free_pass`는 거절합니다(스토어 환불로). 첫 판과 같습니다.

### 4.4 콘텐츠 열람 `content:diary|schedule|profile`

`purpose` `inquiry|incident|policy|legal` 필수. 일기와 일정은 `date` 또는 `id`, 프로필은 계정 하나. 계정 전체 내보내기와 날짜 범위는 없습니다. 목적별로 언제 열어도 되는지는 이 문서와 runbook에 적지 않습니다(D145 ⑤⑥). 첫 판과 같습니다.

## 5. 감사 기록

### 5.1 표 `ops_audit`

첫 판의 칸을 그대로 쓰되 실행자와 경로가 바뀝니다.

| 칸 | 뜻 |
| --- | --- |
| `id` uuid | 기록 id. 부여 행의 `source_ref`로도 씀 |
| `at` timestamptz | 실행 시각. `BEFORE INSERT` trigger가 DB `now()`로 정함 |
| `actor` text | 실행자. 운영 API가 검증한 IAP JWT의 `email`(소문자) |
| `actor_sub` text | 실행자의 IAP `sub`. 메일이 바뀌어도 같은 사람을 찾기 위해 따로 둠 |
| `channel` text | `ops_api` 하나(CHECK). CLI와 어드민 웹 모두 이 API를 거침 |
| `action` text | `account_show`, `grant`, `revoke`, `content_view`, `audit_list`, `denied`(허용 목록 밖 거절) |
| `account_id` uuid | 대상 계정(못 찾으면 NULL, `denied`는 언제나 NULL) |
| `purpose` text | 열람 목적(`content_view`만 필수) |
| `reason` text | 사유 |
| `target` jsonb | 무엇을. 열람은 `accountId`, 연 항목 id, 개수만. `denied`는 `{"route": "<등록 경로>"}` |
| `before`, `after` jsonb | 부여와 회수의 전후 값(`denied`는 NULL, CHECK `ops_audit_denied_shape`) |

### 5.2 기록 규칙

* **실행자 신뢰 경계:** 사람 DB 계정이 없으므로 `ops_audit`에 행을 넣을 수 있는 것은 `server-ops` 서비스 계정(`myungli_ops`)뿐입니다. 실행자 값은 그 서비스가 IAP JWT를 검증해 넣습니다. trigger는 `at`을 `now()`로 덮고 `channel`이 `ops_api`가 아니면 거절합니다. `actor`는 덮지 않습니다(`session_user`는 서비스 계정이라 사람을 가리키지 않음).
* **조회와 열람도 기록, 기록이 먼저, 실패하면 결과 없음:** 첫 판과 같습니다.
* **거절은 허용 목록 밖만 기록:** IAP 검증을 통과했지만 허용 목록 밖이라 403인 요청은 `RecordDenied`가 `denied` 행(실행자 메일, `sub`, 경로, 고정 사유 "허용 목록 밖 운영자의 요청(자동 기록)")을 따로 트랜잭션으로 남깁니다. 본문은 읽지 않으므로 대상 계정과 사유가 없습니다. 기록이 실패해도 응답은 403 그대로이고 로그에는 kind만 남깁니다. 입력 오류, 401, CSRF 403, 429는 기록하지 않습니다. `denied` 행은 계정이 없어 `audit:list`의 `since` 조건으로 봅니다.
* **고칠 수 없음:** `myungli_ops`는 `ops_audit`에 INSERT와 SELECT만, `myungli_app`은 retention용 DELETE와 그 조건이 쓰는 `at` 칸 SELECT만(UPDATE, INSERT, 다른 칸 SELECT 없음, 00024 기본 권한이 준 표 단위 SELECT를 거둠). trigger가 UPDATE와 TRUNCATE를 언제나, DELETE는 2년 안의 행을 거절합니다.
* **`migrate down`이 감사 기록을 지우지 않음:** 00029의 Down은 `ops_audit`과 그 trigger를 남기고 역할 권한만 거둡니다. Up은 이미 있는 표를 그대로 씁니다(#1381 점검 Low 5).
* **보관 2년, 합치기와 계정 삭제:** 첫 판과 같습니다.

## 6. 권한 범위 (`myungli_ops`)

구성원은 `server-ops` 서비스 계정 하나입니다.
* `accounts`, `entitlement_grants`, `purchases`, `diaries`, `diary_days`, `schedules`의 SELECT, `auth_identities`, `devices`, `profiles`는 쿼리가 쓰는 칸만 SELECT(subject, 토큰, 알림 token과 해시, 출생 정보 해시, 알림 설정 제외).
* `entitlement_grants` INSERT와 `revoked_at` UPDATE, sequence USAGE.
* `accounts.updated_at` UPDATE: 부여가 계정 행을 `FOR SHARE`로 잠그는 데 PostgreSQL이 UPDATE 권한을 요구해서입니다. 사람이 쓸 수 없으므로 점검 Low 7의 위험(사람이 임의 갱신)은 없어집니다.
* `ops_audit` INSERT와 SELECT.

**SECURITY DEFINER로 옮기지 않는 이유:** 점검 High와 Low 1, 3은 사람이 이 역할로 직접 SQL을 쓸 수 있다는 전제였습니다. 이제 구성원이 운영 API 서비스 계정 하나라, 그 계정의 쓰기 범위(권한 행 넣기와 회수)는 런타임 계정이 이미 가진 범위(결제 동기화가 권한 행을 쓰고 고침)보다 넓지 않습니다. 서비스 계정 탈취는 런타임 탈취와 같은 등급의 위험으로 보고, 출처와 회수 대상 검사는 Service 코드와 테스트가 맡습니다.

## 7. 구조

```
internal/ops/               핵심 함수(첫 판 그대로, Actor.Channel은 ops_api)
internal/opsapi/            운영 API: 라우터, IAP JWT 검증, 허용 목록, 요청과 응답 JSON
  iap.go                    서명 헤더 검증(공개키 캐시), Identity{Email, Subject}
  router.go                 /ops/v1/* 등록(ops-serve 전용)
  handlers.go               요청 해석과 검증, Service 호출, 오류 매핑
  allowlist.go              허용 목록, 운영자 목록 원천(고정 목록, Secret 볼륨 파일 TTL 1분)
  ratelimit.go              콘텐츠 열람 상한(운영자 sub별 분당 30건, 인스턴스 메모리)
internal/cli/ops.go         CLI: 인자 해석, OAuth ID token, API 호출, 표와 JSON 출력
internal/cli/opsserve.go    server ops-serve: 설정, DB(myungli_ops), opsapi 라우터
deploy/terraform/env/       server-ops 서비스, 서비스 계정, DB 사용자, IAP 에이전트 invoker, OPS_OPERATORS Secret 틀
```

* `ops-serve`는 `CLOUD_SQL_INSTANCE`가 없으면 기동하지 않습니다(배포 환경, #1381 점검 Info 8). local은 `DATABASE_URL`로 띄우고 IAP 검증을 개발용 고정 신원으로 바꾸는 설정은 local에서만 허용합니다(staging과 prod는 거절).
* 앱 서버 라우터와 운영 라우터는 서로의 경로를 갖지 않음을 테스트로 고정합니다.

## 8. 오류 처리

* 입력 오류(사유, 목적, 대상 둘 다 또는 없음, 기간 범위, 거래 id 형식): 400, 감사 없음.
* IAP 헤더 없음이나 검증 실패: 401, 감사 없음. 허용 목록 밖: 403, 감사 `denied`(기록 실패는 응답을 바꾸지 않고 로그에 kind만). 운영자 목록을 읽지 못함: 503, 감사 없음, 로그에 kind만.
* 콘텐츠 열람 상한 초과: 429 `rate_limited`, 감사 없음.
* 조회와 열람의 계정 없음, 프로필 없음: 404, 감사 있음.
* 부여 대상 계정 없음, 회수할 부여 행 없음: 404, 감사 없음.
* 회수 불가, 이미 끝남, 지운 계정 부여: 409, 감사 없음.
* IAP 공개키를 구할 수 없음(받은 적이 없거나 마지막으로 받은 지 24시간이 넘음): 503, 감사 없음.
* CLI는 상태 코드를 첫 판의 종료 코드로 바꿉니다(400은 2, 나머지 실패는 1, 429도 1).
* 예상 밖 로그인 role, 역할 분리 위반: migrate 실패(배포 멈춤), `ops-serve` 기동 실패. 오류에는 role 이름 없이 개수만.

## 9. 테스트

* 첫 판의 `internal/ops`, billing, retention, 역할 권한, 감사 trigger 테스트를 새 실행자와 경로(`ops_api`)에 맞게 유지합니다. 사람 IAM 사용자 편입 테스트는 지우고, `DB_OPS_USER` 지정과 "그 밖의 구성원이 있으면 실패", 런타임이 `myungli_ops` 구성원이면 실패, ops가 `myungli_app` 구성원이면 실패를 더합니다.
* `migrate down` 뒤 `ops_audit`의 행이 남고 다시 up이 성공하는지.
* `internal/opsapi`: 테스트용 ES256 키로 서명한 JWT로 정상, 서명 틀림, `aud` 틀림, `iss` 틀림, 만료, 헤더 없음, 허용 목록 밖, 허용 목록 비어 있음. 공개키 교체(kid 바뀜) 때 다시 받기.
* 경로 분리: `serve` 라우터에 `/ops/` 경로가 없고, `ops-serve` 라우터에 앱 경로가 없음.
* 로그: 요청과 응답 본문, 사유, 목적, 메일이 로거 출력에 없음.
* 사유의 `@` 거절, 거래 id 형식 제한.
* CLI: 테스트 서버(httptest)로 요청 본문, 헤더, 상태 코드에서 종료 코드로의 변환, 출력 형식.
* Terraform: `terraform validate`와 plan에서 `server-ops`에 `allUsers` invoker가 없고 `iap_enabled`가 참인지.

## 10. 외부 준비(사용자)

* 환경마다 OAuth 동의 화면 외부, IAP용 맞춤 웹 OAuth 클라이언트(IAP 설정 `client_id`, `client_secret`), 데스크톱 OAuth 클라이언트(IAP `programmatic_clients`). 클라이언트 secret은 로컬 값(D98 K20). staging은 spike 때 했습니다. 순서는 runbook "준비"입니다.
* 운영자 계정의 IAP 접근 부여(runbook 명령).
* Secret `OPS_OPERATORS` 값 넣기.
* staging spike(§3.4)는 끝났습니다(2026-11-26, 확인용 서비스는 지움).

## 11. 문서와 보고

* runbook `server/docs/runbook/ops.md`: 준비(OAuth 로그인, 로컬 값), 운영자 등록과 빼기(IAP 바인딩, `OPS_OPERATORS`), 명령 사용법. 목적별 운영 기준과 내부 통제 세부는 적지 않습니다.
* 결정 행 S170을 이 개정으로 고칩니다(처음 안을 대체, 대체된 원문은 `decisions-history.md`).
* #1321에 구현 전 큰 갈래(서비스 분리, 인증 두 겹, POST 본문, CLI spike)를 남기고 지휘의 보안 검토를 받은 뒤 구현합니다.
