# 명리일기 컴포넌트 명세

컴포넌트 계약 2.0.0 · 토큰 계약 1.1.0 이상을 기대합니다.

* 제공: design / 사용: app (계약 목록 `docs/contracts/README.md`)
* 근거: [V2 spec](../specs/2026-10-11-components-design.md), [근거 잠금·글자 수 spec](../specs/2026-10-11-depth-lock-lengths-design.md), 결정 V13~V27([`../decisions.md`](../decisions.md)), 화면 목록 IA 계약 v1([`docs/ia/screens.json`](../../../ia/screens.json)), 토큰 [`../tokens/`](../tokens/README.md)
* 명세는 특정 위젯 라이브러리에 묶이지 않습니다. Material 대응은 각 `.md`에 참고 힌트로만 적습니다.
* 고칠 일은 GitHub Issue(`to:design`)로 보냅니다.

## 읽는 법

* **JSON은 사실, Markdown은 설명입니다.** JSON에는 변형·구성 요소별 토큰·크기·상태별 차이·쓰는 요소와 패턴·햅틱·접근성만 있습니다. 이유·배치·쓰는 화면·시안은 같은 이름의 `.md`에 있습니다.
* **토큰 참조:** `"{color.action.primary}"`처럼 중괄호로 토큰 이름을 가리킵니다(DTCG 참조 표기). 모든 참조는 테마 조합 4가지(라이트·다크 × ko·ja) 모두에서 풀립니다.
* **직접 값:** 그 컴포넌트에서만 쓰는 치수는 `{"value": 52, "unit": "px"}`, 시간·곡선은 깊이와 관계없이 모두 `motion.*` 토큰을 가리킵니다(검사기가 확인). 줄 사이 어긋남(`stagger`)처럼 시간 길이가 아닌 간격만 `{"value": 150, "unit": "ms"}`로 적습니다.
* **`uses`:** 쓰는 요소(`elements.json`)와 상호작용 패턴(`interaction.json`)의 id 목록입니다.
* **`pattern`:** 상태가 바뀔 때 쓰는 상호작용 패턴 id입니다.
* **`states`:** 기본 모습(`parts`)에서 달라지는 것만 적습니다. IA 화면 상태와 같은 상태는 IA id 그대로(`time-unknown`, `out-of-range`), 그 밖의 상태는 camelCase(`selectedOnDiary`)로 적습니다.
* **`component` / `element`:** 구성 요소가 다른 컴포넌트·요소를 그대로 쓴다는 뜻입니다.

컴포넌트 하나의 필드:

| 필드 | 뜻 |
| --- | --- |
| `id` | IA `components`의 id |
| `summary` | 한 줄 설명 |
| `uses` | 쓰는 요소·패턴 |
| `variants` | 변형 목록(`id`, `when`, 달라지는 `parts`) |
| `parts` | 구성 요소별 토큰과 크기 |
| `states` | 상태별 차이(`pattern`, `parts`, `note`) |
| `motion` | 여러 단계로 이어지는 움직임(예: 일기 저장 순서) |
| `haptic` | 햅틱 순간과 세기 |
| `a11y` | 역할, 라벨 규칙, 최소 터치 크기 |
| `rules` | 짧은 규칙 문장 |

## 파일

| 파일 | 담는 것 |
| --- | --- |
| `interaction.json` | 공통 상호작용 패턴 12개, 햅틱, 동작 줄이기·투명도 줄이기·저사양 대체 규칙 |
| `elements.json` | 반복 요소 16개(낙관 도장, 오행 칸, 길흉 톤, 꼬리표, 밑줄, 경고 표시, 잠긴 구역 등) |
| `frame.json` | tab-bar, app-bar, sheet, ad-banner |
| `feedback.json` | dialog, toast, notice-banner, skeleton, empty-state, error-state + 화면 상태 대응표 `stateMap` |
| `input.json` | input-step, text-field, date-picker, time-picker, segmented, city-search, check-row |
| `action.json` | primary-button, social-login-button, share-button, settings-row, offer-card |
| `sentence.json` | sentence-block, term-token, depth-link, reaction-button |
| `today.json` | day-character, lucky-card, guide-question-card, share-image |
| `calendar.json` | calendar-month, day-cell, event-row |
| `diary.json` | diary-row, diary-editor, draft-indicator, tag-chip |
| `saju.json` | saju-pillars, ohaeng-bar, manse-table, daeun-table |

IA 컴포넌트 41개가 묶음 파일 전체에서 정확히 한 번씩 나옵니다(광고 배너 `ad-banner`는 frame, 광고 제거권 `offer-card`는 action).

## 공통 규칙

* **명세에 적지 않은 효과는 쓰지 않습니다.** 위젯 라이브러리의 기본 물결 효과, 그림자, 표면 색조, 상태 겹침 색을 끄고 명세 값을 입힙니다.
* 스피너는 쓰지 않습니다. 불러오는 중은 skeleton, 버튼 처리 중만 점 숨쉬기입니다.
* 문장·UI 문구는 모두 자리 채우기입니다. 문구는 writing(UI 슬롯)과 server(콘텐츠)가 정하고, 명세는 자리·글자 스타일·줄바꿈·자르기 규칙만 정합니다. `.md`에 나오는 문구는 예시입니다.
* 생김새는 두 플랫폼에서 하나입니다. 뒤로 가기 제스처, 시스템 공유, 스크롤 튕김, 키보드는 플랫폼 방식을 따릅니다.
* 기기의 글자 크기 설정을 따릅니다. 칸이 고정된 표(원국표·만세력·대운, 달력 칸)만 1.3배 상한을 둡니다(`a11y.textScaleMax`).
* 길흉은 색만으로 전하지 않습니다. 스크린리더 라벨에 길흉 낱말을 넣습니다.
* **모양 규칙(결정 V26):** 누르면 무언가를 실행하는 동작(버튼: 저장·로그인·공유·광고 보고 열기 등)은 둥근 사각(`radius.md`), 값·상태를 보여 주거나 고르는 것(배지·칩·꼬리표·segmented·toast)은 알약(`radius.full`)입니다. 가르는 기준은 "누른 결과가 무언가를 실행하는가, 그 값을 더 보여 주는가"입니다. 행운 칩·태그 칩은 눌러도 그 값의 설명이나 모음을 보여 줄 뿐이라 값 표시, 곧 알약입니다. 이 기준에 예외는 없습니다.
* **화면 좌우 여백(결정 V26):** 페이지 화면의 좌우 여백은 `space.20`입니다(시트 안쪽 여백과 같음). app-bar만 아이콘 터치 영역 때문에 `space.16`입니다.

## 버전

| 바뀌는 것 | 올리는 버전 |
| --- | --- |
| 컴포넌트·변형·상태·구성 요소 이름이 바뀌거나 빠짐 | 주 버전 |
| 컴포넌트·변형·상태·구성 요소 추가 | 부 버전 |
| 값만 바뀜 | 수 버전 |

토큰 계약과 따로 셉니다. 주 버전 변경은 `docs/workflow.md` §5.1을 따릅니다.

| 버전 | 날짜 | 내용 |
| --- | --- | --- |
| 1.0.0 | 2026-10-11 | 마일스톤 V2: IA 컴포넌트 41개, 패턴 12개, 요소 15개 |
| 2.0.0 | 2026-10-11 | 근거 깊이 잠금(D60): 풀이 시트의 '내 사주에서는' 상자와 `term-token` `locked` 빠짐, 근거 시트 구성 `depth-link.evidenceSheet`와 잠김 상태 4개, `sentence-block` `locked`, 요소 `lock.veil`. `share-button` `pill` → `soft`(둥근 사각). 모양 규칙·화면 여백 |

## 검사 (design)

```
python3 docs/identity/design/tools/components.py     # 저장소 루트에서
```

검사하는 것(`tools/test_components.py`가 커밋된 파일에 돌림):

* IA 컴포넌트 41개 id가 정확히 한 번(빠짐·넘침·겹침)
* 구성 요소가 가리키는 `component`(IA 컴포넌트)·`element`(요소)가 있음, 변형 id 겹침 없음, 햅틱 세기는 selection·light·medium
* 문자열 중간에 섞인 `{토큰}` 없음(값 하나에 참조 하나)
* 모든 `{토큰}` 참조가 테마 조합 4가지 모두에 있음(깊이와 관계없이)
* `uses`·`pattern`이 요소·패턴 id를 가리킴, 패턴의 시간·곡선은 토큰 참조, 모든 패턴에 동작 줄이기 대체
* `stateMap`이 IA 화면 상태 전부를 덮고 IA 컴포넌트를 가리킴
* 필드 이름이 위 표 밖이면 실패, JSON마다 같은 이름의 `.md`, 이 README가 모든 파일과 계약 버전을 적음
