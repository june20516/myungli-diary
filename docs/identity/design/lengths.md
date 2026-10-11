# 슬롯별 글자 수 상한

writing 슬롯 명세의 `max_length`에 넣을 값입니다(Issue #54). 굵은 세 열이 확정값입니다.

* 근거: [근거 잠금·글자 수 spec](specs/2026-10-11-depth-lock-lengths-design.md) §5, 결정 V27
* 만드는 도구: `tools/lengths.py`. 이 표는 도구 출력을 그대로 붙인 것이고, 테스트가 둘이 같은지 확인합니다(글꼴이 있을 때).
* 글자 수는 호칭과 매개변수 값이 들어간 **최종 문장 기준**, 띄어쓰기와 문장부호를 포함합니다.

## 상한

| 슬롯 | 놓이는 칸 | 칸 폭 | 줄 | ko 초안 | ko 계산 | **ko** | **ja** | **en** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `daily.fortune.head`<br>`daily.fortune.tag` | today sentence-block card | 320px | 2 | 32 | 42 | **32** | **32** | **57** |
| `daily.guide` | guide-question-card question (안쪽 space.20) | 280px | 2 | 40 | 36 | **36** | **30** | **70** |
| `daily.color`<br>`daily.direction`<br>`daily.number`<br>`daily.focus_time` | lucky-card explain (안쪽 space.12) | 296px | 2 | 36 | 58 | **36** | **36** | **64** |
| `daily.focus_reason` | lucky-card explain 안 한 줄 | 296px | 1 | 10 | 26 | **10** | **10** | **18** |
| `daily.tag_label` | tag-chip (# 포함, 좌우 10px) | 292px | 1 | 10 | 28 | **10** | **10** | **18** |
| `calendar.day_level` | day-character badge (좌우 10px) | 300px | 1 | 10 | 27 | **10** | **10** | **18** |
| `calendar.score_item` | term-token label (좌우 4px) | 312px | 1 | 10 | 30 | **10** | **10** | **18** |
| `calendar.solar_term` | day-cell lunar 줄 (칸 폭 44px, 굵게) | 44px | 1 | 10 | 4 | **4** | **3** | **6** |
| `glossary.value_name` | lucky-card chip 값 (좌우 12px, 아이콘 16 + 간격 6) | 274px | 1 | 10 | 24 | **10** | **10** | **18** |
| `ui.depth.surface`<br>`ui.depth.explain`<br>`ui.depth.evidence` | segmented 세 칸 중 한 칸 | 104px | 1 | 10 | 8 | **8** | **6** | **13** |
| `ui.depth.default_label` | settings-row value 이름 (좌우 16px, 화살표 16, 오른쪽 값 = 단계 이름 8자) | 177.4px | 1 | 10 | 15 | **10** | **10** | **18** |
| `chart.yongsin_method` | saju-chart 본문 sentence-block body | 본문 | 제한 없음 | 60 | - | **60** | **60** | **108** |
| `settings.calculation_basis` | calc-basis 본문 sentence-block body | 본문 | 제한 없음 | 120 | - | **120** | **120** | **216** |

* **ko 계산**: 레이아웃에 들어가는 글자 수입니다. 확정값은 writing 초안과 이 값 중 작은 값입니다(ja 초안 = ko, en 초안 = ko × 1.8).
* 초안보다 줄어든 곳: `daily.guide`(질문 카드 안쪽 여백), `calendar.solar_term`(날짜 칸 44px), `ui.depth.surface`·`explain`·`evidence`(segmented 한 칸).
* `calendar.solar_term` en 6자: 영어 절기 이름("Start of Spring")은 날짜 칸에 들어가지 않습니다. writing이 6자 이하 줄임 표기를 정합니다.

## 계산 방법

* 기준 화면 폭 360px − 화면 좌우 여백 `space.20` × 2 = 본문 폭 320px. 칸 폭은 컴포넌트 명세의 안쪽 여백을 뺀 값입니다.
* 줄 수: 큰 문장(card) 2줄, 행운 설명 상자 2줄, 이름·칩·배지·segmented·날짜 칸 1줄, 스크롤 본문은 제한 없음(spec §5.2).
* ko 문장 자리: writing 라운드 R1~R7 원고 문장을 어절 단위(keep-all)로 칸에 채우고, 꽉 찬 줄 글자 수의 하위 10%를 한 줄로 봅니다.
* ko 이름 자리: 띄어쓰기 없는 한글로 한 줄을 채운 글자 수입니다.
* ja: 글자 단위 줄바꿈 + 금칙 처리, 줄마다 한 글자 여유. 문장 글꼴 Zen Maru Gothic 폭, UI 글꼴은 전각 1em.
* en: 라틴 소문자 폭의 영어 글자 빈도 가중 평균, 줄마다 평균 단어(4.7자 + 띄어쓰기)의 절반을 줄바꿈 손실로 뺍니다.

## 용어 토큰 칩

토큰 하나에 좌우 3px씩 6px가 늘고, 토큰은 한 화면 2개까지(writing `limit.L6`)·한 문장에 모으므로(`limit.L7`) 한 문장에서 최대 12px입니다. card 글자 한 자(15.5px)보다 작고 계산이 꽉 찬 줄의 하위 10%를 쓰므로 그 여유 안에 들어갑니다. **토큰이 든 문장의 상한은 따로 두지 않습니다.**

## 다시 계산하기

측정 글꼴은 저장소에 넣지 않습니다. `.suberpowers/fonts/`에 아래 파일을 두고 저장소 루트에서 실행합니다. 글꼴이 없으면 표 비교 테스트는 skip됩니다.

| 파일 | 받는 곳 |
| --- | --- |
| `GowunDodum-Regular.ttf` | `https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf` |
| `ZenMaruGothic-Regular.ttf` | `https://github.com/google/fonts/raw/main/ofl/zenmarugothic/ZenMaruGothic-Regular.ttf` |
| `Pretendard-{Regular,Medium,SemiBold,Bold}.otf` | `https://cdn.jsdelivr.net/npm/pretendard@1.3.9/dist/public/static/` |

```
uv run --with fonttools==4.54.1 python docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts
```
