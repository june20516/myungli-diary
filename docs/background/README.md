# 배경 문서 목록

| 파일 | 문서 | 위계 |
| --- | --- | --- |
| [00-product-spec.md](00-product-spec.md) | 제품 명세서: 명리일기 | 상위 (무엇을 만드는가, 기능 상세 원본) |
| [01-technical-spec.md](01-technical-spec.md) | 1. 기술 명세서 | 기술 (스택 선정) |
| [02-backend-infrastructure.md](02-backend-infrastructure.md) | 2. 백엔드 인프라 구조 설계서 | 기술 (서버 구조·연동) |
| [03-app-prd.md](03-app-prd.md) | 3. 구체적인 앱 제품 PRD | 제품 (00의 요약판 + Easy/Pro 모드 명명) |
| [04-mvp-spec.md](04-mvp-spec.md) | 4. MVP 명세 | 범위 (1차 개발 대상) |
| [05-roadmap.md](05-roadmap.md) | 5. 제품 로드맵 | 일정 (Phase 1~3, M1~M9) |
| [06-design-system.md](06-design-system.md) | 명리일기 디자인 시스템 펀더멘탈 | 디자인 (UX 원칙·컬러·타이포·컴포넌트) |
| [core/docs/engine-logic-wiki.md](../../core/docs/engine-logic-wiki.md) | 명리일기 코어 엔진 연산 로직 위키 (v1.4) | 엔진 (만세력·룰셋 연산 기준). **core로 이전** |

## 문서 간 관계
* `03-app-prd.md`는 `00-product-spec.md`의 요약판입니다.
  * 03에서 추가된 것: "삶의 패턴 파악" 목적, Easy 모드 / Pro 모드 명칭.
  * 03에서 빠진 것: 외부 캘린더 연동, Easy/Pro JSON 응답 구조. 이 둘은 01·02에 정의되어 있습니다.
* 기능별 상세 기준(예: 목적별 택일 조건)은 `00-product-spec.md`를 따릅니다.
* `04-mvp-spec.md`는 00~03의 전체 범위 중 1차 개발 범위를 정하고, `05-roadmap.md`는 그 나머지를 Phase별로 배치합니다.
* `06-design-system.md`는 00·03의 Easy/Pro 원칙을 UI로 구체화합니다.
  * 디깅 3단계: Surface(카드) → Digging 1(바텀시트 Half) → Digging 2(바텀시트 Full).
  * 오행 5색 팔레트가 옷 색깔 추천과 캘린더 길흉 점에 공통으로 쓰입니다.
* 07 엔진 위키(`core/docs/engine-logic-wiki.md`)는 00 §3.1~3.4의 명리 로직을 수치·조건식으로 구체화합니다. 엔진 구현 시 연산 기준은 07을 따릅니다.
  * 00 §3.3 목적별 택일 → 07 §4.2 배점표 (00의 "결혼"은 07에서 "연애"만 정의됨)
  * 00 §3.4 명리 태깅 → 07 §4.3 해시태그 우선순위·동점 룰

## 엔진 문서
* 07 엔진 위키와 그 검토 메모, 엔진 spec·계획, 원전 근거 자료는 엔진 서브 프로젝트로 옮겼습니다(2026-10-10): `core/docs/`
* 검토 메모의 미결 항목은 엔진 spec에서 모두 확정되었습니다(D34).

## 결정 로그
* 확정한 결정은 [`docs/decisions.md`](../decisions.md)에 모읍니다.

## 근거 자료
* 원문 인용·근거 데이터는 [`core/docs/references/`](../../core/docs/references/README.md)에 있습니다. 문구 작성 시 이 데이터를 인용합니다.
