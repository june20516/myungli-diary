# app — 모바일 앱 (Flutter)

이 디렉터리에서 시작한 세션은 **app 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 플랫폼: iOS / Android (Flutter, 01 §1.1)
* **온보딩:**
  * 생년월일시 입력, 양력·음력(윤달 포함), 시간 모름, 성별 (D18-①②③)
  * 호칭(앱이 사용자를 부를 말) 필수 입력 (D36)
  * 태어난 시간 아래 시진 확인 줄: 기기 지역이 한국일 때만, server의 비로그인 시진 확인 요청 값으로 (D58)
  * 음력 생일은 KASI 한국 음력 기준입니다. 생년월일 입력 범위는 양력 1900-01-31 ~ 2099-12-31입니다 (D41)
  * 출생지는 기본적으로 받지 않고 한국 출생으로 가정해 표시합니다. 언어나 기기의 위치·로케일이 한국이 아닐 때는 도시 단위 출생지 입력을 안내합니다 (D29)
  * 소셜 로그인: 카카오·Apple, iOS·Android 모두. Android의 Apple 로그인은 웹 흐름 (D55)
* **데일리 화면:**
  * 총운 문장, 카드 4종(행운 컬러·방향·숫자·집중 시간), 대표 해시태그 (D18-④⑤, D19~D21·D25)
  * 용신의 날은 "좋은 날"로 강조합니다 (D20)
  * 총운 문장에 대한 반응(좋아요)을 수집합니다 (D40·D57)
  * 깊이 단계(D37) `surface` → `explain` → `evidence`는 카드 → 바텀시트 Half → Full로 펼칩니다 (06 §1)
* **나의 사주:**
  * `surface`: 일간 소개, 용신·행운 색
  * `evidence`: 사주팔자 표, 십성·지장간·12운성·신살, 오행 분포, 용신 근거, 대운·세운 표 (D16·D18-⑥⑦)
* **탭 4개:** 오늘·달력·일기·나 (D48). 로그인은 첫 풀이 미리보기 뒤에 받습니다 (D50)
* **캘린더:** 월간 길흉(날짜 칸 채우기, design 결정 V10), 음력 날짜, 절기 (04 §4.4, D18-⑧). 기본 일정(제목·날짜·종일 또는 시간·메모, D47③). 다른 날 전체 풀이는 없고 그날 성격 한 줄만 (D47⑥)
* **일기:** 텍스트 작성, 작성 전 가이드 질문, 저장 후 해시태그 칩 (04 §4.3, D22, 06 §4). 하루 1편, 지난 날 쓰기 가능 (D49). 태그를 누르면 같은 태그의 일기 목록 (D47①). 오프라인은 로컬 초안만 (D47②)
* **공유:** 오늘 카드 이미지 공유, 로그인 필요 (D47④). 일기는 공유하지 않습니다
* **수익 (D53·D54):** 탭 루트 4곳 하단 적응형 배너 광고(AdMob 기본안), 광고 동의(iOS ATT, 필요한 지역 UMP)는 이 기기에서 처음 광고를 보이기 전에, 1개월 광고 제거권 인앱결제(자동 갱신 없음, 잠정 ₩2,500, RevenueCat 기본안)와 구매 복원. 근거 시트의 잠금 안내와 보상형 광고(D60): 사용자가 고를 때만, 매번 보상 고지 후, 광고가 준비됐을 때만 버튼을 켬. SSV `userId`로 계정을 넘기고 server 권한을 받아 엶
* **알림 수신:** 아침 운세 (D18-⑨)
* **안내 문구:** 엔진 notice를 안내 문구로 보여줍니다. 예: 자시 출생 계산 기준(D6), 시간 모름, 절입 전후 출생. 계산 기준 안내에 "동경 127.5° 기준 -30분 보정, 진태양시 미적용"을 넣습니다 (D42, 우선순위 낮음)
* **다국어:** 한국어·영어·일본어. UI 문자열은 ARB로 관리하고, 콘텐츠 문장은 서버가 렌더해 줍니다. app은 문장을 고르거나 조사를 붙이지 않고, 받은 그날 응답을 캐시해 오프라인에 보입니다 (D27·D28·D59). ARB 메시지 이름은 lowerCamelCase Dart 식별자이며, writing `slots/ui/`와 검사기 `mlw check-arb`가 이 규약을 전제합니다. A1에서 어긋나면 요청함으로 알립니다
* **화면 구성:** 지휘 세션의 MVP 화면 목록(IA, D39)을 따릅니다.
* **디자인:** 기준은 [`docs/identity/README.md`](../docs/identity/README.md)(브랜드 기반)와 [`docs/identity/design/visual-identity.md`](../docs/identity/design/visual-identity.md)(시각 정체성)입니다. **다크 모드는 MVP에 포함**됩니다(design 결정 V4). 앱 아이콘 원본은 `docs/identity/design/logo/`이고, 크기별 PNG 내보내기는 app이 합니다. 디자인 토큰과 컴포넌트 명세는 design 작업 단위가 제공합니다(V1·V2). UI 구현은 V2 이후에 시작하고, 설계는 병행할 수 있습니다.
* **MVP 범위 밖:** 인스타그램 스토리·카카오 템플릿 공유, 궁합, 일기 감성 코멘트(LLM), 구독 결제는 Phase 2 이후입니다 (05, D22·D23·D53)

## 고칠 수 있는 곳
`app/`, `.github/workflows/app.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:app`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| REST API `server/api/openapi.yaml` 1.0.0-draft (freeze는 S3) | **사용** | server |
| `source_ref`·enum 값 (엔진 spec §9·§11, server가 그대로 전달) | **사용** (`evidence` 단계 표시) | core → server |
| 디자인 토큰 1.1.0 (`docs/identity/design/tokens/`, Dart 코드 생성은 app) | **사용** | design |
| 컴포넌트 명세 2.0.0 (`docs/identity/design/components/`) | **사용** | design |
| MVP 화면 목록 (IA) `docs/ia/screens.json` v1 (화면·상태·경로·슬롯·컴포넌트) | **사용** | 지휘 |

## 현재 상태 (2026-10-13, app 세션 갱신)
* **A1 설계 완료, 기반 구현 착수 전**입니다.
  * spec: [`docs/specs/2026-10-13-app-architecture-design.md`](docs/specs/2026-10-13-app-architecture-design.md) (승인)
  * 결정: [`docs/decisions.md`](docs/decisions.md) A1~A15. 핵심은 Riverpod, 생성 클라이언트와 fixture 대역, go_router, drift 사주 기반 영구 캐시, 사주 변경 확인 창, golden과 Widgetbook, SDK 대역 adapter, 문서 기반 E2E(Patrol), 앱 식별자 `app.myungli.diary`입니다.
  * 계획 분할(spec §10): ① 기반 → ② 온보딩·로그인 → ③ 오늘·깊이 시트 → ④ 달력·일정 → ⑤ 일기 → ⑥ 나·설정 → ⑦ 수익·알림
  * 기반 계획: [`docs/plans/2026-10-13-foundation.md`](docs/plans/2026-10-13-foundation.md) (task 22개, subagent-driven으로 실행)
* 보낸 요청(2026-10-13): #84(IA 사주 변경 확인 창, **반영됨**: 슬롯 119), #85(ci-gate 연결), #86(Crashlytics, **D64**: 크래시 기록에 일기 본문·출생 정보·호칭 금지), #87(제품 지도·통합 E2E), #88(오류 code 목록), #89(Apple App Link, 계획 7 실제 adapter를 막음), #90(ARB 키 규칙)
* UI 문구 원고는 writing이 작업 중입니다(#15·#27·#42·#52). 그전까지는 임시 문구를 씁니다(결정 A7).
* MVP 범위는 수익화 사이클 M0에서 다시 확정됐습니다(D53·D54).
* **REST API 초안이 있습니다**: `server/api/openapi.yaml`(OpenAPI 3.1, 1.0.0-draft, operation 37개, PR #62). 생성 코드와 대역 서버를 이 초안으로 만들 수 있습니다. freeze(S3) 전에는 하위 호환이 깨지는 변경이 있을 수 있고, 그때 server가 `kind:notice`로 알립니다. 규칙은 계약의 `info.description`에 모두 있습니다. 요점은 아래와 같습니다(Issue #63).
  * 오류는 RFC 9457 problem+json이고 `code`로 분기합니다. 사용자 문구는 app이 `code`로 만듭니다(D59⑤). 400은 스키마로 거르는 형식·범위 위반(`request.invalid`), 422는 의미 검사(`request.inconsistent`, `date.invalid`, 엔진 판정)입니다.
  * null을 쓰지 않습니다. "모름"·"건너뜀"·"묻지 않음"은 상태 필드로 옵니다. PATCH에서 필드가 없으면 "바꾸지 않음"입니다.
  * 근거 열람 권한은 응답의 `evidenceAccess`(`unlocked`·`locked`)로 옵니다(D60).
  * 콘텐츠 문장은 조각 배열 `segments`로 옵니다. 용어 조각에는 `term`이 붙습니다. 위치 숫자는 쓰지 않습니다(server 결정 S9). `term` 조각의 표시는 design이 정합니다.
  * 시각은 기본 UTC입니다. 화면 표시용 시각(집중 시간, 절기 시각)만 프로필 시간대 offset으로 옵니다.
* **컴포넌트 명세는 2.0.0입니다**(PR #66, Issue #65). 근거 깊이 잠금(근거 시트 잠김 4상태, `lock.veil`, `sentence-block` `locked`), 모양 규칙(동작은 둥근 사각, 표시·고르기는 알약), 화면 좌우 여백 `space.20`, 글자 수 상한이 들어갔습니다.
* **IA v1에 추가된 것**(2026-10-13, 추가만): 근거 시트 구역 제목·해제 실패 toast·접근성 문구 ui 슬롯, `saju-chart.yongsin.open`, 시스템 화면 `system-push`(아침 알림 문장, 호칭 없음, D62). 화면 36·슬롯 118입니다.
* 광고 제거권을 만료 전에 다시 사면 남은 기간에 이어 붙습니다(D61). 계산은 server가 합니다.
* 도시 목록은 GeoNames `cities15000`(CC BY 4.0)으로 server가 만듭니다. **앱 오픈소스 고지(`legal`)에 출처를 표기합니다**(Issue #48 항목 5).
* 받은 notice: Issue #19(토큰 1.0.0), #44(컴포넌트 1.0.0·토큰 1.1.0), #65(컴포넌트 2.0.0), A1 착수 안내(#30). 앞으로 받은 요청은 `gh issue list --label to:app`.
* 반응 버튼(`reaction-button`)은 총운 문장에만 붙습니다(D57).

## 다음 할 일
1. 기반 계획 실행: 브랜치 `app/foundation`(`origin/main`에서 `--no-track`), [`docs/plans/2026-10-13-foundation.md`](docs/plans/2026-10-13-foundation.md)를 subagent-driven-development로 실행합니다. Flutter SDK는 `~/development/flutter`(stable)에 있습니다.
2. 기반 병합 뒤 계획 2(온보딩·로그인)를 writing-plans로 씁니다.
3. 받은 요청은 `gh issue list --label to:app`으로 확인합니다.
