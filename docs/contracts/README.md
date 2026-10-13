# 계약 목록

서브 프로젝트 사이에서 서로 기대는 인터페이스입니다. 지휘 세션이 목록을 관리합니다. 계약은 **제공하는 쪽만** 바꾸며, 하위 호환이 깨지는 변경은 `docs/workflow.md` §5.1 절차를 따릅니다.

| 계약 | 원본 위치 | 제공 | 사용 | 버전 | 상태 | 설계 근거 |
| --- | --- | --- | --- | --- | --- | --- |
| 엔진 gRPC API | `proto/myungli/engine/v1/engine.proto` | core | server | v1 | **구현 완료** (main 병합 완료, PR #1 `ec4fc90`). RPC 5개: `GetChart`·`GetDaily`·`GetMonthCalendar`·`GetBirthHour`(D58)·`GetInfo`(PR #67). 패키지 `myungli.engine.v1`, 서비스 `MyungliEngine`(이름 변경 PR #77, D63). 지원 범위 양력 1900-01-31 ~ 2099-12-31, 밖이면 `OUT_OF_RANGE` | 엔진 spec §9, D41 |
| 메시지 키 목록 | `core/message_keys.json` | core | server (콘텐츠 시드 검사), writing (W1 콘텐츠 작성) | - | **구현 완료**, 153개 (PR #1 `ec4fc90`, 원국 개인 해석 `personal.*` 60개 PR #67) | 엔진 spec §10 |
| 근거 참조 형식 (`source_ref`) | 엔진 spec §11 | core | server, app (`evidence` 단계) | - | **구현 완료** (PR #1) | 엔진 spec §11 |
| 엔진 버전 표기 (`engine_version`, `ruleset_version`) | 엔진 spec §12 | core | server (일기 태그 기록, 캐시 키) | ruleset `2026.10.2`, engine `0.1.0` | **구현 완료** (PR #1, `GetInfo`로 조회 PR #67) | 엔진 spec §12, D31 |
| REST API (앱 ↔ 서버) | `server/api/openapi.yaml` (OpenAPI 3.1, 규칙은 `info.description`) | server | app | 1.0.0-draft | **초안** (PR #62 `8528022`, operation 37개). freeze는 마일스톤 S3. 그 전까지 하위 호환이 깨지는 변경은 `kind:notice`로 알림 | server spec `server/docs/specs/2026-10-11-server-mvp-design.md`, D26·D59·D60, Issue #63 |
| 디자인 토큰 (색·오행 팔레트·타이포·간격·반경·그라데이션·모션·그림자) | `docs/identity/design/tokens/` (읽는 문서 `tokens/README.md`) | design | app | 1.1.0 | **freeze** (1.0.0 PR #18 `d049e08`, 1.1.0 PR #43 `47a1867`: motion·shadow·V2 역할 색·글자 스타일 2개 추가만). DTCG 2025.10 JSON 5개 파일, Dart 코드 생성은 app | 브랜드 기반 spec §9, design 결정 V1~V13, V1 spec |
| 컴포넌트 명세 | `docs/identity/design/components/` (읽는 문서 `components/README.md`, 파일마다 JSON 사실 + MD 설명) | design | app | 2.1.0 | **확정** (1.0.0 V2 PR #43 `47a1867`, 2.0.0 PR #66 `b1317e4`: 근거 깊이 잠금(D60), 모양 규칙, 글자 수 상한. 2.1.0 PR #83: 문장 조각 `term` 표시(V28), 근거 잠금 슬롯 연결). IA 컴포넌트 41개, 상호작용 패턴 12개, 요소 16개. 검사기 `tools/components.py`가 IA와 대조 | V2 spec, 근거 잠금 spec, design 결정 V13~V27 |
| 브랜드 기반 | `docs/identity/README.md` | 지휘 | writing, design | - | 확정 (B0) | 브랜드 기반 spec, D38 |
| MVP 화면 목록 (IA) | `docs/ia/screens.json` (읽는 문서 `docs/ia/README.md`) | 지휘 | app, writing, design, server | 1 | **확정** (v1, 화면 36·컴포넌트 41·슬롯 120) | IA spec, D39·D51·D53·D58·D60·D62, app A6 |
| 슬롯 명세 (원고 표기 포함: `{param}`, `{param:범주}`, 조사 표기 6쌍, 용어 토큰 `[[...]]`) | `docs/identity/writing/slots/` (`_schema.yaml`, `content/`, `ui/`, 읽는 문서 `generated/slot-catalog.md`) | writing | server, app | v1 | **확정** (W0, PR #36 `7698f52`). 콘텐츠 슬롯 15개(메시지 키 93개), `ui/`는 깊이 이름만. 문장 유형 범위는 D57 | 브랜드 기반 spec §8, W0 spec, writing 결정 W1~W15 |
| 호칭·조사 처리 규칙 (렌더 순서 포함) | `docs/identity/writing/guide/honorific-josa.md`, `rules/josa.yaml` | writing | server (콘텐츠 모듈) | v1 | **확정** (W0, PR #36). 호칭 접미사는 원고에 직접 씀(렌더러는 붙이지 않음) | D36, W0 spec |
| 라이팅 검사기 (`mlw` CLI, 패키지 `myungli-writing`) | `docs/identity/writing/tools/`. 저장소 루트에서 `uv run --project docs/identity/writing/tools mlw <명령>` | writing | server (시드 CI), app (CI, `check-arb`) | v0.1.0 | **확정** (W0, PR #36). 명령 `check`·`check-arb`·`gen-docs`·`gen-week-fixture` | 브랜드 기반 spec §8, W0 spec |
| 메시지 키별 매개변수 | `core/message_params.json` (키 → 매개변수 이름 목록) | core | writing (슬롯 `params` 대조), server | - | **구현 완료**, 153개 키 (PR #57 `d33573e`, PR #67). `message_keys.json`과 키 집합이 같고, 엔진이 판정을 만들 때 선언과 대조함. `message_keys.json` 형식은 그대로 | D27, `writing-to-root-contracts`, Issue #38 |

## 생성 코드
* proto에서 생성한 코드는 사용하는 서비스마다 자기 디렉터리에 commit합니다(D33).
  * core: `core/src/myungli_engine/_gen/`
  * server: `server/internal/gen/enginev1/` (server P3에서 생성, Issue #63)
* 생성 코드가 원본 proto와 맞는지는 각 서비스의 CI가 검사합니다.
