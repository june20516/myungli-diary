# 배포 뒤 조합 확인 (D147, S169)

server나 엔진을 배포하면 workflow 끝에서 두 가지를 확인합니다. 스크립트는 `server/deploy/compose-check.sh`입니다.

| 단계 | 무엇을 보나 | 실패하면 |
| --- | --- | --- |
| 판 맞춤 확인 | 그 환경의 server, 엔진 이미지 commit을 요약에 적고, 배포한 commit의 `server/`, `core/` 내용과 다른지 봅니다 | 경고만 합니다. `deploy-server`는 엔진이 뒤처졌으면 같은 실행에서 엔진을 배포합니다(`staging-engine`, `prod-engine` job, prod는 승인 필요) |
| 조합 확인 | Job `server-smoke`(`server job smoke`)가 고정된 시험 출생 정보로 오늘(순환 변주 전부), 달력, 나의 사주 화면을 세 언어와 근거 잠김, 열림으로 조립합니다. 계정, 선택 기록, 결과 캐시를 만들지 않고 엔진을 실제로 부릅니다 | workflow가 실패합니다. 자동으로 되돌리지 않습니다 |

한쪽이 뒤처졌으면 조합 확인을 미룹니다. 옛 판과의 조합을 확인해도 의미가 없기 때문입니다. 미룬 확인은 뒤처진 쪽 배포가 끝난 뒤 그 workflow가 돌립니다.

## 조합 확인이 실패했을 때

1. 실패한 workflow 요약의 "조합 확인 실패"를 엽니다. 실패 칸(슬롯, 문장 키, 변주, 언어, 원인)은 Job 로그에 있습니다.

   ```sh
   gcloud logging read 'resource.type="cloud_run_job" AND resource.labels.job_name="server-smoke" AND severity>=ERROR' \
     --project <프로젝트> --freshness 1h --limit 50 --format='value(timestamp,jsonPayload.message,jsonPayload.slot,jsonPayload.key,jsonPayload.variant,jsonPayload.lang,jsonPayload.error)'
   ```

2. 원인이 판 차이(엔진이나 server가 뒤처짐)면 뒤처진 쪽을 배포합니다. 요약의 "판 맞춤 확인" 표에 두 commit이 있습니다.
   * 엔진: `deploy-engine`을 그 환경의 브랜치(staging은 `staging`, prod는 `main`)에서 `workflow_dispatch`로 돌립니다.
   * server: `deploy-server`를 같은 방식으로 돌립니다.
3. 원인이 원고 누락이나 렌더 오류면 사용자 화면에서도 그 문장이 빠집니다. 바로 되돌릴지 정한 뒤 고치는 PR을 냅니다.
4. 되돌리기(server): 이전 리비전으로 트래픽을 옮깁니다. migrate가 이미 돌았으므로, 이전 server가 새 스키마와 함께 도는지 먼저 확인합니다.

   ```sh
   gcloud run revisions list --service server --region asia-northeast3 --project <프로젝트> --limit 3
   gcloud run services update-traffic server --to-revisions <이전 리비전>=100 --region asia-northeast3 --project <프로젝트>
   ```

   엔진은 상태가 없어 같은 명령(`--service engine`, `update-traffic engine`)으로 되돌릴 수 있습니다. 다음 배포는 트래픽을 최신으로 다시 돌립니다.

## 손으로 돌리기

```sh
gcloud run jobs execute server-smoke --wait --region asia-northeast3 --project <프로젝트>
```
