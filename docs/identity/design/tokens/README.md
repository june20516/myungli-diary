# 명리일기 디자인 토큰

계약 버전: 1.1.0

* 제공: design / 사용: app (계약 목록 `docs/contracts/README.md`)
* 근거: [V1 spec](../specs/2026-10-11-design-tokens-design.md), [V2 spec](../specs/2026-10-11-components-design.md) §5, 결정 V8~V13([`../decisions.md`](../decisions.md)), 사람이 읽는 기준은 [`../visual-identity.md`](../visual-identity.md)
* 컴포넌트 명세(`../components/`)가 이 토큰을 `{이름}`으로 가리킵니다.
* 형식: [DTCG Format Module 2025.10](https://www.designtokens.org/tr/2025.10/format/)
* 이 파일들은 생성기가 만듭니다. **손으로 고치지 않습니다.** 고칠 일은 GitHub Issue(`to:design`)로 보냅니다.

## 파일

| 파일 | 담는 것 |
| --- | --- |
| `primitive.tokens.json` | 모드와 무관한 값. 원시 팔레트 `color.sage.*`·`color.coral.*`·`color.neutral.*`, `color.white`, 오행 견본 `color.ohaeng.<오행>.swatch`, 간격 `space.*`, 반경 `radius.*`, 움직임 시간 `motion.duration.*`·곡선 `motion.easing.*`, 그림자 `shadow.*` |
| `color.light.tokens.json` | 의미 역할 `color.*`(라이트: 바탕·글자·버튼·배지·달력·토스트·비활성·도장·태그·상태 꼬리표·덮개·탭 바·skeleton 등), 오행 바탕·글자 `color.ohaeng.<오행>.bg/.fg`, 그라데이션 `gradient.today` |
| `color.dark.tokens.json` | 위와 같은 이름, 다크 값 |
| `typography.tokens.json` | 글꼴 묶음 `font.family.*`, 글자 스타일 `type.*` (한국어·영어) |
| `typography.ja.tokens.json` | 위와 같은 이름, 일본어 값 |

## 조합

테마 하나 = `primitive` + 색 모드 파일 하나 + 글자 언어 파일 하나.

* 영어는 한국어 파일(`typography.tokens.json`)을 씁니다.
* 짝 파일(라이트·다크, 한국어·일본어)은 토큰 이름 목록이 같습니다. 서로 다른 파일이 같은 이름을 정의하지 않습니다.
* 화면과 컴포넌트는 원시 팔레트가 아니라 의미 역할(`color.bg.base` 등)을 씁니다. 다크 모드는 역할 값만 바뀝니다.
* 오행 색은 데이터(행운 색 견본, 오행 분포, 원국표)에만 쓰고, 브랜드 색은 UI에만 씁니다.

## 형식

* **색:** `{"colorSpace": "srgb", "components": [r, g, b], "hex": "#rrggbb"}`
  * 기준값은 `hex`입니다. `components`는 hex 채널을 255로 나눠 소수 넷째 자리에서 반올림한 값입니다.
  * 투명도가 있으면 `alpha`(0~1)가 붙습니다. 알파는 hex에 넣지 않습니다. 해당 토큰(라이트 / 다크):
    * `color.chip.bg` 0.70 / 0.08, `color.swatch.border` 0.18 / 0.28
    * `color.scrim` 0.32 / 0.50, `color.bar.bg` 0.62 / 0.62, `color.seal.soft` 0.22 / 0.28, `color.skeleton.bone` 0.07 / 0.08
* **참조:** `"{color.sage.700}"`처럼 다른 토큰의 `$value` 전체를 가리킵니다. 참조는 같은 테마 조합 안에서 모두 풀립니다.
  * 의미 역할은 원시 팔레트를 참조합니다.
  * 다음 두 경우만 값을 직접 적습니다.
    * 원시 팔레트에 없는 색: 그라데이션, 오행 바탕·글자
    * 알파가 있는 색(위 목록). 참조에는 알파를 덧붙일 수 없기 때문입니다.
  * 다른 역할을 그대로 가리키는 역할도 있습니다: `color.seal.fill` → `action.primary`, `color.status.*` → `term.*`, `color.calendar.weekday.sun`·`.sat` → `ohaeng.fire.fg`·`ohaeng.earth.fg`, `color.timeline.line` → `line`.
* **치수:** `{"value": 16, "unit": "px"}`. 단위는 px만 씁니다. Flutter 논리 픽셀로 그대로 씁니다.
* **움직임 시간 (`duration`):** `{"value": 320, "unit": "ms"}`.
* **움직임 곡선 (`cubicBezier`):** `[x1, y1, x2, y2]`. Flutter `Cubic(x1, y1, x2, y2)`에 그대로 넣습니다.
* **그림자 (`shadow`):** `color`(알파 포함)·`offsetX`·`offsetY`·`blur`·`spread`.
* **글자:** `typography` 복합 토큰의 `fontFamily`(참조)·`fontSize`·`fontWeight`·`letterSpacing`·`lineHeight`. `lineHeight`는 글자 크기에 곱하는 배수입니다.
* **확장 (`$extensions`의 `io.github.june20516.myungli-diary` 키, DTCG 권장 역도메인 표기):**
  * `gradient.today`의 `angle`: 160(도). DTCG 규격에 각도가 없어 확장으로 적습니다.
  * `type.numeric.*`의 `fontFeatures`: `["tnum"]`(고정폭 숫자).
* **설명:** 토큰마다 쓰임새가 `$description`에 있습니다.

## 쓰는 규칙 (app)

* **Dart 코드 생성과 Flutter 테마 구성은 app이 합니다.** design은 이 파일까지 제공합니다.
* **시스템 글자 크기:** 기기의 글자 크기 설정을 따릅니다. 원국표처럼 칸이 고정된 곳만 상한(1.3배)을 둡니다. 상한을 두는 컴포넌트는 [컴포넌트 명세](../components/README.md)의 `a11y.textScaleMax`에 있습니다.
* **그라데이션:** `gradient.today`는 데일리 카드·온보딩·공유 이미지에만 씁니다. 공유 이미지는 라이트로 고정합니다. 단색으로 바뀌어도 깨지지 않게 씁니다.
* **캘린더 길흉 (엔진 `LuckLevel`):** 날짜 칸을 채웁니다. 점은 쓰지 않습니다.
  * `GOOD`은 `color.calendar.good.bg`, `CAUTION`은 `color.calendar.caution.bg`입니다. `NEUTRAL`은 토큰이 없고 칸을 채우지 않습니다.
  * 채운 칸은 바탕과 대비가 낮아 색만으로는 전달되지 않습니다. 스크린리더 라벨에 길흉 낱말을 넣습니다(컴포넌트 명세 `calendar.json`의 day-cell).
* **날의 성격 배지 (엔진 `DayKind`):** 아래 토큰을 씁니다. `badge.ordinary`는 바탕 없이 테두리만 씁니다.

  | 엔진 값 | 토큰 |
  | --- | --- |
  | `YONGSIN_DAY` | `color.badge.good.*` |
  | `GWIIN_DAY` | `color.badge.gwiin.*` |
  | `GISIN_DAY` | `color.badge.gisin.*` |
  | `ORDINARY_DAY` | `color.badge.ordinary.*` |

* **오행 견본:** `color.ohaeng.*.swatch`에는 항상 `color.swatch.border` 테두리를 둡니다.

## 버전

| 바뀌는 것 | 올리는 버전 |
| --- | --- |
| 토큰 이름이 바뀌거나 빠짐 | 주 버전 |
| 토큰 추가 | 부 버전 |
| 값만 바뀜 | 수 버전 |

| 버전 | 날짜 | 내용 |
| --- | --- | --- |
| 1.0.0 | 2026-10-11 | 마일스톤 V1 freeze |
| 1.1.0 | 2026-10-11 | 추가: `motion.duration.*`·`motion.easing.*`·`shadow.raised`, V2 역할 색(토스트·비활성·덮개·탭 바·도장·상태 꼬리표·태그·요일·skeleton·흐름 줄), 글자 스타일 `type.body.ui`·`type.caption.lg` (마일스톤 V2) |

주 버전 변경은 `docs/workflow.md` §5.1을 따릅니다. 순서는 `kind:notice` Issue로 공지 → 버전 올림 → app 대응 보고 뒤 이전 이름 제거입니다.

## 다시 만들기 (design)

```
python3 docs/identity/design/tools/tokens.py     # 저장소 루트에서
```

* 색은 `tools/palette.py`, 타이포·간격·반경은 `tools/tokens.py`의 상수를 고칩니다.
* `tools/test_tokens.py`가 확인하는 것:
  * 커밋된 파일이 생성기 출력과 바이트 단위로 같은지, 두 번 만들어도 같은지
  * 테마 조합 4가지(라이트·다크 × ko·ja) 각각이 DTCG 형식에 맞는지(`tools/dtcg.py`)
    * 타입, 값 형식, 깨진 참조, 참조 대상 타입
    * 파일 간 이름 중복, 토큰이면서 그룹인 이름
  * 짝 파일의 토큰 이름이 같은지
  * 참조를 푼 색 역할 값이 `palette.py`와 같은지
  * 알파 색, 오행, 그라데이션, 간격·반경, 글자 스타일 값이 spec과 같은지
* 글자 조합 대비는 `python3 docs/identity/design/tools/palette.py --check`로 확인합니다.
