# 명리일기 시각 정체성 기준 (V0·V1)

## 이 문서의 위상
* 명리일기의 색, 그라데이션, 타이포, 간격, 로고 가운데 **지금 유효한 기준**입니다. 시각에 관해서는 이 문서가 `docs/background/06-design-system.md`를 대체합니다.
* 고치는 쪽은 design입니다. 바꿀 일이 있으면 GitHub Issue(`to:design`)로 보냅니다.
* 왜 이렇게 정했는지는 [V0 spec](specs/2026-10-10-visual-identity-design.md)과 [V1 spec](specs/2026-10-11-design-tokens-design.md)에 있습니다. 결정은 [`decisions.md`](decisions.md)의 결정 V1~V12입니다.
* 눈으로 보려면 [견본 페이지](specimen/index.html)를 엽니다(라이트·다크).
* app이 읽는 데이터는 **디자인 토큰** [`tokens/`](tokens/README.md)입니다(계약 1.0.0). 이 문서와 토큰 값이 다르면 토큰이 맞고, 이 문서를 고칩니다.
* 색 값의 출처는 [`tools/palette.py`](tools/palette.py), 토큰 파일은 [`tools/tokens.py`](tools/tokens.py)가 만듭니다.

## 원칙
* 글자가 들어가는 모든 색 조합은 대비 **4.5:1 이상**입니다. `python3 tools/palette.py --check`로 확인합니다.
* **브랜드 색은 UI에, 오행 색은 데이터에만** 씁니다. 서로의 자리에 쓰지 않습니다.
* 화면과 컴포넌트는 원시 팔레트가 아니라 **의미 역할**을 씁니다. 다크 모드는 역할 값만 바뀝니다.
* 다크 모드는 MVP에 포함됩니다.
* **색의 의미 (결정 V8):** 새 역할을 만들 때 이 표로 색 계열을 정합니다. 좋은 쪽 신호에 sage를, 조작에 coral을 쓰지 않습니다. 좋지 않은 날은 경고색 없이 neutral로 담담하게 보여줍니다.

  | 색 | 뜻 | 쓰는 곳 |
  | --- | --- | --- |
  | sage | 나와 내 기록, 조작 | 주 버튼, 선택, 용어 토큰, 일기 쓴 날 표시, 로고의 공책 |
  | coral | 오늘의 좋은 기운 | 좋은 날·귀인의 날 배지, 캘린더 좋음 칸, 로고의 낙관(日) |
  | neutral | 그 밖의 날과 정보 | 기신의 날·평범한 날 배지, 캘린더 주의 칸, 바탕·글자·선 |

## 색

### 원시 팔레트
OKLCH 고정 명도 단계로 만듭니다(sage hue 150, coral hue 28, neutral hue 110).

| 단계 | sage | coral | neutral |
| --- | --- | --- | --- |
| 50 | `#f2f9f3` | `#fef4f2` | `#f7f7f6` |
| 100 | `#e8f2e9` | `#ffe9e5` | `#eeeeed` |
| 200 | `#d4e3d6` | `#f6d5d1` | `#dededc` |
| 300 | `#b8cebc` | `#e8bbb4` | `#c7c7c5` |
| 400 | `#96b49b` | `#d79990` | `#ababa7` |
| 500 | `#749a7b` | `#c4776d` | `#8f908b` |
| 600 | `#597f61` | `#a75c53` | `#747570` |
| 700 | `#47634c` | `#814942` | `#5b5b57` |
| 800 | `#354838` | `#5d3631` | `#424340` |
| 900 | `#242f26` | `#3b2522` | `#2b2b2a` |
| 950 | - | - | `#1b1b1a` |

### 의미 역할

| 역할 | 라이트 | 다크 |
| --- | --- | --- |
| `bg.base` 기본 바탕 | neutral-50 | neutral-950 |
| `bg.sheet` 시트·패널 | `#ffffff` | neutral-900 |
| `text.primary` 본문 글자 | neutral-900 | neutral-100 |
| `text.secondary` 보조 글자 | neutral-700 | neutral-400 |
| `line` 선 | neutral-200 | neutral-800 |
| `action.primary` / `action.on-primary` 주 버튼 바탕 / 글자 | sage-700 / `#ffffff` | sage-300 / neutral-950 |
| `term.bg` / `term.fg` 용어 토큰 | sage-100 / sage-700 | sage-800 / sage-200 |
| `badge.good.bg` / `badge.good.fg` 좋은 날 배지 | coral-600 / `#ffffff` | coral-300 / neutral-900 |
| `badge.gwiin.bg` / `badge.gwiin.fg` 귀인의 날 배지 | coral-100 / coral-700 | coral-800 / coral-200 |
| `badge.gisin.bg` / `badge.gisin.fg` 기신의 날 배지 | neutral-100 / neutral-700 | neutral-800 / neutral-200 |
| `badge.ordinary.border` / `badge.ordinary.fg` 평범한 날 배지 (바탕 없음) | neutral-300 / neutral-700 | neutral-700 / neutral-400 |
| `calendar.good.bg` 캘린더 좋음 칸 | coral-100 | coral-900 |
| `calendar.caution.bg` 캘린더 주의 칸 | neutral-100 | neutral-900 |
| `chip.bg` 칩 바탕 | `#ffffff` 알파 0.70 | `#ffffff` 알파 0.08 |
| `swatch.border` 오행 견본 테두리 | neutral-900 알파 0.18 | neutral-100 알파 0.28 |

* 용어 토큰은 굵게 하지 않고 색과 바탕으로만 표시합니다.
* 날의 성격 배지(엔진 `DayKind`)의 강도는 좋은 날 `YONGSIN_DAY`(채움) > 귀인의 날 `GWIIN_DAY`(옅은 coral) > 기신의 날 `GISIN_DAY`(옅은 회색) > 평범한 날 `ORDINARY_DAY`(테두리만) 순입니다.

### 캘린더 길흉
* 엔진 `LuckLevel`을 **날짜 칸을 옅게 채워** 보여줍니다. `GOOD`은 `calendar.good.bg`, `CAUTION`은 `calendar.caution.bg`이고, `NEUTRAL`은 채우지 않습니다.
* 점은 쓰지 않습니다. 점은 일기를 쓴 날이나 일정 같은 이벤트 표시로 남겨 둡니다(V2).
* 채운 칸은 바탕과 대비가 1.1~1.2:1이라 색만으로는 뜻이 전해지지 않습니다. 날짜를 누르면 그날 정보에 글로 나오고, 스크린리더는 "좋은 날", "주의할 날"로 읽게 합니다(V2 컴포넌트 명세).

### 오행 팔레트 (데이터 전용)

| 오행 | 견본 | 라이트 바탕 / 글자 | 다크 바탕 / 글자 |
| --- | --- | --- | --- |
| 목 | `#418e47` | `#dff1df` / `#2f5831` | `#213321` / `#c4e1c4` |
| 화 | `#d24d45` | `#ffe4e0` / `#733a35` | `#402623` / `#f7ccc6` |
| 토 | `#dea645` | `#f7e9d5` / `#65470f` | `#392b16` / `#ead4b3` |
| 금 | `#b4bfca` | `#e8ebef` / `#454e58` | `#2a2e33` / `#d3d8de` |
| 수 | `#153e78` | `#e0ecfe` / `#304d78` | `#212e42` / `#c4d9f9` |

* **견본**은 행운 색 견본, 오행 분포처럼 색 자체를 보여주는 자리에 씁니다. 실제 옷 색을 가리키므로 모드와 관계없이 같은 값입니다.
* 견본에는 항상 얇은 테두리 `swatch.border`를 둡니다(라이트 neutral-900 알파 0.18, 다크 neutral-100 알파 0.28).
* **바탕 / 글자**는 원국표 칸처럼 글자가 얹히는 자리에 씁니다.

## 그라데이션 `gradient.today`

| 모드 | 시작 | 끝 | 각도 |
| --- | --- | --- | --- |
| 라이트 | `#eef4ef` | `#fbefee` | 160° |
| 다크 | `#162017` | `#271818` | 160° |

* 데일리 카드, 온보딩, 공유 이미지에만 씁니다. 나머지 화면은 `bg.base`입니다.
* 공유 이미지는 라이트로 고정합니다.
* 위에는 `text.primary`, `text.secondary`만 올립니다.
* 컴포넌트는 이 토큰이 두 색이라고 가정하지 않습니다. 단색으로 바뀌어도 깨지지 않아야 합니다.

## 타이포그래피

**글꼴 묶음** (대체 순서까지 적습니다. 영어는 한국어 묶음을 씁니다)

| 토큰 | 한국어·영어 | 일본어 |
| --- | --- | --- |
| `font.family.sentence` 문장 | Gowun Dodum, Pretendard, sans-serif | Zen Maru Gothic, Pretendard JP, sans-serif |
| `font.family.ui` UI·데이터 | Pretendard, sans-serif | Pretendard JP, sans-serif |
| `font.family.hanja` 원국표 한자 | Pretendard JP, sans-serif | Pretendard JP, sans-serif |

**글자 스타일**

| 토큰 | 글꼴 | 크기 | 굵기 | 줄 간격 (ko·en / ja) | 자간 (ko·en / ja) |
| --- | --- | --- | --- | --- | --- |
| `type.sentence.card` 카드 문장 | sentence | 17 | 400 | 1.65 / 1.75 | 0 / 0 |
| `type.sentence.body` 일반 본문 (일기, 풀이) | sentence | 15 | 400 | 1.6 / 1.7 | 0 / 0 |
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

* 크기와 자간 단위는 px입니다.
* 한국어 UI 자간은 글자 크기의 -2%입니다. 문장 글꼴, 일본어, 숫자, 한자는 0입니다.
* `numeric.*`은 고정폭 숫자(`tnum`)를 켭니다.
* 일본어는 한자·가나가 섞여 빽빽하므로 문장 줄 간격을 한국어보다 넓힙니다(카드 1.75, 본문 1.7). 예문으로 정한 값이라 W1 원어민 검수 문장이 나오면 다시 확인합니다.
* 문장 글꼴은 400만 씁니다. 가짜 볼드를 만들지 않습니다.
* 원국표 한자는 언어와 관계없이 Pretendard JP입니다.
* 네 글꼴 모두 SIL OFL 1.1입니다.
* 앱은 기기의 글자 크기 설정을 따릅니다. 원국표처럼 칸이 고정된 곳만 상한을 둡니다(상한 값은 V2).

## 간격과 반경

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

* 어느 컴포넌트가 어느 값을 쓰는지는 V2 컴포넌트 명세에서 정합니다. 그림자와 모션 토큰은 두지 않습니다.

## 로고

| 파일 | 쓰임 |
| --- | --- |
| [`logo/icon-large.svg`](logo/icon-large.svg) | 앱 아이콘, 60px 이상 (스토어, 홈 화면) |
| [`logo/icon-small.svg`](logo/icon-small.svg) | 앱 아이콘, 48px 이하 (설정, 알림, 스포트라이트) |
| [`logo/icon-android-background.svg`](logo/icon-android-background.svg), [`logo/icon-android-foreground.svg`](logo/icon-android-foreground.svg) | Android 적응형 아이콘 레이어 (108 단위, 전경은 가운데 66 안전 영역) |
| [`logo/wordmark.svg`](logo/wordmark.svg), [`logo/wordmark-dark.svg`](logo/wordmark-dark.svg) | 워드마크 (고운돋움 아웃라인) |
| [`logo/lockup.svg`](logo/lockup.svg), [`logo/lockup-dark.svg`](logo/lockup-dark.svg) | 아이콘 + 워드마크 가로 조합 |

* 앱 아이콘 원본은 모서리 없는 풀블리드 정사각입니다. 모서리는 플랫폼이 깎습니다.
* 크기별 PNG 내보내기는 app이 앱 빌드 설정에서 합니다.
* 워드마크는 글꼴로 다시 쓰지 않고 SVG 파일을 그대로 씁니다. 다크 바탕에는 `-dark` 파일을 씁니다.
* 워드마크·가로 조합을 다시 만들 때: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py --font <GowunDodum-Regular.ttf> --out-dir docs/identity/design/logo`
