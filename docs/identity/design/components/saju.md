# saju: 사주 표 (`saju.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.9, [십성 라벨·피드백 spec](../specs/2026-10-28-feedback-saju-labels-design.md) §2, [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §1, §4, 결정 V21·V25·V49·V77·V88~V92
* 시안: `design-v2-saju-pillars`(오행 바탕 A), `design-v2-saju-manse`(격자 A, V89로 바뀜), `design-v2-saju-flow`(대운·세운), `design-ds1-screen-e`(사주 표 DS1, 사용자 확인 대기)

## 원칙: 표준 배치, 차별은 깊이·풀이·시각 언어

사주 표는 정보가 빽빽해 다른 만세력과 모양으로 차별하기 어렵고, 사용자는 다른 앱과 대조해 보며 신뢰를 얻습니다. 그래서 **열 순서·배치·용어는 다른 만세력과 같게** 둡니다. 차별은 세 가지로 냅니다.

1. 깊이 구조: 나 탭 문장 → 근거 보기 → 표. 표는 근거로 내려와서 봅니다.
2. 모든 용어 풀이: 띠 머리 칩과 표 칸의 십성, 12운성, 신살 하나하나가 term-token이고, 풀이 시트(일반 뜻, 무료) → 근거 시트에서 원국 개인 해석 "내 사주에서는"(D60으로 잠긴 기능, sentence.md).
3. 같은 시각 언어: 오행 칸, 상태 꼬리표, 현재 강조, 스밈이 앱 전체와 같습니다.

오늘 일진을 원국표에 겹쳐 보는 화면은 만들지 않습니다(사용자 결정). saju-chart는 segmented 두 탭(원국 / 만세력과 대운)이고, 두 탭 위에 공통 머리("<호칭>님의 사주" + `birth-info-row`)가 있습니다(IA 시안 E).

**사주 표 배치(IA v5, 결정 V88~V92):** 머리 → segmented → 원국 탭(`section-header` 사주 + `saju-pillars`, 오행 분포 + `ohaeng-bar`, 용신 판정 근거 + `sentence-block`, 섹션마다 제목 아래 한 줄 설명을 늘 보임) / 만세력과 대운 탭(`manse-table` 기준 줄과 `band-table`, 대운과 세운 `daeun-table`). 시간 모름이면 내용 첫 줄에 `notice-banner` `time-unknown`.

## saju-pillars

* 쓰는 화면: evidence-sheet, my-saju, saju-chart
* 왼쪽부터 시·일·월·연. 칸은 `ohaeng.cell` `pillar`(66px 높이, 한자 `type.hanja.pillar` + 한글 독음 `type.caption.sm`).
* 위 천간 십성, 아래 지지 십성(정기). 모두 term-token `label`.
* **일간(나):** 칸 안쪽 2px `action.primary` 테두리 + 오른쪽 위 모서리에 `tag.me` "나" 꼬리표(칸이 자르지 않게 칸 밖 층). 십성 줄의 "일간"도 term-token.
  * 꼬리표(`ui.saju.tag`)는 모서리에 붙여 왼쪽으로 늘어나고, 기둥 폭까지 한 줄입니다(V53, ja "わたし"도 들어감).
* 열 머리(시주·일주·월주·연주)는 `ui.saju.header`입니다.
* 시간 모름이면 시주 칸은 점선 테두리 빈 칸이고, 화면에 notice-banner `time-unknown`.

## ohaeng-bar

* 쓰는 화면: my-saju, saju-chart
* 견본색 비례 막대(10px, 칸 사이 2px, 목·화·토·금·수 순) + 아래 다섯 오행 견본·이름·개수.
* 0개는 막대에 칸이 없고, 범례 견본 투명도 0.35·숫자 `text.secondary`.

## manse-table

* 쓰는 화면: saju-chart
* 근거: IA v5 역할("네 열 속성 띠 표로 그림"), 결정 V89. V49의 지장간 두 줄 묶음과 V53의 행 머리 규칙을 바꿈(2026-11-07 개정)
* 만세력과 대운 탭 위 묶음입니다. 기준 줄(`saju-chart.manse.basis`, 매개변수 `stem`, 가안 "내 일간 庚(경금) 기준")은 `type.caption.lg` `text.secondary` 글자 한 줄이고 간 한자만 `font.family.hanja`, 아래 `space.12`에 `band-table`(띠: 지장간 → 12운성 → 신살)입니다.
* 기준 줄은 누를 수 없는 글자입니다. origin의 초록 바탕은 누르면 뜻 시트인 용어 칩과 헷갈려 쓰지 않습니다(V73).
* 이 탭은 원국 칸(사주 블록)을 다시 보이지 않습니다. 네 열이 원국표와 같은 순서라 원국 탭과 대조됩니다. 옛 왼쪽 행 머리 열(52)과 위 mini 칸은 없습니다.
* 불러오는 중은 기준 줄 뼈 한 줄 + `band-table` 뼈, 시간 모름이면 시주 열 칸이 모두 빈 칸 표시입니다.

## band-table

* 쓰는 화면: saju-chart
* 근거: DS1 2단계 spec §4, 결정 V89, 시안 `design-ds1-screen-e`
* 흰 카드(`radius.lg`, 좌우 `space.12`, 위아래 `space.4`)에 네 열(시주, 일주, 월주, 연주)을 같은 폭으로 끝까지 유지합니다. 열 구분선(0.5px `line`)이 열 머리부터 마지막 띠 끝까지 모든 띠를 관통합니다. 표 격자선이라 `list.divider`가 아닙니다.
* 열 머리(`ui.saju.header`)는 `type.caption.md` `text.secondary` 가운데, 위아래 `space.8`.
* **일주 열:** 열 머리부터 끝까지 `status.bg`를 0.35로 옅게 깔고, 열 머리는 `action.primary` 700 + 뒤 `space.4`에 `tag.me` "나"(`ui.saju.tag`)를 한 줄로 둡니다. 글자 실효 폭은 열 74에서 간격 4와 가장 넓은 꼬리표(ja "わたし" 36)를 뺀 약 32이고, 넘치면 꼬리표를 열 머리 아래 줄로 내립니다(글자는 줄이지 않음). 지금 원고(일주, Day, 日柱)는 700 굵기로 약 21px이라 한 줄에 들어갑니다. origin의 "일주(나)" 글자 대신 원국표와 같은 표시라 새 문구가 없습니다. 옅게 까는 이유는 용어 칩 바탕(`term.bg`)과 `status.bg`가 같은 sage라 그대로 깔면 일주 열의 용어 칩이 묻히기 때문입니다.
* **띠 머리줄(`bandHeader`):** 네 열에 걸친 가운데 줄입니다. 흰 바탕(`bg.sheet`)이 열 구분선과 일주 열 바탕을 덮고, 위아래 0.5px `line`, 위 `space.8`, 안쪽 위아래 `space.8`. 가운데 띠 이름은 `term-token` `label`(`ui.saju.header`)이고 누르면 설명 시트(`explain-sheet`)입니다. 본문은 `saju-chart.jijanggan.desc`, `saju-chart.unseong.desc`, `saju-chart.sinsal.desc`이고 12운성 시트만 본문 아래 `stage-strip`이 있습니다. 한 줄 설명은 띠 안에 두지 않습니다.
* **띠 칸:** 가운데, 위로 맞춤, 위 `space.8` 아래 `space.12`(다음 띠 머리줄과 가름). 같은 띠의 칸은 가장 높은 칸만큼 늘어납니다.
  * 지장간: `stem.chip`(오행 바탕색과 글자색, 22) + `space.4` + 십성 `term-token` `label` 한 줄이 지장간 하나이고, 계약 배열 순서로 `space.4` 간격 세로로 쌓습니다. 독음은 그리지 않고 스크린리더가 읽습니다(V49의 "한자와 독음 / 십성" 두 줄 묶음을 바꿈).
  * 12운성: `term-token` `label`. 신살: `term-token` `label`, 여럿이면 세로로 `space.4`.
  * 값이 없는 칸(신살 없음, 시간 모름의 시주 열): 글자 "-" 대신 12×1 가로선(`text.secondary`). 스크린리더는 "없음"(writing 새 슬롯).
* 라벨은 칸 폭 안에서 낱말 단위 두 줄까지, 넘치면 `type.caption.sm`까지 줄이고 말줄임 없음(V49와 같음).
* 불러오는 중: 열 머리, 띠 머리줄, 열 구분선, 일주 열 바탕은 바로 그리고 칸마다 칩 모양 뼈.
* 접근성: 표(table), 열 머리를 읽음. 칸은 "띠 이름, 기둥 이름, 값"(지장간은 한자와 독음, 십성 순서로 하나씩). 글자 배율 상한 1.3배.

## daeun-table

* 쓰는 화면: saju-chart
* 근거: IA v5 역할("대운, 세운 줄. 칸은 luck-pillar이고 가로로 넘기며 scroll-hint"), 결정 V90. V49의 세운 5×2 격자를 바꿈(2026-11-07 개정)
* 대운, 세운 두 줄입니다. 줄마다 `section-header` `plain`(제목 `saju-chart.daeun.title`, `saju-chart.seun.title`과 한 줄 설명 `.desc`를 늘 보임) 아래 흰 카드(`radius.lg`, 위아래 `space.12`, 좌우 `space.12`)에 `luck-pillar` `column`을 `space.4` 간격으로 가로로 넘깁니다.
* 세운도 5×2 격자 대신 대운과 같은 가로 줄입니다(지금 대운 10년, origin). 칸 폭은 대운과 같고, 두 줄은 따로 넘깁니다.
* 넘기는 줄에는 `scroll-hint`(더 있는 쪽 끝만 흐림, 줄 아래 겹 화살표)를 둡니다. 글자 안내는 쓰지 않습니다.
* 처음 열 때 지금 대운, 올해 세운 칸이 보이게 넘겨 둡니다(움직임 없이). 그 칸이 줄 가운데 오면 양쪽이 모두 흐려 보입니다.
* **라벨 폭(V49):** 라벨은 기둥 폭 안에서 가운데, 낱말 단위 두 줄까지, 넘치면 `type.caption.sm`까지 줄이고 말줄임 없음. 사전 이름이 없으면 한자, 한자도 없으면 칩 없이 자리만.
* **높이 맞춤:** 같은 줄의 기둥은 부품 줄마다 높이를 맞춰 간지 칸이 늘 가로로 나란합니다.
* **꼬리표(V53, V90):** "지금", "올해"의 자리와 넘침 규칙은 `luck-pillar` `currentTag`가 정본입니다(강조 바탕 밖 아래, 넘치면 이웃 기둥 아래로 최대 기둥 둘과 간격 108px, 줄 양 끝 밖으로 나가지 않음). 이 표는 그 부품을 가리키기만 합니다.
* 대운 12운성 칩도 뜻 시트 → 근거 보기 → 그 자리의 원국 개인 해석으로 이어집니다(D60, app A58). 낙관 윤곽은 쓰지 않습니다(칸 하나 단위인 달력 오늘에만).
* 접근성: 줄마다 목록(list), 칸은 `luck-pillar` 그룹 읽기, 지금과 올해는 그 낱말을 함께 읽음.

## luck-pillar

* 쓰는 화면: my-saju(`compact`), saju-chart(`column`)
* 근거: [DS1 2단계 spec](../specs/2026-11-05-ds1-screens-design.md) §4, 결정 V77. 시안 `design-ds1-screen-b`
* 대운, 세운 기둥 한 칸입니다. 위에서부터 나이 또는 연도(`type.numeric.table` `text.secondary`, 대운은 한국식 나이 core C22, 세운은 연도) → 천간 십성 → 천간 칸 → 지지 칸 → 지지 십성(정기) → 12운성(`term-token` `label`, 위 `space.2`) → 시작 연도(`type.numeric.table` `text.secondary`) → 꼬리표 자리. 12운성과 시작 연도는 `daeun-table` 대운 기둥에서 옮긴 부품이고 세운에는 그리지 않습니다. 칸은 `ohaeng.cell` `small`(40×40, 한자 `font.family.hanja` 18 700), 부품 사이 `space.4`. 기둥 폭 52, 안쪽 `space.4`, 반경 `radius.md`.
* 십성 칩은 `term-token` `label`이고 누르면 뜻 시트입니다. 세운은 계약에 천간 십성만 있어(`SeunYear.tenGod`) 지지 십성, 12운성, 시작 연도를 그리지 않습니다. 세운 줄은 모든 칸에 없어 자리를 남기지 않습니다(2026-11-07).
* **지금 대운(`current`), 올해 세운(`thisYear`):** 기둥 바탕 `highlight.current`(`status.bg`, 나이나 연도부터 시작 연도까지 `highlightCovers`), 위 글자 `action.primary` 700, 바탕 밖 아래 `space.4`에 `tag.status` 꼬리표 "지금", "올해"(`ui.saju.tag`). 꼬리표 바탕과 강조 바탕이 같은 `status.bg`라 바탕 안에 두면 꼬리표가 묻혀 바탕 밖에 둡니다(관문 질문 Q1, 결정 V90). 낙관 윤곽은 쓰지 않습니다(칸 하나 단위인 달력 오늘에만).
* **`compact`(나 탭 올해와 지금):** 두 줄(지금 대운, 올해 세운), 줄 사이 `space.16`. 줄마다 왼쪽에 천간 칸과 지지 칸을 세로로(사이 `space.4`), 오른쪽 `space.12`에 정보 묶음입니다. 두 줄이 모두 지금이라 강조 바탕을 칠하지 않습니다(사용자 결정 2026-11-06, origin). 바탕을 칠하면 같은 sage 계열의 꼬리표와 용어 칩이 묻히기 때문입니다. 흰 카드(`bg.sheet`) 위에서 꼬리표(알약)와 용어 칩(`radius.xs`)이 구분됩니다. 사주 표 줄(`column`)의 지금 칸 강조는 그대로입니다.
  * 머리: `tag.status` "지금", "올해" + 용어 칩(`term-token` `label`) "대운", "세운"(사이 `space.4`).
  * 기간: `type.caption.lg` `text.secondary` 고정폭, 위 `space.4`. 대운은 나이 범위와 연도 범위, 세운은 연도와 그해 나이. 문구 틀은 IA 슬롯이 없습니다(writing 새 슬롯).
  * 십성: 천간, 지지 순 `term-token` `label`(세운은 하나), 사이 `space.4`, 위 `space.4`.
  * 꼬리표는 기둥 아래 대신 머리에 둡니다. 위 글자, 기둥 위아래 십성, 12운성, 시작 연도는 그리지 않습니다.
* 불러오는 중: 칸 두 개 모양과 십성 칩(36). 꼬리표와 위 글자는 그리지 않습니다.
* 접근성: 그룹 "나이 또는 연도, 천간 십성, 천간 지지 한자와 독음, 지지 십성", 지금과 올해는 그 낱말을 함께 읽습니다. 글자 배율 상한 1.3배.
* 사주 표 대운, 세운 줄(`daeun-table`)의 칸이 이 컴포넌트 `column`입니다(묶음 E, 결정 V90).

## 글자 크기와 스크린리더

표 칸은 고정 폭이라 시스템 글자 크기를 1.3배까지만 키웁니다. 스크린리더는 칸마다 기둥 이름, 한자와 독음, 오행, 십성을 읽습니다. 만세력 지장간은 지장간마다 한자와 독음, 십성 순서로, 대운 기둥은 나이 → 천간 십성 → 간지 → 지지 십성 → 12운성 → 시작 연도 순서로 읽습니다.

## 용신 판정 근거 (saju-chart, D60)

원국 탭의 용신 판정 근거(`saju-chart.yongsin.basis`)는 `sentence-block` `body`입니다. 권한이 없으면 `sentence-block`의 `locked`(앞 2~3 단어 또렷 + 흐린 자리값 두 줄, 오른쪽 자물쇠 + "열기", 문구 슬롯 `saju-chart.yongsin.open`)이고, 누르면 근거 시트가 잠긴 상태로 열립니다. 두 줄은 origin대로이고 V80의 한 줄을 바꿨습니다(관문 질문 Q2, 결정 V92). 원국표, 오행 분포, 만세력, 대운 표 데이터는 무료입니다.

## birth-info-row

* 쓰는 화면: saju-chart
* 근거: DS1 2단계 spec §4, IA 시안 E 확정(#801), 결정 V88, 시안 `design-ds1-screen-e`
* 사주 표 두 탭 공통 머리("<호칭>님의 사주", `saju-chart.head.title`) 아래 출생 정보 한 줄입니다. 칸 셋을 쉼표 없이 세로선(1px, 높이 16, `line`, 좌우 `space.12`)으로 나눕니다. spec §4의 "칸 넷"은 origin과 IA 역할 문장에 맞춰 셋으로 정정했습니다.
  1. 날짜: 달력 종류 꼬리표(`type.caption.sm` `text.secondary`, 0.5px `line` 테두리, `radius.xs`, 좌우 `space.4`, 윤달이면 V48 낱말을 뒤에) + `space.4` + 날짜(`type.label.md` 고정폭 숫자).
  2. 시진: `hanja-tag` `ganji`(지지 한자, 이름 "미시" 같은 시진 이름, writing 새 슬롯) + `space.8` + 시간. 시진 태그는 시진 뜻 원고가 없어 누를 수 없는 표시입니다(관문 질문 Q3).
  3. 성별: 중립 알약(높이 24, 투명 바탕 + 1px `tag.neutral.border`, `tag.neutral.fg`, `type.label.md`, 좌우 `space.8`). 색으로 성별을 나누지 않습니다. origin의 coral은 길흉 톤이라 그 자리(`fortune-verdict`, `score-row`) 밖에 쓰지 않습니다(Q4).
* 넘치면 칸 단위로 다음 줄(줄 사이 `space.8`)이고, 줄이 바뀐 칸 앞에는 선을 긋지 않습니다.
* **시간 모름:** 시진 태그와 시간 대신 같은 중립 알약 "시간 모름"(writing 새 슬롯, 출생 시간 입력의 모름과 같은 낱말) 하나입니다.
* 불러오는 중: 뼈 한 줄(70%). 접근성: 그룹, 달력 종류와 날짜, 시진과 시간, 성별 순서로 이어 읽고 세로선은 읽지 않음. 글자 배율 상한 1.3배.

## stage-strip

* 쓰는 화면: explain-sheet, saju-chart
* 근거: DS1 2단계 spec §4, IA `explain-sheet`("12운성 풀이에는 12단계 선형 띠와 내 네 자리"), 결정 V91, 시안 `design-ds1-screen-e`
* 12운성 설명 시트(사주 표 `band-table` 12운성 띠 머리 칩으로 연 `explain-sheet`) 본문 아래 `space.12`에만 둡니다. 12운성 값 칩(관대 등)의 뜻 시트에는 두지 않습니다.
* 장생, 목욕, 관대, 건록, 제왕, 쇠, 병, 사, 묘, 절, 태, 양 순서의 12칸 막대입니다. 칸 높이 6, 칸 사이 `space.2`, 반경 `radius.full`, 내 자리 칸은 `action.primary`, 나머지 `line`. 강하다 약하다 같은 평가를 덧붙이지 않습니다.
* **자리 표시:** 내 자리 칸 위 가운데(`space.4` 띄움)에 원 18(`action.primary` 바탕, `action.on-primary` 글자 `type.caption.sm` 700) "시", "일", "월", "연"(writing 새 슬롯, 기둥 한 글자 이름). 같은 단계에 자리가 여럿이면 시, 일, 월, 연 순서로 `space.2` 간격 나란히, 칸 폭을 넘으면 이웃 칸 위로 넘치고 트랙 끝 밖으로는 나가지 않습니다.
* **단계 이름:** 칸 아래 `space.4`, `type.caption.sm` `text.secondary` 한 줄, 내 자리 칸은 `text.primary` 600. 칸 폭(약 24)에 이름이 들어가지 않는 언어는 내 자리 칸 이름만 보이고 나머지는 숨깁니다(줄이거나 자르지 않음).
* 시간 모름이면 "시" 표시를 그리지 않습니다. 불러오는 중은 트랙 뼈 하나.
* 스크린리더: 그림(img) 하나로, 내 자리가 있는 단계만 막대 순서로 "장생, 월주 / 목욕, 연주 / 관대, 시주 / 양, 일주"처럼 읽습니다(하늘님). 같은 단계에 자리가 둘이면 두 기둥 이름을 "와"로 이어 읽습니다.

