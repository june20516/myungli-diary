# 슬롯별 글자 수 상한

writing 슬롯 명세의 `max_length`에 넣을 값입니다(Issue #54). 굵은 세 열이 확정값입니다.

* 근거: [근거 잠금·글자 수 spec](specs/2026-10-11-depth-lock-lengths-design.md) §5, 결정 V27
* 만드는 도구: `tools/lengths.py`. 이 표는 도구 출력을 그대로 붙인 것이고, 테스트가 둘이 같은지 확인합니다(글꼴이 있을 때).
* 글자 수는 호칭과 매개변수 값이 들어간 **최종 문장 기준**, 띄어쓰기와 문장부호를 포함합니다.

## 상한

| 슬롯 | 놓이는 칸 | 칸 폭 | 줄 | ko 초안 | ko 계산 | **ko** | **ja** | **en** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `daily.fortune.head`<br>`daily.fortune.tag` | today sentence-block card (상자 없이 본문 폭, 시안 design-v2-today) | 320px | 2 | 32 | 42 | **32** | **32** | **57** |
| `daily.guide` | guide-question-card question (안쪽 space.20) | 280px | 2 | 40 | 36 | **36** | **30** | **70** |
| `daily.color`<br>`daily.direction`<br>`daily.number`<br>`daily.focus_time` | lucky-card explain (안쪽 space.12) | 296px | 2 | 36 | 58 | **36** | **36** | **64** |
| `daily.focus_reason` | lucky-card explain 안 한 줄 | 296px | 1 | 10 | 26 | **10** | **10** | **18** |
| `daily.tag_label` | tag-chip ('#' 뒤, 좌우 10px) | 293px | 1 | 10 | 28 | **10** | **10** | **18** |
| `calendar.day_level` | day-character badge (좌우 10px) | 300px | 1 | 10 | 27 | **10** | **10** | **18** |
| `calendar.score_item` | term-token label (좌우 4px) | 312px | 1 | 10 | 30 | **10** | **10** | **18** |
| `calendar.solar_term` | day-cell lunar 줄 (칸 폭 44px, 굵게) | 44px | 1 | 10 | 4 | **4** | **3** | **6** |
| `glossary.value_name` | lucky-card chip 값 (칩이 한 줄에 혼자일 때, 좌우 12px, 아이콘 16 + 간격 6) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |
| `ui.depth.surface`<br>`ui.depth.explain`<br>`ui.depth.evidence` | segmented 세 칸 중 한 칸 | 104px | 1 | 10 | 8 | **8** | **6** | **13** |
| `ui.depth.default_label` | settings-row value 이름 (좌우 16px, 화살표 16, 오른쪽 값 = 단계 이름) | 177.4px | 1 | 10 | 15 | **10** | **10** | **18** |
| `chart.yongsin_method` | saju-chart 본문 sentence-block body | 본문 | 제한 없음 | 60 | - | **60** | **60** | **108** |
| `settings.calculation_basis` | calc-basis 본문 sentence-block body | 본문 | 제한 없음 | 120 | - | **120** | **120** | **216** |

* **ko 계산**: 레이아웃에 들어가는 글자 수입니다. 확정값은 writing 초안과 이 값 중 작은 값입니다(ja 초안 = ko, en 초안 = ko × 1.8).
* 초안보다 줄어든 곳: `daily.guide`(질문 카드 안쪽 여백), `calendar.solar_term`(날짜 칸 44px), `ui.depth.surface`·`explain`·`evidence`(segmented 한 칸).
* `calendar.solar_term` en 6자: 영어 절기 이름("Start of Spring")은 날짜 칸에 들어가지 않습니다. writing이 6자 이하 줄임 표기를 정합니다.

## 값의 성격

* **이름 자리(1줄: 칩·배지·segmented·날짜 칸·설정 이름)**: 띄어쓰기 없는 한글로 칸을 채운 가장 넓은 경우입니다. 상한 안이면 늘 한 줄에 들어갑니다.
* **문장 자리(2줄: 총운·가이드 질문·행운 설명)**: 실제 원고로 잰 **경험값**입니다. 어절 단위 줄바꿈은 문장마다 줄 끝 빈 자리가 달라서, 어절이 길게 몰린 문장은 상한 안이어도 한 줄을 더 쓸 수 있습니다. 문장 칸은 글을 자르지 않고 줄이 늘어나므로 깨지지는 않습니다. 줄 수를 꼭 지켜야 하는 문장은 화면에서 확인합니다.
* **en**: 평균 글자 폭과 평균 단어 길이로 잰 추정값입니다. 영어 원고가 생기면 ko처럼 원고로 다시 잽니다.
* 공유 이미지(`share-image`, 1080px 캔버스)는 명세에 안쪽 여백이 없어 계산하지 않았습니다. `feed`는 문장 2줄이므로, 캔버스가 화면 비율대로 커진다면 총운 32자가 그대로 들어갑니다.

## 계산 방법

* 기준 화면 폭 360px − 화면 좌우 여백 `space.20` × 2 = 본문 폭 320px. 칸 폭은 컴포넌트 명세의 안쪽 여백을 뺀 값입니다. 오늘 화면 문장은 상자 없이 본문 폭에 놓입니다(채택 시안 `design-v2-today`).
* 줄 수: 큰 문장(card) 2줄, 행운 설명 상자 2줄, 이름·칩·배지·segmented·날짜 칸 1줄, 스크롤 본문은 제한 없음(spec §5.2).
* ko 문장 자리: writing 라운드 R1~R7 원고 문장(중복을 뺀 46개)을 어절 단위(keep-all)로 칸에 채우고, 꽉 찬 줄 글자 수의 하위 10%를 한 줄로 봅니다. 표본이 작아 원고가 바뀌면 한두 글자 움직일 수 있습니다.
* ko 이름 자리: 띄어쓰기 없는 한글로 한 줄을 채운 글자 수입니다. 앞에 붙는 글자(태그 칩 `#`)는 실제 폭을 빼고, 같은 줄의 값 자리(설정 줄 오른쪽 단계 이름)는 그 슬롯의 확정 글자 수만큼 뺍니다.
* ja: 글자 단위 줄바꿈 + 금칙 처리, 줄마다 한 글자 여유, 자간 0. 문장 글꼴은 Zen Maru Gothic 폭, UI 글꼴은 전각 1em(실제 Pretendard 가나보다 넓게 잡은 보수값)입니다.
* en: 라틴 소문자 폭의 영어 글자 빈도 가중 평균, 줄마다 평균 단어(4.7자 + 띄어쓰기)의 절반을 줄바꿈 손실로 뺍니다.

## 용어 토큰 칩

토큰 하나에 좌우 3px씩 6px가 늘어납니다. writing 규칙상 토큰은 한 화면 2개까지(`limit.L6`), 한 문장에 모으므로(`limit.L7`) 한 문장에서 최대 12px입니다. card 글자 한 자(15.5px)보다 작지만, 줄 끝이 빠듯한 문장에서는 마지막 어절 하나를 다음 줄로 밀 수 있습니다. 그 영향은 위 "문장 자리는 경험값"이 이미 안고 있는 줄 끝 변동과 같은 크기라서 **토큰이 든 문장의 상한을 따로 두지 않습니다.** 토큰이 든 문장이 줄 수를 자주 넘기면 그때 토큰 문장 상한을 한 글자 낮춥니다.

## 다시 계산하기

측정 글꼴은 저장소에 넣지 않습니다. `.suberpowers/fonts/`에 아래 파일을 두고 저장소 루트에서 실행합니다. 글꼴이 없으면 표 비교 테스트는 skip되고, 계산 로직은 가짜 글꼴 단위 테스트로만 확인됩니다.

| 파일 | 받는 곳 |
| --- | --- |
| `GowunDodum-Regular.ttf` | `https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf` |
| `ZenMaruGothic-Regular.ttf` | `https://github.com/google/fonts/raw/main/ofl/zenmarugothic/ZenMaruGothic-Regular.ttf` |
| `Pretendard-{Regular,Medium,SemiBold,Bold}.otf` | `https://cdn.jsdelivr.net/npm/pretendard@1.3.9/dist/public/static/` |

```
uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts
```
