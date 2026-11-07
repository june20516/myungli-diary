# 명리일기 컴포넌트 명세

컴포넌트 계약 5.0.0 · 토큰 계약 1.4.0 이상을 기대합니다.

* 제공: design / 사용: app (계약 목록 `docs/contracts/README.md`)
* 근거: [V2 spec](../specs/2026-10-11-components-design.md), [근거 잠금·글자 수 spec](../specs/2026-10-11-depth-lock-lengths-design.md), [문장 조각·잠금 슬롯 spec](../specs/2026-10-13-term-segments-lock-slots-design.md), [구현 대응·글자 수 spec](../specs/2026-10-15-spec-followups-design.md), [로그인 수단·계정 합치기 spec](../specs/2026-10-22-login-methods-account-merge-design.md), [같은 날 여러 편 spec](../specs/2026-10-22-diary-row-multi-design.md), [계정 합치기·구매 내역 spec](../specs/2026-10-23-account-merge-purchase-design.md), [DS1 규칙 spec](../specs/2026-11-05-ds1-rules-design.md), [DS1 화면 spec](../specs/2026-11-05-ds1-screens-design.md), 결정 V13~V95([`../decisions.md`](../decisions.md)), 화면 목록 IA 계약 v5([`docs/ia/screens.json`](../../../ia/screens.json)), 토큰 [`../tokens/`](../tokens/README.md)
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
| `variants` | 변형 목록(`id`, `when`, 달라지는 `parts`). 변형의 `parts`는 최상위 `parts`의 같은 이름을 덮어쓰고, 최상위에 있지만 그 변형에서 그리지 않는 부품은 `visible: false`로 적습니다 |
| `parts` | 구성 요소별 토큰과 크기 |
| `states` | 상태별 차이(`pattern`, `parts`, `note`) |
| `motion` | 여러 단계로 이어지는 움직임(예: 일기 저장 순서) |
| `haptic` | 햅틱 순간과 세기 |
| `a11y` | 역할, 라벨 규칙, 최소 터치 크기 |
| `rules` | 짧은 규칙 문장 |

## 파일

| 파일 | 담는 것 |
| --- | --- |
| `interaction.json` | 공통 상호작용 패턴 13개, 햅틱, 동작 줄이기·투명도 줄이기·저사양 대체 규칙 |
| `elements.json` | 반복 요소 19개(낙관 도장, 오행 칸, 길흉 톤, 꼬리표, 밑줄, 경고 표시, 잠긴 구역, 목록 구분선, 두 버튼, 간지 칩, 키보드 내리기 등) |
| `frame.json` | tab-bar, app-bar, sheet, ad-banner, section-header, explain-sheet, scroll-hint |
| `feedback.json` | dialog, toast, notice-banner, skeleton, empty-state, error-state + 화면 상태 대응표 `stateMap` |
| `input.json` | input-step, text-field, date-picker, time-picker, segmented, city-search, check-row, account-choice |
| `action.json` | primary-button, social-login-button, share-button, settings-row, offer-card, purchase-row |
| `sentence.json` | sentence-block, term-token, depth-link, reaction-button, hanja-tag |
| `today.json` | date-header, day-character, lucky-card, tag-sentence-list, guide-question-card, share-image |
| `calendar.json` | calendar-month, day-cell, event-row, fortune-verdict, score-row |
| `diary.json` | diary-row, diary-editor, date-block, draft-indicator, tag-chip, diary-summary |
| `saju.json` | saju-pillars, ohaeng-bar, manse-table, daeun-table, luck-pillar, birth-info-row, band-table, stage-strip |

IA v5 컴포넌트 58개 가운데 명세를 쓴 57개가 묶음 파일 전체에서 정확히 한 번씩 나옵니다(광고 배너 `ad-banner`는 frame, 광고 제거권 `offer-card`는 action). 묶음마다 줄여 온 대기 목록 `IA_PENDING_COMPONENTS`는 DS1 2단계 묶음 E로 비었습니다. `score-scale` 1개는 쓰지 않기로 해(관문 답 2026-11-07, 색 규칙 시트에 척도 그림 없음) 명세 없이 `IA_REMOVAL_REQUESTED`에 두고 IA에 제거를 요청합니다.

## 공통 규칙

* **명세에 적지 않은 효과는 쓰지 않습니다.** 위젯 라이브러리의 기본 물결 효과, 그림자, 표면 색조, 상태 겹침 색을 끄고 명세 값을 입힙니다.
* 스피너는 쓰지 않습니다. 불러오는 중은 skeleton, 버튼 처리 중만 점 숨쉬기입니다.
* 문장·UI 문구는 모두 자리 채우기입니다. 문구는 writing(UI 슬롯)과 server(콘텐츠)가 정하고, 명세는 자리·글자 스타일·줄바꿈·자르기 규칙만 정합니다. `.md`에 나오는 문구는 예시입니다.
* 생김새는 두 플랫폼에서 하나입니다. 뒤로 가기 제스처, 시스템 공유, 스크롤 튕김, 키보드는 플랫폼 방식을 따릅니다.
* 기기의 글자 크기 설정을 따릅니다. 칸이 고정된 표(원국표·만세력·대운, 달력 칸)만 1.3배 상한을 둡니다(`a11y.textScaleMax`).
* **고정 높이는 최소 높이(결정 V30):** 명세의 고정 높이(`height`)는 기본 글자 크기에서의 높이입니다. 기기 글자가 커지면 글자가 잘리지 않게 늘어나는 최소 높이로 구현합니다. 대상은 `primary-button`, `text-field`, `segmented`, `social-login-button`, `lucky-card` 칩, `day-character` 배지 등 글자를 담은 칸 전부입니다. 칸이 고정된 표와 달력은 글자 크기에 상한(`a11y.textScaleMax`)을 두고, 칸은 그 상한 글자가 들어가는 데까지만 늘어납니다. 상한 위 설정에서는 더 늘지 않습니다(결정 V36).
* 길흉은 색만으로 전하지 않습니다. 스크린리더 라벨에 길흉 낱말을 넣습니다.
* **모양 규칙(결정 V26):** 누르면 무언가를 실행하는 동작(버튼: 저장·로그인·공유·광고 보고 열기 등)은 둥근 사각(`radius.md`), 값·상태를 보여 주거나 고르는 것(배지·칩·꼬리표·segmented·toast)은 알약(`radius.full`)입니다. 가르는 기준은 "누른 결과가 무언가를 실행하는가, 그 값을 더 보여 주는가"입니다. 행운 칩·태그 칩은 눌러도 그 값의 설명이나 모음을 보여 줄 뿐이라 값 표시, 곧 알약입니다. 이 기준에 예외는 없습니다.
* **화면 좌우 여백(결정 V26, V56):** 페이지 화면의 좌우 여백은 `space.20`입니다. 긴 문장을 읽는 화면이 중심이라 레퍼런스의 16보다 넉넉하게 둡니다. app-bar만 아이콘 터치 영역 때문에 `space.16`입니다. 시트 안쪽은 `space.24`입니다(V64).
* **간격 쓰임표(결정 V56):** 간격은 아래 토큰 단계만 쓰고 직접 쓴 px 간격은 0 말고 없습니다(`tools/rules_audit.py`, 테스트 `test_no_raw_spacing_values`). `space.20`은 표의 자리에서만 씁니다(테스트 `test_space_20_only_where_usage_table_allows`). 묶음 안 간격은 묶음 사이 간격보다 두 단계 이상 작게 둡니다. 위아래 여백은 같게 두고, 다르게 둘 때는 그 부품에 `note`로 이유를 적습니다.

  | 토큰 | 쓰는 곳 |
  | --- | --- |
  | `space.2` | 한 덩어리 안 두 줄 사이(표 칸 두 줄 묶음, 섹션 제목과 설명), 글자와 붙은 꺾쇠 |
  | `space.4` | 칩, 배지 안 아이콘과 글자 사이, 표 칸 안 줄 사이 |
  | `space.8` | 같은 묶음 안 요소 사이(칩 줄, 두 버튼, 제목과 본문), 이름과 값 사이, 제목 줄의 아이콘과 글자 사이 |
  | `space.12` | 섹션 제목과 내용 사이, 칩과 배지 좌우 안쪽, 목록 줄 앞 아이콘과 글자 사이, 같은 섹션 안 카드 사이 |
  | `space.16` | 카드와 목록 줄의 안쪽 |
  | `space.20` | 화면 좌우 여백, 버튼 좌우 안쪽, 큰 카드(질문 카드, 상품 카드) 안쪽 |
  | `space.24` | 시트 좌우와 아래, 확인 창 안쪽(사방), 본문과 아래 버튼 사이, 목록 묶음 카드 사이, 시트 안 구역 사이 |
  | `space.32` | 섹션 사이 |
  | `space.48` | 화면 맨 아래 스크롤 여유, 빈 화면 위아래 |
* **자세히 보기 표시(결정 V73):** 무언가를 더 보여 주는 표시는 넷뿐이고 뜻이 하나씩입니다. 용어 칩(`term-token`, `hanja-tag`) = 뜻 시트, 근거 아이콘 하나(`book-open-text`, `depth-link`) = 근거 시트, 오른쪽 꺾쇠(`caret-right`) = 화면 이동, 자물쇠 + "열기" = 잠긴 것 열기. 그 밖의 표시(밑줄 링크, ⓘ `info` 아이콘, "더 보기" 글자 버튼)는 쓰지 않습니다. 테스트 `test_detail_affordances_are_four`가 확인합니다.
* **잠김 표시(결정 V73):** 잠긴 것을 여는 입구는 어디서나 자물쇠(`lock-simple` Regular, 옆 글자 단계) + "열기" 글자이고 꺾쇠를 쓰지 않습니다(요소 `lock.veil` `open`). `sentence-block` `locked`의 열기, 근거 시트 잠금 안내, 원국 개인 해석("내 사주에서는")이 같습니다. 잠금 안내의 `pass`(광고 제거 화면으로 이동)는 화면 이동이라 꺾쇠, 광고 보고 열기는 `primary-button`입니다.
* **흰 표면 위 채움(결정 V74):** `bg.sheet` 표면(카드, 시트, 확인 창) 위의 옅은 바탕은 `fill.soft`입니다. 반투명 `chip.bg`는 흰 표면 위에서 보이지 않아 명세 어디에도 쓰지 않습니다.
* **아이콘(결정 V57):** 크기는 `size.icon.*` 네 단계이거나 옆 글자를 따르는 `adjacent-text`입니다. 규칙은 `elements.md` "아이콘"입니다.

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
| 2.1.0 | 2026-10-13 | 문장 조각(`segments`)의 용어 표시: 칩은 `term-token`이 있는 화면에서만(V28). 근거 잠금 ui 슬롯: `sentence-block` 열기, 근거 시트 구역 제목·해제 실패 toast·접근성 문구 |
| 2.2.0 | 2026-10-13 | `sentence-block` 잠김 라벨의 구역 이름 슬롯 `a11y.lockedNameSlot`(`saju-chart.yongsin.title`, #81) |
| 2.3.0 | 2026-10-15 | 구현 대응(#118·#142·#154)·IA v3(#159). 글자 링크 화살표는 아이콘 `caret-right`로 컴포넌트가 그림(V29), `depth-link` `navigate`(V32), `dialog` `notice`, `segmented` `none`, `date-picker` 윤달 대체(V31), `social-login-button` `disabled`·Apple 글자, `tab-bar` 아이콘, `app-bar` 뒤로 숨김, `input-step` 아래 버튼 생략, `lucky-card` 시간 형식, 근거 시트 빈 구역 생략, 고정 높이는 최소 높이(V30), 요소 값(`icon.set.flutter`, `mark.caution.size`, `lock.veil.lines`) |
| 2.4.0 | 2026-10-16 | app 질문(#195·#211): `city-search` `saving`(고른 줄 끝 점 숨쉬기, V34)·지역 구분자 `region.join`, `input-step` `preface` 간격, `skeleton` 글줄 `type`, 안내 글 본문 레이아웃(`frame.md`) |
| 2.5.0 | 2026-10-16 | 오늘 화면 대표 태그(#239, D76): `lucky-card` 변형 `tag`(글자 굵기 600 + 앞 아이콘 `tag` 본문색, 길흉 색 없음, V35), 칩 줄 맨 앞 순서, 칩 줄 줄 수 제한 없음 |
| 2.6.0 | 2026-10-20 | app 계획 4 확인(#218): `date-picker` `solar`, `text-field` `multiline`, `event-row` 길이 없는 일정 규칙·두 줄 배치(`twoLines`·`timeColumn.overflow`)·`add`·`failed`·'외 N개' 라벨, `day-cell` 윤달 초하루 표지(V38)·윤달 라벨·높이 규칙(V36), 그날 시트 일기 입구(V37, `depth-link` `navigate` `daySheetSlot`), `dialog` `destructive`에 일정 삭제, 근거 여럿 쌓기(`repeat`)·한자 글꼴(`explainSheet.hanja`, 원전 `fontFallback`). 추가와 문구 |
| 2.6.1 | 2026-10-20 | 규칙 정합성 점검(#284, D78): `lucky-card` 칩 최대 개수는 칩 줄 전체 6개(태그 2 + 행운 4), MD "쓰는 화면"을 IA에 맞춤. 문구만 |
| 2.7.0 | 2026-10-22 | D82·D83(#389): `social-login-button` `line`·`google` 변형과 언어별 순서(`parts.stack.order`)·`connected`(V39), `account-choice` 새 컴포넌트와 `account-merge` 배치(V40), 두 버튼 `dialog` 첫 초점 삭제(V41, #354 ②), `day-cell` 윤달 표지 슬롯(#260), `diary-row` 쓰는 화면에 today·day-sheet(D83). 추가와 값 변경 |
| 2.8.0 | 2026-10-22 | D83(#410): `diary-row` 변형 `day`(같은 날 묶음 카드)·`entries`(오늘·그날 시트)와 `entry` 줄·점선(V42), `guide-question-card` 상태 `full`과 `date-picker` `calendar` 상한 규칙(V43), 토큰 1.2.0 이상 기대(`color.timeline.entry`), writing 키 이름 채움(`loginMethodsRowConnected`·`accountChoiceProviderSeparator`, #441), 그날 시트 일기 입구를 머리(`entries.head`) + 줄로 바꾸고 `depth-link` `navigate`의 `label.daySheetSlot` 삭제(V37 개정). 추가와 값 변경 |
| 3.0.0 | 2026-10-23 | D85·D88(#480·#483·#494): `account-choice` 쓰임 바뀜(프로필 고르기, 부품 `facts`·`diaryCount`·`providers` 삭제, `other` 추가), `account-merge` 두 단계와 `login-methods` 합치기 입구(V44), `offer-card` `restore` → `history`, `purchase-row` 새 컴포넌트(V45), #475 값(카카오 배지 `#191919`, LINE 글자 198px, `entry` 꺾쇠 앞 `space.8`, 시각 24시간제 `HH:mm`, V46). 부품 삭제라 major |
| 3.1.0 | 2026-10-27 | W44·#564: `purchase-row` `meta`는 구매일 줄과 사용 기간 줄 두 줄(사이 `space.2`)이고 구분자 `join`(`purchaseMetaSeparator`)을 지움(V47). #548: `offer-card` `buy`·`period`에 IA 슬롯 `ad-free.buy.cta`·`ad-free.offer.period`. 하위 필드 삭제와 슬롯 추가(app은 #569로 이미 구분자를 지움) |
| 3.2.0 | 2026-10-28 | #353: `daeun-table` 대운 기둥 천간·지지 십성과 12운성, 세운 천간 십성 `term-token` `label`, 라벨 두 줄 줄바꿈과 높이 맞춤, `manse-table` 지장간 십성 두 줄 묶음과 12운성·신살 값 칸(V49). #354: `notice-banner` `error`(`cloud-warning`, 버튼 없음), `stateMap.error`에 `notice-banner`, `settings-row` `groupNote`(V50), toast는 아래 고정 버튼 위(V51). #587: `account-choice` 사주 줄 윤달 자리(V48). 추가와 값 변경 |
| 3.3.0 | 2026-11-03 | #546: `lucky-card` `time`은 구간마다 칩 하나(`repeat`, 최대 2), 언어별 범위 표기 `format`, `join` 삭제, 칩 줄 최대 7, 공유 이미지는 첫 구간(V52). #710: `manse-table` 행 머리 두 줄 규칙과 슬롯, `daeun-table` 꼬리표 폭과 슬롯, `tag.me` 최대 폭, `saju-pillars` 열 머리 슬롯(V53), `settings-row` 값 앞 `space.8`, 근거 시트 `personalEmpty`(V54). 하위 필드 삭제와 추가 |
| 3.4.0 | 2026-11-04 | D102 문의 화면(#758·#763): `text-field`에 칸 위 이름 `label`과 칸 오류 줄 `errorLine`(선택 부품), 메일 주소 변형 `email`, `multiline`의 `minLines`와 안내 두 줄, `contact` 화면 배치(V55). 쓰는 화면에 contact. 추가만 |
| 4.0.0 | 2026-11-05 | DS1 1단계(#801, D107): 검수 F-001~F-012를 규칙으로. **지움**: 요소 `link.inline-nowrap`, `icon.custom`·`icon.sizes`, `mark.caution` 0.707배 크기, `depth-link` 근거 변형의 글자 `label`·`chevron`(바탕 부품에서 `navigate`로), `settings-row` `destructive`의 `mark.caution`, `diary-row` `entry.divider` 키 `dash`·`gap`(→ `dashLength`·`dashGap`), `lucky-card` 칩 아래 설명 상자. **더함**: 요소 `list.divider`·`section.header`·`button.pair`·`explain.sheet`, 패턴 `page.push`, `settings-row` `leading`·`select`, `sheet` `handleArea`·`title`·`dragDismiss`, `text-field` `keyboardDismiss`, 내용 컴포넌트 17개의 `loading.skeleton`. **바뀜**: 간격 토큰만(직접 쓴 px 28곳, V56), 아이콘 크기 `size.icon.*`·`adjacent-text`(V57), 구분선 0.5px(V58), `quiet` 52(V60), `press.ink` 반지름과 범위(V61), 근거 진입점 아이콘(V63), 시트 안쪽 24(V64), 확인 창 사방 24와 같은 폭 두 버튼(V65), `navigate` 전환 `page.push`(V67). 토큰 1.3.0 이상 기대 |
| 5.0.0 | 2026-11-07 | DS1 2단계 화면 결정 시안(#801, D105, D107, D108, IA v5, 결정 V69~V95). **지움**: 요소 `section.header`, `explain.sheet`(같은 이름의 컴포넌트 `section-header`, `explain-sheet`로 옮김, V69, V71), `ohaeng.cell` 크기 `mini`(쓰는 곳 없음, V89), `lock.veil.lines.default`(구역별 줄 수로, V80, V92), `lucky-card` 변형 `tag`(대표 태그는 `hanja-tag`, V78)와 `explain.element`(→ `component: explain-sheet`), `term-token` `explainSheet.element`·`explainSheet.container`(→ `component: explain-sheet`, half는 explain-sheet가 줌), `lucky-card`·`term-token` `uses`의 `explain.sheet`, `sentence-block` `segments.term.screens`의 `day-sheet`(IA v5에서 그날 시트 이유 줄이 빠짐, #815), `sentence-block` `locked` `open.chevron`(꺾쇠 대신 자물쇠 `lock.veil` `open`, V73), `diary-row` `badge`(→ 날의 성격 `dayKind` `hanja-tag`, V81), 그 뼈 `badge`와 `day` `group.order`의 `badge`, `entries.head`의 슬롯과 글자 값(그날 시트 일기 머리는 `section-header`, V85), `event-row` `list`의 `add.when`·`empty.action`·`failed.add`(일정 추가는 섹션 머리 +, V85), `calendar-month` `legend.optional`(범례 늘 보임, V84), `manse-table` `rowHeader`·`row`·`grid`·`top`·`hiddenStems`·`twelveStages`·`shinsal`·`value`, `states.time-unknown.parts.grid`, `manse-table` `a11y.cellLabel`·`a11y.rowHeaderAnnounced`, `uses`의 `ohaeng.cell`·`term`(→ `band-table`, V89), `daeun-table` `daeun.*`·`seun.grid`·`seun.cells`·`seun.stemTenGod`·`seun.year`·`currentLabel`의 값·`states.current`·`thisYear`, `daeun-table` `a11y.cellLabel`, `uses`의 `ohaeng.cell`(→ `luck-pillar` `column`과 `scroll-hint`, V90), IA 컴포넌트 `score-scale`은 명세를 쓰지 않고 IA에 제거 요청(`IA_REMOVAL_REQUESTED`, V87). **이름 바뀜**: `lucky-card` `states.open.parts.chip`의 `innerBorder` → `border`(V75), `currentLabel`은 `luck-pillar` `currentTag` 참조로(V90). **더함**: 컴포넌트 14개(`section-header`, `explain-sheet`, `scroll-hint`, `hanja-tag`, `date-header`, `tag-sentence-list`, `fortune-verdict`, `score-row`, `date-block`, `diary-summary`, `luck-pillar`, `birth-info-row`, `band-table`, `stage-strip`), 요소 `stem.chip`(V72), `keyboard.dismiss`(text-field와 diary-editor에 겹친 값을 뺌, V68, V83), `ohaeng.cell` `small`(V77), `app-bar` `edit`·`textAction`(최대 폭 88, V82, V94), `draft-indicator` 가운데 자리, `primary-button` `leadingIcon`·`floating`, `diary-editor` 인용 질문과 바꾸기, `calendar-month` `legend`·`ruleEntry`, `day-cell` 네 단계, `diary-row` `dayKind`, `explain-sheet` `diaryLink`. **바뀜**: `manse-table` `states.loading.skeleton`은 옛 표 칸 뼈(`cells`) 대신 기준 줄 한 줄 뼈(`basis`) + `band-table` 뼈(`table`), `daeun-table` `states.loading.skeleton`의 `pillars`는 옛 기둥 칸 대신 `luck-pillar` 뼈(V66, V89, V90), `lock.veil.placeholder` 문자열 → 객체(`source: app`, `text`, `matchesRealLength: false`, `flow`, `style`. server 길이 힌트 대신 app 자리값, G1, V80), 스크린리더 구조 `manse-table` `a11y.role` `table` → `group`(기준 줄 + `band-table` 표), `daeun-table` `a11y.role` `table` → `list`(대운, 세운 가로 줄), `tag-chip` `a11y.role` `link` → `button`(뜻 시트, V73), 강조 바탕 `highlight.current`를 옅은 회색 `color.highlight.bg`로, `band-table` 일주 열과 `luck-pillar` 지금, 올해 칸이 이 바탕(V93), `lock.veil` G1 앞부분과 자리값(V80), 태그는 어디서나 뜻 시트(V73), `tag-sheet.diary.cta` 편수 없음(V79), 대표 태그가 없는 날 today 사주 기운 한 줄 `today.featured.empty`와 총운 헤드라인만(D112, V95), 초안 상태는 상단 바 가운데 정렬(V94), `sheet` `day-sheet`는 처음부터 `full`(V85), `text-field`·`diary-editor` `keyboardDismiss`는 요소 참조. 지운 부품과 요소를 쓰는 곳은 app이 고쳐야 해 주 버전(app 요청 Issue). 토큰 1.4.0 이상 기대 |

## 검사 (design)

```
python3 docs/identity/design/tools/components.py     # 저장소 루트에서
```

검사하는 것(`tools/test_components.py`가 커밋된 파일에 돌림):

* IA 컴포넌트 id가 정확히 한 번(빠짐·넘침·겹침). 지금 57개이고, IA 제거 요청 1개(`score-scale`)는 "명세가 없음" 문제에서만 빠짐. 대기 목록 `IA_PENDING_COMPONENTS`는 비어 있고 새 IA 컴포넌트가 오면 다시 씀
* 구성 요소가 가리키는 `component`(IA 컴포넌트)·`element`(요소)가 있음, 변형 id 겹침 없음, 햅틱 세기는 selection·light·medium
* 문자열 중간에 섞인 `{토큰}` 없음(값 하나에 참조 하나)
* 모든 `{토큰}` 참조가 테마 조합 4가지 모두에 있음(깊이와 관계없이)
* `uses`·`pattern`이 요소·패턴 id를 가리킴, 패턴의 시간·곡선은 토큰 참조, 모든 패턴에 동작 줄이기 대체
* `stateMap`이 IA 화면 상태 전부를 덮고 IA 컴포넌트를 가리킴
* 필드 이름이 위 표 밖이면 실패, JSON마다 같은 이름의 `.md`, 이 README가 모든 파일과 계약 버전을 적음
