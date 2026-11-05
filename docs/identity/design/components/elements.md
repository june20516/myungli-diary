# 요소 (`elements.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §4, 결정 V15·V16·V18, [근거 잠금 spec](../specs/2026-10-11-depth-lock-lengths-design.md) §3(`lock.veil`, 결정 V25), [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.13
* 여러 컴포넌트가 함께 쓰는 반복 패턴입니다. 컴포넌트는 `uses`로 가리킵니다. 요소를 고치면 그 요소를 쓰는 모든 컴포넌트가 함께 바뀝니다.

| 요소 | 정의 | 쓰는 곳 |
| --- | --- | --- |
| `seal` 낙관 도장 | 로고 낙관 경로(20 단위), -8° 기울임. 변형 `fill`·`soft`·`outline`. 안의 내용은 도장 영역 가운데 정렬 | 아래 표 |
| `ohaeng.cell` 오행 칸 | 오행 바탕 + 오행 글자, `radius.sm`. 크기 `pillar`(66px 높이), `mini`(30×30) | 원국표, 만세력 표, 대운·세운 |
| `ohaeng.swatch` 오행 견본 | 견본색 + 1px `swatch.border` | 행운 색 칩, 오행 분포 |
| `tone` 길흉 톤 | 좋음·귀인 coral, 나쁨 neutral 채움, 중립 테두리만 | 배지, tag-chip, day-cell |
| `tag.status` 상태 꼬리표 | 옅은 sage 알약 `status.*`, `type.label.md` | 일정 요약(진행 중·다음), 대운 지금·세운 올해 |
| `tag.me` '나' 꼬리표 | sage 채움 작은 알약(10px 700), 칸 오른쪽 위 모서리에 겹침 | 원국표 일간 |
| `highlight.current` 현재 강조 | 바탕 `status.bg` + 글자 `action.primary` 굵게 | 대운 지금, 세운 올해 |
| `mark.underline-grow` 펼침 밑줄 | `action.primary` 14×2px 둥근 막대, 숫자 아래 2px | 달력 선택 날짜 |
| `mark.caution` 경고 표시 | Phosphor `warning-circle` Fill, 글자색, 옆 글자 기준 아이콘 단계 | 되돌릴 수 없는 동작 |
| `surface.paper` 종이 | `bg.sheet`, `radius.lg`, 안쪽 16px, 아래 여백에 늘 도장 자리 | 일기 쓰기·보기 |
| `rail.timeline` 세로 흐름 줄 | `timeline.line` 1.5px, 날짜 열 가운데 | 일기 목록 |
| `term` 용어 표시 | `term.*`, `radius.xs`, 굵게 하지 않음 | term-token, 표 행 머리 |
| `button.pair` 두 버튼 | 세로로 쌓고 `filled`가 위, `quiet`가 아래, 사이 `space.8`, 높이 둘 다 52 | 두 동작이 나란한 화면 |
| `explain.sheet` 짧은 설명 시트 | 내용 높이 half 시트, 제목 `type.subtitle` + 본문, 배치 안에 끼우지 않음 | lucky-card, term-token 풀이 시트 |
| `list.divider` 목록 구분선 | `line` 0.5px(`border.width.hairline`), 좌우 같은 `space.16` 들임, 앞 아이콘 아래까지, 줄 사이에만 | settings-row, purchase-row, event-row list, city-search 결과 |
| `section.header` 섹션 제목 | `type.label.lg` 600 제목 + 선택 설명 `type.caption.md`(사이 `space.2`), 내용과 `space.12`, 섹션 사이 `space.32` | 2단계 IA가 화면에 둠 |
| `skeleton.bone` 자리 | `skeleton.bone` 색, 실제 요소와 같은 크기·반경 | skeleton |
| `icon` 아이콘 | Phosphor, 크기 16·20·24·28 단계, 글자 옆은 글자 굵기와 짝 | 전체 |
| `lock.veil` 잠긴 구역 | 자물쇠 + 또렷한 제목, 흐린 자리 채우기 본문(6px, 0.5) | 근거 시트 세 구역, 잠긴 용신 근거 |

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

| 톤 | 엔진 값 | 태그 칩 | 달력 칸 | 배지 |
| --- | --- | --- | --- | --- |
| good | 좋음, `YONGSIN_DAY`, `GWIIN_DAY`, `LuckLevel.GOOD` | `tag.good.*` | `calendar.good.bg` | `badge.good`·`badge.gwiin` |
| bad | 나쁨, `GISIN_DAY`, `LuckLevel.CAUTION` | `tag.bad.*` | `calendar.caution.bg` | `badge.gisin` |
| neutral | 중립, `ORDINARY_DAY`, `LuckLevel.NEUTRAL` | `tag.neutral.*` 테두리 | 채우지 않음 | `badge.ordinary` |

색만으로 전하지 않습니다. 스크린리더 라벨에 길흉 낱말("좋은 날", "조심할 날")을 넣습니다(문구는 writing).

## 시스템 글자 크기

기기의 글자 크기 설정을 따릅니다. 칸이 고정된 곳만 상한을 둡니다: `ohaeng.cell`(원국표·만세력·대운)은 1.3배, `day-cell`도 1.3배(calendar.json). 상한을 넘는 설정에서는 표 아래에 같은 내용을 목록으로 읽을 수 있게 합니다(스크린리더는 칸마다 전체 내용을 읽음).

## 경고 표시 `mark.caution`

빨간색을 쓰는 대신 Phosphor `warning-circle` Fill을 문장 앞에 둡니다. 색은 놓인 글자의 색을 따릅니다. 아이콘 세트에서 Fill을 쓰는 곳은 이것뿐입니다.

크기는 다른 글자 옆 아이콘과 같은 단계 규칙(`adjacent-text`, 아래 "아이콘")입니다. 전에는 글자 크기 × 0.707(대문자 높이)이었는데 한글보다 작아 보여 바꿨습니다(결정 V57).

## 잠긴 구역 `lock.veil`

D60으로 잠기는 근거·해석 구역 하나의 모습입니다.

* 제목: 자물쇠 `lock-simple` Regular 14 + 구역 이름(`type.label.md`, `text.secondary`). 무엇이 잠겼는지 늘 읽힙니다.
* 본문: `type.sentence.body`를 흐림 6px, 투명도 0.5로 그리고 선택·복사를 막습니다. V2 풀이 시트 잠김 변형의 값을 그대로 옮겼습니다.
* **실제 내용은 내려받지 않습니다**(server가 빼서 보냄, D60 ④). 흐린 글은 자리 채우기입니다. server가 길이 힌트를 주면 그 길이, 없으면 두 줄입니다.
* 줄 수는 매개변수 `lines`입니다. 기본은 위와 같고 `sentence-block` `locked`는 1줄입니다. app의 `LockVeil.line`은 새 변형이 아니라 `lines: 1`입니다.
* 스크린리더는 "판정 근거, 잠김"처럼 제목 + "잠김"만 읽고 흐린 글은 건너뜁니다.
* 동작 줄이기에서도 흐림은 그대로 둡니다(대상 자신의 효과, 결정 V14).

## 아이콘 `icon`

* Phosphor 2.1.2(MIT), Flutter `phosphor_glyphs` 2.1.2+1. `phosphor_flutter` 2.1.0은 Flutter 3.47에서 컴파일되지 않아 같은 세트·버전을 담은 패키지로 바꿨습니다.
* 평소·미선택 Light, 선택 Regular. Bold·Thin·Duotone은 쓰지 않고, Fill은 경고 표시만.
* 글자 옆 아이콘의 굵기는 옆 글자와 짝입니다: 400~500 글자 옆 Light, 600 이상 옆 Regular(결정 V57).
* 크기는 `size.icon.16`·`20`·`24`·`28` 네 단계뿐입니다. 부품의 `size`(또는 `iconSize`)는 이 토큰이거나 `adjacent-text`입니다.
  * `adjacent-text`: 옆 글자 크기로 고릅니다. 14px 이하 16, 15~17px 20, 20px 24, 24px 28. Phosphor 그림은 상자의 약 0.81(208/256)이고 Pretendard 한글은 글자 크기의 0.861~0.882배라, 그림이 한글 높이 이상이 되는 가장 작은 단계입니다.
  * 글자와 한 줄에 있지 않은 아이콘: 목록 줄 앞 20, 탭 바와 위 막대 24, 빈 화면과 오류 화면 28.
  * 기기 글자가 커지면 아이콘도 같은 배율로 커집니다(V30과 같은 원리).
* 직접 그린 아이콘은 쓰지 않습니다. 세트에 없는 뜻은 글자로 씁니다. 명세에 적는 이름은 `tools/phosphor_names.txt`(`phosphor_glyphs` 2.1.2+1에서 뽑은 1512개)에 있어야 하고, 테스트가 대조합니다.
* 소셜 로그인 로고는 아이콘 세트에서 가져오지 않습니다(각 사 공식 자산).

## 두 버튼 `button.pair`

두 동작을 함께 둘 때의 배치입니다(결정 V60). 세로로 쌓고 주 동작(`primary-button` `filled`)이 위, 보조 동작(`quiet`)이 아래, 사이 `space.8`입니다. 두 버튼은 높이 52, 폭 전체로 같고, 위계는 크기가 아니라 모양으로 구분합니다. 가로로 나란히 두지 않습니다. 확인 창(`dialog`)의 두 버튼만 상자 안 가로 둘입니다(V65).

## 짧은 설명 시트 `explain.sheet`

칩, 배지, 용어를 눌러 짧은 설명을 여는 곳입니다(결정 V62). 내용 높이만큼의 half 시트(`sheet` 규칙, 핸들 있음)이고, 제목은 누른 항목의 이름(`type.subtitle`, 아래 `space.8`), 본문은 `sentence-block` `body`입니다. 바깥 누르기, 끌어 내리기, 뒤로 가기로 닫힙니다.

설명은 화면 배치 안에 끼워 넣지 않습니다. 그래서 열려도 아래 내용이 밀리지 않습니다(F-008). 연 항목에는 열린 동안 표시가 남습니다(`lucky-card` 테두리, V52). 어느 화면의 어느 항목이 이 시트를 열지와 제목 문구 슬롯은 IA가 정합니다(#801).

## 목록 구분선 `list.divider`

같은 묶음 안 줄과 줄 사이에만 긋습니다(결정 V58). 굵기 0.5px(`border.width.hairline`), 색 `line`이고, 묶음 카드 좌우에서 같은 거리(`space.16`, 줄 안쪽 여백)만큼 들입니다. 앞 아이콘이 있어도 아이콘 아래까지 긋습니다. 첫 줄 위와 끝 줄 아래에는 없고, 묶음과 묶음은 선 없이 간격으로 나눕니다. 같은 날 일기 사이 점선(`diary-row` `entry.divider`, V42)과 표 격자선(`manse-table` `grid.divider`)은 이 요소가 아닙니다.

## 섹션 제목 `section.header`

내용 묶음의 이름입니다(결정 V59). 제목은 `type.label.lg` 600 본문색, 설명 줄은 선택이고 `type.caption.md` `text.secondary`, 제목 아래 `space.2`입니다. 제목과 내용 사이 `space.12`, 섹션과 섹션 사이 `space.32`입니다. 오른쪽 더 보기 자리는 두지 않습니다. 스크린리더는 머리글로 읽습니다.

묶음의 기본은 간격(가까운 것끼리 묶여 보임)이고, 목록 줄이 이어지는 묶음은 카드(`bg.sheet`, `radius.lg`)로 묶을 수 있습니다. 어느 화면에 섹션 제목을 두고 어떤 문구 슬롯을 쓸지는 2단계 IA가 정합니다(#801).
