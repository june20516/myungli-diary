# server — 메인 API 서버 (Go)

이 디렉터리에서 시작한 세션은 **server 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 인증: JWT, 소셜 로그인 1~2개 (04 §4.1)
* 사용자 프로필: 출생 정보 저장. 생년월일시, 음력·윤달(KASI 한국 음력, D41), 시간 모름, 성별, 출생 시간대·(선택) 경도 (D18·D29). 호칭 필수 (D36). 생년월일 지원 범위 양력 1900-01-31 ~ 2099-12-31 (D41)
* 일기 CRUD: 저장 시 엔진의 태그 키 전체와 `ruleset_version`을 함께 기록 (엔진 spec §7.7·§12). **하루 1편**(날짜 유일), 지난 날 쓰기 가능, 미래 불가 (D49). 태그별 일기 조회 (D47①)
* 기기 간 동기화: MVP는 앱의 로컬 초안만입니다. 저장은 온라인에서만 하고, 동기화·충돌 처리는 Phase 2입니다 (D47②)
* 기본 일정 CRUD: 제목·날짜·종일 또는 시간·메모 (D47③). 반복·일정 알림·외부 캘린더 연동은 범위 밖
* 로그인 없는 미리보기 요청 하나(입력을 저장하지 않음), 새 계정 약관 동의 (D50)
* 도시 목록(시간대·경도, D29·D47⑤), 계정 삭제, 최소 앱 버전 응답 (IA spec §10)
* **수익 (D53·D54):** 만료일이 있는 entitlement 모델(구독으로 넓혀 쓸 수 있게), 영수증 검증(RevenueCat webhook 기본안), 광고 제거 여부 응답. 상품은 1개월 광고 제거권(자동 갱신 없음, 잠정 ₩2,500)이며 구독 결제는 MVP 이후입니다
* **콘텐츠 모듈:** 엔진의 메시지 키를 언어별 문장으로 변환합니다. 템플릿은 PostgreSQL에 저장하고 버전을 관리하며, 시드 파일로 초기화합니다. 언어는 한국어·영어·일본어입니다 (D27·D28). 문장 유형(`advice`·`state`·`care`) 순환과 문장 반응(좋아요) 저장 (D40), 호칭 접미사·조사 처리 (D36, 규칙은 writing W0이 제공)
* 엔진 gRPC 클라이언트 (D26), 시간대별 배치와 Redis 캐시. 캐시 키에 `ruleset_version`을 넣습니다 (D31)
* 아침 운세 알림 발송 (D18-⑨)
* 앱을 위한 REST/JSON API (D26)
* **MVP 범위 밖:** LLM 기능은 Phase 2 유료입니다 (D22·D23). 목적별 택일, 외부 캘린더 연동, 다른 날 전체 풀이(D47⑥), 구독 결제(D53)도 범위 밖입니다

## 고칠 수 있는 곳
`server/`, `.github/workflows/server.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:server`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| `proto/myungri/engine/v1/engine.proto` | **사용** | core |
| `core/message_keys.json` | **사용** (콘텐츠 시드가 모든 키를 3개 언어로 갖췄는지 검사) | core |
| REST API v1 (위치는 설계 때 정하고 `docs/contracts/README.md`에 등록 요청) | **제공** | app |
| 슬롯 명세, 호칭·조사 처리 규칙, 라이팅 검사기 | **사용** (W0 이후) | writing |
| MVP 화면 목록 (IA) `docs/ia/screens.json` v1 | **참고** (`source: content` 슬롯이 콘텐츠 모듈의 템플릿 범위) | 지휘 |

## 현재 상태 (2026-10-11, 지휘 세션 작성)
* **설계(S1) 착수 가능**입니다. 디렉터리는 비어 있습니다. 수익화 사이클 M0가 끝나 MVP 범위가 다시 확정됐습니다(D53·D54).
* 엔진 계약 상태: **구현 완료** (main 병합 완료, PR #1 `ec4fc90`). 계약 메모는 Issue #3(원문 보관: `docs/coordination/2026-10-10-core-to-server-engine-proto-v1.md`)에 있습니다.
* 받은 notice: Issue #7 (D36·D37·D40), S1 착수 안내 Issue(마일스톤 S1). 앞으로 받은 요청은 `gh issue list --label to:server`.
* **지휘 미결 두 가지가 S1 범위에 걸려 있습니다:** 소셜 로그인 제공자, 서버·엔진 배포 플랫폼(`docs/roadmap.md` "지휘 세션 미결"). spec을 쓰다 이 결정이 필요해지면 `to:root` Issue로 올립니다.

## 다음 할 일
1. 읽을 것:
   - `docs/background/` 00~06, 특히 01·02·04
   - `docs/decisions.md` (특히 D47~D54)
   - 엔진 spec `core/docs/specs/2026-10-10-myungri-engine-design.md` §9~§12 (내가 쓸 계약)
   - IA spec `docs/specs/2026-10-11-ia-design.md` §10 (server 범위), `docs/ia/README.md`
   - 수익화 사이클 `docs/business/cycles/2026-10-11-launch-payment.md` §2.2·§4 (결제·entitlement)
2. worktree와 브랜치를 만들고 그 안에서 세션을 시작합니다. 원래 checkout은 다른 세션이 쓰고 있을 수 있으므로, 저장소 루트에서 그대로 실행합니다.
   ```
   git fetch origin
   git worktree add ../myungli-diary-server -b server/design --no-track origin/main
   cd ../myungli-diary-server && git status -sb && cd server && claude
   ```
3. brainstorming으로 server spec을 작성합니다 → `server/docs/specs/`
4. REST API v1의 초안이 정해지면 `from:server`·`to:root` Issue로 계약 등록을 요청합니다. app이 이 계약에 기대어 개발합니다.
