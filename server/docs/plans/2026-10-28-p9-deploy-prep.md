# P9 배포 준비 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** spec의 배포 구조(Terraform bootstrap·env, 배포 workflow 둘, Firebase Hosting, Cloud SQL IAM 연결)를 외부 값 없이 만들어, bootstrap과 Secret 값만 채우면 배포되게 합니다.

**Architecture:** Go는 `CLOUD_SQL_INSTANCE`가 있을 때만 Cloud SQL connector로 붙고, `APP_ENV`가 local이 아니면 `ENGINE_AUDIENCE`를 요구합니다. Terraform은 bootstrap(사용자 로컬 1회)과 env(Actions apply) 두 root module이고, 이미지는 workflow가 바꿉니다.

**Tech Stack:** Go(`cloud.google.com/go/cloudsqlconn`), Terraform(google provider), GitHub Actions(`google-github-actions/auth`, `setup-gcloud`), firebase-tools. 로컬 검사는 Docker 이미지 `hashicorp/terraform`, `rhysd/actionlint`.

**Spec:** `server/docs/specs/2026-10-28-p9-deploy-design.md`

## Global Constraints

* 리전 `asia-northeast3`, 프로젝트 staging `myungli-diary-staging`(번호 `1056563158649`), prod `myungli-diary`(번호 `21526308173`), 저장소 `june20516/myungli-diary`.
* 자원 이름은 spec §3·§4 그대로입니다. Secret id는 환경 변수 이름 그대로입니다.
* Terraform `required_version = ">= 1.9"`, google provider `~> 8.9`(작성 시점 최신 8.9.0). `.terraform.lock.hcl`을 commit합니다.
* tfvars에는 공개 값만 둡니다. 아직 오지 않은 값은 빈 문자열입니다.
* 단위 `CLAUDE.md`에는 버전을 적지 않습니다. 사용자에게 보이는 글은 없습니다(D93 해당 없음).

## Review Focus

1. bootstrap 전(`DEPLOY_ENABLED` 없음)과 fork PR: 배포·plan job이 건너뛰어지고 실패로 보이지 않아야 합니다.
2. tfvars의 server 필수 값이 비어 있을 때: 인프라와 엔진은 배포되고 server 서비스·Job 배포만 건너뛰어 요약에 이유가 남아야 합니다.
3. 키 교체용 이전 키 id가 빈 값일 때 `*_PREVIOUS_KEY` Secret이 만들어지거나 연결되지 않아야 합니다.
4. `CLOUD_SQL_INSTANCE`가 없을 때 local·CI 연결이 지금과 똑같아야 합니다.
5. migrate Job 실패 때 seed와 server 배포가 돌지 않아야 합니다.

---

### Task 1: Cloud SQL IAM 연결과 엔진 audience 필수

**Files:** Modify `internal/platform/postgres/postgres.go`, `postgres_test.go`, `internal/platform/config/config.go`, `config_test.go`, `internal/cli/cli.go`, `serve.go`, `retention.go`, `go.mod`

**Interfaces:**
- Produces: `config.Config.CloudSQLInstance string`(`CLOUD_SQL_INSTANCE`), `type postgres.Dialer interface { Dial(ctx context.Context, instance string) (net.Conn, error) }`, `func postgres.OpenWithDialer(ctx context.Context, url, instance string, d Dialer) (*pgxpool.Pool, error)`, `func postgres.OpenCloudSQL(ctx context.Context, url, instance string) (*pgxpool.Pool, error)`(IAM 인증 `cloudsqlconn` dialer를 만들어 OpenWithDialer, 풀이 닫힐 때 dialer도 닫음), cli의 `openDatabase(ctx, cfg config.Config) (*pgxpool.Pool, error)`
- `config.LoadEngine`은 `APP_ENV`가 비어 있지 않고 `local`이 아니면 `ENGINE_AUDIENCE`를 요구합니다.

- [ ] Step 1: 테스트 — `TestOpenWithDialer_DialsInstance`(가짜 dialer가 실제 테스트 DB로 TCP 연결을 이어 주고, 받은 instance 이름이 같음), `TestLoadEngine_RequiresAudienceOutsideLocal`(`APP_ENV=prod`, audience 없음 → `ENGINE_AUDIENCE` 오류), `TestLoadEngine_LocalAllowsNoAudience`, `TestLoad_ReadsCloudSQLInstance`
- [ ] Step 2: RED 확인 — `go test ./internal/platform/...` 컴파일 실패
- [ ] Step 3: 구현(`go get cloud.google.com/go/cloudsqlconn`), cli 네 곳을 `openDatabase`로
- [ ] Step 4: GREEN — `go test -race ./internal/platform/... ./internal/cli/`
- [ ] Step 5: Commit `feat(server): Cloud SQL IAM 연결과 엔진 audience 필수 (P9, S121)`

### Task 2: Terraform bootstrap

**Files:** Create `server/deploy/terraform/bootstrap/{versions.tf,main.tf,variables.tf,outputs.tf,.terraform.lock.hcl}`, `server/deploy/terraform/README.md`

* 변수: `project_id`, `region`(기본 `asia-northeast3`), `github_repository`(기본 `june20516/myungli-diary`).
* 자원: API 켜기(run, sqladmin, artifactregistry, secretmanager, cloudscheduler, iamcredentials, sts, compute, dns, firebasehosting, cloudresourcemanager, iam, servicenetworking 제외), state bucket `<project_id>-tfstate`(버전 관리, uniform access), Artifact Registry `myungli`, WIF pool `github`·provider `github`(`attribute_condition`은 저장소 고정), `deployer`·`planner` 서비스 계정과 spec §4 권한, WIF 바인딩(deployer: `attribute.environment` staging/prod 그리고 `ref` main, planner: `attribute.event_name == pull_request`).
* 출력: `workload_identity_provider`, `deployer_email`, `planner_email`, `state_bucket`.
* README: bootstrap 절차, GitHub 변수 이름(`GCP_WIF_PROVIDER_<ENV>`, `GCP_DEPLOYER_<ENV>`, `GCP_PLANNER_<ENV>`, `DEPLOY_ENABLED`), Secret 넣는 명령.

- [ ] Step 1: 작성
- [ ] Step 2: 검사 — `docker run --rm -v $PWD:/w -w /w/server/deploy/terraform/bootstrap hashicorp/terraform:1.9 init -backend=false && … validate`, `fmt -check -recursive` Expected: Success
- [ ] Step 3: Commit `feat(server): Terraform bootstrap (P9, S121)`

### Task 3: Terraform env와 tfvars

**Files:** Create `server/deploy/terraform/env/{versions.tf,variables.tf,network.tf,sql.tf,secrets.tf,run.tf,jobs.tf,scheduler.tf,outputs.tf,staging.tfvars,prod.tfvars,.terraform.lock.hcl}`

* backend `gcs`(bucket·prefix `env`는 init 때).
* 변수: `project_id`, `project_number`, `environment`(`staging`|`prod`), `sql_tier`, `deletion_protection`, `server_settings`(map(string), spec §5 tfvars 이름 그대로), `jwt_previous_key_id`, `token_previous_key_id`, `test_login_enabled`(bool).
* `locals.server_env` = `server_settings` + Terraform이 채우는 넷(`ENGINE_ADDR`, `ENGINE_AUDIENCE`, `CLOUD_SQL_INSTANCE`, `DATABASE_URL`) + `GOOGLE_CLOUD_PROJECT`.
* Secret: 고정 6개 + `test_login_enabled`면 `TEST_LOGIN_SECRET` + 이전 키 id가 있으면 해당 `*_PREVIOUS_KEY`(`for_each`). `server-runtime`에 각 Secret의 `secretAccessor`.
* `run.tf`: `engine`(internal, `http2`, gRPC startup probe, `max_instance_request_concurrency` 기본, 8초 grace는 컨테이너가 처리하므로 timeout 설정 없음, 이미지 `…/myungli/engine:current`, invoker는 server-runtime), `server`(placeholder 이미지, `allUsers` invoker, `vpc_access` network interface + `PRIVATE_RANGES_ONLY`, env·Secret). 둘 다 `lifecycle { ignore_changes = [template[0].containers[0].image, client, client_version] }`.
* `jobs.tf`: 세 Job, `args`는 spec §3 명령, 같은 env·Secret·VPC, 이미지 ignore.
* `scheduler.tf`: `retention-daily` `30 4 * * *` `Asia/Seoul`, HTTP target `https://run.googleapis.com/v2/projects/<p>/locations/<r>/jobs/server-retention:run`, OAuth `scheduler-invoker`.
* `outputs.tf`: `engine_url`, `server_url`, `missing_server_settings`(필수인데 빈 값인 이름 목록 — workflow가 읽음).
* tfvars: #607의 값과 지금 아는 공개 값(패키지, 지문, 스토어 URL, Apple bundle id `app.myungli.diary`처럼 저장소에 이미 있는 값만). 나머지는 `""`.

- [ ] Step 1: 작성 — Review Focus 3은 `for_each` 조건으로, 2는 `missing_server_settings` 출력으로
- [ ] Step 2: 검사 — `init -backend=false`, `validate`, `fmt -check` Expected: Success
- [ ] Step 3: Commit `feat(server): Terraform 환경 자원과 tfvars (P9, S121)`

### Task 4: Firebase Hosting과 배포 workflow

**Files:** Create `server/deploy/firebase/firebase.json`, `.github/workflows/deploy-server.yml`, `.github/workflows/deploy-engine.yml`; Modify `server/Dockerfile`(빌드 인자 `GO_TAGS`, 기본 빈 값)

* `firebase.json`: `hosting.public`은 빈 디렉터리 `public`(`.gitkeep`), `rewrites: [{source: "**", run: {serviceId: "server", region: "asia-northeast3"}}]`.
* workflow는 spec §7. `if: vars.DEPLOY_ENABLED == 'true'`로 plan·배포 job을 막고(Review Focus 1), fork PR은 `github.event.pull_request.head.repo.full_name == github.repository`일 때만 plan. server 단계는 `terraform output -json missing_server_settings`가 비어 있을 때만(Review Focus 2). migrate 실패 시 이후 step이 돌지 않도록 `gcloud run jobs execute --wait`(Review Focus 5). action은 major 버전 태그로 고정.
- [ ] Step 1: 작성
- [ ] Step 2: 검사 — `docker run --rm -v $PWD:/repo -w /repo rhysd/actionlint:latest -color` Expected: 출력 없음, 종료 0. `docker build --build-arg GO_TAGS=staging server` 성공
- [ ] Step 3: Commit `feat(server): 배포 workflow와 Firebase Hosting 설정 (P9, S121)`

### Task 5: 결정과 문서

**Files:** Modify `server/docs/decisions.md`(S121), `server/CLAUDE.md`(상태, 다음 할 일), `server/docs/plans/README.md`(P9 줄)

- [ ] Step 1: S121(spec §11), 사용자 영향 `없음`(배포 구조, 데이터·화면 변화 없음)
- [ ] Step 2: `golangci-lint run ./...`, `go test -race -p 2 ./...`, `python3 tools/docs-check/docs_check.py` Expected: 0 issues, FAIL 없음, OK
- [ ] Step 3: Commit `docs(server): S121 배포 구조와 P9 상태 (P9)`
- [ ] Step 4: PR 뒤 지휘에 `to:root` `kind:prep` Issue로 spec §8 사용자 준비 안내 요청
