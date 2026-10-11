# server 구현 계획 목록

spec: [`../specs/2026-10-11-server-mvp-design.md`](../specs/2026-10-11-server-mvp-design.md)

spec이 서브시스템 9개를 다루므로 계획을 나눕니다. 각 계획은 그 자체로 동작하고 테스트할 수 있는 결과로 끝납니다. 다음 계획은 앞 계획이 병합된 뒤 실제 코드를 보고 씁니다(rolling wave). 앞 계획에서 정한 인터페이스가 다음 계획의 입력이기 때문입니다.

| 순서 | 계획 | spec 절 | 상태 |
| --- | --- | --- | --- |
| P1 | [기반과 REST 계약 초안](2026-10-11-p1-foundation.md): 모듈, 하위 명령, 설정, Clock, 로깅, DB·migration, HTTP 뼈대, 오류 형식, `openapi.yaml` 초안, 생성 코드, CI, 이미지 | §2, §5, §11.1, §12, §13.1 일부 | 작성 완료 |
| P2 | 인증·계정·약관: 카카오·Apple 검증, JWT, refresh rotation, 동의, 삭제 예약·복구 | §3.3 계정, §4 | 대기 |
| P3 | 프로필·엔진·캐시: 프로필 검증(호칭 규칙, D41, 엔진 검증), proto 생성, 엔진 클라이언트·대역, `ResultCache`, `ruleset_version` 확인 | §3.2, §3.3 프로필·캐시, §7 | 대기 |
| P4 | 콘텐츠: 시드 변환·적재, 렌더러(조사·호칭·토큰), 선택·순환·돌봄 상한, 값 이름 사전, 데일리·나의 사주·캘린더 응답, 반응 | §6 | 대기 |
| P5 | 일기·일정: soft delete, 복구, 태그 조회, 저장 시 태그·가이드 질문 기록 | §5.3, §3.3 일기 | 대기 |
| P6 | 비로그인·참조: 미리보기, 시진 확인, App Check, 요청 한도, 도시, app-config | §5.3, §3.3 기타 | 대기 |
| P7 | 결제와 권한: RevenueCat webhook·동기화, entitlement 부여 기록, 복원, AdMob SSV 검증과 근거 열람 권한(D60) | §10 | 대기 |
| P8 | Job: precompute, notify(FCM), retention과 익명화 | §8, §9 | 대기 |
| P9 | 배포: staging·prod, Cloud Run service·Jobs·Scheduler, Cloud SQL 연결, OpenTelemetry, 외부 준비 안내 | §13 | 대기 |

P2~P8의 순서는 의존 순서입니다. P2·P3 다음부터는 P5·P6·P7이 서로 기다리지 않습니다.
