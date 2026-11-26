# 운영 명령: 계정 조회, 권한 부여와 회수, 콘텐츠 열람, 감사 기록 (#1321, D145)

## 1. 목적

출시 뒤 사용자 지원(결제 반영 누락, 환불 대응, 오류 문의)과 장애, 정책 위반, 법령 요청에 대응할 때 **prod DB에 직접 SQL로 붙지 않고** 정해진 명령으로만 데이터를 보고 고칩니다. 모든 명령은 감사 기록을 남깁니다. 출시 뒤 어드민 웹(D144)은 같은 핵심 함수와 감사 기록 위에 화면을 얹습니다.

성공 기준:
* 문의 메일의 계정 id 하나로 지원에 필요한 상태(가입, 로그인 수단, 최근 접속, 권한, 구매)를 한 번에 봅니다.
* 광고 제거권과 근거 열람을 기간을 정해 주고, 운영자가 준 것과 보상 광고 권한을 거둡니다.
* 일기, 일정, 프로필을 목적과 사유를 밝히고 좁혀서 열람하며, 본문은 실행한 사람의 터미널로만 갑니다.
* 모든 조회, 변경, 열람이 언제, 누가, 무엇을, 왜, 전후 값과 함께 지울 수 없는 표에 남습니다.
* app에 나가는 계약(REST v1)은 바뀌지 않습니다.

## 2. 확인한 사실

| 사실 | 출처 |
| --- | --- |
| Cloud Run Job의 stdout과 stderr는 Cloud Logging으로 가며, 실행한 사람의 터미널로 돌아오지 않습니다. | Cloud Run Jobs 동작, `internal/cli` 기존 Job들이 결과를 구조화 로그로 남김 |
| Cloud SQL은 공개 IP(`ipv4_enabled = true`, `ENCRYPTED_ONLY`)이고 IAM 인증(`cloudsql.iam_authentication`)이 켜져 있습니다. server는 Cloud SQL Go connector로 IAM 연결을 씁니다(S121). | `deploy/terraform/env/sql.tf`, `internal/cli/cli.go` `openDatabase` |
| 런타임 계정은 `myungli_app` 역할의 구성원으로만 표에 닿습니다(S137). | `db/migrations/00024_app_role.sql` |
| 요청 로그(`accessLog`)는 method, route, status, latencyMs만 남기고 계정 id를 남기지 않습니다. 계정별로 찾을 수 없습니다. | `internal/httpapi/middleware.go` |
| 앱 버전은 어디에도 저장하지 않습니다. 최근 접속 흔적은 `accounts.last_active_at`과 `devices.last_seen_at`(플랫폼 포함)뿐입니다. | `db/migrations/00002`, `00020` |
| 권한 출처 DB 값은 `ad_free_pass`, `rewarded_ad`, `subscription`, `test_grant`이고 취소는 `revoked_at`으로 합니다. 광고 제거권 구간(`ad_free_pass`)은 구매 장부에서 다시 잇기(`rechainFromTx`)로 만들어집니다. | `00012`, `00022`, `internal/billing/ledger.go` |
| 계약 `Insight.source`는 `rewarded_ad`, `ad_free_pass`, `subscription`이고, staging `test_grant`는 계약 밖이라 `ad_free_pass`로 보냅니다(S125). | `api/openapi.yaml`, `internal/httpapi/billing_handlers.go` |
| 계정 삭제는 즉시 익명화이고 `accounts.status`는 `active`, `deleted`뿐입니다. 삭제 대기 상태, 삭제 요청 시각, 로그인 수단의 연결 해제 칸은 없습니다. | `db/migrations`, S105 |
| 처리방침 처리 목적에 "문의 응대"와 "구매 복원과 환불 처리"는 있으나, "결제 오류 처리"와 운영자 콘텐츠 열람(정책 위반 확인, 법령 요청 대응)은 따로 적혀 있지 않습니다. | `docs/legal/ko/privacy.md` §1 |

## 3. 실행 방식

**운영 명령은 Cloud Run Job이 아니라 운영자 컴퓨터에서 같은 server 바이너리로 실행합니다.** Issue 4번은 Job 방식을 적었지만, 7번(열람 본문이 Cloud Logging에 남지 않고 터미널로만 감)은 Job으로 지킬 수 없습니다. 조회 결과(가입일, 구매 내역 등)도 로그에 90일 남기지 않는 편이 맞아(D74, S164) 명령 전부를 같은 방식으로 둡니다.

* **명령:** `server ops <하위 명령> ...`. 운영자는 저장소의 배포된 커밋에서 `go run ./cmd/server ops ...`로 실행합니다.
* **연결:** 운영자 본인의 Google 계정으로 `gcloud auth application-default login` 한 뒤, Cloud SQL Go connector가 IAM 인증으로 붙습니다. DB 사용자는 운영자의 Cloud SQL IAM 사용자(메일 주소)입니다. 비밀번호나 Secret을 운영자 컴퓨터에 두지 않습니다.
* **설정:** `ops`는 DB 연결 값(`CLOUD_SQL_INSTANCE`, `DATABASE_URL`)만 읽습니다. 서버 기동용 Secret을 요구하지 않습니다. 환경별 값은 로컬 값 대장(D98)에 `server/<환경>/ops.env`로 둡니다(인스턴스 이름과 DB 이름, 비밀 아님).
* **실행자와 시각 식별:** 감사 기록의 실행자는 명령 인자가 아니라 DB가 인증한 세션 사용자(`session_user`)입니다. `ops_audit`의 `BEFORE INSERT` trigger(`ops_audit_stamp`)가 `at`을 언제나 `now()`로, `actor`를 `session_user`로 덮으므로 명령 인자나 운영자 컴퓨터 시계로 바꿀 수 없습니다. `SET ROLE`은 `current_user`만 바꾸고 `session_user`는 그대로라 역할 이름이 아니라 로그인한 사람이 남습니다. 부여 시작, 회수 시각, 기간 검사, 권한 상태 판정도 트랜잭션 안의 DB `now()` 기준입니다. 어드민 API가 붙으면 그 경로는 인증한 운영자 식별자를 넘기고, 그때 그 경로의 감사 INSERT 권한과 실행자 출처를 다시 정합니다(§6).
* **출력:** 결과는 stdout(사람이 읽는 표)으로만 씁니다. 표에서 사용자 입력 글의 터미널 제어문자(ESC 등 C0, DEL, C1)와 양방향 제어문자(U+200E, U+200F, U+202A~U+202E, U+2066~U+2069)는 U+FFFD로 바꿉니다(JSON은 이스케이프됨). 로컬 실행이라 Cloud Logging에 남지 않습니다. `--json`으로 기계가 읽는 출력도 냅니다.

### 3.1 prod 실행 권한 범위

* DB에 새 역할 `myungli_ops`(NOLOGIN)를 migration으로 만듭니다. 권한은 아래뿐입니다. 표 구조 변경, 삭제, 다른 표 쓰기는 못 합니다.
  * `accounts`, `entitlement_grants`, `purchases`, `diaries`, `diary_days`, `schedules`의 `SELECT`.
  * `auth_identities`, `devices`, `profiles`는 `db/queries/ops.sql`이 쓰는 칸만 칼럼 단위 `SELECT`. 제공자 subject, Apple 토큰, 알림 token과 그 해시, 출생 정보 해시, 알림 설정은 읽지 못합니다.
  * `entitlement_grants`의 `INSERT`와 `revoked_at` 갱신(`UPDATE`), id sequence `USAGE`.
  * `accounts`의 `updated_at` 갱신(`UPDATE`). 운영자 부여가 계정 행을 `FOR SHARE`로 잠그는 데 PostgreSQL이 그 표의 UPDATE 권한(한 칸 이상)을 요구하기 때문이고, 값은 바꾸지 않습니다.
  * 감사 표 `ops_audit`의 `INSERT`와 `SELECT`.
* **남는 위험과 다음 조건:** `myungli_ops` 구성원은 `diaries`, `schedules`, `profiles`를 `psql` 같은 직접 SQL로 읽을 수 있고, 이 열람은 감사 행을 남기지 않습니다. 지금 운영자는 프로젝트 소유자 한 명이라 받아들입니다. 프로젝트 소유자가 아닌 운영자를 등록하기 전에 콘텐츠 열람을 `SECURITY DEFINER` 함수(함수 안에서 감사 행을 함께 씀)로 옮기고 `myungli_ops`에는 그 함수의 `EXECUTE`만 줍니다.
* **운영자 등록은 Cloud SQL IAM 사용자 추가 하나입니다.** 운영자 메일은 개인정보라 공개 저장소의 tfvars나 CI 로그(env는 CI가 저장소 tfvars로 apply)에 둘 수 없습니다. 프로젝트 관리자가 `gcloud sql users create <메일> --instance=<인스턴스> --type=cloud_iam_user`로 추가하고, 다음 `migrate up`(배포마다 도는 `server-migrate` Job)이 사람 IAM 사용자 전부를 `myungli_ops` 구성원으로 넣습니다.
* **사람 IAM 사용자 판별:** Cloud SQL은 사람 IAM 사용자의 DB 이름을 메일 전체로, 서비스 계정은 `.gserviceaccount.com`을 뗀 `<이름>@<프로젝트>.iam`으로 둡니다(Cloud SQL 문서 "Add and manage IAM users"). 그래서 로그인 가능한 역할 중 이름에 `@`가 있고 `.iam`으로 끝나지 않는 것을 사람으로 봅니다. 런타임과 migrator 서비스 계정은 들어가지 않습니다.
* **IAM 권한:** 연결에는 프로젝트 IAM `roles/cloudsql.client`(connector)와 `roles/cloudsql.instanceUser`(IAM 로그인)가 필요합니다. 프로젝트 소유자가 아닌 운영자에게는 runbook대로 두 역할을 줍니다.
* **빼기:** `gcloud sql users delete <메일>`로 DB 사용자를 지우면 역할 구성원도 함께 사라집니다.
* 지금 운영자는 사용자 한 명이고, staging과 prod 모두 같은 방식입니다.

## 4. 명령

공통 인자: `--account <uuid>`(대상), `--reason "<문자열>"`(필수, 앞뒤 공백을 뗀 뒤 1~500자). 사유에 `\n`, `\r`, U+0085, U+2028, U+2029, NUL, 잘못된 UTF-8이 있으면 거절합니다(감사 표와 터미널 출력이 깨지지 않게). 사유가 없으면 사용법 오류로 아무것도 하지 않습니다.

### 4.1 계정 조회 `ops account show`

`--account` 또는 `--store-transaction <스토어 거래 id>`(구매 장부 `store_purchase_id`, 사용자가 받은 스토어 영수증 번호로 문의할 때) 중 하나로 찾습니다.

보이는 것:
* 계정: 상태(`active`, `deleted`, 계정 삭제는 즉시 익명화라 삭제 대기 상태가 없음, S105), 가입 시각, 삭제 시각(`deleted_at`), 최근 활동(`last_active_at`)
* 로그인 수단: 제공자 종류(`kakao`, `apple`)와 연결 시각. 제공자 subject와 토큰은 보이지 않습니다.
* 기기: 플랫폼, 활성 여부, 등록 시각, 마지막 접속(`last_seen_at`). 알림 token은 보이지 않습니다.
* 권한: 지금 상태(광고 제거, 근거 열람의 활성, 만료, 출처)와 부여 행 전부(행 id, 종류, 출처, 시작, 만료, 취소 시각)
* 구매 장부: 상품, 스토어, 스토어 거래 id, 구매 시각, 환불 시각, 환경(`production`, `sandbox`), 합치기로 옮겨 온 구매인지

보이지 않는 것: 호칭, 출생 정보, 일기와 일정 본문(열람 명령 몫), 메일 주소(저장하지 않음).

**최근 접속 기록(Issue 6번):** 기존 기록 중 계정으로 찾을 수 있는 것은 `last_active_at`과 기기별 `last_seen_at`, 플랫폼입니다. 요청 로그는 계정 id를 남기지 않아 계정별로 찾을 수 없고, 앱 버전은 저장하지 않으므로 보이지 않습니다. 둘을 보려면 새로 수집해야 하므로 이번에는 넣지 않고 지휘에 보고합니다.

### 4.2 권한 부여 `ops grant`

`--entitlement ad_free|insight`, 기간은 `--days <1~366>` 또는 `--until <RFC 3339 시각>` 중 하나.

* `ad_free`는 광고 제거권 기간처럼 광고 제거와 근거 열람 두 행을 줍니다(D60, test_grant와 같은 묶음). `insight`는 근거 열람 한 행입니다.
* DB 출처는 새 값 `operator`, `source_ref`는 그 감사 기록 id입니다.
* 시작은 지금, 만료는 지정한 값입니다. 이미 지난 시각이거나 1년을 넘으면 거절합니다.
* 지운 계정에는 주지 않습니다.

**계약:** app에 나가는 `Insight.source`에 새 값을 더하지 않습니다(D138). S125처럼 `operator`의 `ad_free` 묶음은 `ad_free_pass`로, `insight` 단독은 `rewarded_ad`로 보냅니다. app이 보이는 뜻(광고 제거권 기간, 광고 보상으로 연 열람)과 같고, 운영자가 줬다는 사실은 DB 출처와 감사 기록에만 남습니다.

### 4.3 권한 회수 `ops revoke`

`--grant <부여 행 id>`. 그 행의 `revoked_at`을 지금으로 찍습니다.

* 거둘 수 있는 출처는 `operator`와 `rewarded_ad`입니다. `ad_free` 묶음으로 준 두 행은 한 번에 거둡니다.
* `ad_free_pass`(구매에서 생긴 구간)는 거두지 않습니다. 구매 구간은 장부에서 다시 이어지므로 행만 취소하면 다음 동기화와 어긋납니다. 환불은 스토어에서 처리하면 webhook과 동기화가 장부와 구간을 고칩니다. 명령은 이 안내를 오류 메시지로 냅니다.
* 이미 취소됐거나 만료된 행은 아무것도 바꾸지 않고 알립니다.

### 4.4 콘텐츠 열람 `ops content diary|schedule|profile`

필수: `--purpose inquiry|incident|policy|legal`, `--reason`.

| 값 | 뜻 |
| --- | --- |
| `inquiry` | 이용자 문의와 오류 처리 |
| `incident` | 서비스 장애와 데이터 사고 대응 |
| `policy` | 이용약관과 운영 정책 위반 확인과 조치 |
| `legal` | 부정 이용 방지와 법령에 따른 요청 대응 |

대상은 좁혀서만 엽니다.
* `diary`: `--date YYYY-MM-DD`(그날 일기 전부, 하루 최대 10편) 또는 `--id <일기 id>`. 본문, 날짜, 작성과 수정 시각, 그날 기록한 태그.
* `schedule`: `--date` 또는 `--id`. 제목, 날짜, 시간, 메모.
* `profile`: 호칭, 출생 정보(계산 오류 문의 확인용).

계정 전체를 내보내는 명령, 날짜 범위 인자는 두지 않습니다. 목적별로 언제 열어도 되는지는 이 문서와 runbook에 적지 않습니다(D145 ⑤⑥, 비공개 내부 관리계획).

## 5. 감사 기록

### 5.1 표 `ops_audit`

| 칸 | 뜻 |
| --- | --- |
| `id` uuid | 기록 id. 부여 행의 `source_ref`로도 씀 |
| `at` timestamptz | 실행 시각. trigger가 DB `now()`(트랜잭션 시작 시각)로 정함 |
| `actor` text | 실행자. trigger가 `session_user`로 정함 |
| `channel` text | `cli`. `admin_api`는 표의 CHECK에는 있지만 어드민 API 전까지 trigger가 거절함 |
| `action` text | `account_show`, `grant`, `revoke`, `content_view`, `audit_list` |
| `account_id` uuid | 대상 계정(조회로 찾지 못하면 NULL) |
| `purpose` text | 열람 목적(`content_view`만 필수, DB CHECK) |
| `reason` text | 사유(필수) |
| `target` jsonb | 무엇을: 조회 키(스토어 거래 id로 찾았으면 그 값), 권한 종류와 기간, 행 id, 열람 종류와 날짜나 항목 id |
| `before`, `after` jsonb | 바뀐 행의 전후 값(`grant`, `revoke`). 조회와 열람은 NULL |

본문, 호칭, 출생 정보는 기록에 넣지 않습니다. 열람 기록의 `target`에는 항상 `accountId`와 연 항목 id, 개수만 남깁니다. 스토어 거래 id가 여러 계정에 걸려 모호한 조회는 `target`에 후보 계정 id 목록을 남깁니다.

### 5.2 기록 규칙

* **조회와 열람도 기록합니다.** 개인정보 처리 시스템 접속 기록은 조회를 포함하므로(안전성 확보조치 기준) 모든 명령이 기록합니다.
* **기록이 먼저:** 변경 명령은 변경과 기록을 한 트랜잭션에 씁니다. 조회와 열람 명령은 기록을 커밋한 뒤에만 결과를 출력합니다. 기록에 실패하면 아무것도 보이지 않습니다.
* **거절은 기록하지 않음:** 부여와 회수가 거절되면(DB 시각 기준 기간 검사 실패, 회수 불가 출처 등) 트랜잭션이 되돌아가 감사 행이 없습니다. 인자 해석과 사유 검사 같은 사용법 오류는 DB에 붙기 전에 끝납니다.
* **어드민 API 전까지 cli만:** trigger가 `channel`이 `cli`가 아닌 행을 거절합니다. psql로 `admin_api`를 넣어 실행자를 임의로 남기는 경로가 없습니다. 어드민 API를 만들 때 그 경로의 실행자 결정 방식과 INSERT 권한을 다시 정합니다.
* **고칠 수 없음:** `myungli_ops`는 `ops_audit`에 `INSERT`와 `SELECT`만 있습니다. `myungli_app`은 retention 때문에 `DELETE`가 필요하므로(app 역할의 `UPDATE`와 `INSERT`는 거둠), 표의 trigger가 `UPDATE`를 언제나 거절하고 `DELETE`는 `at`이 2년보다 오래된 행만 허용합니다. 표 주인(migrator)만 trigger를 끌 수 있습니다.
* **보관:** 2년. `job retention`이 2년 지난 행을 지웁니다(접속 기록 보관 기준). 정리 쿼리는 clock과 DB `now()` 기준 2년을 함께 만족하는 행만 고릅니다(trigger의 DB 시계와 어긋나도 거절당하지 않게). 운영자 부여 권한 행(`operator`)도 끝난 지 2년이 지나면 함께 지웁니다.
* **합치기:** 계정 합치기는 구매 구간만 옮깁니다(보상 구간과 같이 운영자 부여 행은 옮기지 않음). 필요하면 합친 계정에 다시 줍니다. 계정 삭제(익명화) 때도 지우지 않습니다. 계정 id만 있고 개인정보 본문이 없기 때문입니다. 지휘의 수집, 보관 대장(D87)에 반영을 요청합니다.
* **기록 보기:** `ops audit list --account <uuid>` 또는 `--since <날짜>`. 이 조회 자체도 기록합니다(`action` `audit_list`).

## 6. 구조와 재사용

```
internal/ops/            핵심 함수(어드민 API가 그대로 씀)
  ops.go                 Service와 DB 시각 출처, Actor{ID, Channel}
  account.go             AccountSummary
  grant.go               Grant, Revoke
  content.go             ViewDiary, ViewSchedule, ViewProfile
  auditlist.go           AuditList
  audit.go               감사 기록 쓰기(트랜잭션 안), 목적과 사유 검사
  opsdb/                 sqlc 쿼리
internal/cli/ops.go      인자 해석, session_user로 Actor 만들기, 표와 JSON 출력
```

* Service 함수는 모두 `Actor`와 사유를 받고 안에서 감사 기록을 씁니다. 기록 없이 데이터를 돌려주는 공개 함수는 없습니다.
* 권한 부여와 회수는 `internal/billing`에 출처 `operator`와 행 단위 회수 함수를 더해 씁니다. 권한 판정(`Status`)과 계약 변환(`contractSource`)은 billing과 httpapi에 있는 그대로 고칩니다.
* HTTP 경로는 열지 않습니다.

## 7. 오류 처리

* 인자 오류(사유 없음, 목적 값 틀림, 대상 둘 다 또는 하나도 없음, 기간 범위 밖): 종료 코드 2, 데이터를 바꾸거나 보이지 않고 감사 기록도 남기지 않습니다. 인자 해석 단계의 오류는 DB에 붙기 전에, 기간 범위처럼 DB 시각이 필요한 검사는 Service가 트랜잭션을 되돌려 끝냅니다.
* 계정 없음: 종료 코드 1, 감사 기록은 남깁니다(무엇을 찾았는지 남기기 위해, `account_id` NULL).
* 프로필 없음(계정은 있고 프로필 행만 없음): 종료 코드 1, "프로필이 없습니다"로 계정 없음과 구분하고 감사 기록은 남깁니다.
* 권한 오류(DB 역할 없음): 종료 코드 1, 연결 사용자를 보여 주고 runbook의 권한 절로 안내합니다.

## 8. 테스트

* `internal/ops`: testcontainers DB로 명령마다 결과와 감사 행(칸, 전후 값), 기록 실패 때 결과 없음, 사유와 목적 검사, `ad_free_pass` 회수 거절, 지운 계정 부여 거절, 거절한 부여와 회수는 감사 행을 남기지 않음.
* 역할 권한: `myungli_ops` 구성원 연결로 허용된 쓰기만 되고, `ops_audit` 갱신과 삭제가 `myungli_app`, `myungli_ops` 모두 거절되는지, `myungli_app`의 `ops_audit` INSERT가 거절되는지, 민감 칸(`auth_identities.subject`, `devices.fcm_token`, `profiles.birth_hash` 등)을 `myungli_ops`가 읽지 못하는지.
* 감사 trigger: 다른 `actor`와 과거 `at`으로 넣어도 `cli` 행에는 `session_user`와 `now()`가 남는지.
* 계약: `operator` 출처가 `ad_free_pass`, `rewarded_ad`로 나가는지(`billing_handlers` 테스트), `contractgate`가 변경 없음으로 통과.
* `internal/cli`: 인자 해석과 출력 형식, 본문이 stderr나 로그로 새지 않는지(로거 출력에 본문이 없음).
* `retention`: 2년 지난 감사 행 정리.

## 9. 문서와 보고

* runbook `server/docs/runbook/ops.md`: 준비(gcloud 로그인, 로컬 값), 명령별 사용법과 예시. 목적별 운영 기준은 적지 않습니다.
* 결정 행 S170(이 설계의 요점), Terraform README의 운영자 추가 절, `docs/local-values.md` server 행(`ops.env`).
* 지휘 보고(#1376으로 올렸습니다):
  * 처리방침 처리 목적에 "결제 오류 처리"와 운영자 콘텐츠 열람(정책 위반 확인, 법령 요청 대응)이 따로 없음(writing, 법적 문서 몫, Issue 8번과 함께).
  * 요청 로그에는 계정 id가 없어 계정별 접속 기록과 앱 버전은 보이지 않음. 필요하면 새 수집 결정이 필요함.
  * 감사 기록 2년 보관을 수집, 보관 대장에 반영.
