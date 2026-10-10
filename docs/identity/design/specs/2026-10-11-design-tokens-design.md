# 마일스톤 V1 디자인 토큰 설계

* 작업 단위: design
* 마일스톤: V1 (로드맵: 선행 V0, 후행 V2·A1)
* 기준 문서: [시각 정체성 기준](../visual-identity.md), [V0 spec](2026-10-10-visual-identity-design.md) §10(넘긴 것)
* 계약: 디자인 토큰 (`docs/contracts/README.md`, 제공 design → 사용 app)
* 시안 기록: [`../artifacts/index.json`](../artifacts/index.json)의 `design-v1-*`

## 1. 목적과 완료 기준

app이 라이트·다크 테마와 한국어·영어·일본어 글자 스타일을 **토큰 파일만 보고** 만들 수 있게, V0 값과 V1에서 새로 정한 값을 중립적인 데이터 형식으로 동결합니다. Dart 코드 생성은 app이 합니다. design의 역할은 토큰 파일과 그 설명까지입니다.

V1은 다음이 모두 있을 때 끝납니다.

1. 토큰 파일 다섯 개와 계약 설명 `tokens/README.md` (계약 버전 1.0.0)
2. 생성기 `tools/tokens.py`. 커밋된 토큰 파일이 생성기 출력과 같다는 테스트를 통과합니다.
3. DTCG 형식 검사, 짝 파일 이름 일치 검사, 대비 검사(`palette.py --check`) 통과
4. `visual-identity.md`, 견본 페이지, 결정 로그(결정 V8~V12), 시안 기록 갱신
5. app 앞 `kind:notice` Issue, 지휘 세션 앞 `kind:report` Issue

## 2. 색의 의미 규칙 (결정 V8)

| 색 | 뜻 | 쓰는 곳 |
| --- | --- | --- |
| sage | 나와 내 기록, 조작 | 주 버튼, 선택, 용어 토큰, 일기 쓴 날 표시, 로고의 공책 |
| coral | 오늘의 좋은 기운 | 좋은 날·귀인의 날 배지, 캘린더 좋음 칸, 로고의 낙관(日) |
| neutral | 그 밖의 날과 정보 | 기신의 날·평범한 날 배지, 캘린더 주의 칸, 바탕·글자·선 |

* 새 역할을 만들 때 이 표로 색 계열을 정합니다. 좋은 쪽 신호에 sage를, 조작에 coral을 쓰지 않습니다.
* 좋지 않은 날(기신의 날, 캘린더 `CAUTION`)은 경고색을 쓰지 않고 neutral로 담담하게 표시합니다.

## 3. 새로 정한 색 역할

### 3.1. 날의 성격 배지 (엔진 `DayKind`, 결정 V10)

| 엔진 값 | 배지 | 토큰 | 라이트 | 다크 | 대비 (라이트 / 다크) |
| --- | --- | --- | --- | --- | --- |
| `YONGSIN_DAY` | 좋은 날 | `badge.good.bg` / `.fg` | coral-600 / `#ffffff` (V0 그대로) | coral-300 / neutral-900 | 4.89 / 8.23 |
| `GWIIN_DAY` | 귀인의 날 | `badge.gwiin.bg` / `.fg` | coral-100 / coral-700 | coral-800 / coral-200 | 6.08 / 7.54 |
| `GISIN_DAY` | 기신의 날 | `badge.gisin.bg` / `.fg` | neutral-100 / neutral-700 | neutral-800 / neutral-200 | 5.87 / 7.39 |
| `ORDINARY_DAY` | 평범한 날 | `badge.ordinary.border` / `.fg` | neutral-300 / neutral-700 | neutral-700 / neutral-400 | 6.07 이상 / 6.15 이상 |

* 강도 순서는 좋은 날(채움) > 귀인의 날(옅은 coral) > 기신의 날(옅은 회색) > 평범한 날(테두리만)입니다.
* 평범한 날 배지는 바탕이 없습니다. 그래서 글자 대비는 놓일 수 있는 모든 바탕(`bg.base`, `bg.sheet`, 그라데이션 양 끝)에서 검사합니다.

### 3.2. 캘린더 길흉 (엔진 `LuckLevel`, 결정 V10)

길흉은 **날짜 칸을 옅게 채워** 보여줍니다. 점은 쓰지 않습니다. 점은 일기를 쓴 날이나 일정 같은 이벤트 표시로 남겨 둡니다(V2에서 정함).

| 엔진 값 | 토큰 | 라이트 | 다크 |
| --- | --- | --- | --- |
| `GOOD` | `calendar.good.bg` | coral-100 | coral-900 |
| `NEUTRAL` | (없음, 채우지 않음) | - | - |
| `CAUTION` | `calendar.caution.bg` | neutral-100 | neutral-900 |

* 칸 위 글자(`text.primary`, `text.secondary`)는 대비 5.86:1 이상입니다.
* 채운 칸과 바탕의 대비는 1.1~1.2:1이라 색만으로는 WCAG 1.4.11(그래픽 3:1)을 맞추지 못합니다. 그래서 길흉은 색 말고도 두 가지로 전합니다. 날짜를 누르면 그날 정보에 글로 나오고, 스크린리더는 "좋은 날", "주의할 날"로 읽습니다. 이 규칙은 V2 컴포넌트 명세에 넣습니다.
* 엔진 spec §8과 app 문서는 "길흉 점"이라고 적고 있습니다. 표시 방식이 바뀐 것을 지휘 세션에 보고합니다(§9).

### 3.3. V0 값 중 토큰으로 옮기며 하나로 정한 것

| 항목 | V0 표기 | V1 토큰 값 |
| --- | --- | --- |
| 칩 바탕 `chip.bg` | 흰색 70% / 8% | `#ffffff` alpha 0.70 / alpha 0.08 |
| 견본 테두리 `swatch.border` | `text.primary` 15~20% / 20~35% | 라이트 neutral-900 alpha 0.18 / 다크 neutral-100 alpha 0.28 |

## 4. 타이포그래피 (결정 V11)

### 4.1. 글꼴 묶음

대체 순서까지 배열로 적습니다. 영어는 한국어 파일을 씁니다.

| 토큰 | 한국어·영어 (`typography.tokens.json`) | 일본어 (`typography.ja.tokens.json`) |
| --- | --- | --- |
| `font.family.sentence` | Gowun Dodum, Pretendard, sans-serif | Zen Maru Gothic, Pretendard JP, sans-serif |
| `font.family.ui` | Pretendard, sans-serif | Pretendard JP, sans-serif |
| `font.family.hanja` | Pretendard JP, sans-serif | Pretendard JP, sans-serif |

### 4.2. 글자 스타일

V0의 범위 값(라벨 12~14, 캡션 11~12)을 단일 값으로 나눴고, `display`와 숫자 스타일을 더했습니다.

| 토큰 | 글꼴 | 크기 | 굵기 | 줄 간격 (ko·en / ja) | 자간 (ko·en / ja) |
| --- | --- | --- | --- | --- | --- |
| `type.sentence.card` 카드 문장 | sentence | 17 | 400 | 1.65 / **1.75** | 0 / 0 |
| `type.sentence.body` 일반 본문 | sentence | 15 | 400 | 1.6 / **1.7** | 0 / 0 |
| `type.display` 큰 제목 | ui | 24 | 600 | 1.25 | -0.48 / 0 |
| `type.title` 화면 제목 | ui | 20 | 600 | 1.3 | -0.40 / 0 |
| `type.subtitle` 소제목 | ui | 16 | 600 | 1.4 | -0.32 / 0 |
| `type.label.lg` 버튼·탭 | ui | 14 | 600 | 1.3 | -0.28 / 0 |
| `type.label.md` 칩·배지 | ui | 13 | 500 | 1.3 | -0.26 / 0 |
| `type.caption.md` 캡션·날짜 | ui | 12 | 500 | 1.3 | -0.24 / 0 |
| `type.caption.sm` 원국표 칸 아래 표기 | ui | 11 | 500 | 1.3 | -0.22 / 0 |
| `type.numeric.calendar` 캘린더 날짜 | ui | 14 | 500 | 1.2 | 0 / 0 |
| `type.numeric.table` 대운·세운 표의 나이·연도 | ui | 13 | 500 | 1.3 | 0 / 0 |
| `type.hanja.pillar` 원국표 한자 | hanja | 17 | 700 | 1.0 | 0 / 0 |

* 크기와 자간 단위는 px입니다(Flutter 논리 픽셀).
* **자간:** 한국어 UI(Pretendard)는 글자 크기의 -2%를 px로 환산한 값입니다. DTCG 치수는 px·rem만 허용해 em을 쓸 수 없기 때문입니다. 문장 글꼴, 일본어, 숫자, 한자는 0입니다.
* **고정폭 숫자:** `numeric.*` 두 스타일은 `$extensions`에 `fontFeatures: ["tnum"]`을 적습니다. DTCG 글자 규격에는 이 항목이 없습니다.
* **줄 간격:** 일본어 값은 작성한 예문으로 비교해 정했습니다(시안 `design-v1-ja-line-height`). W1에서 원어민이 검수한 실제 문장이 나오면 다시 확인합니다.
* **시스템 글자 크기:** app은 기기의 글자 크기 설정을 따릅니다. 원국표처럼 칸이 고정된 곳만 상한을 둡니다. 상한 값은 V2에서 정하며, 이 규칙은 `tokens/README.md`에 적습니다.

## 5. 간격과 반경 (결정 V12)

| 간격 토큰 | `space.2` | `space.4` | `space.8` | `space.12` | `space.16` | `space.20` | `space.24` | `space.32` | `space.48` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 값 (px) | 2 | 4 | 8 | 12 | 16 | 20 | 24 | 32 | 48 |

| 반경 토큰 | 값 (px) | 예시 쓰임 |
| --- | --- | --- |
| `radius.xs` | 4 | 문장 안 용어 토큰 |
| `radius.sm` | 8 | 캘린더 칸, 원국표 칸, 색 견본 |
| `radius.md` | 12 | 버튼, 입력창 |
| `radius.lg` | 20 | 카드, 패널 |
| `radius.xl` | 28 | 아래에서 올라오는 시트의 위쪽 모서리 |
| `radius.full` | 9999 | 배지, 칩 |

* V1은 값만 동결합니다. 어느 컴포넌트가 어느 토큰을 쓰는지는 V2 컴포넌트 명세에서 정합니다.
* 그림자와 모션 토큰은 만들지 않습니다.

## 6. 토큰 파일 (결정 V9)

### 6.1. 형식

[DTCG Format Module 2025.10](https://www.designtokens.org/tr/2025.10/format/)을 따릅니다.

* 파일 확장자는 `.tokens.json`입니다. 그룹은 중첩 객체이고, 토큰은 `$value`와 `$type`을 가집니다. 쓰임새는 `$description`에 적습니다.
* **색:**
  ```json
  {"$type": "color", "$value": {"colorSpace": "srgb", "components": [r, g, b], "hex": "#rrggbb"}}
  ```
  * `components`는 hex 각 채널을 255로 나눠 소수 넷째 자리에서 반올림한 값입니다. 기준값은 `hex`입니다.
  * 투명도가 있으면 `alpha`를 더합니다.
* **치수:** `{"value": 16, "unit": "px"}`입니다.
* **참조:** 의미 역할은 원시 값을 `"{color.sage.700}"`처럼 가리킵니다. 원시 팔레트에 없는 값(그라데이션 색, 오행 바탕·글자)만 값을 직접 적습니다.
* **글자:** `typography` 복합 토큰의 다섯 항목(`fontFamily`·`fontSize`·`fontWeight`·`letterSpacing`·`lineHeight`)을 모두 적습니다. `fontFamily`는 `{font.family.*}` 참조입니다.
* **그라데이션:** `gradient` 토큰(`[{color, position}]`)으로 적습니다. 규격에 각도가 없어 `$extensions`에 `{"myungli-diary": {"angle": 160}}`으로 적습니다.
* **확장 키:** 이 저장소의 확장 키는 `myungli-diary` 하나입니다.
* 모드는 DTCG Resolver Module을 쓰지 않고 파일로 나눕니다. 규격 상태가 출처마다 다르게 적혀 있어서입니다(W3C 공동체 그룹 보고서는 안정판, designtokens.org 초안 페이지는 미리보기).

### 6.2. 파일과 조합

| 파일 | 담는 것 |
| --- | --- |
| `primitive.tokens.json` | `color.sage.*`, `color.coral.*`, `color.neutral.*`, `color.white`, `color.ohaeng.<오행>.swatch`, `space.*`, `radius.*` |
| `color.light.tokens.json` | 의미 역할 (아래 목록), `color.ohaeng.<오행>.bg/.fg`, `gradient.today` |
| `color.dark.tokens.json` | 같은 이름, 다크 값 |
| `typography.tokens.json` | `font.family.*`, `type.*` (한국어·영어) |
| `typography.ja.tokens.json` | 같은 이름, 일본어 값 |

* **의미 역할:** 모두 `color.` 아래에 둡니다.
  * V0: `bg.base`, `bg.sheet`, `text.primary`, `text.secondary`, `line`, `action.primary`, `action.on-primary`, `term.bg`, `term.fg`, `badge.good.bg/fg`
  * V1: `badge.gwiin.bg/fg`, `badge.gisin.bg/fg`, `badge.ordinary.border/fg`, `calendar.good.bg`, `calendar.caution.bg`, `chip.bg`, `swatch.border`
* **조합:** `primitive` + 색 모드 파일 하나 + 글자 언어 파일 하나 = 테마 하나.
* **이름 규칙:** 짝 파일(라이트·다크, 한국어·일본어)은 토큰 이름 목록이 같아야 합니다. 서로 다른 파일이 같은 토큰 이름을 정의하지 않습니다.
* **이름 충돌:** 어떤 이름이 토큰이면서 그룹일 수는 없습니다. 그래서 오행 견본은 `color.ohaeng.wood`가 아니라 `color.ohaeng.wood.swatch`로 씁니다.

### 6.3. 계약 버전

`tokens/README.md` 맨 위에 계약 버전을 적습니다. 첫 버전은 `1.0.0`입니다.

| 바뀌는 것 | 올리는 버전 |
| --- | --- |
| 토큰 이름이 바뀌거나 빠짐 | 주 버전 |
| 토큰 추가 | 부 버전 |
| 값만 바뀜 | 수 버전 |

하위 호환이 깨지는 변경(주 버전)은 workflow §5.1 절차를 따릅니다.

## 7. 생성기와 검사

* **`palette.py`**
  * §3의 새 역할을 `roles`에 더합니다(`chip.bg`, `swatch.border`는 알파가 있어 토큰 생성기에서 다룹니다).
  * 대비 검사에 새 조합을 더합니다: 배지 3종, 평범한 날 글자 × 바탕 4종, 캘린더 칸 2종 × 글자 2종. 조합 수는 32에서 52로 늡니다.
* **`tools/tokens.py`** (표준 라이브러리만 씁니다)
  * `build_palette()`와 §4·§5 상수로 다섯 파일의 내용을 만듭니다.
  * 역할 값이 원시 팔레트의 어느 단계인지 찾아 참조로 적습니다.
  * 출력은 `json.dumps(indent=2, ensure_ascii=False)`에 키 순서 고정이고, 끝에 줄바꿈 하나를 둡니다.
  * 실행: 저장소 루트에서 `python3 docs/identity/design/tools/tokens.py`
* **테스트 (`tools/test_tokens.py`)**
  1. 커밋된 토큰 파일 다섯 개가 생성기 출력과 바이트 단위로 같습니다.
  2. DTCG 형식:
     * 모든 토큰에 `$value`와 허용된 `$type`(`color`, `dimension`, `fontFamily`, `typography`, `gradient`)이 있습니다.
     * 색의 `hex`와 `components`가 일치합니다.
     * 치수 단위는 `px`입니다.
     * 모든 참조가 조합된 토큰 집합 안의 토큰을 가리킵니다.
     * 토큰이면서 그룹인 이름이 없습니다.
  3. 짝 파일의 토큰 이름 목록이 같고, 파일끼리 이름이 겹치지 않습니다.
  4. 토큰 파일에서 참조를 풀어 얻은 색 역할 값이 `build_palette()["roles"]`와 같습니다.
  5. 생성기 출력은 두 번 돌려도 같습니다.

## 8. 함께 고치는 문서와 산출물

* **`visual-identity.md`:** 색의 의미 규칙, 새 역할 표, 타이포 표(§4), 간격·반경, 토큰 파일 안내.
  * "좋은 날 외 배지·길흉 점은 V1에서" 문장을 지웁니다.
  * 요청 경로 문구를 GitHub Issues로 고칩니다.
* **견본 페이지:** 배지 4종, 캘린더 칸 채우기, 일본어 줄 간격(Zen Maru Gothic 예문), 간격·반경 견본을 더합니다. 견본 CSS 변수 테스트를 새 역할까지 넓힙니다.
* **`decisions.md`:** 결정 V8~V12를 적습니다.
* **`artifacts/index.json`:** 아래 다섯 항목을 등록합니다. 모두 PNG를 함께 둡니다.

  | id | status |
  | --- | --- |
  | `design-v1-day-badges-luck-dots` (점 방식, 귀인 sage 안) | `superseded` |
  | `design-v1-luck-cell-tint` (칸 채우기 A·B) | `chosen` (A) |
  | `design-v1-color-meaning` | `chosen` |
  | `design-v1-ja-line-height` | `chosen` (B) |
  | 견본 페이지 V1 판 | `chosen` |

* **`CLAUDE.md`:** "현재 상태"와 "다음 할 일"(V2는 IA 대기)을 고칩니다.

## 9. 전달 (workflow §3·§5·§6)

* 브랜치 `design/tokens` 하나를 PR 하나로 합칩니다. 내용이 대부분 토큰 계약이라 계약만 담은 PR을 따로 나누지 않습니다.
* **app 앞 `kind:notice` Issue (마일스톤 V1):**
  * 토큰 위치와 조합법
  * Dart 코드 생성은 app이 한다는 것
  * 칩·견본 테두리의 알파
  * `fontFeatures` 확장
  * 시스템 글자 크기 규칙
* **지휘 세션 앞 `kind:report` Issue (마일스톤 V1):**
  * 완료 보고
  * 계약 목록의 디자인 토큰 상태를 "동결 1.0.0"으로 바꿔 달라는 요청
  * 길흉 표시가 점에서 칸 채우기로 바뀐 것: 엔진 spec §8·app 문서의 "길흉 점" 표기
  * 색의 의미 규칙(결정 V8)
* 마무리는 workflow §3의 체크리스트를 따릅니다.

## 10. 범위 밖

| 항목 | 넘기는 곳 |
| --- | --- |
| Dart 코드 생성, Flutter 테마 구성, 아이콘 PNG 내보내기 | app |
| 컴포넌트별 토큰 사용, 일기·일정 표시 점, 오늘·선택 표시, 시스템 글자 크기 상한, 길흉의 글·스크린리더 표현 | V2 |
| 그림자, 모션 토큰 | 필요해지면 부 버전으로 추가 |
| DTCG Resolver Module 도입 | 규격 상태가 정리되고 app이 원할 때 |
| 일본어 줄 간격 재확인 | W1 원어민 검수 문장이 나온 뒤 |
