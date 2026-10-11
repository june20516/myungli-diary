# 요소 (`elements.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §4, 결정 V15·V16·V18
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
| `mark.caution` 경고 표시 | Phosphor `warning-circle` Fill, 글자색, 글자 높이 | 되돌릴 수 없는 동작 |
| `link.inline-nowrap` 끊기지 않는 링크 | 문장 끝 링크 전체를 한 덩어리로 | 근거 보기 |
| `surface.paper` 종이 | `bg.sheet`, `radius.lg`, 안쪽 16px, 아래 여백에 늘 도장 자리 | 일기 쓰기·보기 |
| `rail.timeline` 세로 흐름 줄 | `timeline.line` 1.5px, 날짜 열 가운데 | 일기 목록 |
| `term` 용어 표시 | `term.*`, `radius.xs`, 굵게 하지 않음 | term-token, 표 행 머리 |
| `skeleton.bone` 자리 | `skeleton.bone` 색, 실제 요소와 같은 크기·반경 | skeleton |
| `icon` 아이콘 | Phosphor, 평소 Light · 선택 Regular | 전체 |

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
| 질문 카드 "쓴 일기 보기" 버튼 뒤 | soft | 52 | 없음(버튼 글자가 위 층) |

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

빨간색을 쓰는 대신, 글자 높이에 맞춘 Phosphor `warning-circle` Fill을 문장 앞에 둡니다. 색은 놓인 글자의 색을 따릅니다. 아이콘 세트에서 Fill을 쓰는 곳은 이것뿐입니다.

## 끊기지 않는 링크 `link.inline-nowrap`

이유 문장 끝에 붙는 "근거 보기 ›"가 줄 끝에서 둘로 갈라지지 않게 합니다. 링크 낱말 사이에 U+00A0(줄바꿈 없는 공백), 글자 사이에 U+2060(단어 결합자)을 넣어 한 덩어리로 만들고, 줄 끝에 안 들어가면 통째로 다음 줄로 넘깁니다. Flutter는 `TextSpan` + `TapGestureRecognizer`, 스크린리더 초점은 링크에 따로 줍니다.

## 아이콘 `icon`

* Phosphor 2.1.2(MIT), Flutter `phosphor_flutter`.
* 평소·미선택 Light, 선택 Regular. Bold·Thin·Duotone은 쓰지 않고, Fill은 경고 표시만.
* 세트에 없는 것(오행, 절기, 시간 모름 등)은 Phosphor 24 격자와 획 규칙으로 직접 그립니다.
* 소셜 로그인 로고는 아이콘 세트에서 가져오지 않습니다(각 사 공식 자산).
