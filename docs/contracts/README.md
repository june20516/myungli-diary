# 계약 목록

서브 프로젝트 사이에서 서로 기대는 인터페이스입니다. **계약 버전과 상태의 기준은 이 표 하나입니다**(단위 `CLAUDE.md`에는 버전을 적지 않습니다). 지휘 세션이 목록을 관리하고, 각 행은 **제공하는 쪽이 계약 PR에서 직접** 고치거나 새로 넣습니다(`docs/workflow.md` §2). 계약은 제공하는 쪽만 바꾸며, 하위 호환이 깨지는 변경은 `docs/workflow.md` §5.1 절차를 따릅니다.

표의 상태 칸은 지금 상태 한 줄입니다. 버전마다 바뀐 내용은 [`CHANGELOG.md`](CHANGELOG.md)의 계약별 절 맨 위에 적습니다(D131).

| 계약 | 원본 위치 | 제공 | 사용 | 버전 | 상태 | 설계 근거 |
| --- | --- | --- | --- | --- | --- | --- |
| 엔진 gRPC API | `proto/myungli/engine/v1/engine.proto` | core | server, writing (검사기 생성 코드, #144) | v1 | **구현 완료** | 엔진 spec §9, D41 |
| 메시지 키 목록 | `core/message_keys.json` | core | server (콘텐츠 시드 검사), writing (W1 콘텐츠 작성) | - | **구현 완료** | 엔진 spec §10 |
| 근거 참조 형식 (`source_ref`) | 엔진 spec §11 | core | server, app (`evidence` 단계) | - | **구현 완료** | 엔진 spec §11 |
| 엔진 버전 표기 (`engine_version`, `ruleset_version`) | 엔진 spec §12 | core | server (일기 태그 기록, 캐시 키) | ruleset `2026.11.9`, engine `0.1.0` | **구현 완료** | 엔진 spec §12, D31 |
| REST API (앱 ↔ 서버) | `server/api/openapi.yaml` (OpenAPI 3.1, 규칙은 `info.description`) | server | app | 1.13.1 | **freeze** | server spec `server/docs/specs/2026-10-11-server-mvp-design.md`, D26·D59·D60, Issue #63 |
| 디자인 토큰 (색·오행 팔레트·타이포·간격·반경·그라데이션·모션·그림자) | `docs/identity/design/tokens/` (읽는 문서 `tokens/README.md`) | design | app | 1.10.0 | **freeze** | 브랜드 기반 spec §9, design 결정 V1~V13·V42·V57·V58·V67·V74·V84·V86·V93·V98·V102·V111·V115·V121, V1 spec, 같은 날 여러 편 spec, DS1 규칙 spec, DS1 화면 spec |
| 컴포넌트 명세 | `docs/identity/design/components/` (읽는 문서 `components/README.md`, 파일마다 JSON 사실 + MD 설명) | design | app | 8.0.0 | **확정** | V2 spec, 근거 잠금 spec, design 결정 V13~V131, 구현 대응 spec, 로그인 수단·계정 합치기 spec, 같은 날 여러 편 spec, 계정 합치기·구매 내역 spec, 십성 라벨·피드백 spec, W51 상한·시간 칩 spec, 문의 화면 spec, DS1 규칙 spec, DS1 화면 spec |
| 브랜드 기반 | `docs/identity/README.md` | 지휘 | writing, design | - | 확정 (B0) | 브랜드 기반 spec, D38 |
| MVP 화면 목록 (IA) | `docs/ia/screens.json` (읽는 문서 `docs/ia/README.md`) | 지휘 | app, writing, design, server | 5 | **확정** | IA spec, D39·D51·D53·D58·D60·D62·D66·D67·D68·D71·D77, app A6 |
| 슬롯 명세 (원고 표기 포함: `{param}`, `{param:범주}`, 조사 표기 6쌍, 용어 토큰 `[[...]]`) | `docs/identity/writing/slots/` (`_schema.yaml`, `content/`, `ui/`, 읽는 문서 `generated/slot-catalog.md`) | writing | server, app | v1.50 | **확정** | 브랜드 기반 spec §8, W0 spec, writing 결정 W1~W67(W15·W17 D79 개정) |
| 호칭·조사 처리 규칙 (렌더 순서 포함) | `docs/identity/writing/guide/honorific-josa.md`, `rules/josa.yaml` | writing | server (콘텐츠 모듈), app (ui ARB 조사 `josaClass`) | v1.2 | **확정** | D36, W0 spec |
| 라이팅 검사기 (`mlw` CLI, 패키지 `myungli-writing`) | `docs/identity/writing/tools/`. 저장소 루트에서 `uv run --project docs/identity/writing/tools mlw <명령>` | writing | server (시드 CI), app (CI, `check-arb`) | v0.13.0 | **확정** | 브랜드 기반 spec §8, W0 spec |
| 근거 규칙 목록 (`rule_id` → `detail` 키) | `core/evidence_rules.json` (선언 `core/src/myungli_engine/constants/evidence_rules.py`) | core | writing (`evidence.basis`·`explain.today_reason` 키), server | - | **구현 완료** | 엔진 spec §11, Issue #130 |
| 근거 원전 목록 (`source_ref` → 원전 이름·대목·원문) | `core/evidence_sources.json` (생성 `core/src/myungli_engine/references/sources.py`) | core | writing (`evidence.source` 키), server | - | **구현 완료** | 엔진 spec §11, Issue #130 |
| 계산 규칙 지도 (공통 틀, 그룹, 항목별 규칙과 원전, 바탕지식, 불일치 목록) | `core/rules_map.json` (원본 `core/docs/rules-map/rules_map.toml`, 생성 `core/tools/rules_map.py`) | core | root (제품 지도 "계산 규칙" 탭) | `meta.version` 2 | **구현 완료** | Issue #988 |
| 메시지 키별 매개변수 | `core/message_params.json` (키 → 매개변수 이름 목록) | core | writing (슬롯 `params` 대조), server | - | **구현 완료** | D27, `writing-to-root-contracts`, Issue #38 |
| 라운드 원고 (글자 수 측정 근거) | `docs/identity/writing/artifacts/*-round-R*.md` | writing | design (`tools/lengths.py`가 선택 문장으로 상한을 잼) | - | **사용 중** | design `lengths.md`, D73 |
| 법적 문서 원문 (이용약관·개인정보 처리방침) | `docs/legal/<언어>/{terms,privacy}.md` (읽는 문서 `docs/legal/README.md`) | 지휘 | server (`/legal/*` 정적 페이지), app (`getAppConfig`의 주소로 엶) | - | **원문 있음** (시행일은 출시 때 적음. 원문이 바뀌면 `ci-gate` server drift로 알림, #341) | D80, D64, D74 |
| 글자 수 상한 표 | `docs/identity/design/lengths.md` | design | writing (슬롯 `max_length` 대조 테스트) | - | **사용 중** | design `lengths.md`, writing W26 |

## 생성 코드
* proto에서 생성한 코드는 사용하는 서비스마다 자기 디렉터리에 commit합니다(D33).
  * core: `core/src/myungli_engine/_gen/`
  * server: `server/internal/gen/enginev1/` (server P3에서 생성, Issue #63)
* 생성 코드가 원본 proto와 맞는지는 각 서비스의 CI가 검사합니다.
