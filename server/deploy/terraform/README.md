# 배포 Terraform

설계는 [`server/docs/specs/2026-10-28-p9-deploy-design.md`](../../docs/specs/2026-10-28-p9-deploy-design.md), 결정은 S121입니다.

| 디렉터리 | 누가 apply | 내용 |
| --- | --- | --- |
| `bootstrap/` | 사용자, 프로젝트마다 로컬에서 한 번(staging, prod, 부하 전용 load) | API, state bucket, Artifact Registry, WIF, `deployer`·`planner`, 알림 받는 곳(메일)과 예산(S133), Cloud Run 요청 로그 제외(S136), 부하 프로젝트만 결과 bucket(L1-2b) |
| `env/` | GitHub Actions(`deploy-server.yml`) | VPC, Cloud SQL, Secret 틀, Cloud Run 엔진·server, Job, Scheduler, 알림 정책과 uptime check(S133) |

## 처음 한 번 (프로젝트마다)

bootstrap state의 원본은 그 프로젝트의 state bucket `<프로젝트>-tfstate` 안 `bootstrap/default.tfstate`입니다(D98, `docs/local-values.md` K12). 저장소 안에는 state를 두지 않습니다. bucket은 버전 관리가 켜져 있어 지난 state를 되살릴 수 있습니다.

1. `gcloud auth application-default login`
2. `cd server/deploy/terraform/bootstrap`
3. 프로젝트를 고르고 init합니다. 다른 프로젝트로 바꿀 때도 같은 명령을 씁니다(`-reconfigure`).

   ```sh
   env=staging; project=myungli-diary-staging   # prod는 env=prod; project=myungli-diary
   terraform init -reconfigure -backend-config="bucket=${project}-tfstate" -backend-config="prefix=bootstrap"
   ```

   state bucket이 아직 없는 새 프로젝트는 아래 "새 프로젝트"를 먼저 합니다.
4. 로컬 값 파일을 준비하고(아래 "알림과 예산 값") apply합니다. `staging.tfvars`, `prod.tfvars`에 프로젝트와 environment가 짝으로 있습니다. deployer는 그 environment의 main job만 씁니다.

   ```sh
   terraform apply -var-file="$env.tfvars" -var-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/$env/observability.tfvars"
   ```
5. 출력값을 GitHub 저장소 변수로 넣습니다.

| 변수 | 값 |
| --- | --- |
| `GCP_WIF_PROVIDER_STAGING`, `GCP_WIF_PROVIDER_PROD` | `workload_identity_provider` |
| `GCP_DEPLOYER_STAGING`, `GCP_DEPLOYER_PROD` | `deployer_email` |
| `GCP_PLANNER_STAGING`, `GCP_PLANNER_PROD` | `planner_email` |
| `DEPLOY_ENABLED` | `true` (두 프로젝트 bootstrap과 아래 준비가 끝난 뒤) |

6. GitHub environment `staging`, `prod`를 만들고, 둘 다 "Deployment branches"를 `main`으로 제한합니다. prod에는 필수 승인자를 둡니다. WIF도 environment와 main ref를 함께 보지만 이 제한은 이중 장치입니다.
7. Secret 값을 넣습니다. Secret 틀은 첫 `deploy-server` 실행(env apply)이 만들고, server 배포는 값이 들어올 때까지 건너뜁니다. Secret 값을 바꾼 뒤에는 `deploy-server`를 다시 돌려야 새 revision이 새 값을 읽습니다.

```sh
printf '%s' "<값>" | gcloud secrets versions add JWT_SIGNING_KEY --project <프로젝트> --data-file=-
```

Secret 목록: `JWT_SIGNING_KEY`, `TOKEN_ENCRYPTION_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_PRIVATE_KEY`, `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`, `RESEND_API_KEY`(문의 메일, S134), staging만 `TEST_LOGIN_SECRET`. `RESEND_API_KEY`는 값을 넣은 뒤 env tfvars의 `support_mail_enabled`를 `true`로 바꿔야 server에 붙습니다(그 전에는 문의 접수만 503). 키 교체 때는 tfvars에 이전 키 id를 넣으면 `JWT_PREVIOUS_KEY`·`TOKEN_PREVIOUS_KEY` 틀이 생깁니다. staging은 `billing_enabled = false`인 동안 `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH` 값이 없어도 server를 배포합니다(결제만 꺼짐, S123). 값을 넣고 env tfvars의 결제 설정 둘을 채운 뒤 `true`로 바꿉니다.

### 알림과 예산 값

알림 받는 메일 주소, 결제 계정 id, 월 예산은 공개 저장소에 적지 않습니다(D74, D98 L3, `docs/local-values.md` K14). 환경마다 `$MYUNGLI_LOCAL_DIR/server/<환경>/observability.tfvars`(폴더 700, 파일 600)에 둡니다.

```hcl
alert_email        = "<알림 받을 메일>"
billing_account_id = "<XXXXXX-XXXXXX-XXXXXX>"   # gcloud billing projects describe <프로젝트> 의 billingAccountName 뒷부분
budget_amount      = <정수>                      # 결제 계정 통화 기준 월 예산
budget_currency    = "<KRW 또는 USD 등>"          # 결제 계정 통화와 같아야 합니다
```

* apply하는 사용자에게 결제 계정의 Billing Account Costs Manager 이상 역할이 있어야 예산을 만들 수 있습니다.
* 알림이 그 주소로 정말 오는지는 S133의 staging 시험 오류(`GET /test/v1/server-error`)로 확인합니다(`server/docs/runbook/alerts.md` 1절).
* env의 알림 정책은 이 channel을 이름(`myungli-alerts`)으로 찾으므로, **알림 정책이 든 env를 처음 배포하기 전에 두 프로젝트 bootstrap을 이 파일로 다시 apply해야 합니다.** 그 전에는 PR의 plan이 channel을 찾지 못해 실패합니다.

### 새 프로젝트

state bucket은 bootstrap이 만들지만 backend가 그 bucket을 쓰므로, 처음에는 bucket만 손으로 만들고 Terraform으로 가져옵니다.

```sh
gcloud storage buckets create "gs://${project}-tfstate" --project "$project" --location asia-northeast3 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update "gs://${project}-tfstate" --versioning
terraform init -reconfigure -backend-config="bucket=${project}-tfstate" -backend-config="prefix=bootstrap"
terraform import -var-file="$env.tfvars" -var-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/$env/observability.tfvars" google_storage_bucket.tfstate "${project}-tfstate"
terraform apply -var-file="$env.tfvars" -var-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/$env/observability.tfvars"
```

## DB 계정 (S137)

| DB 사용자 | 서비스 계정 | 권한 | 쓰는 곳 |
| --- | --- | --- | --- |
| `server-migrator@<프로젝트>.iam` | `server-migrator` | `cloudsqlsuperuser`, 표의 주인 | Job `server-migrate`, `server-seed` |
| `server-runtime@<프로젝트>.iam` | `server-runtime` | `myungli_app` 구성원(읽기와 쓰기만) | serve, Job `server-retention`, `server-precompute`, `server-notify` |

`migrate up`은 `DB_RUNTIME_USER`를 `myungli_app` 구성원으로 두고, 그 사용자가 `cloudsqlsuperuser`에 속하면 실패합니다. 실패하면 런타임 DB 사용자를 지우고 다시 배포해 Terraform이 역할 없이 다시 만들게 합니다(`database_roles`는 provider가 다시 읽지 않아 목록 수정만으로는 거둬지지 않음).

```sh
gcloud sql users delete "server-runtime@${project}.iam" --instance myungli-pg --type cloud_iam_service_account --project "$project"
```

staging은 이 구조로 바꿀 때 데이터베이스 `myungli`와 런타임 DB 사용자를 지우고 배포가 다시 만들게 했습니다(2026-11-04). 다시 할 일은 아닙니다.

## 부하 환경 (L1, D104)

부하 테스트는 부하 전용 프로젝트 `myungli-diary-load`에서 돌립니다(L1 plan `server/docs/plans/2026-11-04-l1-load-test.md`, 외부 준비물 E21). 같은 env Terraform을 `env/load.tfvars`로 띄웁니다. staging 빌드(테스트 로그인)이고, SQL 크기는 prod와 같으며, Scheduler는 켜지 않습니다. GitHub environment 이름은 `load`이고 `APP_ENV`는 `staging`입니다.

### 처음 한 번 (사용자, E21)

1. 프로젝트를 만들고 결제 계정을 연결합니다.

   ```sh
   project=myungli-diary-load
   gcloud projects create "$project" --name "myungli-diary-load"
   gcloud billing projects link "$project" --billing-account <결제 계정 id>
   ```
2. Firebase 콘솔에서 "프로젝트 추가 → 기존 Google Cloud 프로젝트"로 `myungli-diary-load`를 고릅니다. Hosting 기본 사이트 `myungli-diary-load.web.app`이 생깁니다. 앱 등록과 Analytics는 필요 없습니다. 프로젝트 설정의 **Project number**는 `env/load.tfvars`의 `project_number`에 있습니다(2026-11-04 채움).
3. 알림과 예산 값 `$MYUNGLI_LOCAL_DIR/server/load/observability.tfvars`를 위 "알림과 예산 값"과 같은 형식으로 만듭니다(K14). 예산은 부하 회차 비용에 맞춰 정합니다.
4. bootstrap을 "새 프로젝트" 순서로 apply합니다(`env=load; project=myungli-diary-load`). bootstrap 코드 변경이 아니라 새 프로젝트에 처음 apply하는 것이라 D103 묶음과 상관없습니다.
5. GitHub 저장소 변수 `GCP_WIF_PROVIDER_LOAD`, `GCP_DEPLOYER_LOAD`에 bootstrap 출력 `workload_identity_provider`, `deployer_email`을 넣습니다. GitHub environment `load`를 만들고 "Deployment branches"를 `main`으로 제한합니다. 필수 승인자는 두지 않아도 됩니다.
6. `deploy-engine`을 `workflow_dispatch`, target `load`로 돌려 `engine:current`를 push합니다.
7. `deploy-server`를 target `load`로 한 번 돌립니다. env apply가 Secret 틀을 만들고, 값이 없어 server 배포는 건너뜁니다.
8. Secret 값을 **새로** 만들어 넣습니다. staging 값을 복사하지 않습니다. 같은 JWT 서명 키를 쓰면 부하 환경에서 받은 토큰이 staging에서도 통하기 때문입니다. 테스트 로그인만 쓰므로 Kakao와 Apple 키는 실제로 불리지 않아, 형식만 맞는 새 값을 넣습니다. 값은 화면에 나오지 않고 바로 Secret으로 들어갑니다.

   ```sh
   project=myungli-diary-load
   add() { gcloud secrets versions add "$1" --project "$project" --data-file=-; }
   openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 | add JWT_SIGNING_KEY   # ES256 PKCS8 PEM
   openssl rand -base64 32 | tr -d '\n' | add TOKEN_ENCRYPTION_KEY                       # AES-256 base64
   openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 | add APPLE_PRIVATE_KEY # 쓰이지 않는 자리값
   openssl rand -hex 16 | tr -d '\n' | add KAKAO_ADMIN_KEY                               # 쓰이지 않는 자리값
   openssl rand -base64 32 | tr -d '\n' | add TEST_LOGIN_SECRET
   ```

   `TEST_LOGIN_SECRET`은 부하 스크립트가 Secret Manager에서 바로 읽으므로 따로 적어 두지 않습니다.
9. `deploy-server`를 target `load`로 다시 돌립니다. 이번에는 server가 배포되고 Hosting이 연결됩니다.

### 생성기 Job 준비 (사용자, 한 번, L1-2b)

부하 생성기 Job `load-k6`(env `load.tf`)는 결과를 bucket `myungli-diary-load-load-results`에 씁니다. deployer는 bucket을 만들 권한이 없으므로 bootstrap이 만들고, deployer에게 그 bucket 하나의 관리 권한을 줍니다. env apply가 이 bucket에 기대므로 D103 ②의 **지금 apply 필요**입니다. apply할 곳은 부하 프로젝트뿐입니다. staging과 prod는 `environment`가 `load`가 아니라 바뀌는 것이 없어 묶음에도 넣지 않습니다.

```sh
cd server/deploy/terraform/bootstrap
env=load; project=myungli-diary-load
terraform init -reconfigure -backend-config="bucket=${project}-tfstate" -backend-config="prefix=bootstrap"
terraform plan -var-file="$env.tfvars" -var-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/$env/observability.tfvars"   # 2 to add만 있어야 합니다
terraform apply -var-file="$env.tfvars" -var-file="${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/$env/observability.tfvars"
```

그다음 `deploy-server` target `load`를 돌리면 env apply가 Job과 계정을 만들고, workflow가 스크립트 이미지(`server/load/Dockerfile`)와 `TEST_LOGIN_SECRET`을 붙입니다. 실행은 `server/load/README.md` "생성기 Job"입니다.

### 회차마다

1. `deploy-server` target `load`: 지워 둔 Cloud SQL을 다시 만들고 migrate, seed, server를 배포합니다.
2. 생성기 Job으로 계정을 만들고 측정합니다(`server/load/README.md` "생성기 Job").
3. `deploy-server` target `load-teardown`: Cloud SQL 인스턴스와 그에 기대는 자원(DB, DB 사용자, SQL 알림 정책)만 지웁니다. DB와 DB 사용자는 인스턴스와 함께 사라지므로 state에서만 빼고 인스턴스를 지웁니다(따로 지우면 연결이 남은 DB와 표를 가진 migrator 사용자에서 막힘). 지운 인스턴스 이름은 바로 다시 쓸 수 있습니다(Cloud SQL 문서 "Delete instances"). Secret, Cloud Run(요청이 없으면 인스턴스 0), 네트워크는 남기므로 다음 회차는 1부터 다시 하면 됩니다. 계정과 데이터는 회차마다 새로 만듭니다.

L1이 모두 끝나면 프로젝트를 지울지 지휘와 정합니다.

## 첫 배포 순서

bootstrap → `deploy-engine`(`workflow_dispatch`, 엔진 이미지 `engine:current` push) → `deploy-server`(env apply가 엔진 서비스를 만들고 server를 배포). `engine:current`가 없으면 `deploy-server`는 요약만 남기고 끝납니다. Scheduler `retention-daily`는 첫 server 배포 때 켜집니다.

## 로컬 검사

```sh
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform/env hashicorp/terraform:1.17 init -backend=false
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform/env hashicorp/terraform:1.17 validate
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform hashicorp/terraform:1.17 fmt -check -recursive
```
