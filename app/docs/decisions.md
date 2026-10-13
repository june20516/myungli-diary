# app 결정 로그

app 안의 결정입니다(번호 `A<n>`, `docs/workflow.md` §4). 마일스톤 A1·A2와 글자가 같으므로 문장에서는 "결정 A1"처럼 종류를 붙여 씁니다(D46).

| # | 날짜 | 영역 | 결정 | 근거 / 문서 |
| --- | --- | --- | --- | --- |
| A1 | 2026-10-13 | 상태 관리 | **Riverpod 3.x**를 씁니다. 상태 대부분이 server 응답·캐시·권한이라 비동기 상태와 의존성 주입이 내장된 쪽을 고릅니다. 대역 교체는 provider override입니다 | 사용자 승인, [아키텍처 spec](specs/2026-10-13-app-architecture-design.md) §2 |
| A2 | 2026-10-13 | 통신 | `openapi.yaml`에서 **생성한 클라이언트**를 쓰고 commit합니다. 대역은 HTTP 계층의 interceptor가 JSON fixture를 돌려주는 방식이며, fixture는 CI에서 계약 스키마로 검증합니다 | 사용자 승인, spec §4.1·§4.2 |
| A3 | 2026-10-13 | 구조 | feature 우선 구조(data·application·presentation)이고 **별도 도메인 계층은 두지 않습니다.** repository는 생성 모델을 돌려줍니다 | 사용자 승인, spec §2 |
| A4 | 2026-10-13 | 라우팅 | **go_router**, route 이름은 IA 화면 id. 탭은 `StatefulShellRoute`, 시트는 route가 아니라 시트 서비스. 진입 갈래는 상태 하나에서 계산하고, IA 대조 테스트를 CI에 둡니다 | 사용자 승인, spec §3 |
| A5 | 2026-10-13 | 로컬 저장 | **drift(SQLite)**. 달력·나의 사주는 계정 + 사주 지문 + 언어 + 기간을 키로 하는 영구 캐시이며, 사주 변경·`rulesetVersion` 변경·잠금 해제 때만 버립니다. 오늘은 그날 캐시, 일정·일기는 캐시하지 않거나 편집 때 다시 받습니다 | 사용자 지적 반영 후 승인, spec §4.4 |
| A6 | 2026-10-13 | 정보 수정 | 생일·시간·성별·출생지 변경은 **무거운 변경**으로 다룹니다. 바뀌기 전 → 뒤와 영향(다시 계산되는 것, 지난 일기는 그대로)을 확인 창으로 보이고, 기본 선택은 취소입니다. 호칭은 바로 저장합니다 | 사용자 제안·승인, spec §5 |
| A7 | 2026-10-13 | 다국어 | ARB 키는 writing 슬롯의 `keys`를 따르고, 원고 전에는 IA 슬롯 id의 lowerCamelCase 키와 임시 문구를 씁니다 | spec §6.4 |
| A8 | 2026-10-13 | 검증 | 컴포넌트는 **golden 테스트(CI Linux 기준) + Widgetbook**으로 검증합니다 | 사용자 승인, spec §6.3 |
| A9 | 2026-10-13 | 플랫폼 | 모든 외부 SDK를 인터페이스 뒤에 두고 대역 구현을 함께 둡니다. A1은 fake 모드로 전 흐름을 완성합니다 | 사용자 승인, spec §7 |
| A10 | 2026-10-13 | 운영 | 비정상 종료 보고에 **Firebase Crashlytics**를 씁니다 | 사용자 승인, spec §7 |
| A11 | 2026-10-13 | 도구 | Flutter는 **stable 채널을 따라가고** 정확한 SDK 버전은 고정하지 않습니다(커뮤니티 표준). `pubspec.lock`은 commit하고 안정판 의존성만 씁니다 | 사용자 결정, spec §9 |
| A12 | 2026-10-13 | 인증 | Android의 Apple 로그인은 Custom Tabs + **Android App Link** 복귀로 받고, app이 `state`를 확인합니다 | 사용자 승인, spec §7 |
| A13 | 2026-10-13 | 테스트 | **문서 기반 E2E**: Patrol로 기기 E2E를 돌리고, 테스트는 IA 화면·슬롯 id(Key·Semantics `identifier`)로 자리를 찾습니다. 각 테스트가 덮는 IA 경로·상태·결정을 선언하고, 도구가 `screens.json`과 대조해 커버리지 보고서를 만들며 CI는 커버리지 감소를 막습니다. 같은 E2E를 A2·I2·I3에서 http 모드로 재사용합니다 | 사용자 제안·승인, spec §6.6·§8.1 |
