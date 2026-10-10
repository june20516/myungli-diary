# 계약 목록

서브 프로젝트 사이에서 서로 기대는 인터페이스입니다. 지휘 세션이 목록을 관리합니다. 계약은 **제공하는 쪽만** 바꾸며, 하위 호환이 깨지는 변경은 `docs/workflow.md` §5.1 절차를 따릅니다.

| 계약 | 원본 위치 | 제공 | 사용 | 버전 | 상태 | 설계 근거 |
| --- | --- | --- | --- | --- | --- | --- |
| 엔진 gRPC API | `proto/myungri/engine/v1/engine.proto` | core | server | v1 | **구현 완료** (main 병합 완료, PR #1 `ec4fc90`). 지원 범위 양력 1900-01-31 ~ 2099-12-31, 밖이면 `OUT_OF_RANGE` | 엔진 spec §9, D41 |
| 메시지 키 목록 | `core/message_keys.json` | core | server (콘텐츠 시드 검사), writing (W1 콘텐츠 작성) | - | **구현 완료**, 93개 (main 병합 완료, PR #1 `ec4fc90`) | 엔진 spec §10 |
| 근거 참조 형식 (`source_ref`) | 엔진 spec §11 | core | server, app (`evidence` 단계) | - | **구현 완료** (PR #1) | 엔진 spec §11 |
| 엔진 버전 표기 (`engine_version`, `ruleset_version`) | 엔진 spec §12 | core | server (일기 태그 기록, 캐시 키) | ruleset `2026.10.1`, engine `0.1.0` | **구현 완료** (PR #1) | 엔진 spec §12, D31 |
| REST API (앱 ↔ 서버) | (server 설계 때 정함) | server | app | v1 | 미설계 (S3) | D26 |
| 디자인 토큰 (색·오행 팔레트·타이포·간격·반경·그라데이션) | `docs/identity/design/tokens/` (읽는 문서 `tokens/README.md`) | design | app | 1.0.0 | **freeze** (main 병합 완료, PR #18 `d049e08`). DTCG 2025.10 JSON 5개 파일, Dart 코드 생성은 app | 브랜드 기반 spec §9, design 결정 V1~V12, V1 spec |
| 브랜드 기반 | `docs/identity/README.md` | 지휘 | writing, design | - | 확정 (B0) | 브랜드 기반 spec, D38 |
| MVP 화면 목록 (IA) | `docs/ia/screens.json` (읽는 문서 `docs/ia/README.md`) | 지휘 | app, writing, design, server | 1 | **확정** (v1, 화면 34·컴포넌트 41·슬롯 100) | IA spec, D39·D51·D53 |
| 슬롯 명세 (원고 표기 포함: `{param}`, `{param:범주}`, 조사 표기 6쌍, 용어 토큰 `[[...]]`) | `docs/identity/writing/slots/` (`_schema.yaml`, `content/`, `ui/`, 읽는 문서 `generated/slot-catalog.md`) | writing | server, app | v1 | **확정** (W0, PR #36 `7698f52`). 콘텐츠 슬롯 15개(메시지 키 93개), `ui/`는 깊이 이름만. 문장 유형 범위는 D57 | 브랜드 기반 spec §8, W0 spec, writing 결정 W1~W15 |
| 호칭·조사 처리 규칙 (렌더 순서 포함) | `docs/identity/writing/guide/honorific-josa.md`, `rules/josa.yaml` | writing | server (콘텐츠 모듈) | v1 | **확정** (W0, PR #36). 호칭 접미사는 원고에 직접 씀(렌더러는 붙이지 않음) | D36, W0 spec |
| 라이팅 검사기 (`mlw` CLI, 패키지 `myungli-writing`) | `docs/identity/writing/tools/`. 저장소 루트에서 `uv run --project docs/identity/writing/tools mlw <명령>` | writing | server (시드 CI), app (CI, `check-arb`) | v0.1.0 | **확정** (W0, PR #36). 명령 `check`·`check-arb`·`gen-docs`·`gen-week-fixture` | 브랜드 기반 spec §8, W0 spec |
| 메시지 키별 매개변수 | `core/message_params.json` (예정, 키 → 매개변수 이름 목록) | core | writing (슬롯 `params` 대조), server | - | 요청함 (Issue #38). `message_keys.json` 형식은 그대로 두고 새 파일로 추가 | D27, `writing-to-root-contracts` |

## 생성 코드
* proto에서 생성한 코드는 사용하는 서비스마다 자기 디렉터리에 commit합니다(D33).
  * core: `core/src/myungri_engine/_gen/`
  * server: server 설계 때 정합니다.
* 생성 코드가 원본 proto와 맞는지는 각 서비스의 CI가 검사합니다.
