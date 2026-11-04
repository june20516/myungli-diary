# 알림 대응 절차 (O1)

알림 메일이 오면 이 문서를 봅니다. 알림 정책은 `server/deploy/terraform/env/monitoring.tf`, 받는 곳과 예산은 `server/deploy/terraform/bootstrap/observability.tf`이고 기준은 결정 S133입니다. 메일 본문 끝의 괄호(예: `(5xx)`)가 아래 절 이름입니다.

## 0. 먼저 할 일
1. 메일 제목에서 **환경**(프로젝트 `myungli-diary-staging` 또는 `myungli-diary`)과 대상을 확인합니다.
2. 아래 명령의 `P`를 그 프로젝트로 둡니다.
   ```sh
   P=myungli-diary-staging   # prod면 myungli-diary
   R=asia-northeast3
   ```
3. 사용자에게 보이는 장애인지 판단합니다: 공개 주소 `GET /health`가 200인지(`curl -i https://api-staging.myungli-diary.app/health`, prod는 `api.myungli-diary.app`).
4. 알림이 끝나면(정책이 회복되면) 회복 메일도 옵니다. 원인과 조치를 해당 Issue나 새 Issue(`to:server`)에 남깁니다.

## 1. 5xx
server나 엔진이 5분 동안 5xx를 5건 넘게 냈습니다.
* 어느 경로인지: 요청 로그에서 5xx만 봅니다.
  ```sh
  gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="server" AND jsonPayload.status>=500' \
    --project $P --freshness 30m --limit 50 --format='value(timestamp,jsonPayload.route,jsonPayload.status,jsonPayload.traceId)'
  ```
* 왜인지: 같은 시각의 Error 로그를 봅니다(traceId로 이어 봄).
  ```sh
  gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="server" AND severity>=ERROR' \
    --project $P --freshness 30m --limit 50 --format=json
  ```
* 자주 있는 원인
  * 503 `service.unavailable`이 엔진 관련이면: 엔진 서비스 로그(`service_name="engine"`)에서 시작 실패, 메모리 초과(`Memory limit`), 새 revision 실패를 봅니다. 엔진 배포 직후면 `deploy-engine` 실행을 봅니다.
  * DB 오류면: 아래 Cloud SQL 절을 함께 봅니다.
  * 새 server revision 직후면: 직전 revision으로 트래픽을 돌립니다.
    ```sh
    gcloud run revisions list --service server --project $P --region $R --limit 5
    gcloud run services update-traffic server --to-revisions <직전 revision>=100 --project $P --region $R
    ```
    되돌린 뒤 main에 고치는 PR을 올리고, 배포가 끝나면 `--to-latest`로 돌려 둡니다.
* staging에서 이 알림을 일부러 내는 방법(알림 확인용): `GET /test/v1/server-error`에 테스트 로그인 비밀 헤더를 붙여 5분 안에 6번 부릅니다(S133).

## 2. 지연
지연 p95가 15분 동안 기준(server 3초, 엔진 2초)을 넘었습니다. cold start 한 번으로는 울리지 않게 잡았으므로(S132) 계속 느린 상태입니다.
* 느린 경로: 요청 로그의 `latencyMs`가 큰 요청을 봅니다.
  ```sh
  gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="server" AND jsonPayload.latencyMs>=3000' \
    --project $P --freshness 1h --limit 50 --format='value(timestamp,jsonPayload.route,jsonPayload.latencyMs)'
  ```
* 엔진 호출이 느린지(데일리, 캘린더, 나의 사주): 엔진의 지연도 같이 올랐으면 엔진 쪽입니다. DB가 느린지는 Cloud SQL CPU와 연결 수를 봅니다.
* 인스턴스가 늘지 않고 요청이 쌓이는지: 아래 인스턴스 절.

## 3. 인스턴스
인스턴스 수가 기본 상한 100의 80%를 넘었습니다. 상한에 닿으면 새 요청이 429로 거절됩니다.
* 실제 사용자 증가인지, 반복 요청(재시도 폭주, 봇)인지 봅니다: 요청 로그를 경로와 IP별로 셉니다.
* 반복 요청이면 원인 경로를 Issue로 남기고(app 재시도라면 `to:app`), 급하면 상한을 잠시 올립니다(`gcloud run services update server --max-instances <값>`). 올린 값은 Terraform에 반영해야 다음 배포에서 되돌아가지 않습니다. 용량 값의 기준은 L1입니다.

## 4. Cloud SQL
CPU가 10분 동안 80%를 넘었거나, 연결 수가 `max_connections`(staging 25, prod 100)의 80%를 넘었습니다.
* 연결 수: server 인스턴스 수 × 연결 풀 크기가 상한에 가까운지 봅니다. 인스턴스가 늘어서라면 인스턴스 절과 같이 봅니다.
* 느린 쿼리와 잠금: Cloud SQL 콘솔의 Query insights, 또는 `gcloud sql operations list --instance myungli-pg --project $P`로 진행 중인 작업(백업, 유지보수)을 봅니다.
* 배치가 겹쳤는지: `job precompute`(UTC 0분, 30분), `job notify`(5분마다), `job retention`(KST 04:30) 실행 시각과 맞춰 봅니다.

## 5. Job
Cloud Run Job 실행이 실패했습니다. 메일의 `job_name`이 대상입니다.
* 실패한 실행과 로그
  ```sh
  J=server-retention   # 메일의 job_name
  gcloud run jobs executions list --job $J --project $P --region $R --limit 5
  gcloud logging read "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"$J\" AND severity>=WARNING" \
    --project $P --freshness 2h --limit 30 --format='value(timestamp,severity,jsonPayload.message,jsonPayload.error)'
  ```
* Job별 의미
  * `server-notify`: 그 5분 창의 아침 알림이 다 나가지 못했을 수 있습니다. 같은 날 같은 사람에게 두 번 보내지 않으므로(S129) 다음 실행이 남은 대상을 보냅니다. 실패가 이어지면 FCM 오류(로그의 `failed`, `token_invalid`)를 봅니다.
  * `server-precompute`: 다음 날 결과가 미리 계산되지 않아 첫 요청이 엔진을 부릅니다. 사용자 영향은 지연뿐입니다.
  * `server-retention`: 보관 기간 정리가 하루 밀립니다. 이어지면 개인정보 보관 기간(S113)을 넘기므로 그날 안에 고칩니다. 단계별 오류가 로그에 따로 있습니다.
  * `server-migrate`, `server-seed`: 배포 중 실패이며 server 배포가 멈춥니다. 배포 workflow 실행을 봅니다.
* 엔진 호출 실패(`engine timeout`, `engine unavailable`)면 엔진 서비스 로그를 봅니다. cold start는 S132로 기다리게 되어 있으므로, 그래도 실패하면 엔진 시작 자체를 봅니다.
* 고친 뒤 다시 돌리기: `gcloud run jobs execute $J --project $P --region $R --wait`

## 6. uptime
공개 주소 `GET /health`가 여러 지역에서 실패합니다(DB 확인을 포함, S127).
* 공개 주소와 Cloud Run 직접 주소를 나눠 봅니다.
  ```sh
  curl -i https://api-staging.myungli-diary.app/health
  curl -i "$(gcloud run services describe server --project $P --region $R --format='value(status.url)')/health"
  ```
  * 직접 주소도 실패: server나 DB 문제입니다. 1절, 4절을 봅니다.
  * 직접 주소는 200, 공개 주소만 실패: Firebase Hosting(S117, S130)이나 도메인과 인증서 문제입니다. Firebase 콘솔 Hosting 화면과 마지막 `firebase deploy`를 봅니다.

## 7. 예산
이 프로젝트의 월 비용이 예산의 50%, 90%, 100%에 닿았거나 100%를 넘을 것으로 예측됩니다. 금액은 저장소에 적지 않습니다(D74).
* 결제 콘솔의 보고서에서 서비스별(Cloud Run, Cloud SQL, 로그, 네트워크) 비용을 봅니다.
* 갑자기 늘었으면 인스턴스 수, 요청 수, 로그 양을 같은 기간과 맞춰 봅니다. 원인과 조치를 지휘에게 Issue로 올립니다.
* 예산 금액을 바꾸려면 로컬 값 파일(`docs/local-values.md` K14)을 고치고 bootstrap을 다시 apply합니다.
