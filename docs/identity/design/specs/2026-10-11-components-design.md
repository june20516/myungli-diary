# 마일스톤 V2 컴포넌트 명세 설계

* 작업 단위: design
* 마일스톤: V2 (로드맵: 선행 V1·IA, 후행 A1 UI 구현)
* 기준 문서: [시각 정체성 기준](../visual-identity.md), [V1 spec](2026-10-11-design-tokens-design.md), IA 계약 v1 [`docs/ia/screens.json`](../../../ia/screens.json)
* 입력: Issue #16(IA 컴포넌트 목록), Issue #24(표기 freeze, 처리함)
* 계약: 컴포넌트 명세 (제공 design → 사용 app), 디자인 토큰 1.1.0
* 시안: brainstorming 시안은 로컬 `.suberpowers/brainstorm/`(git 제외). 고른 시안은 [`../artifacts/index.json`](../artifacts/index.json)에 `design-v2-*`로 등록합니다(§8).

## 1. 목적과 완료 기준

app이 IA의 컴포넌트 39개를 **명세와 토큰만 보고** Flutter로 만들 수 있게 합니다. 명세는 생김새(구성 요소·토큰·변형), 상태별 모습, 상호작용(피드백·움직임·햅틱), 접근성을 담습니다. 명세는 특정 위젯 라이브러리에 묶이지 않습니다(§2.4).

V2는 다음이 모두 있을 때 끝납니다.

1. `components/`의 명세 파일: 묶음 9개 + 공통 2개(`interaction`, `elements`), 파일마다 JSON(사실) + Markdown(설명). 계약 설명 `components/README.md`(컴포넌트 계약 1.0.0)
2. 토큰 1.1.0: motion·shadow 토큰과 새 역할 색(§5). 생성기 `tools/tokens.py`가 원본입니다.
3. 검사 도구 `tools/components.py`와 테스트(§7) 통과, 대비 검사 통과
4. `visual-identity.md`, 견본 페이지, 결정 로그(V13~V22), 시안 기록, `CLAUDE.md` 갱신
5. app 앞 notice, 지휘 세션 앞 request·report Issue(§9)

## 2. 명세 형식 (결정 V13)

### 2.1. 파일
```
docs/identity/design/components/
  README.md                 계약 설명, 버전, 읽는 법, 파일 목록
  interaction.json / .md    공통 상호작용 패턴, 햅틱, 동작 줄이기·저사양 대체 규칙
  elements.json / .md       반복 패턴 요소 15개(§4)
  frame.json / .md          tab-bar, app-bar, sheet
  feedback.json / .md       dialog, toast, notice-banner, skeleton, empty-state, error-state + 화면 상태 대응표
  input.json / .md          input-step, text-field, date-picker, time-picker, segmented, city-search, check-row
  action.json / .md         primary-button, social-login-button, share-button, settings-row
  sentence.json / .md       sentence-block, term-token, depth-link, reaction-button
  today.json / .md          day-character, lucky-card, guide-question-card, share-image
  calendar.json / .md       calendar-month, day-cell, event-row
  diary.json / .md          diary-row, diary-editor, draft-indicator, tag-chip
  saju.json / .md           saju-pillars, ohaeng-bar, manse-table, daeun-table
```
* JSON에는 **사실**만 적습니다: 변형, 구성 요소별 토큰, 크기, 상태별 차이, 쓰는 요소·패턴, 햅틱, 접근성. 이유·배치 설명·예시 그림 링크는 Markdown에 씁니다.
* 컴포넌트 계약 버전은 토큰 계약과 따로 셉니다. 규칙은 토큰과 같습니다: 컴포넌트·변형·상태·구성 요소 이름이 바뀌거나 빠지면 주 버전, 추가는 부 버전, 값만 바뀌면 수 버전.

### 2.2. 컴포넌트 JSON 모양
```json
{
  "version": "1.0.0",
  "group": "action",
  "components": [
    {
      "id": "primary-button",
      "summary": "주 동작 버튼",
      "uses": ["press.ink", "loading.breathe"],
      "variants": [
        { "id": "filled", "when": "화면의 주 동작" },
        { "id": "quiet", "when": "보조 동작(다시 입력, 건너뛰기)" },
        { "id": "destructive", "when": "되돌릴 수 없는 동작", "uses": ["mark.caution"] }
      ],
      "parts": {
        "container": { "bg": "{color.action.primary}", "radius": "{radius.md}", "height": { "value": 52, "unit": "px" } },
        "label": { "fg": "{color.action.on-primary}", "type": "{type.label.lg}" }
      },
      "states": {
        "pressed": { "pattern": "press.ink" },
        "disabled": { "parts": { "container": { "bg": "{color.disabled.bg}" }, "label": { "fg": "{color.disabled.fg}" } } },
        "loading": { "pattern": "loading.breathe", "note": "글자 자리에 점 세 개" }
      },
      "haptic": [],
      "a11y": { "role": "button", "label": "글자 그대로", "minTarget": 48 }
    }
  ]
}
```
* 토큰은 `{이름}`으로 가리킵니다(DTCG 참조 표기). 그 컴포넌트에서만 쓰는 치수는 `{ "value", "unit": "px" }`로 직접 적습니다.
* `uses`·`pattern`은 `elements.json`의 요소 id와 `interaction.json`의 패턴 id를 가리킵니다.
* 필드 이름은 위가 기준입니다: `version`, `group`, `components[]`의 `id`·`summary`·`uses`·`variants`·`parts`·`states`·`motion`·`haptic`·`a11y`·`rules`. `rules`는 짧은 규칙 문장 목록입니다.

### 2.3. 공통 규칙
* **명세에 적지 않은 효과는 쓰지 않습니다.** 위젯 라이브러리의 기본 물결 효과, 그림자, 표면 색조, 상태 겹침 색을 끄고 명세 값을 입힙니다.
* 스피너는 쓰지 않습니다. 불러오는 중은 skeleton, 버튼 처리 중만 점 숨쉬기입니다(§3).
* 문장·UI 문구는 모두 자리 채우기입니다. 문구는 writing(UI 슬롯)과 server(콘텐츠)가 정하고, 명세는 자리·글자 스타일·줄바꿈·자르기 규칙만 정합니다.
* 1인 개발 비용을 이유로 경험을 줄이지 않습니다. 성능이 걱정되는 효과는 대체 규칙을 함께 적습니다(§3.3).

### 2.4. 구현 수단
* 생김새는 두 플랫폼에서 하나입니다. 뒤로 가기 제스처, 시스템 공유, 스크롤 튕김, 키보드는 플랫폼 방식을 따릅니다.
* app은 1차로 Flutter Material 3 위에 토큰을 입혀 만들 수 있습니다. 명세는 Material 위젯 이름을 쓰지 않으므로 나중에 자체 위젯으로 옮겨도 명세는 그대로입니다. Material 대응 힌트는 Markdown에 참고로만 적습니다.

## 3. 공통 상호작용 (결정 V14)

### 3.1. 패턴 (`interaction.json`)

| 패턴 id | 쓰임 | 움직임 |
| --- | --- | --- |
| `press.ink` | 모든 눌림 | 누른 자리에서 가장자리가 부드러운 원형 얼룩이 번짐(알파 0.12, 그 컴포넌트 글자색). 자람 520ms `seep`, 떼면 420ms 동안 1.15배로 번지며 사라짐. 구현은 원형 그라데이션(흐림 필터 아님). 얼룩은 컴포넌트 안쪽 별도 층에서만 잘림 |
| `appear.seep` | 토스트·배너·확인 창·풀이 내용 | 제자리에서 흐림 8px→0, 투명도 0→1. 320ms `seep` |
| `disappear.seep` | 위의 사라짐 | 흐림 0→8px, 투명도 1→0. 200ms `ease` |
| `select.seep-slide` | segmented·탭 선택 표시 | 새 표시가 이전 자리 쪽에서 거리의 **15%** 만큼 미끄러져 들어오며 흐림 6px→0, 크기 0.92→1. 340ms `seep`. 이전 표시는 제자리에서 흐림 0→6px·투명도 1→0·크기 1→1.06, 260ms |
| `loading.breathe` | skeleton, 버튼 처리 중 점 | 투명도 0.55↔1, 한 주기 1800ms `ease-in-out`, 줄마다 150ms씩 어긋남 |
| `seal.stamp` | 도장 찍힘 | 520ms 2구간: ① 0~35% 크기 1.2→1, 투명도 0→0.55, 흐림 3→1.5px, `stamp-press` ② 35~100% 투명도 0.55→1, 흐림 1.5→0, `seep` |
| `seal.erase` | 도장 지워짐 | 200ms, 흐림 0→5px, 투명도 1→0 |
| `mark.underline-grow` | 달력 선택 밑줄 | 가로 크기 0→1, 가운데 기준, 420ms `seep` |
| `sheet.enter` / `sheet.exit` | 시트 | 아래에서 올라옴 420ms `enter` / 내려감 300ms `exit`. 바깥 덮개는 280ms 투명도 |
| `sheet.stack` | 시트 깊어짐 | 새 시트가 위에 쌓이고 아래 화면은 크기 0.92·밝기 0.9, 아래 시트는 위로 30px·크기 0.94·밝기 0.95. 이동·크기만 씀 |
| `focus.ring` | 입력 포커스 | 테두리 1px `line` → 2px `action.primary`, 160ms |

* 곡선: `seep` = cubic(0.2, 0.7, 0.2, 1), `enter` = cubic(0.2, 0.8, 0.2, 1), `exit` = cubic(0.4, 0, 1, 1), `stamp-press` = cubic(0.5, 0, 0.9, 0.6), `standard` = cubic(0.4, 0, 0.2, 1). 시간·곡선은 모두 motion 토큰을 가리킵니다(§5).

### 3.2. 햅틱
의미 있는 순간에만 울립니다. 기기의 시스템 햅틱 설정을 따릅니다.

| 순간 | 세기 |
| --- | --- |
| 선택이 바뀜(segmented, 탭, 체크, 날짜 휠 눈금) | selection(아주 가벼움) |
| 저장·완료(일기 저장, 동의 완료) | light |
| 반응(좋아요) | light |
| 되돌릴 수 없는 동작 확인(일기 삭제, 계정 삭제) | medium |

일반 버튼·목록 줄을 누를 때는 울리지 않습니다.

### 3.3. 대체 규칙
* **동작 줄이기**(기기 설정)가 켜지면 모든 패턴은 투명도 변화만 남깁니다. 이동·크기·흐림을 뺍니다.
* **투명도 줄이기**가 켜지면 반투명 탭 바는 불투명 `bg.sheet`로 바꿉니다.
* 흐림은 대상 컴포넌트 자신에게만 겁니다(배경 흐림 아님). 저사양 기기에서 프레임이 떨어지면 흐림을 빼고 투명도만 씁니다. app은 저사양 Android에서 한 번 확인합니다.

## 4. 요소 (`elements.json`)

여러 컴포넌트가 함께 쓰는 반복 패턴입니다. 컴포넌트는 `uses`로 가리킵니다.

| 요소 id | 정의 | 쓰는 곳 |
| --- | --- | --- |
| `seal` 낙관 도장 (결정 V16) | 로고 낙관 경로 `M1.2 1.5 q8.8 -1.3 17.6 0 q1.2 8.5 0 17 q-8.8 1.3 -17.6 0 q-1.2 -8.5 0 -17 z`(20 단위), -8° 기울임. 변형: `fill`(진한 `seal.fill`, 날짜 숫자를 `seal.knock` 가는 양각으로 새길 수 있음), `soft`(옅은 반투명 `seal.soft`), `outline`(1.6px `seal.fill` 선). 안의 내용은 도장 영역 가운데 정렬. 크기는 쓰는 곳이 정함 | 선택된 탭(fill + 아이콘 흰색), 반응 하트(fill), 일기 종이(fill + 날짜, 64px), 달력 일기 쓴 날(soft 26px), 달력 오늘(outline 26px), 일기 목록 날짜(soft 34px), 질문 카드 버튼 뒤(soft 52px) |
| `ohaeng.cell` 오행 칸 | 바탕 `ohaeng.<오행>.bg`, 글자 `ohaeng.<오행>.fg`, `radius.sm`. 크기 `pillar`(원국표 66px 높이, 한자 `type.hanja.pillar` + 한글 독음 `type.caption.sm`), `mini`(30×30, 한자 15px 700) | 원국표, 만세력 표, 대운·세운 |
| `ohaeng.swatch` 오행 견본 | `ohaeng.<오행>.swatch` + `swatch.border` 테두리 | 행운 색 칩, 오행 분포 |
| `tone` 길흉 톤 | 좋음·귀인 = coral 계열, 나쁨 = neutral 채움, 중립·평범 = 테두리만(결정 V8·V10). 배지·태그·달력 칸이 같은 매핑 | day-character, tag-chip, day-cell |
| `tag.status` 상태 꼬리표 | 옅은 sage 알약(`status.bg`/`status.fg`, `type.label.md`) | 일정 요약(진행 중·다음), 대운 지금·세운 올해 |
| `tag.me` "나" 꼬리표 | sage 채움 작은 알약(10px 700), 칸 오른쪽 위 모서리에 겹침(칸이 자르지 않음) | 원국표 일간 |
| `highlight.current` 현재 강조 | 기둥·칸 바탕 `status.bg` + 글자 `action.primary` 굵게. 낙관 윤곽은 칸 하나 단위(달력 오늘)에만 | 대운 지금, 세운 올해 |
| `mark.underline-grow` 펼침 밑줄 | `action.primary` 14×2px 둥근 막대, 숫자 아래 | 달력 선택 날짜 |
| `mark.caution` 경고 표시 | Phosphor `warning-circle` Fill, 글자 높이에 맞춰 문장 안에 놓임. 빨간색 없음(결정 V18) | 되돌릴 수 없는 동작의 확인 창 제목·버튼 |
| `link.inline-nowrap` 끊기지 않는 링크 | 문장 끝에 붙는 링크 전체를 한 덩어리로(줄 끝에 안 들어가면 통째로 다음 줄). 링크 글자 사이에 U+00A0·U+2060. 스크린리더 초점을 따로 받음 | 근거 보기 |
| `surface.paper` 종이 | `bg.sheet`, `radius.lg`, 안쪽 16px, **아래 여백에 늘 도장 자리**(64px 도장 + 12px) | 일기 쓰기·보기 |
| `rail.timeline` 세로 흐름 줄 | `line` 1.5px, 날짜 열 가운데, 요일 아래에서 다음 날짜까지 | 일기 목록 |
| `term` 용어 표시 | `term.bg`/`term.fg`, `radius.xs`, 굵게 하지 않음(V0) | term-token, 행 머리 용어 |
| `skeleton.bone` 자리 | `skeleton.bone` 색, 실제 요소와 같은 크기·반경 | skeleton |
| `icon` 아이콘 (결정 V15) | Phosphor(MIT). 미선택·평소 Light, 선택 Regular. Bold·Fill은 쓰지 않음(경고 표시만 Fill). 세트에 없는 것은 Phosphor 24 격자·획 규칙으로 직접(오행·절기·시간 모름 등) | 전체 |

## 5. 토큰 1.1.0 (결정 V13)

추가만 하므로 부 버전입니다. 생성기 `tools/tokens.py`에 더합니다.

### 5.1. 움직임 (`primitive`)
| 토큰 | 값 | DTCG 타입 |
| --- | --- | --- |
| `motion.duration.short` | 200ms | duration |
| `motion.duration.medium` | 320ms | duration |
| `motion.duration.select` | 340ms | duration |
| `motion.duration.long` | 420ms | duration |
| `motion.duration.stamp` | 520ms | duration |
| `motion.duration.breathe` | 1800ms | duration |
| `motion.duration.toast-hold` | 2500ms | duration |
| `motion.easing.seep` | (0.2, 0.7, 0.2, 1) | cubicBezier |
| `motion.easing.enter` | (0.2, 0.8, 0.2, 1) | cubicBezier |
| `motion.easing.exit` | (0.4, 0, 1, 1) | cubicBezier |
| `motion.easing.stamp-press` | (0.5, 0, 0.9, 0.6) | cubicBezier |
| `motion.easing.standard` | (0.4, 0, 0.2, 1) | cubicBezier |

### 5.2. 그림자 (`primitive`)
| 토큰 | 값 | 쓰임 |
| --- | --- | --- |
| `shadow.raised` | 0 4px 16px neutral-900 알파 0.14 | 공유 미리보기 이미지 |

### 5.3. 새 역할 색 (`color.light` / `color.dark`)
| 토큰 | 라이트 | 다크 |
| --- | --- | --- |
| `color.scrim` | neutral-950 알파 0.32 | `#000000` 알파 0.50 |
| `color.inverse.bg` / `color.inverse.fg` 토스트 | neutral-900 / neutral-100 | neutral-100 / neutral-900 |
| `color.disabled.bg` / `color.disabled.fg` | neutral-100 / neutral-600 | neutral-800 / neutral-500 |
| `color.bar.bg` 반투명 탭 바 | `#ffffff` 알파 0.62 | neutral-900 알파 0.62 |
| `color.seal.fill` | → `action.primary` | → `action.primary` |
| `color.seal.soft` | sage-700 알파 0.22 | sage-200 알파 0.28 |
| `color.seal.knock` | sage-50 | neutral-900 |
| `color.status.bg` / `color.status.fg` | → `term.bg` / `term.fg` | → `term.bg` / `term.fg` |
| `color.tag.good.bg` / `.fg` | coral-100 / coral-700 | coral-800 / coral-200 |
| `color.tag.bad.bg` / `.fg` | neutral-100 / neutral-700 | neutral-800 / neutral-200 |
| `color.tag.neutral.border` / `.fg` | neutral-300 / neutral-700 | neutral-700 / neutral-400 |
| `color.calendar.weekday.sun` / `.sat` | → `ohaeng.fire.fg` / `ohaeng.earth.fg` | 같음(모드별 값) |
| `color.skeleton.bone` | neutral-900 알파 0.07 | neutral-100 알파 0.08 |
| `color.timeline.line` | → `line` | → `line` |

### 5.4. 새 글자 스타일 (`typography` / `typography.ja`)
| 토큰 | 글꼴 | 크기 | 굵기 | 줄 간격 | 자간 (ko·en / ja) | 쓰임 |
| --- | --- | --- | --- | --- | --- | --- |
| `type.body.ui` | ui | 14 | 400 | 1.5 | -0.28 / 0 | 확인 창 본문, 설정 줄, 일정 줄, 행 머리 표의 값 |
| `type.caption.lg` | ui | 13 | 400 | 1.45 | -0.26 / 0 | 배너, 이유 한 줄, 도움말, 칩 설명 |

* `color.focus.ring`은 따로 두지 않고 `action.primary`를 씁니다.
* 대비 검사(`palette.py --check`)에 더할 조합: `tag.*.fg`/`bg`, `inverse.fg`/`inverse.bg`, `calendar.weekday.*` × `bg.base`, `text.primary` × (`seal.soft`를 `bg.base`·`calendar.good.bg`·`calendar.caution.bg` 위에 겹친 색), `status.fg`/`status.bg`, `seal.knock`/`seal.fill`. `disabled.fg`는 WCAG 1.4.3 예외(비활성)이지만 3:1 이상을 지킵니다.
* `visual-identity.md`의 "그림자와 모션 토큰은 두지 않습니다" 문장과 반경 표의 `radius.md` 쓰임 예시를 고칩니다.

## 6. 컴포넌트 (묶음별)

### 6.1. frame (결정 V17)
* **tab-bar**: 반투명 `bar.bg` + 뒤 흐림(투명도 줄이기 시 불투명). 탭 4개, 높이 72px(아래 안전 영역 별도). 아이콘 24px, 글자 11px. 선택 탭: 아이콘 Regular `seal.fill`색 위 흰색 + `seal` fill 34px(`seal.stamp`), 글자 `action.primary` 600. 미선택: Light, `text.secondary` 계열(neutral-500). 선택이 바뀌면 이전 도장 `seal.erase`, 햅틱 selection.
* **app-bar**: 변형 `tab-root`(탭 첫 화면: 작은 제목 `type.subtitle` 왼쪽 + 오른쪽 동작 아이콘) / `inner`(뒤로 + 제목 왼쪽 정렬 + 동작). 높이 44px. 바탕 없음(아래 화면이 비침).
* **sheet**: 변형 `half` / `full`. 위 모서리 `radius.xl`, 손잡이 36×4, 바깥 덮개 `scrim`. 깊어짐은 `sheet.stack`(새 route). 닫기: 뒤로 가기·끌어내리기 = 한 단계, 바깥 누르기 = 모두.

### 6.2. feedback
* **dialog**: `bg.sheet`, `radius.lg`, 좌우 28px 여백, 제목 `type.subtitle` + 본문 `type.body.ui` `text.secondary`, 오른쪽 아래 글자 버튼. 되돌릴 수 없는 동작은 제목 앞 `mark.caution`, 확정 버튼 글자 `text.primary` 굵게(빨간색 없음), 취소 `action.primary`. 나타남 `appear.seep`.
* **toast**: `inverse.bg`/`inverse.fg` 알약, 탭 바 위 16px, `motion.duration.toast-hold` 뒤 `disappear.seep`.
* **notice-banner**: 화면 맨 위 내용 첫 줄(떠 있지 않음), `bg.sheet`, `radius.md`, 아이콘 + `type.caption.lg` `text.secondary`. 닫기 없음. 상태가 풀리면 `disappear.seep`.
* **skeleton**: `skeleton.bone`, `loading.breathe`.
* **empty-state** / **error-state**: sage 원(56px, `status.bg`) 안 Light 아이콘 + 문장(`type.sentence.body`) + 있으면 버튼(빈 상태 주 버튼, 오류 상태 `quiet` "다시 시도").
* **화면 상태 대응표** (`feedback.json`의 `stateMap`): `loading` → skeleton, `empty` → empty-state, `error` → error-state, `offline` → notice-banner(받아둔 내용이 없으면 error-state 오프라인 변형), `draft` → draft-indicator + notice-banner, `time-unknown` → notice-banner(사주 표는 시주 칸 비움 + 배너), `out-of-range` → input-step 오류 줄. IA 화면 `states`의 상태 id 7종을 모두 덮어야 합니다(§7).

### 6.3. input
* **input-step**: 진행 막대(온보딩만, 3px), 질문 `type.title`, 입력, 도움말 `type.caption.lg`, 오류 줄, 아래 고정 버튼(키보드 위에 붙음).
* **text-field**: `bg.sheet`, 1px `line`, `radius.md`, 높이 52px, 글자 17px. 포커스 `focus.ring`(바탕 변화 없음).
* **date-picker**: 변형 `birth`(휠 년·월·일, 양력·음력 segmented, 음력이면 그해 윤달이 있을 때만 월 휠에 "윤N월" 끼움, 음력이면 양력 확인 줄, 지원 범위 1900-01-31~2099-12-31 밖은 오류 줄) / `calendar`(시트 안 달력, 표시는 calendar-month와 같음, 미래 날짜 흐리게 막음, 길흉 칸 채우기 없음, 아래 버튼에 고른 날짜). 휠 선택 띠 `status.bg`, 휠 눈금 햅틱 selection.
* **time-picker**: 변형 `birth`(오전·오후·시·분 휠 + "몰라요" 체크, 켜면 휠 흐림 + 3주 안내 `appear.seep`; 출생 기록의 벽시계 시각을 그대로 받음; 시진 확인 줄은 엔진이 계산한 시진을 받을 수 있을 때만 — §9 요청) / `notify`(모름 없음).
* **segmented**: `bg.sheet` + 1px `line` 알약, 선택 표시 `action.primary` 알약 + 흰 글자, `select.seep-slide`, 햅틱 selection.
* **city-search**: 검색칸(text-field + 돋보기) + 결과 묶음 카드(설정 줄과 같은 모양, 도시 + 나라·지역 캡션).
* **check-row**: 떨어진 카드(`bg.sheet`, `radius.md`), 24px 체크 상자(`radius.sm`, 켜면 `action.primary` 채움 + 흰 체크가 그어짐), 오른쪽 "보기" 링크.

### 6.4. action
* **primary-button**: §2.2 예시가 기준. 둥근 사각 `radius.md`, 높이 52(조용한 44). 변형 `filled` / `quiet` / `destructive`(바탕 `text.primary`, 글자 `bg.sheet`, `mark.caution` 앞). 상태 `pressed`·`disabled`·`loading`(점 숨쉬기 — 스피너의 유일한 대체).
* **social-login-button**: 높이 52, `radius.md`, 세로로 쌓기 간격 12. 색·로고·문구는 각 사 공식 가이드와 공식 자산(아이콘 세트에서 가져오지 않음). 제공자는 지휘 미결.
* **share-button**: 변형 `icon`(app-bar 44px 터치, Light export) / `pill`(옅은 sage 알약 + 아이콘 + 글자).
* **settings-row**: 묶음 카드(`bg.sheet`, `radius.md`) 안에서 1px `line`으로 나눔. 글자 + 오른쪽 값(`text.secondary`) + 화살표.

### 6.5. sentence
* **sentence-block**: 문장 글꼴 `type.sentence.card`(카드) / `type.sentence.body`(본문). 호칭 자리 포함. 쓰임에 따라 자르기 규칙(예: 일기 목록 미리보기 2줄 말줄임).
* **term-token**: `term` 요소, 누르면 풀이 시트(`press.ink` → `sheet.enter`). 변형 `inline`(문장 안) / `label`(표 행 머리·십성 줄). 풀이 시트 내용: 일반 뜻 + "내 사주에서는" 상자(`status.bg`). **잠김** 변형: "내 사주에서는" 상자 흐림 + 자물쇠 + 열기 안내(무엇을 잠글지는 M0, Issue #32).
* **depth-link**: "근거 보기 ›", `action.primary` `type.label.lg`. 변형 `inline-end`(이유 문장 끝, `link.inline-nowrap`) / `block`(나 탭 등).
* **reaction-button**: 하트 44px 터치, Light `text.secondary`. 누르면 `seal` fill 34px가 `seal.stamp`로 찍히고 하트 Regular 흰색, 햅틱 light. 다시 누르면 `seal.erase`. 자리: 문장 아래 오른쪽 홀로(근거 보기와 떨어짐).

### 6.6. today
* **day-character**: 배지(V1 `badge.*`, `radius.full`, `type.label.md`) + 이유 한 줄(`type.caption.lg`) 끝에 depth-link `inline-end`.
* **lucky-card**: 변형 `color`·`direction`·`number`·`time`. 칩(`chip.bg` 알약, 아이콘 Regular 16 + 값; 색은 `ohaeng.swatch` 14px). 누르면 칩에 1.5px `action.primary` 안쪽 테두리 + 아래에 설명 한 줄이 `appear.seep`(칩 바탕 `radius.md` 상자). 다시 누르면 닫힘. 화면 폭에 따라 두 줄로 넘어감.
* **guide-question-card**: `bg.sheet`, `radius.lg`. 상태 `before`(질문 `type.sentence.card` + 주 버튼 "일기 쓰기") / `after`(질문 `text.secondary`, 가운데 조용한 버튼 "쓴 일기 보기", 버튼 글자 뒤 층에 `seal` soft 52px).
* **share-image**: 라이트 고정(V5), `gradient.today`, 날짜·배지·문장(호칭 포함)·행운 칩·로고 조합 + `image.footer`. 변형 `story` 9:16(이유 줄, 문장 전체, 칩 4개) / `feed` 4:5(문장 두 줄, 칩 3개) / `square` 1:1(첫 문장, 칩 3개). 공유 미리보기 시트 위 segmented로 고르고, 바뀔 때 `appear.seep`. 미리보기에 `shadow.raised`.

### 6.7. calendar (결정 V19)
* **calendar-month**: 달 제목 `type.subtitle` + 이전·다음. 요일 머리 `type.caption.md` 12px — 일 `calendar.weekday.sun`, 토 `calendar.weekday.sat`, 나머지 `text.secondary`. 날짜 숫자에는 요일 색을 넣지 않음. 달 넘김은 `appear.seep`.
* **day-cell**: 높이 62, `radius.sm`, 길흉 칸 채우기(V10). 숫자 `type.numeric.calendar`, 32px 상자 안 가운데(도장은 그 상자 가운데 26px). 아래 음력(`type.caption.sm` 10.5~11px `muted`): 초하루는 "월.1", 절기 날은 절기 이름(굵게). 표시:
  * 일기 쓴 날: `seal` soft 26px, 숫자 본문색
  * 오늘: `seal` outline 26px(일기 도장과 같은 크기·자리)
  * 선택: 숫자 `action.primary` 700 + `mark.underline-grow`
  * 일정: 날짜 아래 `action.primary` 점 5px
  * 겹침: 모두 같은 자리에서 겹쳐 그림(빼기 처리 없음). 반투명 도장이 길흉 바탕과 섞여 보이는 것은 의도(겹침으로 읽힘).
* **event-row**: 변형 `summary`(오늘 화면: 지금 시각 기준 `tag.status` "진행 중"/"다음" + 시각·제목 + "외 N개", 모두 지나면 개수 문장; 하루 종일은 진행 중으로 보되 시각 있는 일정이 앞섬) / `list`(그날 시트: 시각 58px 칸(하루 종일 포함) + 제목 + 화살표) / 빈 상태 + "일정 추가".

### 6.8. diary (결정 V20)
* **diary-row**: `rail.timeline` 왼쪽 날짜 열(숫자 18px 600 + `seal` soft 34px + 요일) + 오른쪽 카드(`bg.sheet`, `radius.lg`: 배지, 미리보기 두 줄 `type.sentence.body` 계열 14.5px 말줄임, 대표 태그).
* **diary-editor**: `surface.paper` 위 문장 글꼴 본문. 해시태그를 쓰지 않음(태그는 엔진이 저장 시 붙임). 저장 순간: 버튼 점 숨쉬기 → 종이 맨 아래로 스크롤 → 아래 여백에 날짜를 새긴 `seal` fill 64px `seal.stamp` → 대표 태그 칩 `appear.seep` → 토스트, 햅틱 light. 일기 보기도 같은 종이(도장 그대로, 아래 태그 칩).
* **draft-indicator**: app-bar 오른쪽 작은 글자 + 아이콘. 상태 `local`(구름 + "초안 저장됨") / `saving`(점 숨쉬기) / `saved`(체크 + "저장됨"), 바뀔 때 `appear.seep`.
* **tag-chip**: `tone` 요소(좋음 `tag.good`, 나쁨 `tag.bad`, 중립 `tag.neutral` 테두리), `radius.full`, `type.label.md` 12px, "#이름". 누르면 태그 모아보기. 목록·보기·저장 순간에 같은 컴포넌트(저장 순간은 Issue #31).

### 6.9. saju (결정 V21)
* **saju-pillars**: 왼쪽부터 시·일·월·연. 위 천간 십성, 아래 지지 십성(정기), 모두 term-token `label`. 칸 `ohaeng.cell` pillar. 일간 칸 2px `action.primary` 안쪽 테두리 + `tag.me`, 십성 줄은 "일간"(term-token). 시간 모름이면 시주 칸을 비우고 notice-banner.
* **ohaeng-bar**: 견본색 비례 막대(10px, 칸 사이 2px) + 다섯 오행 견본·이름·개수. 0개는 견본 투명도 0.35·숫자 `muted`.
* **manse-table**: 원국표와 같은 열 순서 격자, 왼쪽 행 머리(지장간·12운성·신살 = term-token `label`) 52px. 위에 `ohaeng.cell` mini 천간·지지. 지장간은 한자 + 한글 독음.
* **daeun-table**: 대운 가로 넘김(기둥 52px: 한국식 나이(core C22) + mini 두 칸 + 시작 연도), 세운 5×2(지금 대운 10년). 지금 대운·올해는 `highlight.current` + "지금"/"올해" 글자. 처음 열 때 지금 대운이 보이게 넘김.
* 표의 배치와 용어는 다른 만세력과 같게 둡니다(대조·신뢰). 차별은 깊이 구조(나 탭 문장 → 근거 보기 → 표), 모든 용어 풀이, 같은 시각 언어로 냅니다.

## 7. 검사 (`tools/components.py`, 테스트)

1. IA `docs/ia/screens.json`의 컴포넌트 39개 id가 묶음 파일 전체에서 **정확히 한 번** 나옵니다(빠짐·넘침·겹침 실패).
2. `{토큰}` 참조가 모든 테마 조합(색 모드 2 × 글자 언어 2)에 있습니다. 토큰 검사기 `tools/dtcg.py`를 재사용합니다.
3. `uses`·`pattern`이 `elements.json`·`interaction.json`의 id를 가리킵니다. 패턴의 `duration`·`easing`도 토큰 참조입니다.
4. `feedback.json`의 `stateMap`이 IA 화면 `states`에 나오는 상태 id 전부를 덮습니다.
5. JSON 파일마다 같은 이름의 `.md`가 있고, `components/README.md`가 모든 파일과 계약 버전을 적습니다.
6. 필드 이름이 §2.2의 목록 밖이면 실패합니다(오타 방지).
7. 토큰 1.1.0: 생성기 출력 = 커밋 파일, DTCG 검사(`duration`·`cubicBezier`·`shadow` 타입을 검사기에 추가), 대비 검사 추가 조합(§5.3).

## 8. 함께 고치는 문서와 산출물
* `tokens/` 1.1.0 재생성, `tokens/README.md` 버전 줄·파일 설명.
* `visual-identity.md`: 아이콘(Phosphor), 낙관 도장 요소, 상호작용 언어 요약, 요일 오행색, 그림자·모션 문장, `radius.md` 쓰임.
* `decisions.md`: V13(명세 형식·중립 명세) · V14(상호작용 언어·햅틱·대체) · V15(아이콘 Phosphor) · V16(낙관 도장 요소) · V17(화면 틀 C·시트 겹쳐 쌓기·닫기 규칙) · V18(경고 표시, 빨간색 없음) · V19(달력 표시 체계) · V20(일기 저장 도장·태그 칩 길흉·일기 목록 흐름 줄) · V21(사주 표: 오행 바탕·표준 배치·풀이 잠김 변형) · V22(공유 이미지 비율 3종·호칭 포함).
* 견본 `specimen/index.html`: V2 절(요소·상호작용 패턴 움직임 견본) 추가.
* `artifacts/`: 고른 시안을 HTML + PNG로 등록(`design-v2-*`, chosen), 버린 비교안은 superseded.
* `CLAUDE.md` 현재 상태·다음 할 일.

## 9. 전달
* **app** `kind:notice`: 컴포넌트 계약 1.0.0, 토큰 1.1.0, Phosphor(`phosphor_flutter`), 구현 메모(반투명 탭 바 배경 흐림, 자기 자신 흐림 스밈, 원형 그라데이션 번짐, `TweenSequence` 도장, nowrap 링크, 대체 규칙), 저사양 Android 성능 확인 요청.
* **root** `kind:request` (spec 승인 뒤 바로): ① `share-preview` components에 `segmented` 추가(공유 비율 고르기) ② 생일 시간 입력의 시진 확인 줄용 엔진 시진 값(core·server 경유, 받을 수 없으면 확인 줄을 뺌) ③ writing에 새 UI 문구 자리 전달(일정 상태 꼬리표, 초안 상태 3종, 잠김 안내, 공유 비율 이름, 저장 태그 알림). 이미 연 것: #31(diary-edit tag-chip), #32(M0 잠김 notice). 소셜 로그인 제공자는 지휘 미결 그대로.
* **root** `kind:report` (완료 시): V2 완료, 계약 목록 갱신 요청(컴포넌트 명세 1.0.0, 토큰 1.1.0), 로드맵 V2 완료.
* core·server: 일기 저장 응답에 대표 태그(키·길흉)가 있어야 함 — #31과 함께 지휘 세션이 전달.

## 10. 범위 밖
* Dart 코드와 Flutter 테마 구성(app).
* 문구·콘텐츠(writing·server).
* 오늘 일진을 원국표에 겹쳐 보는 화면(사용자 결정으로 하지 않음).
* 유료 범위와 결제 화면(M0).
* 소셜 로그인 제공자 선정(지휘).

## 11. 최종 리뷰 반영 (2026-10-11)



구현 뒤 브랜치 전체 리뷰와 main 병합으로 바뀐 것입니다. 위 절과 다르면 이 절이 맞습니다.



* **IA 41개:** main의 IA에 `ad-banner`(frame, 결정 V23: 탭 바 바로 위에 함께 고정)와 `offer-card`(action, D53·D54)가 더해져 명세도 41개입니다.

* **토큰 추가 (1.1.0 안):** `motion.duration.fade` 280ms(바깥 덮개, 이전 선택 표시가 사라짐. §3.1의 260·280ms를 하나로), `color.seal.on-soft`(라이트 sage-800 / 다크 sage-200, 결정 V24). 토큰이 없던 §3.1의 300ms·160ms·`ease`·`ease-in-out`은 `medium`·`short`·`standard`로 씁니다.

* **검사 강화 (§7):** 깊이와 관계없이 `duration`·`easing`(과 `…Duration`·`…Easing`) 키는 토큰 참조, 문자열 안에 섞인 참조 금지, `component`·`element` 링크와 변형 id 겹침, 햅틱 세기·`reduceMotion` 값, 이상한 모양 입력은 오류 대신 문제 문장.

* **지휘 결정 반영:** 소셜 로그인 카카오·Apple(D55), 시진 확인 줄은 기기 지역이 한국일 때만·대표 경도·`Asia/Seoul`·슬롯 `onboard-time.hour.confirm`(D58), 풀이 잠김 변형은 MVP 화면에 쓰지 않음(D53, 아이디어 I7).
