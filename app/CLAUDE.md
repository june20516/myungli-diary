# app — 모바일 앱 (Flutter)

이 디렉터리에서 시작한 세션은 **app 세션**입니다. 루트 `CLAUDE.md`와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다.

## 범위 (MVP, 루트 결정 기준)
* 플랫폼: iOS / Android (Flutter, 01 §1.1)
* **온보딩:**
  * 생년월일시 입력, 양력·음력(윤달 포함), 시간 모름, 성별 (D18-①②③)
  * 호칭(앱이 사용자를 부를 말) 필수 입력 (D36)
  * 음력 생일은 KASI 한국 음력 기준입니다. 생년월일 입력 범위는 양력 1900-01-31 ~ 2099-12-31입니다 (D41)
  * 출생지는 기본적으로 받지 않고 한국 출생으로 가정해 표시합니다. 언어나 기기의 위치·로케일이 한국이 아닐 때는 도시 단위 출생지 입력을 안내합니다 (D29)
  * 소셜 로그인: 카카오·Apple, iOS·Android 모두. Android의 Apple 로그인은 웹 흐름 (D55)
* **데일리 화면:**
  * 총운 문장, 카드 4종(행운 컬러·방향·숫자·집중 시간), 대표 해시태그 (D18-④⑤, D19~D21·D25)
  * 용신의 날은 "좋은 날"로 강조합니다 (D20)
  * 콘텐츠 문장에 대한 반응(좋아요)을 수집합니다 (D40)
  * 깊이 단계(D37) `surface` → `explain` → `evidence`는 카드 → 바텀시트 Half → Full로 펼칩니다 (06 §1)
* **나의 사주:**
  * `surface`: 일간 소개, 용신·행운 색
  * `evidence`: 사주팔자 표, 십성·지장간·12운성·신살, 오행 분포, 용신 근거, 대운·세운 표 (D16·D18-⑥⑦)
* **탭 4개:** 오늘·달력·일기·나 (D48). 로그인은 첫 풀이 미리보기 뒤에 받습니다 (D50)
* **캘린더:** 월간 길흉(날짜 칸 채우기, design 결정 V10), 음력 날짜, 절기 (04 §4.4, D18-⑧). 기본 일정(제목·날짜·종일 또는 시간·메모, D47③). 다른 날 전체 풀이는 없고 그날 성격 한 줄만 (D47⑥)
* **일기:** 텍스트 작성, 작성 전 가이드 질문, 저장 후 해시태그 칩 (04 §4.3, D22, 06 §4). 하루 1편, 지난 날 쓰기 가능 (D49). 태그를 누르면 같은 태그의 일기 목록 (D47①). 오프라인은 로컬 초안만 (D47②)
* **공유:** 오늘 카드 이미지 공유, 로그인 필요 (D47④). 일기는 공유하지 않습니다
* **수익 (D53·D54):** 탭 루트 4곳 하단 적응형 배너 광고(AdMob 기본안), 광고 동의(iOS ATT, 필요한 지역 UMP)는 이 기기에서 처음 광고를 보이기 전에, 1개월 광고 제거권 인앱결제(자동 갱신 없음, 잠정 ₩2,500, RevenueCat 기본안)와 구매 복원
* **알림 수신:** 아침 운세 (D18-⑨)
* **안내 문구:** 엔진 notice를 안내 문구로 보여줍니다. 예: 자시 출생 계산 기준(D6), 시간 모름, 절입 전후 출생. 계산 기준 안내에 "동경 127.5° 기준 -30분 보정, 진태양시 미적용"을 넣습니다 (D42, 우선순위 낮음)
* **다국어:** 한국어·영어·일본어. UI 문자열은 ARB로 관리하고, 콘텐츠 문장은 서버가 줍니다 (D27·D28)
* **화면 구성:** 지휘 세션의 MVP 화면 목록(IA, D39)을 따릅니다.
* **디자인:** 기준은 [`docs/identity/README.md`](../docs/identity/README.md)(브랜드 기반)와 [`docs/identity/design/visual-identity.md`](../docs/identity/design/visual-identity.md)(시각 정체성)입니다. **다크 모드는 MVP에 포함**됩니다(design 결정 V4). 앱 아이콘 원본은 `docs/identity/design/logo/`이고, 크기별 PNG 내보내기는 app이 합니다. 디자인 토큰과 컴포넌트 명세는 design 작업 단위가 제공합니다(V1·V2). UI 구현은 V2 이후에 시작하고, 설계는 병행할 수 있습니다.
* **MVP 범위 밖:** 인스타그램 스토리·카카오 템플릿 공유, 궁합, 일기 감성 코멘트(LLM), 구독 결제는 Phase 2 이후입니다 (05, D22·D23·D53)

## 고칠 수 있는 곳
`app/`, `.github/workflows/app.yml`, GitHub Issues(요청·보고 작성, `gh issue list --label to:app`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| REST API v1 (server 설계 후 `docs/contracts/README.md`에 등록) | **사용** | server |
| `source_ref`·enum 값 (엔진 spec §9·§11, server가 그대로 전달) | **사용** (`evidence` 단계 표시) | core → server |
| 디자인 토큰 1.0.0 (`docs/identity/design/tokens/`, Dart 코드 생성은 app) | **사용** | design |
| MVP 화면 목록 (IA) `docs/ia/screens.json` v1 (화면·상태·경로·슬롯·컴포넌트) | **사용** | 지휘 |

## 현재 상태 (2026-10-11, 지휘 세션 작성)
* **설계(A1) 착수 가능**입니다. 디렉터리는 비어 있습니다. 수익화 사이클 M0가 끝나 MVP 범위가 다시 확정됐습니다(D53·D54).
* REST API가 아직 없습니다. 설계와 화면 구현은 대역(mock) 데이터로 시작할 수 있습니다. 대역의 형태는 엔진 spec §9의 응답 구조를 참고합니다.
* 받은 notice: Issue #19(디자인 토큰 1.0.0), A1 착수 안내 Issue(마일스톤 A1). 앞으로 받은 요청은 `gh issue list --label to:app`.
* UI 구현은 design V2(컴포넌트 명세) 이후입니다. 설계와 화면 흐름·상태 관리는 지금 시작할 수 있습니다.

## 다음 할 일
1. 읽을 것:
   - `docs/identity/README.md` (정체성 기준, 06보다 우선)
   - `docs/ia/README.md`와 `docs/ia/screens.json` (화면 34개, 상태·경로·인증 갈래)
   - IA spec `docs/specs/2026-10-11-ia-design.md` §3·§10
   - `docs/background/` 00~06, 특히 03·04·06
   - `docs/decisions.md` (특히 D47~D56)
   - 엔진 spec §7~§9 (화면에 보일 데이터)
2. worktree와 브랜치를 만들고 그 안에서 세션을 시작합니다. 원래 checkout은 다른 세션이 쓰고 있을 수 있으므로, 저장소 루트에서 그대로 실행합니다.
   ```
   git fetch origin
   git worktree add ../myungli-diary-app -b app/design --no-track origin/main
   cd ../myungli-diary-app && git status -sb && cd app && claude
   ```
3. brainstorming으로 app spec을 작성합니다 → `app/docs/specs/`
   - 상태 관리(Provider / Riverpod)는 app 내부 결정(`A<n>`)입니다.
   - 디자인 토큰은 계약 1.0.0으로 freeze됐습니다(`docs/identity/design/tokens/README.md`, Issue #19). 캘린더 길흉은 점이 아니라 날짜 칸 채우기입니다(design 결정 V10).
   - 광고·인앱결제 SDK 선택(AdMob, RevenueCat 기본안)은 app spec에서 확정합니다. 계정 준비는 사용자 몫입니다(`docs/roadmap.md` 외부 준비물).
