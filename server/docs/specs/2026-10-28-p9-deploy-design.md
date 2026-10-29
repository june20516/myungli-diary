# P9 배포 준비 설계 (Terraform, 배포 workflow, Firebase Hosting)

* 날짜: 2026-10-28
* 범위: P9 중 외부 값 없이 만들 수 있는 것. 값(Secret, 아직 오지 않은 설정)이 오면 tfvars와 Secret Manager만 채워 배포합니다.
* 근거: D56(GCP·Cloud Run·Cloud SQL·WIF), D65(배포 workflow는 server 소유), S1(하위 명령과 Cloud Run Jobs), S12(staging·prod 두 프로젝트), S113(백업 7일), S117(서울 리전과 Firebase Hosting rewrite), #79(엔진 실행 조건), #607(프로젝트 값과 App Link 값), spec `2026-10-11-server-mvp-design.md` §13
* 사용자 결정(2026-10-28): GCP 자원은 Terraform으로 만들고, apply는 GitHub Actions에서 합니다(bootstrap만 사용자가 로컬에서 한 번).

## 1. 목표와 성공 기준

* 사용자가 준비할 것이 이름까지 정해진 목록으로 나옵니다(§8).
* bootstrap과 Secret 값, 남은 설정 값이 들어오면 main 병합만으로 staging에 배포되고, prod는 승인 한 번으로 같은 흐름을 탑니다.
* bootstrap 전에는 배포 job이 건너뛰어져 main CI가 실패하지 않습니다.
* PR은 Terraform fmt·validate와 workflow 검사를 통과해야 합니다.

## 2. 파일 배치 (server 소유)

| 경로 | 내용 |
| --- | --- |
| `server/deploy/terraform/bootstrap/` | 프로젝트마다 사용자가 로컬에서 한 번 apply. state는 그 bucket의 `bootstrap/` prefix(S122). API 켜기, state bucket, Artifact Registry `myungli`, WIF pool·provider, `deployer`·`planner` 서비스 계정 |
| `server/deploy/terraform/env/` | 환경 하나의 자원. backend는 GCS(bucket은 `-backend-config`로 넘김) |
| `server/deploy/terraform/env/staging.tfvars`, `prod.tfvars` | 비밀이 아닌 설정 값(공개 값만) |
| `server/deploy/firebase/firebase.json` | Hosting 설정 |
| `.github/workflows/deploy-server.yml` | 검사, PR plan, staging → prod 호출 |
| `.github/workflows/deploy-server-env.yml` | 환경 하나의 Terraform apply, server 이미지, Job, Hosting 배포(재사용 workflow) |
| `.github/workflows/deploy-engine.yml`, `deploy-engine-env.yml` | 엔진 이미지(`core/`만으로 빌드, D33)와 엔진 서비스 배포 |

Terraform `>= 1.9`와 google provider 버전을 고정하고 `.terraform.lock.hcl`을 commit합니다.

## 3. 자원 (환경마다 같은 이름, 리전 `asia-northeast3`)

| 자원 | 이름과 설정 |
| --- | --- |
| VPC | `myungli`, subnet `myungli-run`(Private Google Access 켬). 비공개 Cloud DNS zone `run.app.`: `*.run.app.` A 레코드를 `private.googleapis.com`(199.36.153.8/30)으로 |
| Cloud Run `engine` | ingress internal, HTTP/2 end-to-end(h2c), gRPC startup probe(서비스 `myungli.engine.v1.MyungliEngine`), 종료 grace 8초(#79), 서비스 계정 `engine-runtime`, invoker는 `server-runtime`만 |
| Cloud Run `server` | ingress all, `allUsers` invoker, Direct VPC egress `PRIVATE_RANGES_ONLY`(subnet `myungli-run`), 서비스 계정 `server-runtime` |
| Cloud Run Job | `server-migrate`(`migrate up`), `server-seed`(`seed`), `server-retention`(`job retention`). 같은 server 이미지와 같은 env·egress. precompute·notify는 P8-3·P8-4에서 더함 |
| Cloud Scheduler | `retention-daily`: 매일 04:30 Asia/Seoul에 `server-retention` 실행(서비스 계정 `scheduler-invoker`) |
| Cloud SQL | `myungli-pg`(PostgreSQL 17), public IP(승인된 네트워크 없음, Cloud SQL connector로만 접속), DB `myungli`, IAM DB 사용자 `server-runtime`. 자동 백업 7개, PITR 7일(S113). tier는 staging `db-f1-micro`, prod `db-custom-1-3840`. prod는 삭제 보호 |
| Secret Manager | §5의 틀만 만듦(버전 없음) |

* **엔진 호출 경로:** server와 Job은 private ranges만 VPC로 보내고, 비공개 DNS가 `run.app`을 Google API 대역으로 풀어 그 요청만 VPC를 거칩니다. 그래서 엔진의 internal ingress를 통과하고, 외부 호출(카카오, Apple, RevenueCat, FCM)은 그대로 인터넷으로 나가 Cloud NAT가 필요 없습니다(Cloud Run 문서 "Private networking", Private Google Access와 DNS 방식). 엔진은 IAM 인증도 요구하고 `ENGINE_AUDIENCE`는 엔진 서비스 URL입니다.
* **env와 Secret 연결:** Terraform은 server 서비스와 Job에 env·Secret을 두지 않고(`ignore_changes`), 값을 출력(`server_env`, `secret_ids`)만 합니다. 값이 없는 Secret을 연결하면 revision이 뜨지 않아 첫 apply가 실패하고, 설정 변경이 준비 확인 없이 새 revision을 만들기 때문입니다. 배포 workflow가 준비를 확인한 뒤 이미지와 함께 `--env-vars-file`·`--set-secrets`로 붙입니다. Secret 값을 바꾸면 다음 배포 때 새 revision이 새 값을 읽습니다.
* **Scheduler:** `retention-daily`는 멈춘 채 만들고(`paused`, 이후 Terraform은 무시), 첫 server 배포 때 workflow가 다시 켭니다.
* **이미지:** Terraform은 Cloud Run 서비스·Job의 이미지를 `lifecycle.ignore_changes`로 두고 배포 workflow가 이미지를 바꿉니다. 배포 순서를 workflow가 지키기 위해서입니다. 처음 만들 때 server와 Job은 공개 placeholder(`us-docker.pkg.dev/cloudrun/container/hello`)를 쓰고, 엔진은 h2c·gRPC probe 때문에 placeholder로 뜨지 않으므로 `deploy-engine`이 먼저 push한 `myungli/engine:current`를 씁니다. Artifact Registry가 bootstrap에 있는 이유입니다.

## 4. 서비스 계정과 권한

| 계정 | 만드는 곳 | 권한 |
| --- | --- | --- |
| `deployer` | bootstrap | env 자원을 만들고 바꾸는 역할(Cloud Run admin, Cloud SQL admin, Artifact Registry writer, Secret Manager admin, Scheduler admin, Compute network admin, DNS admin, IAM 서비스 계정 admin, 프로젝트 IAM admin, Firebase Hosting admin), 실행 계정에 대한 `iam.serviceAccountUser`, state bucket 쓰기 |
| `planner` | bootstrap | env 자원의 서비스별 읽기 역할(run, cloudsql, compute network, dns, scheduler, secretmanager, 서비스 계정)과 `roles/iam.securityReviewer`, state bucket 읽기. PR 브랜치 코드가 쓰므로 로그를 읽는 `roles/viewer`는 주지 않음 |
| `server-runtime` | env | Secret 읽기(§5 Secret만), `cloudsql.client`, `cloudsql.instanceUser`, 엔진 `run.invoker`, `firebasecloudmessaging.admin`(P8-4 발송) |
| `engine-runtime` | env | 없음 |
| `scheduler-invoker` | env | `server-retention` Job의 `run.invoker`(Job 실행) |

WIF provider는 이 저장소(`june20516/myungli-diary`)의 토큰만 받습니다. `deployer`는 environment와 ref를 묶은 속성(`attribute.env_ref`)이 `staging@refs/heads/main` 또는 `prod@refs/heads/main`인 토큰만, `planner`는 같은 저장소의 `pull_request` 토큰만 쓸 수 있습니다. 두 environment의 "Deployment branches"를 `main`으로 제한하는 것은 이중 장치입니다(사용자 준비 §8).

## 5. 설정과 Secret

Secret id는 환경 변수 이름 그대로입니다. Cloud Run은 Secret을 `latest` 버전으로 env에 넣습니다.

* **Secret:**
  * 두 환경: `JWT_SIGNING_KEY`, `TOKEN_ENCRYPTION_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_PRIVATE_KEY`, `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`
  * staging만: `TEST_LOGIN_SECRET`
  * 키 교체용 `JWT_PREVIOUS_KEY`, `TOKEN_PREVIOUS_KEY`: tfvars에 이전 키 id가 있을 때만 만들고 연결합니다(버전 없는 Secret을 연결하면 배포가 실패).
* **tfvars(공개 값):** `APP_ENV`, `GOOGLE_CLOUD_PROJECT`, `FIREBASE_PROJECT_NUMBER`(#607의 Project number), `JWT_SIGNING_KEY_ID`, `TOKEN_ENCRYPTION_KEY_ID`, 이전 키 id 둘, `KAKAO_APP_KEY`, `LINE_CHANNEL_ID`, `GOOGLE_CLIENT_IDS`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_BUNDLE_ID`, `APPLE_SERVICES_ID`, `APPLE_WEB_REDIRECT_URI`, `APP_LINK_BASE`, `ANDROID_APP_PACKAGE`, `ANDROID_CERT_SHA256`(staging은 debug 지문도 쉼표로 함께, prod는 Play 앱 서명 지문만, #607), `ANDROID_STORE_URL`, `REVENUECAT_PROJECT_ID`, `AD_FREE_PRODUCT_IDS`, `TRUSTED_PROXY_HOPS`, `APP_MIN_VERSION_IOS`, `APP_MIN_VERSION_ANDROID`, `LOG_LEVEL`.
* **Terraform이 채우는 값:** `ENGINE_ADDR`(엔진 서비스 host:443), `ENGINE_AUDIENCE`(엔진 URL), `CLOUD_SQL_INSTANCE`(연결 이름), `DATABASE_URL`(`user=<server-runtime IAM 사용자> dbname=myungli sslmode=disable`, 비밀 아님).
* tfvars의 server 필수 값이 비어 있으면 배포 workflow는 server 서비스·Job 배포를 건너뛰고 이유를 요약에 남깁니다(인프라 apply와 엔진 배포는 진행). 필수 목록은 workflow가 `config` 검증과 같은 이름으로 확인합니다.

## 6. server 코드 변경

* **Cloud SQL IAM 연결:** `CLOUD_SQL_INSTANCE`가 있으면 `postgres.Open`이 `cloud.google.com/go/cloudsqlconn`(IAM 인증, private IP 아님·public IP 경유 connector)으로 pgx dial 함수를 만들고 `DATABASE_URL`의 host는 무시합니다. 없으면 지금처럼 `DATABASE_URL`로 바로 붙습니다(local, CI).
* **엔진 audience 필수:** `APP_ENV`가 local이 아니면 `ENGINE_AUDIENCE`가 비어 있을 때 시작에 실패합니다(`serve`와 `job retention`).
* **ENGINE_ADDR TLS:** audience가 있으면 TLS로 붙는 지금 동작(`engine.NewClient`)을 그대로 씁니다.

## 7. 배포 workflow

### 7.1 `deploy-server.yml`

* 트리거: `server/**`, `server/deploy/**`, 이 파일이 바뀐 `push`(main)와 `pull_request`, 그리고 `workflow_dispatch`.
* `checks`(언제나): `terraform fmt -check -recursive`, bootstrap과 env의 `terraform init -backend=false` + `validate`, `actionlint`.
* `plan`(PR, 저장소 변수 `DEPLOY_ENABLED == 'true'`일 때): `planner`로 staging·prod plan을 돌려 요약을 job summary에 남깁니다.
* `staging`(main push, `DEPLOY_ENABLED`): environment `staging`, `deployer`로
  1. `terraform apply -var-file=staging.tfvars`
  2. server 이미지 빌드(`-tags staging`)와 push, 태그는 commit SHA
  3. `server-migrate` 이미지 갱신 후 실행(`--wait`), 실패하면 멈춤
  4. `server-seed` 이미지 갱신 후 실행(`--wait`)
  5. `server` 새 리비전 배포
  6. `server-retention` 이미지 갱신
  7. Firebase Hosting 배포(`firebase deploy --only hosting --project <id>`, `server/deploy/firebase`)
* `prod`: `staging` 성공 뒤 environment `prod`(필수 승인자). 같은 순서, prod 이미지는 태그 없이 빌드.
* apply 전에 `engine:current`가 없으면(deploy-engine 전) 요약을 남기고 끝냅니다(실패 아님).
* `concurrency`: workflow·환경마다 하나(`deploy-server-<env>`, `deploy-engine-<env>`), 진행 중인 것을 취소하지 않습니다. 두 workflow가 한 group을 쓰면 대기 job이 서로를 밀어내므로 나눕니다.

### 7.2 `deploy-engine.yml`

* 트리거: `core/**`, 이 파일이 바뀐 main `push`와 `workflow_dispatch`.
* `staging` → `prod`(승인): `core/`로 이미지 빌드, `engine:<sha>`와 `engine:current`로 push, `engine` 서비스가 있으면 새 리비전 배포(없으면 push만). 인프라(서비스 정의)는 `deploy-server.yml`의 Terraform이 맡습니다.
* 첫 배포 순서: bootstrap → `deploy-engine`(`workflow_dispatch`, push만) → `deploy-server`(Terraform이 `engine:current`로 엔진 서비스를 만들고 server를 배포).

## 8. 사용자가 준비할 것 (지휘에 `to:root` `kind:prep`으로 안내)

1. 두 프로젝트에서 bootstrap apply(로컬 `gcloud auth application-default login` 뒤 `terraform apply -var project_id=…`). 출력의 WIF provider 이름과 서비스 계정 email을 GitHub 저장소 변수로 넣습니다.
2. GitHub environment `staging`, `prod`를 만들고 prod에 필수 승인자를 둡니다. 저장소 변수 `DEPLOY_ENABLED=true`.
3. Secret 값 넣기(§5 목록, `gcloud secrets versions add`).
4. 아직 오지 않은 tfvars 값을 server에 전달(받으면 server가 tfvars PR).
5. Firebase를 두 프로젝트에 연결(E5, #605). 커스텀 도메인 연결은 도메인이 정해진 뒤.

## 9. 오류 처리

* migrate가 실패하면 seed와 server 배포를 하지 않습니다. 이전 리비전이 계속 돕니다(migration은 expand/contract, spec §13.1).
* server 리비전이 시작에 실패하면 Cloud Run이 트래픽을 옮기지 않으므로 이전 리비전이 남습니다.
* Terraform apply가 실패하면 그 뒤 단계는 돌지 않습니다.

## 10. 검사

* CI: `terraform fmt`·`validate`, `actionlint`(이 PR에서 server CI에 더함).
* Go: Cloud SQL 연결 설정 선택(`CLOUD_SQL_INSTANCE` 유무)과 `ENGINE_AUDIENCE` 필수 검사를 단위 테스트로.
* 실제 GCP 동작은 staging 첫 배포에서 확인합니다: 엔진 비공개 DNS 경로와 h2c·probe, Cloud SQL IAM 연결(첫 connector 연결이 `connectTimeout` 5초 안인지 포함), S117 확인 항목 셋.

## 12. 남긴 위험

* `server-runtime` 하나가 serve와 migration을 함께 맡아 `cloudsqlsuperuser`를 가집니다. 인터넷에 열린 serve가 DDL 권한을 갖는 셈이라, 출시 전에 migration 전용 `server-migrator`(migrate·seed Job)와 DML 권한만 가진 실행 역할로 나눕니다. 테이블 주인이 굳기 전, staging 첫 배포 뒤 바로 하는 것이 쌉니다.

## 11. 결정

* S121: 이 문서의 배포 구조(Terraform과 GitHub Actions apply, 자원 이름, 서비스 계정, Secret과 tfvars 나누기, 엔진 호출 경로).
