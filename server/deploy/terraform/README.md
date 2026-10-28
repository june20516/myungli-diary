# 배포 Terraform

설계는 [`server/docs/specs/2026-10-28-p9-deploy-design.md`](../../docs/specs/2026-10-28-p9-deploy-design.md), 결정은 S121입니다.

| 디렉터리 | 누가 apply | 내용 |
| --- | --- | --- |
| `bootstrap/` | 사용자, 프로젝트마다 로컬에서 한 번 | API, state bucket, Artifact Registry, WIF, `deployer`·`planner` |
| `env/` | GitHub Actions(`deploy-server.yml`) | VPC, Cloud SQL, Secret 틀, Cloud Run 엔진·server, Job, Scheduler |

## 처음 한 번 (프로젝트마다)

1. `gcloud auth application-default login`
2. `cd server/deploy/terraform/bootstrap`
3. `terraform init`
4. `terraform apply -var project_id=myungli-diary-staging` (prod는 `myungli-diary`)
   * state 파일은 이 디렉터리에 남습니다. 공개 저장소이므로 commit하지 않고(`.gitignore`), 잃어버리지 않게 따로 보관합니다.
   * 두 프로젝트를 차례로 apply하려면 프로젝트마다 `terraform workspace new <env>`로 state를 나눕니다.
5. 출력값을 GitHub 저장소 변수로 넣습니다.

| 변수 | 값 |
| --- | --- |
| `GCP_WIF_PROVIDER_STAGING`, `GCP_WIF_PROVIDER_PROD` | `workload_identity_provider` |
| `GCP_DEPLOYER_STAGING`, `GCP_DEPLOYER_PROD` | `deployer_email` |
| `GCP_PLANNER_STAGING`, `GCP_PLANNER_PROD` | `planner_email` |
| `DEPLOY_ENABLED` | `true` (두 프로젝트 bootstrap과 아래 준비가 끝난 뒤) |

6. GitHub environment `staging`, `prod`를 만들고, 둘 다 "Deployment branches"를 `main`으로 제한합니다. prod에는 필수 승인자를 둡니다. WIF는 environment 값으로 `deployer`를 묶으므로 이 제한이 main 전용 조건을 맡습니다.
7. Secret 값을 넣습니다. Secret 틀은 첫 `deploy-server` 실행(env apply)이 만들고, server 배포는 값이 들어올 때까지 건너뜁니다.

```sh
printf '%s' "<값>" | gcloud secrets versions add JWT_SIGNING_KEY --project <프로젝트> --data-file=-
```

Secret 목록: `JWT_SIGNING_KEY`, `TOKEN_ENCRYPTION_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_PRIVATE_KEY`, `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`, staging만 `TEST_LOGIN_SECRET`. 키 교체 때는 tfvars에 이전 키 id를 넣으면 `JWT_PREVIOUS_KEY`·`TOKEN_PREVIOUS_KEY` 틀이 생깁니다.

## 첫 배포 순서

bootstrap → `deploy-engine`(`workflow_dispatch`, 엔진 이미지 `engine:current` push) → `deploy-server`(env apply가 엔진 서비스를 만들고 server를 배포).

## 로컬 검사

```sh
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform/env hashicorp/terraform:1.17 init -backend=false
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform/env hashicorp/terraform:1.17 validate
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform hashicorp/terraform:1.17 fmt -check -recursive
```
