# 요소 (`elements.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §4, 결정 V15·V16·V18, [근거 잠금 spec](../specs/2026-10-11-depth-lock-lengths-design.md) §3(`lock.veil`, 결정 V25), [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.13
* 여러 컴포넌트가 함께 쓰는 반복 패턴입니다. 컴포넌트는 `uses`로 가리킵니다. 요소를 고치면 그 요소를 쓰는 모든 컴포넌트가 함께 바뀝니다.

| 요소 | 정의 | 쓰는 곳 |
| --- | --- | --- |
| `seal` 낙관 도장 | 로고 낙관 경로(20 단위), -8° 기울임. 변형 `fill`·`soft`·`outline`. 안의 내용은 도장 영역 가운데 정렬 | 아래 표 |
| `ohaeng.cell` 오행 칸 | 오행 바탕 + 오행 글자, `radius.sm`. 금과 수는 1px 안쪽 테두리 `ohaeng.metal.border`·`water.border`(V98). 안쪽에 그려 칸과 글자 크기는 그대로. 크기 `pillar`(66px 높이), `small`(40×40, 한자 18 700, `luck-pillar`) | 원국표, 대운, 세운 칸(만세력 띠 표 지장간은 `stem.chip`) |
| `ohaeng.swatch` 오행 견본 | 견본색 + 1px `swatch.border` | 행운 색 칩, 오행 분포 |
| `tone` 길흉 톤 | 좋음·귀인 coral, 나쁨 neutral 채움, 중립 테두리만 | 배지, hanja-tag 날의 성격, day-cell |
| `tag.status` 상태 꼬리표 | 옅은 sage 알약 `status.*`, `type.label.md` | 일정 요약(진행 중·다음), 대운 지금·세운 올해 |
| `tag.me` '나' 꼬리표 | sage 채움 작은 알약(10px 700), 칸 오른쪽 위 모서리에 겹침 | 원국표 일간 |
| `highlight.current` 현재 강조 | 바탕 `highlight.bg`(옅은 회색, 카드 `bg.sheet` 위에서만) + 글자 `action.primary` 굵게 (V93) | 대운 지금, 세운 올해, 띠 표 일주 열 |
| `mark.underline-grow` 펼침 밑줄 | `action.primary` 14×2px 둥근 막대, 숫자 아래 2px | 달력 선택 날짜 |
| `mark.caution` 경고 표시 | Phosphor `warning-circle` Fill, 글자색, 옆 글자 기준 아이콘 단계 | 되돌릴 수 없는 동작 |
| `surface.paper` 종이 | `bg.sheet`, `radius.lg`, 안쪽 16px, 아래 여백에 늘 도장 자리 | 일기 쓰기·보기 |
| `rail.timeline` 세로 흐름 줄 | `timeline.line` 1.5px, 날짜 열 가운데 | 일기 목록 |
| `term` 용어 표시 | `term.*`, `radius.xs`, 굵게 하지 않음 | term-token, 표 십성 칩과 띠 머리 칩 |
| `keyboard.dismiss` 키보드 내리기 | 키보드 inset 위 `space.12` 오른쪽 44 원형 버튼(`bg.sheet`, `shadow.raised`, `caret-down` Regular 20) | `text-field`, `diary-editor` 초점 상태 |
| `button.pair` 두 버튼 | 세로로 쌓고 `filled`가 위, `quiet`가 아래, 사이 `space.8`, 높이 둘 다 52 | 두 동작이 나란한 화면 |
| `list.divider` 목록 구분선 | `line` 0.5px(`border.width.hairline`), 좌우 같은 `space.16` 들임, 앞 아이콘 아래까지, 줄 사이에만 | settings-row, purchase-row, event-row list, city-search 결과 |
| `stem.chip` 간지 칩 | 한자 칸 22, `ohaeng.cell` 바탕색과 글자색(금, 수는 테두리까지), 한자 `font.family.hanja` 13 700 | band-table 지장간 칸 |
| `skeleton.bone` 자리 | `skeleton.bone` 색, 실제 요소와 같은 크기·반경 | skeleton |
| `icon` 아이콘 | Phosphor, 크기 16·20·24·28 단계, 글자 옆은 글자 굵기와 짝 | 전체 |
| `lock.veil` 잠긴 구역 | 자물쇠 + 또렷한 제목, 또렷한 앞 2~3 단어 + 흐린 자리값 본문(6px, 0.5, G1), 여는 입구 `open`(자물쇠 + 열기) | 근거 시트 세 구역, 잠긴 용신 근거 |
| `open.ring` 시트를 연 칩 표시 | 누른 칩이나 용어 안쪽 둘레 1.5px `action.primary`(크기 그대로), 그 시트가 열린 동안(위에 시트가 쌓여도), 문장 안 용어는 줄 조각마다 닫힌 테두리 | `hanja-tag` 전부, `term-token` `inline`·`label`, `lucky-card` 칩, 달력 규칙 입구 칩 (V129) |
| `unlock.mark` 열린 구역 표시 | 동작 줄이기에서 `unlock.glint` 대신: 구역 제목 글자를 `gradient.unlocked`로, 구역 왼쪽 밖 12에 2px 세로선(제목 첫 줄 위 ~ 본문 끝) | 근거 시트 열린 세 구역, 열린 용신 근거(선만) |

## 낙관 도장 `seal`

로고의 낙관(붉은 인장 자리)을 브랜드 요소로 떼어 씁니다. 도장이 찍히는 순간은 "내가 했다"는 기록의 순간에만 씁니다.

| 쓰는 곳 | 변형 | 크기 | 안의 내용 |
| --- | --- | --- | --- |
| 선택된 탭 | fill | 34 | 아이콘 Regular, `action.on-primary` |
| 반응 하트 | fill | 34 | 하트 Regular, `action.on-primary` |
| 일기 종이 오른쪽 아래 | fill | 64 | 그날 날짜를 `seal.knock`으로 가늘게 새김 |
| 달력 일기 쓴 날 | soft | 26 | 날짜 숫자(본문색) |
| 달력 오늘 | outline 1.6px | 26 | 날짜 숫자 |
| 일기 목록 날짜 | soft | 34 | 날짜 숫자 |
| 질문 카드 오늘 쓴 뒤 버튼(`todayGuideCtaWritten`) 뒤 | soft | 52 | 없음(버튼 글자가 위 층) |

* 위치 규칙: 날짜 숫자에 찍는 곳(달력·일기 목록)은 숫자 뒤, 일기 종이는 오른쪽 아래, 질문 카드는 버튼 글자 뒤.
* 안의 숫자·아이콘은 도장 영역의 가운데에 둡니다. 기울임은 도장 모양에만 걸고 안의 내용은 바로 세웁니다.
* 반투명 도장이 길흉 바탕(coral·neutral) 위에 겹쳐 탁해지는 것은 의도입니다. 겹침으로 읽힙니다. 숫자 대비는 겹친 색으로 검사합니다(`palette.py --check`의 `seal.soft over` 조합).
* 옅은 도장 위에 sage 글자를 올릴 때(선택된 날 숫자, 질문 카드 버튼 글자)는 `action.primary` 대신 한 단계 진한 `seal.on-soft`를 씁니다(결정 V24).
* 움직임: 찍힘 `seal.stamp`, 지워짐 `seal.erase`.

## 길흉 톤 `tone`

| 톤 | 엔진 값 | 태그(`hanja-tag` 날의 성격) | 달력 칸 | 배지 |
| --- | --- | --- | --- | --- |
| good | 좋음, `YONGSIN_DAY`, `GWIIN_DAY`, 잘 풀리는 날, 아주 잘 풀리는 날 | `tag.good.*` | `calendar.level.good`, 아주 잘 풀리는 날 `calendar.level.great`(V84) | `badge.good`·`badge.gwiin` |
| bad | 나쁨, `GISIN_DAY`, 조심할 날 | `tag.bad.*` | `calendar.level.caution` | `badge.gisin` |
| neutral | 중립, `ORDINARY_DAY`, 무난한 날 | `tag.neutral.*` 테두리 | 채우지 않음 | `badge.ordinary` |

색만으로 전하지 않습니다. 스크린리더 라벨에 길흉 낱말(달력은 네 단계 이름 "아주 잘 풀리는 날", "잘 풀리는 날", "무난한 날", "조심할 날")을 넣습니다(문구는 writing, V84).

## 시스템 글자 크기

기기의 글자 크기 설정을 따릅니다. 칸이 고정된 곳만 상한을 둡니다: `ohaeng.cell`(원국표·만세력·대운)은 1.3배, `day-cell`도 1.3배(calendar.json). 상한을 넘는 설정에서는 표 아래에 같은 내용을 목록으로 읽을 수 있게 합니다(스크린리더는 칸마다 전체 내용을 읽음).

## 경고 표시 `mark.caution`

빨간색을 쓰는 대신 Phosphor `warning-circle` Fill을 문장 앞에 둡니다. 색은 놓인 글자의 색을 따릅니다. 아이콘 세트에서 Fill을 쓰는 곳은 이것뿐입니다.

크기는 다른 글자 옆 아이콘과 같은 단계 규칙(`adjacent-text`, 아래 "아이콘")입니다. 전에는 글자 크기 × 0.707(대문자 높이)이었는데 한글보다 작아 보여 바꿨습니다(결정 V57).

## 잠긴 구역 `lock.veil`

D60으로 잠기는 근거·해석 구역 하나의 모습입니다.

* 제목: 자물쇠 `lock-simple` Regular 14 + 구역 이름(`type.label.md`, `text.secondary`). 무엇이 잠겼는지 늘 읽힙니다.
* **G1(D106, 결정 V80):** 본문 맨 앞에 server가 준 문장 앞부분(2~3 단어, #797)을 또렷하게(`lead`, `type.sentence.body` 본문색) 두고, 바로 뒤 같은 줄부터 app이 준비한 자리값 글자를 흐리게 이어 채웁니다. 앞부분이 오지 않으면 자리값만입니다.
* 흐린 자리값: `type.sentence.body`를 흐림 6px, 투명도 0.5로 그리고 선택·복사를 막습니다. V2 풀이 시트 잠김 변형의 값을 그대로 옮겼습니다.
* **실제 내용은 내려받지 않습니다**(server가 빼서 보냄, D60 ④). 자리값 글자는 app이 언어별로 하나 준비하고, 실제 문장 길이와 맞추지 않습니다.
* 줄 수(`lines`, 앞부분 포함)는 구역마다 고정입니다: 판정 근거 3, 원전 2, 내 사주에서는 3, `sentence-block` `locked`(사주 표 용신 판정 근거) 2(2026-11-07 V92, origin. 그 전 1). app의 `LockVeil.line`(지금 한 줄)은 새 변형이 아니라 이 자리의 `lines` 값(2)으로 그립니다. server 길이 힌트는 쓰지 않습니다.
* 스크린리더는 "판정 근거, 오늘은 용신의, 잠김"처럼 제목 + 앞부분 + "잠김"을 읽고 흐린 자리값은 건너뜁니다.
* 동작 줄이기에서도 흐림은 그대로 둡니다(대상 자신의 효과, 결정 V14).
* **여는 입구(`open`, 결정 V73):** 잠긴 것을 여는 입구는 어디서나 자물쇠 `lock-simple` Regular(옆 글자 단계, 링크 색, 글자 앞 `space.4`) + "열기" 글자입니다. 꺾쇠를 쓰지 않습니다. `sentence-block` `locked`의 열기가 이 모양이고, 근거 시트 잠금 안내 머리도 자물쇠로 시작합니다. 잠금 안내의 `pass`(광고 제거 화면으로 이동)는 화면 이동이라 꺾쇠, 광고 보고 열기는 `primary-button`입니다.

## 아이콘 `icon`

* Phosphor 2.1.2(MIT), Flutter `phosphor_glyphs` 2.1.2+1. `phosphor_flutter` 2.1.0은 Flutter 3.47에서 컴파일되지 않아 같은 세트·버전을 담은 패키지로 바꿨습니다.
* 평소·미선택 Light, 선택 Regular. Bold·Thin·Duotone은 쓰지 않고, Fill은 경고 표시와 집중 시간 칩의 해, 달(`timeOfDay`, 색 `color.time.day`·`night`, 결정 V115)만.
* 글자 옆 아이콘의 굵기는 옆 글자와 짝입니다: 400~500 글자 옆 Light, 600 이상 옆 Regular(결정 V57).
* 크기는 `size.icon.16`·`20`·`24`·`28` 네 단계뿐입니다. 부품의 `size`(또는 `iconSize`)는 이 토큰이거나 `adjacent-text`입니다.
  * `adjacent-text`: 옆 글자 크기로 고릅니다. 14px 이하 16, 15~18px 20, 19~22px 24, 23px 이상 28(경계는 단계 × 0.81 ÷ 0.882). Phosphor 그림은 상자의 약 0.81(208/256)이고 Pretendard 한글은 글자 크기의 0.861~0.882배라, 그림이 한글 높이 이상이 되는 가장 작은 단계입니다.
  * 글자와 한 줄에 있지 않은 아이콘: 목록 줄 앞 20, 탭 바와 위 막대 24, 빈 화면과 오류 화면 28.
  * 기기 글자가 커지면: 글자 옆 아이콘(`adjacent-text`)은 기본 글자 크기로 단계를 고르고 그리는 크기에 기기 배율을 곱합니다(그 칸의 `textScaleMax`까지, V30과 같은 원리). 탭 바, 위 막대, 목록 줄 앞, 빈 화면, 키보드 내리기처럼 글자와 한 줄에 있지 않은 아이콘은 배율을 따르지 않습니다.
* 직접 그린 아이콘은 쓰지 않습니다. 세트에 없는 뜻은 글자로 씁니다. 명세에 적는 이름은 `tools/phosphor_names.txt`(`phosphor_glyphs` 2.1.2+1에서 뽑은 1512개)에 있어야 하고, 테스트가 대조합니다.
* 소셜 로그인 로고는 아이콘 세트에서 가져오지 않습니다(각 사 공식 자산).

## 키보드 내리기 `keyboard.dismiss`

입력칸에 초점이 있는 동안 키보드 바로 위 오른쪽에 띄우는 44 원형 버튼입니다(결정 V68, V83). 기준은 플랫폼 키보드 inset(OS 자동완성과 추천 줄 포함)이고 그 위 `space.12`입니다. 누르면 키보드가 내려가고 초점이 풀립니다. 스크린리더 이름은 `ui.keyboard.dismiss`, 동작 구현은 app #796입니다. `text-field`와 `diary-editor`는 `focused` 상태에서 이 요소를 가리키기만 합니다. 4.0.0까지 두 컴포넌트에 같은 값이 겹쳐 있던 것을 5.0.0에서 요소로 뺐습니다.

## 두 버튼 `button.pair`

두 동작을 함께 둘 때의 배치입니다(결정 V60). 세로로 쌓고 주 동작(`primary-button` `filled`)이 위, 보조 동작(`quiet`)이 아래, 사이 `space.8`입니다. 두 버튼은 높이 52, 폭 전체로 같고, 위계는 크기가 아니라 모양으로 구분합니다. 가로로 나란히 두지 않습니다. 확인 창(`dialog`)의 두 버튼만 상자 안 가로 둘입니다(V65).

## 목록 구분선 `list.divider`

같은 묶음 안 줄과 줄 사이에만 긋습니다(결정 V58). 굵기 0.5px(`border.width.hairline`), 색 `line`이고, 묶음 카드 좌우에서 같은 거리(`space.16`, 줄 안쪽 여백)만큼 들입니다. 앞 아이콘이 있어도 아이콘 아래까지 긋습니다. 묶음 카드 없이 시트 본문에 바로 놓인 목록과 구역(행운 색 둘 시트의 두 색 사이, 사주 기운 시트 문장 목록)은 줄 안쪽 여백이 없으므로 들임 0이고 선은 시트 본문 폭(시트 안쪽 24 안) 그대로입니다(`inSheet`, 결정 V124). 첫 줄 위와 끝 줄 아래에는 없고, 묶음과 묶음은 선 없이 간격으로 나눕니다. 같은 날 일기 사이 점선(`diary-row` `entry.divider`, V42)과 표와 줄의 세로선(`band-table` 열 구분선 `columns.divider`, `birth-info-row` 칸 사이 `divider`)은 이 요소가 아닙니다.

## 간지 칩 `stem.chip`

`band-table` 지장간 칸의 천간 한 글자를 오행 색으로 보이는 정사각 칸입니다(DS1 2단계, 결정 V72). 크기 22, 반경 `radius.sm`, 바탕색과 글자색은 `ohaeng.cell`의 그 오행 값(금과 수는 테두리까지, V98), 한자는 `font.family.hanja` 13 700입니다. 지장간 칸 전용입니다. 원국 칸(`saju-pillars`)과 대운, 세운 칸(`luck-pillar`)은 `ohaeng.cell` 자체라 같은 색 규칙을 이미 쓰고 독음과 큰 한자를 담아 이 칩을 쓰지 않습니다(`notFor`, 결정 V89. spec §1의 "원국 칸도 씀"을 정정). `hanja-tag` `ganji`는 이 칩을 쓰지 않고 알약 전체를 오행 색으로 칠합니다(`sentence.md`). 칸이 고정이라 글자 배율 상한은 1.3배입니다(`ohaeng.cell`과 같음).

1단계 요소 `section.header`와 `explain.sheet`는 IA v5의 컴포넌트 `section-header`, `explain-sheet`로 옮겼습니다(`frame.md`, 결정 V69, V71).
