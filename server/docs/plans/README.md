# server 구현 계획 목록

spec: [`../specs/2026-10-11-server-mvp-design.md`](../specs/2026-10-11-server-mvp-design.md)

spec이 서브시스템 9개를 다루므로 계획을 나눕니다. 각 계획은 그 자체로 동작하고 테스트할 수 있는 결과로 끝납니다. 다음 계획은 앞 계획이 병합된 뒤 실제 코드를 보고 씁니다(rolling wave). 앞 계획에서 정한 인터페이스가 다음 계획의 입력이기 때문입니다.

| 순서 | 계획 | spec 절 | 상태 |
| --- | --- | --- | --- |
| P1 | [기반과 REST 계약 초안](2026-10-11-p1-foundation.md): 모듈, 하위 명령, 설정, Clock, 로깅, DB·migration, HTTP 뼈대, 오류 형식, `openapi.yaml` 초안, 생성 코드, CI, 이미지 | §2, §5, §11.1, §12, §13.1 일부 | **완료** |
| P2 | [인증·계정·약관](2026-10-13-p2-auth-account.md): 카카오·Apple 검증, JWT, refresh rotation, 동의, 삭제 예약·복구 | §3.3 계정, §4 | 계획 |
| P3 | 프로필·엔진·캐시: 프로필 검증(호칭 규칙, D41, 엔진 검증), proto 생성, 엔진 클라이언트·대역, `ResultCache`, `ruleset_version` 확인 | §3.2, §3.3 프로필·캐시, §7 | 대기 |
| P4 | 콘텐츠: 시드 변환·적재, 렌더러(조사·호칭·토큰), 선택·순환·돌봄 상한, 값 이름 사전, 데일리·나의 사주·캘린더 응답, 반응 | §6 | 대기 |
| P5 | 일기·일정: soft delete, 복구, 태그 조회, 저장 시 태그·가이드 질문 기록 | §5.3, §3.3 일기 | 대기 |
| P6 | 비로그인·참조: 미리보기, 시진 확인, App Check, 요청 한도, 도시, app-config | §5.3, §3.3 기타 | 대기 |
| P7 | 결제와 권한: RevenueCat webhook·동기화, entitlement 부여 기록, 복원, AdMob SSV 검증과 근거 열람 권한(D60) | §10 | 대기 |
| P8 | Job: precompute, notify(FCM), retention과 익명화 | §8, §9 | 대기 |
| P9 | 배포: staging·prod, Cloud Run service·Jobs·Scheduler, Cloud SQL 연결, OpenTelemetry, 외부 준비 안내 | §13 | 대기 |

P2~P8의 순서는 의존 순서입니다. P2·P3 다음부터는 P5·P6·P7이 서로 기다리지 않습니다.

## 다음 계획에 넘길 메모

P1 실행 중 정한 것 가운데 다음 계획이 알아야 할 것입니다. 근거는 commit 메시지와 코드 주석에 있습니다.

**P2 (인증·계정·약관)**
* 인증 위치: 요청 검증은 라우트마다 strict handler를 감싸고 그 안에서 `AuthenticationFunc`가 돕니다. 인증을 별도 middleware로 두면 검증보다 안쪽이 되어 인증 안 된 요청이 400 필드 상세를 먼저 받습니다. `AuthenticationFunc`에서 인증하거나 `RegisterAPI`가 auth → validate 순으로 감싸게 하고, "토큰 없음 + 잘못된 본문 → 401"을 테스트로 고정합니다.
* 401 응답: 일반 `problem.Write`는 `WWW-Authenticate`를 붙이지 않습니다. bearer 인증 실패에는 `problem.WriteBearerChallenge`를 씁니다.
* 오류 경로 단일화: strict handler의 오류는 `httpapi.Error{Status, Code}` 같은 타입을 반환하고 `ResponseErrorHandlerFunc`에서 `problem.Write`로 쓰는 한 갈래로 만듭니다. 핸들러 오류 로그가 pgx 오류 detail로 개인정보를 남기지 않게 정제 규칙을 둡니다.
* `errors[].code` 통일: 지금 본문 형식 오류는 `errors[]` 없이 400을 내고, 경로 parameter는 code가 `type`으로 나옵니다. 필드별 code 체계를 정해 맞춥니다.
* serve가 DB를 열기 시작하면 `RequireDatabase`·`postgres.Open`을 붙이고, "DB가 꺼져 있으면 5초 안에 0이 아닌 코드로 종료"를 serve에도 테스트로 고정합니다.
* 요청 검증은 parameter 기본값을 채우지 않습니다. `limit` 같은 기본값은 핸들러가 적용합니다.
* 상태-값 짝 위반(422 `request.inconsistent`, `required_by_status`·`forbidden_by_status`)과 422 `date.invalid`(`LunarOrSolarDate`만)는 계약에만 있고 아직 구현이 없습니다.

**P3 (프로필·엔진·캐시)**
* 범위에 일부만 걸친 달(1900년 1월)은 엔진이 `OUT_OF_RANGE`를 내므로 422 `date.out_of_range`로 매핑합니다.

**P7 (결제와 권한)**
* AdMob SSV 서명은 원본 쿼리 문자열로 검증합니다. 요청 검증 미들웨어는 RawQuery를 바꾸지 않도록 설정되어 있고(`SkipSettingDefaults`) 테스트로 고정되어 있습니다.

**P9 (배포)**
* Cloud Run은 `GOOGLE_CLOUD_PROJECT`를 자동으로 넣지 않으므로 배포 설정에 명시해야 로그의 trace 상관관계가 켜집니다. `X-Cloud-Trace-Context`만 오는 경로가 있는지 확인합니다.
* Cloud SQL Go connector를 쓰려면 `postgres.Open`이 `*pgxpool.Config`나 dial 옵션을 받도록 바꿉니다.
* ci-gate 연결 2단계(지휘)가 끝나면 `server.yml`의 `pull_request`·`push` 트리거를 지웁니다(3단계).
* 요청 검증은 kin-openapi가 3.1 문서에서 format을 검사하지 않아 버전만 3.0.3으로 낮춘 계약 사본으로 합니다. 계약 테스트가 3.0 Schema 키워드 allowlist로 이 전제를 지킵니다.
