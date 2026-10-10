# 계약 목록

서브 프로젝트 사이에서 서로 기대는 인터페이스입니다. 지휘 세션이 목록을 관리합니다. 계약은 **제공하는 쪽만** 바꾸며, 하위 호환이 깨지는 변경은 `docs/workflow.md` §5.1 절차를 따릅니다.

| 계약 | 원본 위치 | 제공 | 사용 | 버전 | 상태 | 설계 근거 |
| --- | --- | --- | --- | --- | --- | --- |
| 엔진 gRPC API | `proto/myungri/engine/v1/engine.proto` | core | server | v1 | 설계됨, 파일 미생성 (core Task 14) | 엔진 spec §9 |
| 메시지 키 목록 | `core/message_keys.json` | core | server (콘텐츠 시드 검사), writing (W1 콘텐츠 작성) | - | 설계됨, 파일 미생성 (core Task 2) | 엔진 spec §10 |
| 근거 참조 형식 (`source_ref`) | 엔진 spec §11 | core | server, app (`evidence` 단계) | - | 설계됨 | 엔진 spec §11 |
| 엔진 버전 표기 (`engine_version`, `ruleset_version`) | 엔진 spec §12 | core | server (일기 태그 기록, 캐시 키) | - | 설계됨 | 엔진 spec §12, D31 |
| REST API (앱 ↔ 서버) | (server 설계 때 정함) | server | app | v1 | 미설계 (S3) | D26 |
| 디자인 토큰 (오행 팔레트·타이포·그라데이션) | `docs/identity/design/tokens/` | design | app | - | 미설계 (V1에서 동결) | 브랜드 기반 spec §9, 06 |
| 브랜드 기반 | `docs/identity/README.md` | 지휘 | writing, design | - | 확정 (B0) | 브랜드 기반 spec, D38 |
| MVP 화면 목록 (IA) | (지휘 세션 작성 예정) | 지휘 | app, writing, design | - | 미작성 | D39 |
| 슬롯 명세 | `docs/identity/writing/` (W0에서 정함) | writing | server, app | - | 미설계 (W0) | 브랜드 기반 spec §8 |
| 호칭·조사 처리 규칙 | (W0에서 정함) | writing | server (콘텐츠 모듈) | - | 미설계 (W0) | D36 |
| 라이팅 검사기 | `docs/identity/writing/tools/` (W0에서 정함) | writing | server (시드 CI), app (CI) | - | 미설계 (W0) | 브랜드 기반 spec §8 |

## 생성 코드
* proto에서 생성한 코드는 사용하는 서비스마다 자기 디렉터리에 commit합니다(D33).
  * core: `core/src/myungri_engine/_gen/`
  * server: server 설계 때 정합니다.
* 생성 코드가 원본 proto와 맞는지는 각 서비스의 CI가 검사합니다.
