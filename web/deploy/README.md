# 랜딩 배포

랜딩(`myungli-diary.app`, staging `staging.myungli-diary.app`)은 Firebase Hosting의 web 전용 사이트에 올립니다(WB1, 준비 메모 `docs/specs/2026-11-25-web-landing-design.md` §5). 사용자 준비물은 외부 준비물 E25(#1332)입니다.

| 경로 | 내용 |
| --- | --- |
| `../firebase.json` (`web/`) | Hosting 설정(사이트 target `landing`, `app-ads.txt` 헤더, 캐시, 언어별 404), 로컬 에뮬레이터 포트. Firebase 프로젝트 폴더가 `web/`이고 `public`(`site/dist`)은 그 안이어야 합니다. 밖이면 에뮬레이터는 받아도 `firebase deploy`가 거절합니다(#1379, `site/test/hosting.test.ts`가 미리 잡음) |
| `../.firebaserc` (`web/`) | 프로젝트별 target → 사이트 id |
| `terraform/` | 사이트, 커스텀 도메인, 배포 계정 `web-deployer`, WIF 연결. 사용자가 로컬에서 apply합니다 |
| `.github/workflows/deploy-web.yml` | staging push는 staging, main(승격)은 prod 배포 |

## 환경

| 환경 | Firebase 프로젝트 | Hosting 사이트 | 주소 | GitHub environment | 배포 브랜치 |
| --- | --- | --- | --- | --- | --- |
| staging | `myungli-diary-staging` | `myungli-diary-staging-landing` | `staging.myungli-diary.app` | `web-staging` | `staging` |
| prod | `myungli-diary` | `myungli-diary-landing` | `myungli-diary.app` (`www`는 본 도메인으로) | `web-prod`(필수 승인자) | `main` |

* 사이트 이름은 `<Firebase 프로젝트 id>-<표면>`입니다. WB2 social은 `-social`로 같은 규칙을 씁니다. 사이트 id는 Firebase 전역에서 유일해야 해서, 이미 누가 쓰고 있으면 apply가 실패합니다. 그때는 `-web` 접미로 바꾸고 이 표와 `.firebaserc`를 같이 고칩니다.
* 사이트 이름은 Firebase 안에서 사이트를 구분하는 이름이고 기본 주소 `<사이트 id>.web.app`이 됩니다. Cloudflare에는 이름을 만들지 않고 도메인 DNS 기록만 넣습니다.

## 계정과 권한

* 프로젝트마다 `web-deployer` 서비스 계정을 둡니다. 역할은 `roles/firebasehosting.admin`, `roles/serviceusage.serviceUsageConsumer`뿐이고, server 배포 계정 `deployer`(Cloud Run, SQL 등)와 나눕니다.
* GitHub Actions는 키 없이 Workload Identity로 들어옵니다. pool `github`과 provider는 server bootstrap이 만든 것을 같이 쓰고(저장소 변수 `GCP_WIF_PROVIDER_STAGING`, `GCP_WIF_PROVIDER_PROD` 그대로), 계정 연결은 `env_ref`(environment 이름과 브랜치) 하나만 허용합니다. 그래서 server의 `staging`, `prod` environment job은 `web-deployer`를, web의 job은 server `deployer`를 쓸 수 없습니다.
* **한계:** Hosting 권한은 사이트가 아니라 프로젝트 단위입니다. `web-deployer`는 같은 프로젝트의 다른 Hosting 사이트(api 주소의 기본 사이트)에도 배포할 수 있습니다. 배포 명령은 `--only hosting:landing`으로 랜딩 사이트만 고릅니다.

## 처음 한 번 (사용자, E25)

server bootstrap(`server/deploy/terraform/README.md`)을 이미 apply한 두 프로젝트가 전제입니다(state bucket, WIF pool, Hosting API).

1. `gcloud auth application-default login`
2. 환경마다(staging 먼저):
   ```sh
   cd web/deploy/terraform
   env=staging; project=myungli-diary-staging     # prod: env=prod; project=myungli-diary
   terraform init -reconfigure -backend-config="bucket=${project}-tfstate" -backend-config="prefix=web"
   terraform apply -var-file="$env.tfvars"
   terraform output dns_records
   ```
3. `dns_records`가 비어 있으면 Firebase가 아직 값을 만들지 않은 것이니 잠시 뒤 `terraform apply -refresh-only -var-file="$env.tfvars"`로 새로 읽습니다. Cloudflare DNS에 `dns_records`의 기록을 넣습니다. **프록시는 끕니다**(회색 구름). 켜 두면 Firebase가 인증서를 발급하지 못합니다. 발급은 몇 분에서 하루까지 걸립니다. Firebase 콘솔 Hosting의 사이트 화면에서 도메인 상태가 "연결됨"이 되면 끝입니다.
4. GitHub 저장소 Settings의 Environments에서 `web-staging`(Deployment branches: `staging`)과 `web-prod`(Deployment branches: `main`, Required reviewers: 사용자)를 만듭니다. WIF도 environment와 브랜치를 함께 보지만 이 제한은 이중 장치입니다.
5. 저장소 변수 `WEB_DEPLOY_ENABLED`를 `true`로 둡니다. 그 뒤 staging에 `web/**`가 바뀌거나 `deploy-web`을 staging 브랜치에서 수동 실행하면 배포됩니다.

확인: `curl -sI https://staging.myungli-diary.app/app-ads.txt` → `HTTP/2 200`, `content-type: text/plain; charset=utf-8`.

## 되돌리기

* 배포만 멈춤: 저장소 변수 `WEB_DEPLOY_ENABLED`를 `false`로.
* 이전 판으로: Firebase 콘솔 Hosting의 사이트 출시 기록에서 이전 판을 "롤백"합니다.
* 모두 지움: 같은 init 뒤 `terraform destroy -var-file="$env.tfvars"`. 사이트, 도메인 연결, 계정이 지워지고, 사이트 id는 지운 뒤 한동안 다시 쓸 수 없습니다. Cloudflare 기록은 손으로 지웁니다.

## 로컬에서 보기

`web/`에서 `pnpm e2e`가 빌드 뒤 Hosting 에뮬레이터(포트 47291)로 Playwright를 돌립니다. 눈으로 보려면 빌드한 뒤 `web/`에서 `pnpm exec firebase emulators:start --only hosting --project demo-myungli-web`.
