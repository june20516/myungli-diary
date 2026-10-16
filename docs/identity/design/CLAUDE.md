# design — 디자인 시스템

이 디렉터리에서 시작한 세션은 **design 세션**입니다. 루트 [`CLAUDE.md`](../../../CLAUDE.md)와 [`docs/workflow.md`](../../workflow.md)의 공통 규약을 함께 따릅니다. 기준 문서는 [`docs/identity/README.md`](../README.md)(브랜드 기반)입니다.

## 범위
명리일기의 시각 정체성, 디자인 토큰, 컴포넌트 명세를 만듭니다. 구현(Flutter)은 app이 합니다. 상세는 [브랜드 기반 spec §7·§9](../../specs/2026-10-10-brand-foundation-design.md)에 있습니다.

| 산출물 | 받는 쪽 | 마일스톤 |
| --- | --- | --- |
| 시각 정체성: 로고 방향, 그라데이션 규칙, 오행 팔레트, 타이포 | 모두 | V0 |
| 디자인 토큰 (`tokens/`, 데이터 파일) | app (Dart 코드 생성) | V1 freeze |
| 캘린더 길흉 표시 규칙 (엔진 spec §8 `LuckLevel` 3단계, 루트 미결에서 이관). 점이 아니라 날짜 칸 채우기(결정 V10) | app | V1 |
| 컴포넌트 명세 (`components/`): IA 컴포넌트 + 상호작용 패턴·요소 | app | V2 |

* 비공개 기록 `background/06-design-system.md`(D74)는 V0의 입력이었습니다. V0 결과가 정체성 기준으로 06을 대체합니다.
* 그라데이션은 조건부 선택입니다(README "시각 방향"). 토큰 하나로 묶어, 리뉴얼할 때 그 토큰만 바꾸면 되게 합니다.
* 사용자는 제품 작업을 컴포넌트부터 설계하기를 원합니다. app의 UI 구현은 V2 뒤에 시작합니다.

## 고칠 수 있는 곳
`docs/identity/design/`, GitHub Issues(요청·보고 작성, `gh issue list --label to:design`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (V2의 선행 조건) | 지휘 |
| 디자인 토큰 (`tokens/`) | **제공** (V1 freeze, 그 뒤는 추가만) | app |
| 컴포넌트 명세 (`components/`) | **제공** | app |
| 글자 수 상한 | **주고받음** (요청함) | writing |

계약 버전과 상태는 [`docs/contracts/README.md`](../../contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.

## 현재 상태 (2026-10-16, design 세션 작성)
* **app 질문 #195·#211** (브랜치 `design/app-questions`): `city-search` 고른 뒤 저장 중 `saving`(고른 줄 끝 점 숨쉬기, 결정 V34), 지역 구분자 `region.join`(ja `、`), `input-step` `preface` 간격 `space.24`, `skeleton` 글줄 `type`, 안내 글 본문 레이아웃(`frame.md`, IA 컴포넌트 아님).
* **구현 대응·IA v3·글자 수 상한** (브랜치 `design/spec-followups`, Issue #118·#142·#154·#159·#131).
  * app 구현 차이 판단을 명세에 확정: 링크 화살표는 아이콘 `caret-right`로 컴포넌트가 그림, 고정 높이는 최소 높이, `dialog` `notice`, `segmented` `none`, 윤달 대체 모양, 탭 아이콘, 시간 형식, 근거 시트 빈 구역 생략, 요소 값 3개.
  * IA v3: 출생지 → 계산 기준 링크 `depth-link` `navigate`(슬롯 `birthplace.standard.link`).
  * 글자 수 상한: ui 이름 자리와 새 content 슬롯 칸을 더함, 상한 없음 표, 확인 창 슬롯은 제목·버튼 키만. 기존 확정값 그대로.
  * 명세를 바꾸지 않는 Flutter 대응(의미 표시 등)은 각 `.md`의 구현 힌트에 적음.
  * 근거: [spec](specs/2026-10-15-spec-followups-design.md), 결정 V29~V33.
* **용신 근거 줄 이름 슬롯** (브랜치 `design/yongsin-title`, Issue #81): `sentence-block` `a11y.lockedNameSlot` = `saju-chart.yongsin.title`(잠김 라벨의 구역 이름).
* **문장 조각 용어 표시·근거 잠금 슬롯** (브랜치 `design/lock-slots`, Issue #68, PR #83).
  * `sentence-block.parts.segments`: `term` 조각은 `term-token`이 있는 화면에서만 칩(`term-token` `inline`), 그 밖은 일반 글자. 용어와 붙은 조사는 한 덩어리로 줄바꿈.
  * IA v1 추가분(#70) 슬롯: `sentence-block` 열기(`saju-chart.yongsin.open`), 근거 시트 구역 제목 3개·해제 실패 toast·접근성 문구 3개.
  * 슬롯 이름과 `term-token` 화면 목록은 테스트가 IA에서 읽어 비교합니다.
  * 근거: [spec](specs/2026-10-13-term-segments-lock-slots-design.md), 결정 V28.
* **V2 후속: 근거 깊이 잠금·글자 수 상한** (브랜치 `design/v2-followups`, Issue #53·#54).
  * 근거 시트 구성과 잠김 상태 4개(`depth-link.evidenceSheet`), 요소 `lock.veil`, `sentence-block` `locked`. 풀이 시트의 개인 해석 상자와 `term-token` 잠김은 뺌(D60).
  * 공통 규칙: 동작 = 둥근 사각, 표시·고르기 = 알약(예외 없음), 화면 좌우 여백 `space.20`.
  * 글자 수 상한: [`lengths.md`](lengths.md), 도구 `tools/lengths.py`(측정 글꼴은 `.suberpowers/fonts`, 없으면 표 비교 테스트 skip).
  * 근거: [spec](specs/2026-10-11-depth-lock-lengths-design.md), 결정 V25~V27.
* **마일스톤 V2 컴포넌트 명세** (브랜치 `design/components`).
  * 명세: [`components/`](components/README.md) JSON(사실) + MD(설명) 11쌍. 공통 `interaction`(패턴 12개)·`elements`(요소 15개, 근거 잠금에서 16개).
  * 검사: 저장소 루트에서 `python3 docs/identity/design/tools/components.py`(IA 41개·토큰 참조·요소·패턴·상태 대응표·짝 MD).
  * 근거: [V2 spec](specs/2026-10-11-components-design.md), 결정 V13~V24. 대비 검사 86/86(비활성 글자 3:1).
* **마일스톤 V1 디자인 토큰 freeze** (브랜치 `design/tokens`).
  * 토큰: [`tokens/`](tokens/README.md) 다섯 파일. 생성: 저장소 루트에서 `python3 docs/identity/design/tools/tokens.py`. 손으로 고치지 않습니다.
  * 근거: [V1 spec](specs/2026-10-11-design-tokens-design.md), 결정 V8~V12. 대비 검사 52/52.
  * 길흉 표시는 점이 아니라 칸 채우기입니다(결정 V10).
* **V0 시각 정체성 완료** (PR #10).
  * 기준 문서: [`visual-identity.md`](visual-identity.md). 시각에 관해서는 06을 대체합니다.
  * 근거: [V0 spec](specs/2026-10-10-visual-identity-design.md), 결정 V1~V7([`decisions.md`](decisions.md)).
  * 색 값의 출처: [`tools/palette.py`](tools/palette.py) (`--check`로 대비 검사).
  * 로고 원본: [`logo/`](logo/), 견본: [`specimen/index.html`](specimen/index.html), 시안 기록: [`artifacts/index.json`](artifacts/index.json).
* 테스트: 저장소 루트에서 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`
* 고운돋움 TTF는 저장소에 넣지 않습니다(`.suberpowers/fonts/GowunDodum-Regular.ttf`). 받는 곳: `https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf`
  * 글꼴이 없으면 워드마크 생성 테스트 2개가 **skip**됩니다. 새 checkout이나 CI에서 전부 통과로 보여도 그 2개는 돌지 않은 것입니다. 워드마크를 고쳤다면 글꼴을 받고 다시 돌립니다.
* 로고 원본(`logo/`)을 바꾸면 순서대로 다시 만듭니다.
  1. 워드마크·가로 조합: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py --font .suberpowers/fonts/GowunDodum-Regular.ttf --out-dir docs/identity/design/logo`
  2. 로고 모음 산출물: `python3 docs/identity/design/tools/logo_sheet.py`. 다시 만들지 않으면 `test_logo_sheet_matches_committed_artifact`가 실패합니다.

## 다음 할 일
지금은 대기합니다. 아래 일이 생기면 엽니다.
1. **writing 확인 창 슬롯 답:** 확인 창 슬롯을 역할별로 나눌지, 상한 없음 표기를 어떻게 할지 writing 답(Issue #191)이 오면 `tools/lengths.py`의 `DIALOG_SLOTS`·`NO_LIMIT`과 `lengths.md`를 맞춥니다.
2. **윤달 조회 계약:** server 음력→양력·윤달 조회(#141)가 REST 계약에 들어오면 app에 `date-picker` `birth` 목표 모양(V31)으로 바꾸도록 확인합니다.
3. **app 대응 지원:** app이 명세로 만들 수 없는 곳이나 저사양 Android 성능 결과를 `to:design` Issue로 보내면 컴포넌트 계약 버전 규칙대로 고칩니다. notice는 #82입니다.
4. W1 원어민 검수 문장이 나오면 일본어 줄 간격(1.75 / 1.7)을 다시 확인합니다.
5. app이 토큰 형식 변경을 요청하면 계약 버전 규칙(`tokens/README.md`)대로 대응합니다.
