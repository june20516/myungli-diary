# 계약 목록

서브 프로젝트 사이에서 서로 기대는 인터페이스입니다. 지휘 세션이 목록을 관리합니다. 계약은 **제공하는 쪽만** 바꾸며, 하위 호환이 깨지는 변경은 `docs/workflow.md` §5.1 절차를 따릅니다.

| 계약 | 원본 위치 | 제공 | 사용 | 버전 | 상태 | 설계 근거 |
| --- | --- | --- | --- | --- | --- | --- |
| 엔진 gRPC API | `proto/myungri/engine/v1/engine.proto` | core | server | v1 | 설계됨, 파일 미생성 (core Task 14) | 엔진 spec §9 |
| 메시지 키 목록 | `core/message_keys.json` | core | server (콘텐츠 시드 검사) | - | 설계됨, 파일 미생성 (core Task 2) | 엔진 spec §10 |
| 근거 참조 형식 (`source_ref`) | 엔진 spec §11 | core | server, app (`evidence` 단계) | - | 설계됨 | 엔진 spec §11 |
| 엔진 버전 표기 (`engine_version`, `ruleset_version`) | 엔진 spec §12 | core | server (일기 태그 기록, 캐시 키) | - | 설계됨 | 엔진 spec §12, D31 |
| REST API (앱 ↔ 서버) | (server 설계 때 정함) | server | app | v1 | 미설계 (S3) | D26 |
| 디자인 토큰 (오행 팔레트·타이포) | `docs/background/06-design-system.md` | 지휘 | app | - | 원칙만 있음 | 06 |

## 생성 코드
* proto에서 생성한 코드는 사용하는 서비스마다 자기 디렉터리에 commit합니다(D33).
  * core: `core/src/myungri_engine/_gen/`
  * server: server 설계 때 정합니다.
* 생성 코드가 원본 proto와 맞는지는 각 서비스의 CI가 검사합니다.
