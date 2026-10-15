# saju: 사주 표 (`saju.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.9, 결정 V21·V25
* 시안: `design-v2-saju-pillars`(오행 바탕 A), `design-v2-saju-manse`(격자 A), `design-v2-saju-flow`(대운·세운)

## 원칙: 표준 배치, 차별은 깊이·풀이·시각 언어

사주 표는 정보가 빽빽해 다른 만세력과 모양으로 차별하기 어렵고, 사용자는 다른 앱과 대조해 보며 신뢰를 얻습니다. 그래서 **열 순서·배치·용어는 다른 만세력과 같게** 둡니다. 차별은 세 가지로 냅니다.

1. 깊이 구조: 나 탭 문장 → 근거 보기 → 표. 표는 근거로 내려와서 봅니다.
2. 모든 용어 풀이: 행 머리·십성 하나하나가 term-token이고, 풀이 시트(일반 뜻, 무료) → 근거 시트에서 원국 개인 해석 "내 사주에서는"(D60으로 잠긴 기능, sentence.md).
3. 같은 시각 언어: 오행 칸, 상태 꼬리표, 현재 강조, 스밈이 앱 전체와 같습니다.

오늘 일진을 원국표에 겹쳐 보는 화면은 만들지 않습니다(사용자 결정). saju-chart는 segmented 두 탭(원국·오행 / 만세력·대운)입니다.

## saju-pillars

* 쓰는 화면: evidence-sheet, saju-chart
* 왼쪽부터 시·일·월·연. 칸은 `ohaeng.cell` `pillar`(66px 높이, 한자 `type.hanja.pillar` + 한글 독음 `type.caption.sm`).
* 위 천간 십성, 아래 지지 십성(정기). 모두 term-token `label`.
* **일간(나):** 칸 안쪽 2px `action.primary` 테두리 + 오른쪽 위 모서리에 `tag.me` "나" 꼬리표(칸이 자르지 않게 칸 밖 층). 십성 줄의 "일간"도 term-token.
* 시간 모름이면 시주 칸은 점선 테두리 빈 칸이고, 화면에 notice-banner `time-unknown`.

## ohaeng-bar

* 쓰는 화면: saju-chart
* 견본색 비례 막대(10px, 칸 사이 2px, 목·화·토·금·수 순) + 아래 다섯 오행 견본·이름·개수.
* 0개는 막대에 칸이 없고, 범례 견본 투명도 0.35·숫자 `text.secondary`.

## manse-table

* 쓰는 화면: saju-chart
* 원국표와 같은 열 순서 격자. 왼쪽 행 머리 52px(지장간·12운성·신살 = term-token `label`). 위에 `ohaeng.cell` `mini`(30×30) 천간·지지. 지장간은 한자 + 한글 독음.

## daeun-table

* 쓰는 화면: saju-chart
* 대운: 가로 넘김. 기둥 52px = 한국식 나이(core C22) + mini 두 칸 + 시작 연도.
* 세운: 5×2 격자(지금 대운의 10년).
* 지금 대운·올해 세운은 `highlight.current`(바탕 `status.bg`, 나이·연도 `action.primary` 굵게) + `tag.status` "지금"/"올해". 낙관 윤곽은 쓰지 않습니다(칸 하나 단위인 달력 오늘에만).
* 처음 열 때 지금 대운이 보이게 넘겨 둡니다(움직임 없이).

## 글자 크기와 스크린리더

표 칸은 고정 폭이라 시스템 글자 크기를 1.3배까지만 키웁니다. 스크린리더는 칸마다 기둥 이름, 한자와 독음, 오행, 십성을 읽습니다.

## 용신 판정 근거 (saju-chart, D60)

원국·오행 탭의 용신 판정 근거(`saju-chart.yongsin.basis`)는 `sentence-block` `body`입니다. 권한이 없으면 `sentence-block`의 `locked`(흐린 한 줄 + "열기" 링크와 화살표, 문구 슬롯 `saju-chart.yongsin.open`)이고, 누르면 근거 시트가 잠긴 상태로 열립니다. 원국표·오행 분포·만세력·대운 표 데이터는 무료입니다.
