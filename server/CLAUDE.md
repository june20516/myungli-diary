# server — 메인 API 서버 (Go)

이 디렉터리에서 시작한 세션은 **server 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 인증: JWT, 소셜 로그인 1~2개 (04 §4.1)
* 사용자 프로필: 출생 정보 저장. 생년월일시, 음력·윤달(KASI 한국 음력, D41), 시간 모름, 성별, 출생 시간대·(선택) 경도 (D18·D29). 호칭 필수 (D36). 생년월일 지원 범위 양력 1900-01-31 ~ 2099-12-31 (D41)
* 일기 CRUD: 저장 시 엔진의 태그 키 전체와 `ruleset_version`을 함께 기록 (엔진 spec §7.7·§12)
* 기기 간 동기화: 타임스탬프 기반 Sync-token (02 §2.2). MVP 포함 여부는 루트 미결입니다(`docs/roadmap.md`)
* **콘텐츠 모듈:** 엔진의 메시지 키를 언어별 문장으로 변환합니다. 템플릿은 PostgreSQL에 저장하고 버전을 관리하며, 시드 파일로 초기화합니다. 언어는 한국어·영어·일본어입니다 (D27·D28). 문장 유형(`advice`·`state`·`care`) 순환과 문장 반응(좋아요) 저장 (D40), 호칭 접미사·조사 처리 (D36, 규칙은 writing W0이 제공)
* 엔진 gRPC 클라이언트 (D26), 시간대별 배치와 Redis 캐시. 캐시 키에 `ruleset_version`을 넣습니다 (D31)
* 아침 운세 알림 발송 (D18-⑨)
* 앱을 위한 REST/JSON API (D26)
* **MVP 범위 밖:** LLM 기능은 Phase 2 유료입니다 (D22·D23). 목적별 택일, 외부 캘린더 연동도 범위 밖입니다

## 고칠 수 있는 곳
`server/`, `.github/workflows/server.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:server`). 그 밖은 읽기만 합니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| `proto/myungri/engine/v1/engine.proto` | **사용** | core |
| `core/message_keys.json` | **사용** (콘텐츠 시드가 모든 키를 3개 언어로 갖췄는지 검사) | core |
| REST API v1 (위치는 설계 때 정하고 `docs/contracts/README.md`에 등록 요청) | **제공** | app |
| 슬롯 명세, 호칭·조사 처리 규칙, 라이팅 검사기 | **사용** (W0 이후) | writing |

## 현재 상태 (2026-10-10, 지휘 세션 작성)
* **설계 시작 전**입니다. 디렉터리가 비어 있습니다.
* 엔진 계약 상태: **구현 완료** (main 병합 완료, PR #1 `ec4fc90`). 계약 메모는 Issue #3(원문 보관: `docs/coordination/2026-10-10-core-to-server-engine-proto-v1.md`)에 있습니다.
* 받은 notice: Issue #7 (D36·D37·D40). 앞으로 받은 요청은 `gh issue list --label to:server`.

## 다음 할 일
1. 읽을 것:
   - `docs/background/` 00~06, 특히 01·02·04
   - `docs/decisions.md`
   - 엔진 spec `core/docs/specs/2026-10-10-myungri-engine-design.md` §9~§12 (내가 쓸 계약)
2. worktree와 브랜치를 만들고 그 안에서 세션을 시작합니다. 원래 checkout은 다른 세션이 쓰고 있을 수 있으므로, 저장소 루트에서 그대로 실행합니다.
   ```
   git fetch origin
   git worktree add ../myungli-diary-server -b server/design --no-track origin/main
   cd ../myungli-diary-server/server && claude
   ```
3. brainstorming으로 server spec을 작성합니다 → `server/docs/specs/`
   - 먼저 루트 미결(`docs/roadmap.md` "지휘 세션 미결")에서 server에 걸린 항목을 지휘 세션에 확인합니다.
4. REST API v1의 초안이 정해지면 `server-to-root` 요청으로 계약 등록을 요청합니다. app이 이 계약에 기대어 개발합니다.
