# 근거 깊이 잠금과 글자 수 상한 설계 (컴포넌트 계약 2.0.0)

* 작업 단위: design
* 마일스톤: V2 후속 (선행 V2 컴포넌트 1.0.0, 후행 A1 UI 구현)
* 입력: Issue #53(root → design, D60 근거 깊이 잠금), Issue #54(writing → design, 슬롯별 글자 수 상한)
* 기준 문서: [V2 spec](2026-10-11-components-design.md), `docs/decisions.md` D60, IA 계약 v1 [`docs/ia/screens.json`](../../../ia/screens.json)(`explain-sheet`, `evidence-sheet`, `saju-chart`, `system-rewarded-ad`)
* 계약: 컴포넌트 명세 1.0.0 → **2.0.0**(제공 design → 사용 app). 토큰 1.1.0은 그대로입니다.
* 시안: `.suberpowers/brainstorm/90921-1791702733/content/lock-layout*.html`(git 제외). 고른 시안은 `design-v2-evidence-lock`으로 등록합니다(§7).

## 1. 목적과 완료 기준

D60으로 잠기는 자리가 풀이 시트에서 근거 시트로 옮겨졌습니다. app이 잠김·해제 흐름을 명세만 보고 만들 수 있게 컴포넌트 명세를 고치고, writing이 `max_length`에 바로 넣을 수 있는 글자 수 상한을 레이아웃에서 계산해 돌려줍니다.

끝나는 조건은 다음과 같습니다.

1. 컴포넌트 명세 2.0.0: 풀이 시트에서 개인 해석 상자 제거, 근거 시트 구성과 잠김 상태 4개, 새 요소 `lock.veil`, `sentence-block` 잠김 상태, 모양 규칙과 화면 여백(§2~§4)
2. 글자 수 상한 표 [`lengths.md`](../lengths.md)와 계산 도구 `tools/lengths.py`, 테스트(§5)
3. 검사기 `tools/components.py`와 pytest 통과
4. 결정 V25~V27, 시안 기록, `CLAUDE.md` 갱신
5. Issue: #53·#54 답, app 앞 2.0.0 notice, 지휘 앞 IA 요청(§8)

## 2. 근거 시트 잠금 (결정 V25)

### 2.1. 무엇이 어디로 가나

| 시트 | 1.0.0 | 2.0.0 |
| --- | --- | --- |
| 풀이 시트(explain-sheet, half) | 제목·한자 → 일반 뜻 → "내 사주에서는" 상자. 상자에 잠김 변형(MVP 미사용) | 제목·한자 → 일반 뜻 → 오늘 그런 이유(오늘 화면에서 열었을 때) → 근거 보기 링크. **모두 무료, 잠김 없음** |
| 근거 시트(evidence-sheet, full) | 명세에 구성이 없음 | 제목 → 원국표 → 판정 근거 → 원전 → 내 사주에서는(사주 표·만세력·대운 표의 용어에서 열었을 때). 앞의 둘(제목·원국표)은 무료, 뒤의 셋은 잠김 |

근거: D60 ①(잠기는 것: 판정 근거, 원전 인용, 원국 개인 해석 / 무료: surface·explain, 표 데이터), IA `explain-sheet`·`evidence-sheet` 슬롯.

### 2.2. 명세 위치

IA 컴포넌트 41개 밖의 컴포넌트를 만들 수 없으므로(검사기가 막음) 기존 컴포넌트의 구성 요소로 둡니다.

* `term-token.parts.explainSheet`: `mine`을 빼고 `todayReason`(오늘 그런 이유)과 `evidenceLink`(depth-link `block`)를 둡니다. `states.locked`를 뺍니다.
* `depth-link.parts.evidenceSheet`(새 구성 요소): 근거 시트 구성. 풀이 시트를 `term-token`이 갖는 방식과 같습니다. 근거 시트는 늘 근거 보기 링크(또는 잠긴 용신 근거)에서 열리기 때문입니다.
* `depth-link.states`: `locked`, `lockedNoAd`, `unlocking`, `unlocked`(§2.4). 상태 이름은 IA 화면 상태가 아니므로 camelCase입니다(IA는 잠김을 화면 상태로 두지 않음, D60 ⑥).
* 새 요소 `lock.veil`(§3): 잠긴 구역 하나의 모습. 근거 시트 세 구역과 사주 표 용신 근거, 두 곳에서 씁니다.

### 2.3. 잠긴 모습 (시안 B)

* 세 구역(판정 근거·원전·내 사주에서는)은 열렸을 때와 **같은 자리**에 `lock.veil`로 그립니다. 구역 제목은 또렷하고, 본문은 흐린 자리 채우기 글입니다. 실제 내용은 server가 보내지 않습니다(D60 ④).
* 시트 아래에 **잠금 안내 영역**을 고정합니다: 위 1px `line` 선, 바탕 `bg.sheet`, 안쪽 `space.16`/`space.20`.
  * `lock.head`: 자물쇠(`lock-simple` Regular 16, `status.fg`) + `type.label.lg` `text.primary`
  * `lock.reward`: 보상 고지 `type.caption.lg` `text.secondary`. 광고 버튼보다 **먼저** 보입니다(D60 ⑤ AdMob 고지).
  * `lock.cta`: `primary-button` `filled`
  * `lock.pass`: 광고 제거권 안내 링크(`type.label.md` `action.primary`, 가운데, 누르면 `ad-free`)
* 안내 영역 높이만큼 본문 아래 여백을 둬서 마지막 구역이 가려지지 않게 합니다.
* 시안 A(안내 카드 하나 + 아래로 흐려짐)와 C(흐린 본문 위 겹친 안내)는 고르지 않았습니다(사용자 결정).

### 2.4. 상태와 전환

| 상태 | 언제 | 모습 |
| --- | --- | --- |
| `locked` | 권한 없음, 광고 준비됨 | §2.3 |
| `lockedNoAd` | 권한 없음, 광고 준비 안 됨 | `lock.cta` `disabled` + 버튼 아래 `lock.unavailable`(`type.caption.lg` `text.secondary`, 가운데). 광고가 준비되면 `locked`로 바뀝니다(`appear.seep`) |
| `unlocking` | 광고를 끝까지 보고 돌아옴, server 확인(SSV) 기다림 | `lock.cta` `loading`(점 숨쉬기). 시트는 그대로 |
| `unlocked` | 권한 있음 | 안내 영역 없음, 세 구역 본문이 보임 |

`system-rewarded-ad`에서 돌아올 때:

* **끝까지 봄** → `unlocking` → 권한이 오면 세 구역이 skeleton(`loading.breathe`)으로 바뀌고, 내용이 오면 `appear.seep`. 안내 영역은 `disappear.seep`. 햅틱 `light` 한 번(열림은 사용자가 기다린 결과라서).
* **확인이 오지 않음**(app이 정한 대기 시간 초과, server 확인 흐름에 따름) → `locked`로 돌아가고 `toast`로 알립니다. 문구 슬롯은 IA에 없으므로 지휘에 요청합니다(§8).
* **중간에 닫음** → `locked` 그대로, 알림 없음(IA `system-rewarded-ad`: "닫으면 아무것도 바뀌지 않습니다").
* 처음부터 권한이 있으면(그날 이미 열었거나 광고 제거권 기간) 시트는 `unlocked`로 열립니다. 잠김을 거쳐 보이지 않습니다.
* 자정이 지나 권한이 끝나도 보고 있던 시트는 바꾸지 않습니다. 다음에 여는 시트부터 `locked`입니다. 이미 받은 내용을 화면에서 지울 이유가 없고, 읽는 중에 바뀌면 놀랍기 때문입니다.

### 2.5. 사주 표 용신 판정 근거

* `saju-chart.yongsin.basis`는 콘텐츠 문장이므로 `sentence-block` `body`로 그립니다. 권한이 없으면 `sentence-block`의 새 상태 `locked`: `lock.veil` 한 줄 + 오른쪽 끝 "열기 ›"(`depth-link` 모양). 누르면 근거 시트가 `locked`로 열립니다(IA exit "잠긴 근거 열기").
* IA `saju-chart`의 `components`에 `sentence-block`이 없습니다. 콘텐츠 슬롯이 있는데 그릴 컴포넌트가 빠진 것이므로 지휘에 추가를 요청합니다(§8). 명세는 그 전제로 씁니다.

### 2.6. 접근성

* 잠긴 구역: "판정 근거, 잠김" 식으로 구역 제목 + "잠김"을 읽고, 흐린 자리 채우기 글은 읽지 않습니다(`excludeFromSemantics`).
* `unlocking`: 버튼이 "확인 중"을 알립니다. `unlocked`로 바뀌면 "근거와 해석이 열렸습니다"를 한 번 알립니다(실시간 안내).
* 동작 줄이기: 흐림은 그대로(대상 자신의 흐림, V14), 스밈은 투명도만.

## 3. 요소 `lock.veil`

| 구성 | 값 |
| --- | --- |
| 구역 제목 | 자물쇠 `lock-simple` Regular 14 `text.secondary` + 제목 `type.label.md` `text.secondary`, 간격 4px |
| 흐린 본문 | `type.sentence.body`, 흐림 6px, 투명도 0.5, 선택·복사 불가. 글은 자리 채우기(server가 보낸 글자 수 힌트가 있으면 그 길이, 없으면 두 줄) |
| 쓰는 곳 | 근거 시트 세 구역, `sentence-block` `locked`(사주 표 용신 근거) |

1.0.0 `term-token.states.locked`의 흐림 값(6px, 0.5)을 그대로 옮깁니다. 이 값은 V2에서 이미 대비 검사를 거친 값입니다.

## 4. 공통 규칙 추가 (결정 V26)

### 4.1. 모양 규칙

**누르면 실행하는 동작은 둥근 사각(`radius.md`), 값·상태를 보여 주거나 고르는 것은 알약(`radius.full`)입니다.** 예외는 두지 않습니다.

* 1.0.0에서 이미 그렇게 쓰고 있습니다: 동작 `primary-button`·`social-login-button`(V13) / 알약 배지·칩·꼬리표·segmented·toast.
* 어긋나던 `share-button`의 `pill` 변형을 `soft` 변형(`radius.md`, 높이 36)으로 바꿉니다. 이름이 모양을 가리키므로 이름도 바꿉니다.

### 4.2. 화면 좌우 여백

페이지 화면의 좌우 여백은 `space.20`입니다. 채택 시안 `design-v2-today`·`design-v2-frame`(폭 375px, 여백 20px)과 시트 `paddingX`(`space.20`)에서 쓰던 값인데 명세에 적히지 않았습니다. app-bar는 아이콘 터치 영역 때문에 `space.16`을 그대로 씁니다.

## 5. 글자 수 상한 (결정 V27)

### 5.1. 계산 방법

* 기준 화면 폭 360px(Android 최소 다수 폭) − 좌우 여백 20×2 = 본문 폭 320px. 칸 폭은 각 컴포넌트 명세의 안쪽 여백을 뺀 값입니다.
* 글자 폭은 실제 글꼴에서 읽습니다: 문장 고운돋움(ko·en)·Zen Maru Gothic(ja), UI Pretendard(굵기별). 일본어 UI 글꼴(Pretendard JP)은 전각 1em으로 봅니다(Zen Maru Gothic 측정값도 1em).
* **ko 문장 자리:** writing 라운드 R1~R7 원고 52문장을 어절 단위(keep-all)로 칸에 채우고, 꽉 찬 줄 글자 수의 하위 10%를 한 줄로 봅니다. 상한 = 한 줄 × 줄 수.
* **ko 이름 자리:** 띄어쓰기 없는 한글로 한 줄을 채운 글자 수입니다.
* **ja:** 글자 단위 줄바꿈 + 금칙 처리라 줄마다 한 글자를 여유로 뺍니다.
* **en:** 라틴 소문자 폭을 영어 글자 빈도로 가중 평균하고, 줄마다 평균 단어(4.7자 + 띄어쓰기)의 절반을 줄바꿈 손실로 뺍니다.
* **최종값 = writing 초안과 레이아웃 계산 중 작은 값**(ja 초안 = ko, en 초안 = ko × 1.8). 레이아웃이 초안보다 넉넉하면 초안을 지킵니다. 문체 판단(W8 짧은 한 문장 등)은 writing의 것이기 때문입니다.

### 5.2. 줄 수 기준

| 자리 | 줄 | 근거 |
| --- | --- | --- |
| 큰 문장(`sentence-block` `card`): 총운 헤드라인·보조 문장, 가이드 질문 | 2 | 두 자리 모두 같은 card 스타일. 첫 시선에서 두 줄을 넘으면 W8 "짧은 한 문장"과 맞지 않음 |
| 행운 설명 상자 | 2 | 상자에 줄 수 제한이 없고(`lucky-card.explain`), W7 두 문장형("오늘은 남색이 잘 맞아요. 옷이나 소품으로 챙겨 보세요.", 30자)이 사용자 선택으로 정해짐. IA의 "설명 한 줄"은 설명이 하나라는 뜻으로 봄 |
| 이름·칩·배지·segmented·날짜 칸 | 1 | 줄바꿈하면 칩·칸 모양이 깨짐 |
| 스크롤 본문(용신 산출 방법, 계산 기준 안내) | 제한 없음 | 레이아웃이 막지 않음. 초안 그대로 |

### 5.3. 결과

표와 칸 폭은 [`lengths.md`](../lengths.md)에 있고 `tools/lengths.py`가 만듭니다. 초안보다 짧아지는 곳만 적습니다.

| 슬롯 | 초안 (ko) | 확정 ko / ja / en | 이유 |
| --- | --- | --- | --- |
| `daily.guide` | 40 | 36 / 30 / 70 | 질문 카드 안쪽 여백(`space.20`)으로 칸이 280px |
| `calendar.solar_term` | 10 | 4 / 3 / 6 | 날짜 칸 폭 44px, 굵게 10.5px. **영어 절기 이름("Start of Spring")은 들어가지 않으므로 writing이 6자 이하 줄임 표기를 정해야 함** |
| `ui.depth.surface` / `explain` / `evidence` | 10 | 8 / 6 / 13 | segmented 세 칸 중 한 칸(104px) |

### 5.4. 용어 토큰 칩

토큰 하나에 좌우 3px씩(`term-token` `inline`), 6px가 늘어납니다. writing 규칙상 토큰은 한 화면에 2개까지(`limit.L6`), 한 문장에 모읍니다(`limit.L7`). 그래서 한 문장에서 늘어나는 폭은 최대 12px이고, card 글자(17px, 한글 한 자 15.5px)로 한 글자가 안 됩니다. 상한 계산이 꽉 찬 줄의 하위 10%를 쓰므로 이 폭은 그 여유 안에 들어갑니다. **토큰이 든 문장의 상한을 따로 두지 않습니다.**

## 6. 계약 2.0.0 변경 목록

| 종류 | 내용 |
| --- | --- |
| 빠짐(주) | `term-token.parts.explainSheet.mine`, `term-token.states.locked`, `term-token.a11y.lockedLabel`, `share-button` 변형 `pill` |
| 추가(부) | `term-token.parts.explainSheet.todayReason`·`evidenceLink`, `depth-link.parts.evidenceSheet`, `depth-link.states.locked`·`lockedNoAd`·`unlocking`·`unlocked`, `sentence-block.states.locked`, `share-button` 변형 `soft`, 요소 `lock.veil`, 접근성 라벨(`sentence-block`·`depth-link`의 `lockedLabel` 등) |
| 규칙 | README 공통 규칙: 모양 규칙(§4.1), 화면 좌우 여백(§4.2) |

모든 명세 JSON의 `version`과 검사기 `CONTRACT_VERSION`을 2.0.0으로 올립니다. 2026-10-11 기준 main의 `app/`은 비어 있고 app 브랜치도 없어서 1.0.0을 쓰는 구현이 없습니다. 그래서 1.0.0을 남겨 두지 않습니다. `docs/workflow.md` §5.1의 공지는 app 앞 notice Issue로 합니다.

## 7. 함께 고치는 문서와 산출물

* `components/`: `sentence`, `elements`, `action`, `README` (JSON + MD), 나머지 JSON은 `version`만
* `tools/components.py`(`CONTRACT_VERSION`), `tools/test_components.py`(버전 문자열)
* `lengths.md`(새), `tools/lengths.py`·`tools/test_lengths.py`(새)
* `decisions.md` V25~V27, `artifacts/index.json` + 시안 HTML·PNG(`design-v2-evidence-lock`), `CLAUDE.md` 현재 상태
* `docs/coordination/2026-10-11-writing-to-design-length.md` 상태 `done`(받는 쪽 처리)

## 8. 전달

* **#53 답**(root): 반영 내용과 지휘에 넘기는 두 가지.
* **#54 답**(writing): 확정 표, 절기 영어 줄임 표기 필요, 토큰 칩 답.
* **app notice**: 컴포넌트 계약 2.0.0 변경 목록(§6).
* **지휘 request**: ① IA `saju-chart.components`에 `sentence-block` 추가 ② 근거 시트 잠금 해제 확인 실패 toast 슬롯(예: `evidence-sheet.lock.failed`, ui) 추가.

## 9. 범위 밖

* 보상형 광고 화면 자체(AdMob이 그림), 대기 시간 값(app·server), 권한 판정(server).
* 잠금 문구(writing #52), 개인 해석 콘텐츠(core #51).
