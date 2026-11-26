# 운영 API runbook (S170, #1321, D145 ⑦)

사용자 지원, 장애, 정책 위반, 법령 요청에 대응할 때 prod DB에 사람이 붙지 않고, IAP로 막은 내부 운영 API(Cloud Run 서비스 `server-ops`)를 `server ops` 명령으로 불러서만 데이터를 보고 고칩니다. 사람 DB 계정은 없습니다. DB에는 운영 API의 서비스 계정 `server-ops`만 붙고, 모든 호출은 감사 기록(`ops_audit`)을 남깁니다. 설계는 [`server/docs/specs/2026-11-26-ops-commands-design.md`](../specs/2026-11-26-ops-commands-design.md)입니다.

이 문서에는 목적별로 언제 열어도 되는지(운영 기준)와 내부 통제 세부를 적지 않습니다(D145 ⑤⑥, 비공개 내부 관리계획).

아래 명령의 `<프로젝트>`는 `server/deploy/terraform/env/<환경>.tfvars`의 `project_id`, 리전은 `asia-northeast3`(`variables.tf`의 `region` 기본값)입니다. 운영자 메일은 개인정보라 저장소, tfvars, Issue, CI 로그에 적지 않습니다(D74). 명령에는 `<운영자 메일>`로 적고 실행할 때만 넣습니다.

## 1. 준비 (환경마다 한 번, 프로젝트 소유자가 실행)

staging은 2026-11-26 spike 때 ①의 IAP API 켜기, ②, ③을 이미 했습니다(IAP 서비스 에이전트, 동의 화면 외부, 맞춤 웹 클라이언트, 데스크톱 클라이언트, IAP 설정 둘 다). staging은 ①의 bootstrap apply와 ④ 이후를 합니다(②는 다시 해도 그대로입니다). prod는 처음부터 합니다.

① **bootstrap apply.** IAP API(`iap.googleapis.com`)를 켜고, deployer에 서비스 계정 보기 역할(`roles/iam.serviceAccountViewer`, 배포 검사가 `server-ops`의 키 목록을 읽음)을 더합니다. 명령은 [`server/deploy/terraform/README.md`](../../deploy/terraform/README.md) "처음 한 번" 3, 4입니다.

② **IAP 서비스 에이전트 만들기.** env apply가 이 에이전트에게 `server-ops`의 `roles/run.invoker`를 주므로 그 전에 있어야 합니다. 이미 있으면 그대로 둡니다.

```sh
gcloud services identity create --service=iap.googleapis.com --project=<프로젝트>
```

③ **OAuth 동의 화면과 클라이언트 두 개.** 운영자 계정이 프로젝트의 조직 밖(gmail)이라, IAP의 Google 관리 OAuth 클라이언트는 로그인을 거절합니다. Google Cloud 콘솔(APIs & Services)에서 합니다.

1. OAuth 동의 화면의 사용자 유형을 외부(External)로 둡니다.
2. 웹 애플리케이션 OAuth 클라이언트를 만듭니다(IAP 브라우저 로그인용). 승인된 리디렉션 URI에 `https://iap.googleapis.com/v1/oauth/clientIds/<웹 클라이언트 id>:handleRedirect`를 넣습니다.
3. 데스크톱 앱 OAuth 클라이언트를 만들고 JSON을 내려받아 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/<환경>/ops-oauth-client.json`(폴더 700, 파일 600, `docs/local-values.md` K20)으로 둡니다.
4. 두 클라이언트를 IAP 설정에 넣습니다. 설정 파일에는 secret이 들어가므로 저장소 밖 임시 경로에 만들고 끝나면 지웁니다.

   ```sh
   umask 077
   cat > "$TMPDIR/iap-settings.yaml" <<'EOF'
   access_settings:
     oauth_settings:
       client_id: <웹 클라이언트 id>
       client_secret: <웹 클라이언트 secret>
       programmatic_clients: [<데스크톱 클라이언트 id>]
   EOF
   gcloud iap settings set "$TMPDIR/iap-settings.yaml" --project=<프로젝트>
   rm "$TMPDIR/iap-settings.yaml"
   gcloud iap settings get --project=<프로젝트>   # programmatic_clients에 데스크톱 클라이언트 id가 있는지 봅니다
   ```

④ **운영자에게 IAP 접근 주기.** 아래 2절 "운영자 등록"의 1번입니다. 서비스가 있어야 하므로 env apply(첫 `deploy-server`)가 `server-ops`를 만든 뒤에 합니다.

⑤ **허용 목록 Secret `OPS_OPERATORS` 값 넣기.** 2절 "운영자 등록"의 2번입니다. 값이 없으면 `deploy-server`는 `server-ops` 갱신만 건너뛰고 요약에 적습니다.

⑥ **배포.** `deploy-server`를 그 환경으로 돌립니다. 배포는 `server-ops` 계정 검사(`server/deploy/check-ops-sa.sh`)를 먼저 하고, 실패하면 멈춥니다(아래 5절).

⑦ **로그인.** 운영자 컴퓨터에서 한 번 합니다. 브라우저가 열리고, 운영자 Google 계정으로 로그인하면 `ops-oauth.json`(600, 운영 API 주소, 클라이언트 id와 secret, refresh token)이 생깁니다. 이 파일은 비밀(L2)이라 내용을 출력하거나 옮기지 않습니다.

```sh
cd server
api_url="$(gcloud run services describe server-ops --region asia-northeast3 --project <프로젝트> --format='value(status.url)')"
go run ./cmd/server ops login --env prod --api-url "$api_url"
go run ./cmd/server ops audit list --env prod --since 2026-12-01 --reason "등록 확인"
```

마지막 줄이 표를 내면 끝입니다(이 확인도 감사 행을 남깁니다). 로그인을 다시 하면 파일을 새로 씁니다. refresh token이 거절되면(비밀번호 변경, 접근 취소 등) 다시 로그인합니다.

## 2. 운영자 등록과 빼기

두 겹 모두에 넣어야 운영 API를 부를 수 있습니다. ① IAP 접근(`roles/iap.httpsResourceAccessor`, `server-ops` 서비스 단위) ② API 안 허용 목록 `OPS_OPERATORS`. IAP 바인딩이 실수로 넓어져도 목록 밖 계정은 403입니다. 값이 비면 모든 요청이 403입니다.

**운영자 등록**

1. IAP 접근을 서비스 단위로 줍니다. 프로젝트 단위로 주지 않습니다.

   ```sh
   gcloud iap web add-iam-policy-binding --member=user:<운영자 메일> --role=roles/iap.httpsResourceAccessor \
     --region=asia-northeast3 --resource-type=cloud-run --service=server-ops --project=<프로젝트>
   ```

2. `OPS_OPERATORS`에 새 버전을 넣습니다. 값은 쉼표로 나눈 운영자 메일 전체입니다(공백은 지우고 대소문자는 가리지 않음). 버전마다 전체 목록이므로 기존 운영자도 함께 적습니다. 값이 터미널 기록에 남지 않게 입력으로 받습니다.

   ```sh
   read -rs operators   # 쉼표로 나눈 메일 전체를 붙여 넣고 Enter
   printf '%s' "$operators" | gcloud secrets versions add OPS_OPERATORS --project <프로젝트> --data-file=-
   unset operators
   ```

3. `deploy-server`를 다시 돌려 `server-ops` 새 revision이 새 값을 읽게 합니다.
4. 운영자가 1절 ⑦로 로그인하고 확인합니다.

**운영자 빼기**

1. IAP 접근을 거둡니다. IAM 변경이 퍼지는 몇 분 뒤부터 이 단계에서 막힙니다.

   ```sh
   gcloud iap web remove-iam-policy-binding --member=user:<운영자 메일> --role=roles/iap.httpsResourceAccessor \
     --region=asia-northeast3 --resource-type=cloud-run --service=server-ops --project=<프로젝트>
   ```

2. 그 메일을 뺀 목록으로 `OPS_OPERATORS` 새 버전을 넣고(등록 2번과 같음), 이전 버전은 사용 중지합니다(`gcloud secrets versions disable <버전> --secret OPS_OPERATORS --project <프로젝트>`). `deploy-server`를 다시 돌립니다.
3. 지금 바인딩을 확인합니다.

   ```sh
   gcloud iap web get-iam-policy --region=asia-northeast3 --resource-type=cloud-run --service=server-ops --project=<프로젝트>
   ```

빠진 운영자의 컴퓨터에 남은 `ops-oauth.json`은 IAP와 허용 목록에서 막히지만, 본인에게 지우라고 알리고 Google 계정의 앱 접근에서 그 클라이언트를 끊게 합니다.

## 3. 명령

모든 명령에 `--env staging|prod`(먼저 그 환경으로 로그인)와 `--reason "<사유>"`가 필수입니다. 아래는 `go run ./cmd/server`(`server/`에서)를 `server`로 줄여 씁니다. `--json`은 기계가 읽는 출력입니다.

**사유 규칙:** 앞뒤 공백을 뗀 뒤 1~500자이고, 줄바꿈(`\n`, `\r`, U+0085, U+2028, U+2029), NUL, 잘못된 UTF-8, `@`는 안 됩니다. 사유는 2년 보관되므로 **이름, 메일, 전화번호 같은 개인정보를 쓰지 않고 문의 번호나 Issue 번호만** 적습니다(예 `문의 2026-1201-03 결제 반영 확인`).

### 계정 조회

문의 메일의 계정 id, 또는 스토어 거래 id(1~128자, 영문, 숫자, `.`, `_`, `-`)로 찾습니다. 둘 중 하나만 줍니다.

```sh
server ops account show --env prod --account 00000000-0000-0000-0000-000000000000 --reason "문의 2026-1201-03"
server ops account show --env prod --store-transaction <스토어 거래 id> --reason "문의 2026-1201-03"
```

보이는 것: 계정(상태 `active`/`deleted`, 가입, 삭제 시각, 최근 활동), 로그인 수단(제공자 종류와 연결 시각), 기기(플랫폼, 활성, 마지막 접속), 권한, 구매 장부. 제공자 subject, 토큰, 알림 token, 호칭, 출생 정보, 본문은 보이지 않습니다. 같은 스토어 거래 id가 여러 계정에 있으면 후보 계정 id를 알려 주고 끝납니다(409). `--account`로 다시 조회합니다.

### 권한 부여

```sh
server ops grant --env prod --account 00000000-0000-0000-0000-000000000000 --entitlement ad_free --days 30 --reason "문의 2026-1201-03 결제 반영 누락"
server ops grant --env prod --account 00000000-0000-0000-0000-000000000000 --entitlement insight --until 2026-12-31T00:00:00Z --reason "Issue 1400 오류 보상"
```

* `--entitlement`: `ad_free`(광고 제거와 근거 열람 두 행) 또는 `insight`(근거 열람 한 행).
* 기간은 `--days <1~366>` 또는 `--until <RFC 3339>` 중 하나입니다. 만료는 지금보다 뒤이고 지금부터 366일 이내여야 합니다. "지금"과 부여 시작 시각은 운영자 컴퓨터 시계가 아니라 DB 시각입니다.
* 지운 계정에는 주지 않습니다(409).

### 권한 회수

```sh
server ops revoke --env prod --account 00000000-0000-0000-0000-000000000000 --grant 123 --reason "Issue 1400 잘못 부여"
```

`--grant`는 `account show`에 나온 부여 행 id입니다. 거둘 수 있는 출처는 `operator`, `rewarded_ad`뿐이며, `ad_free` 묶음으로 준 두 행은 한 번에 거둡니다. 구매에서 생긴 구간(`ad_free_pass`)은 거절합니다(409). 환불은 스토어에서 처리하면 webhook과 동기화가 장부를 고칩니다. 이미 취소됐거나 만료된 행도 409입니다.

### 콘텐츠 열람

`--purpose`는 정확히 `inquiry`, `incident`, `policy`, `legal` 중 하나입니다. 대상은 좁혀서만 엽니다. 본문은 HTTPS 응답으로 실행한 사람의 터미널(stdout)에만 옵니다.

```sh
server ops content diary --env prod --account 00000000-0000-0000-0000-000000000000 --date 2026-11-01 --purpose inquiry --reason "문의 2026-1201-03"
server ops content diary --env prod --account 00000000-0000-0000-0000-000000000000 --id 00000000-0000-0000-0000-000000000001 --purpose inquiry --reason "문의 2026-1201-03"
server ops content schedule --env prod --account 00000000-0000-0000-0000-000000000000 --date 2026-11-01 --purpose inquiry --reason "문의 2026-1201-03"
server ops content profile --env prod --account 00000000-0000-0000-0000-000000000000 --purpose inquiry --reason "문의 2026-1201-03 계산 오류"
```

`diary`와 `schedule`은 `--date YYYY-MM-DD` 또는 `--id <uuid>` 중 하나입니다. 계정 전체를 내보내거나 날짜 범위를 주는 인자는 없습니다. 화면에 나온 본문은 터미널 기록, 클립보드 등 다른 곳에 남기지 않습니다.

### 감사 기록 보기

```sh
server ops audit list --env prod --account 00000000-0000-0000-0000-000000000000 --reason "문의 2026-1201-03 처리 이력"
server ops audit list --env prod --since 2026-11-01 --limit 200 --reason "Issue 1400 기간 점검"
```

`--account`와 `--since`(UTC 날짜) 중 하나 이상이 필요하고, 둘 다 주면 AND입니다. `--limit`은 1~1000(기본 100)입니다. 이 조회도 감사 기록에 남습니다. 표의 "대상" 칸은 `target` JSON 그대로이고, 부여와 회수의 전후 값(`before`, `after`)과 실행자 `sub`(`actorSub`)는 `--json`으로 봅니다.

## 4. 상태 코드와 종료 코드

운영 API는 모두 `POST /ops/v1/...`와 JSON 본문이고, 사용자 정의 헤더 `X-Myungli-Ops: 1`이 필요합니다(CLI가 붙임). 오류 본문은 `{"code", "message"}`이고, CLI는 `message` 한 줄을 stderr로 냅니다.

| HTTP | `code` | 뜻 | CLI 종료 코드 |
| --- | --- | --- | --- |
| 200 | | 성공 | 0 |
| 400 | `invalid_input` | 사유, 목적, 대상, 기간, 거래 id 형식이 틀림. 데이터를 바꾸거나 보이지 않고 감사 행도 없음 | 2 |
| 401 | `unauthenticated` | IAP 서명 헤더가 없거나 검증 실패 | 1 |
| 403 | `forbidden` | 허용 목록 밖, 또는 브라우저 요청 차단(헤더, `Origin`, `Sec-Fetch-Site`) | 1 |
| 404 | `not_found`, `profile_not_found` | 계정, 부여 행, 프로필이 없음(계정 없음과 프로필 없음은 감사 행이 남음) | 1 |
| 409 | `conflict` | 회수 불가, 이미 끝남, 지운 계정 부여, 여러 계정에 걸친 거래 id | 1 |
| 503 | `unavailable` | IAP 공개키를 구할 수 없음. 잠시 뒤 다시 | 1 |
| 500 | `internal` | 내부 오류(원문은 응답과 로그에 없음) | 1 |

CLI 자체의 사용법 오류(인자 빠짐, 형식 틀림)도 종료 코드 2입니다. IAP가 앞에서 막으면 JSON이 아닌 응답이 오고, CLI는 "운영 API가 HTTP <코드>로 답했습니다"를 냅니다. 이때는 2절의 IAP 접근과 1절 ③의 `programmatic_clients`를 봅니다.

## 5. 배포 검사가 멈췄을 때 (`server-ops` 계정 검사)

`deploy-server`는 `server-ops`를 갱신하기 전에 `server/deploy/check-ops-sa.sh`로 `server-ops` 계정을 빌려 쓸 수 있는 주체를 검사하고, 아래가 있으면 멈춥니다. 요약에는 역할과 주체 종류만 나오고 사람 메일은 가려집니다.

* `server-ops` 계정의 IAM 정책에 deployer의 `roles/iam.serviceAccountUser` 말고 다른 바인딩
* `server-ops` 계정의 사용자 관리 키
* 프로젝트 단위 `roles/iam.serviceAccountUser`, `roles/iam.serviceAccountTokenCreator`, `roles/iam.workloadIdentityUser`, `roles/iam.serviceAccountKeyAdmin`, `roles/editor`(예외는 deployer의 프로젝트 단위 `roles/iam.serviceAccountUser` 하나)

**흔한 원인: Firebase나 GCP가 기본 계정에 넓은 역할을 붙임.** Firebase는 자동 계정 `firebase-adminsdk-fbsvc@<프로젝트>.iam.gserviceaccount.com`에 프로젝트 단위 `roles/iam.serviceAccountTokenCreator`를 줍니다. 2026-11-26에 staging, prod, load 모두 이 상태였고, 프로젝트 단위 부여를 떼고 그 계정 자기 자신에게만 다시 주었습니다(커스텀 토큰 서명은 그대로 됨). load의 기본 Compute 계정(`<프로젝트 번호>-compute@developer.gserviceaccount.com`)이 가지던 프로젝트 `roles/editor`도 거두었습니다(load의 서비스, Job, Scheduler는 모두 전용 계정을 씀). Firebase 기능을 새로 켜거나 콘솔에서 무엇을 연결하면 다시 붙을 수 있습니다. 그때는 아래처럼 고치고 `deploy-server`를 다시 돌립니다.

```sh
project=<프로젝트>
sa="firebase-adminsdk-fbsvc@${project}.iam.gserviceaccount.com"
# 1. 무엇이 붙었는지 봅니다(감시 역할만).
gcloud projects get-iam-policy "$project" --flatten='bindings[].members' \
  --filter='bindings.role:(roles/iam.serviceAccountUser roles/iam.serviceAccountTokenCreator roles/iam.workloadIdentityUser roles/iam.serviceAccountKeyAdmin roles/editor)' \
  --format='table(bindings.role, bindings.members)'
# 2. Firebase 계정: 자기 자신에게 먼저 주고 프로젝트 단위 부여를 뗍니다(순서를 지켜 서명이 끊기지 않게).
gcloud iam service-accounts add-iam-policy-binding "$sa" --project "$project" \
  --member="serviceAccount:$sa" --role=roles/iam.serviceAccountTokenCreator
gcloud projects remove-iam-policy-binding "$project" \
  --member="serviceAccount:$sa" --role=roles/iam.serviceAccountTokenCreator
# 3. 기본 Compute 계정의 editor(쓰는 곳이 없음을 확인한 뒤):
gcloud projects remove-iam-policy-binding "$project" \
  --member="serviceAccount:<프로젝트 번호>-compute@developer.gserviceaccount.com" --role=roles/editor
```

모르는 주체가 `server-ops` 계정 정책에 있거나 사용자 관리 키가 있으면 고치기 전에 누가 언제 넣었는지 관리 활동 감사 로그(6절)로 확인합니다. 키는 `gcloud iam service-accounts keys list --iam-account=server-ops@<프로젝트>.iam.gserviceaccount.com --managed-by=user --project <프로젝트>`로 보고 `keys delete`로 지웁니다.

## 6. 남는 위험과 감사 로그

**프로젝트 소유자(owner)는 막을 수 없습니다.** owner는 IAM 정책 자체를 바꿀 수 있어, 자기에게 `server-ops` 계정의 토큰 발급 권한을 주거나 키를 만들어 그 계정으로 DB에 붙으면 IAP와 `ops_audit`을 건너뜁니다. 배포 검사(5절)는 다음 배포 때 이 흔적(정책 바인딩, 키)을 잡지만 그 사이의 접근은 막지 못합니다. 기록이 남는 곳(Cloud Audit Logs, 공식 문서로 확인, spec §2):

| 행위 | 감사 로그 종류 | 기본 |
| --- | --- | --- |
| IAM 정책 바꾸기, 서비스 계정 키 만들기 | 관리 활동 | 항상 켜짐(끌 수 없음) |
| Cloud SQL 연결(`cloudsql.instances.connect`) | 관리 활동 | 항상 켜짐 |
| 서비스 계정 토큰 발급(`iamcredentials` `GenerateAccessToken`, `GenerateIdToken`) | 데이터 접근(`iam.googleapis.com`으로 켬) | **꺼짐** |
| Cloud SQL IAM 로그인, Cloud SQL 사용자 만들기와 지우기 | 데이터 접근(`cloudsql.googleapis.com` `DATA_WRITE`) | **꺼짐** |
| IAP를 거친 요청(실행자 메일, IP, 메서드와 URL, 허용 여부. 본문과 헤더 없음) | 데이터 접근(`iap.googleapis.com`) | **꺼짐** |

토큰 발급은 관리 활동이 아니라 데이터 접근 로그라 기본으로 남지 않습니다. 그래서 prod는 아래 둘을 켭니다. IAP 기록이 있으면 "운영 API를 불렀는데 `ops_audit` 행이 없는" 경우를 찾을 수 있습니다. `server-ops`만 IAP를 쓰므로 IAP 로그 양은 운영 호출 수만큼입니다. `cloudsql.googleapis.com`의 데이터 접근은 앱 런타임 연결마다 로그인 기록이 생겨 양이 늘므로 지금은 켜지 않고, 사람 DB 사용자 추가는 관리 활동의 연결 기록과 migrate의 역할 검사(아래)로 봅니다.

켜는 법(사람이 실행, 프로젝트 IAM 정책 전체를 다시 쓰므로 `bindings`와 `etag`를 그대로 둡니다):

```sh
project=<프로젝트>
gcloud projects get-iam-policy "$project" --format=yaml > "$TMPDIR/policy.yaml"
# policy.yaml 맨 아래에 다음을 더합니다(이미 auditConfigs가 있으면 그 목록에 항목만 더함).
# auditConfigs:
# - auditLogConfigs:
#   - logType: ADMIN_READ
#   - logType: DATA_READ
#   service: iam.googleapis.com
# - auditLogConfigs:
#   - logType: ADMIN_READ
#   - logType: DATA_READ
#   - logType: DATA_WRITE
#   service: iap.googleapis.com
gcloud projects set-iam-policy "$project" "$TMPDIR/policy.yaml"
rm "$TMPDIR/policy.yaml"
```

`etag` 충돌이 나면 처음부터 다시 읽습니다. 확인은 Logs Explorer에서 `protoPayload.serviceName="iamcredentials.googleapis.com"`, `protoPayload.serviceName="iap.googleapis.com"`로 봅니다.

**deployer는 `server-ops` 계정을 쓸 수 있습니다.** bootstrap이 deployer에 프로젝트 단위 `roles/iam.serviceAccountUser`(모든 서비스와 Job을 각자의 계정으로 배포하는 actAs)를 주므로, 배포 브랜치(staging은 `staging`, prod는 `main`)의 코드가 `server-ops` 계정으로 실행될 수 있습니다. deployer는 그 밖에도 `run.admin`, `cloudsql.admin`, `secretmanager.admin`, `resourcemanager.projectIamAdmin`을 가져 배포 코드가 운영 경로를 바꿀 수 있습니다. 이것을 막는 것은 브랜치 보호, PR 리뷰, prod 배포 승인(environment `prod`)입니다. deployer의 `serviceAccountUser`를 서비스 계정 단위 부여로 좁히는 bootstrap 변경은 #1321에 제안으로 남깁니다.

**사람 DB 계정이 다시 생기면 배포가 멈춥니다.** migrate가 배포마다 `myungli_ops` 구성원이 `DB_OPS_USER` 하나인지, 런타임이 `myungli_ops`에, `server-ops`가 `myungli_app`에 속하지 않는지 확인합니다(S170 개정 ③). `gcloud sql users create`로 사람 사용자를 만들고 `myungli_ops`에 넣으면 다음 배포의 migrate가 실패합니다.

## 7. 감사 기록

* 표 `ops_audit`에 언제(`at`, DB 시각), 누가(`actor`, 운영 API가 검증한 IAP 메일, `actor_sub`, IAP `sub`), 어떤 경로로(`channel` `ops_api`), 무엇을(`action` `account_show`, `grant`, `revoke`, `content_view`, `audit_list`와 `target`), 왜(`reason`, 열람은 `purpose`) 했는지, 부여와 회수는 전후 값(`before`, `after`)이 남습니다.
* 열람 기록에는 본문이 아니라 계정 id와 연 항목 id, 개수만 남습니다.
* 조회와 열람도 기록합니다. 기록에 실패하면 결과가 오지 않습니다. 입력 오류, 인증 실패, 허용 목록 밖, 거절된 부여와 회수는 감사 행을 남기지 않습니다.
* `at`은 trigger가 DB `now()`로 정하고, `channel`은 `ops_api` 말고는 trigger가 거절합니다. 실행자는 CLI가 보내지 않고 서버가 IAP 서명 헤더에서 정합니다.
* 행은 고칠 수 없고, 2년이 지난 행만 지울 수 있습니다(trigger). `job retention`이 2년 지난 감사 행과 끝난 지 2년 지난 운영자 부여 행을 지웁니다. `migrate down`도 표를 지우지 않습니다.
* 운영 API의 요청 로그에는 메서드, 경로(route), 상태, 지연 시간만 남고 본문, 사유, 목적, 메일은 남지 않습니다.

## 8. 범위 밖

요청 로그는 계정 id를 남기지 않고 앱 버전은 저장하지 않으므로, 계정별 접속 기록은 `last_active_at`과 기기의 `last_seen_at`까지만 보입니다.
