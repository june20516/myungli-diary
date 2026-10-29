# 배포 Terraform

설계는 [`server/docs/specs/2026-10-28-p9-deploy-design.md`](../../docs/specs/2026-10-28-p9-deploy-design.md), 결정은 S121입니다.

| 디렉터리 | 누가 apply | 내용 |
| --- | --- | --- |
| `bootstrap/` | 사용자, 프로젝트마다 로컬에서 한 번 | API, state bucket, Artifact Registry, WIF, `deployer`·`planner` |
| `env/` | GitHub Actions(`deploy-server.yml`) | VPC, Cloud SQL, Secret 틀, Cloud Run 엔진·server, Job, Scheduler |

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
4. `terraform apply -var-file="$env.tfvars"` (`staging.tfvars`, `prod.tfvars`에 프로젝트와 environment가 짝으로 있습니다. deployer는 그 environment의 main job만 씁니다)
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

Secret 목록: `JWT_SIGNING_KEY`, `TOKEN_ENCRYPTION_KEY`, `KAKAO_ADMIN_KEY`, `APPLE_PRIVATE_KEY`, `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH`, staging만 `TEST_LOGIN_SECRET`. 키 교체 때는 tfvars에 이전 키 id를 넣으면 `JWT_PREVIOUS_KEY`·`TOKEN_PREVIOUS_KEY` 틀이 생깁니다.

### 새 프로젝트

state bucket은 bootstrap이 만들지만 backend가 그 bucket을 쓰므로, 처음에는 bucket만 손으로 만들고 Terraform으로 가져옵니다.

```sh
gcloud storage buckets create "gs://${project}-tfstate" --project "$project" --location asia-northeast3 \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update "gs://${project}-tfstate" --versioning
terraform init -reconfigure -backend-config="bucket=${project}-tfstate" -backend-config="prefix=bootstrap"
terraform import -var-file="$env.tfvars" google_storage_bucket.tfstate "${project}-tfstate"
terraform apply -var-file="$env.tfvars"
```

## 첫 배포 순서

bootstrap → `deploy-engine`(`workflow_dispatch`, 엔진 이미지 `engine:current` push) → `deploy-server`(env apply가 엔진 서비스를 만들고 server를 배포). `engine:current`가 없으면 `deploy-server`는 요약만 남기고 끝납니다. Scheduler `retention-daily`는 첫 server 배포 때 켜집니다.

## 로컬 검사

```sh
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform/env hashicorp/terraform:1.17 init -backend=false
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform/env hashicorp/terraform:1.17 validate
docker run --rm -v "$PWD":/w -w /w/server/deploy/terraform hashicorp/terraform:1.17 fmt -check -recursive
```
