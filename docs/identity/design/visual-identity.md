# 명리일기 시각 정체성 기준 (V0)

## 이 문서의 위상
* 명리일기의 색, 그라데이션, 타이포, 로고 가운데 **지금 유효한 기준**입니다. 시각에 관해서는 이 문서가 `docs/background/06-design-system.md`를 대체합니다.
* 고치는 쪽은 design입니다. 바꿀 일이 있으면 요청함(`docs/coordination/`)으로 보냅니다.
* 왜 이렇게 정했는지는 [V0 spec](specs/2026-10-10-visual-identity-design.md)에, 결정은 [`decisions.md`](decisions.md)의 결정 V1~V7에 있습니다.
* 눈으로 보려면 [견본 페이지](specimen/index.html)를 엽니다(라이트·다크).
* 색 값의 출처는 [`tools/palette.py`](tools/palette.py)입니다. 아래 표와 다르면 `palette.py`가 맞고, 이 문서를 고칩니다.

## 원칙
* 글자가 들어가는 모든 색 조합은 대비 **4.5:1 이상**입니다. `python3 tools/palette.py --check`로 확인합니다.
* **브랜드 색은 UI에, 오행 색은 데이터에만** 씁니다. 서로의 자리에 쓰지 않습니다.
* 화면과 컴포넌트는 원시 팔레트가 아니라 **의미 역할**을 씁니다. 다크 모드는 역할 값만 바뀝니다.
* 다크 모드는 MVP에 포함됩니다.

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
| `chip` 칩 바탕 | `#ffffff` 70% | `#ffffff` 8% |

* 용어 토큰은 굵게 하지 않고 색과 바탕으로만 표시합니다.
* 좋은 날 외 날의 성격 배지 3종과 캘린더 길흉 점의 색은 V1에서 정합니다.

### 오행 팔레트 (데이터 전용)

| 오행 | 견본 | 라이트 바탕 / 글자 | 다크 바탕 / 글자 |
| --- | --- | --- | --- |
| 목 | `#418e47` | `#dff1df` / `#2f5831` | `#213321` / `#c4e1c4` |
| 화 | `#d24d45` | `#ffe4e0` / `#733a35` | `#402623` / `#f7ccc6` |
| 토 | `#dea645` | `#f7e9d5` / `#65470f` | `#392b16` / `#ead4b3` |
| 금 | `#b4bfca` | `#e8ebef` / `#454e58` | `#2a2e33` / `#d3d8de` |
| 수 | `#153e78` | `#e0ecfe` / `#304d78` | `#212e42` / `#c4d9f9` |

* **견본**은 행운 색 견본, 오행 분포처럼 색 자체를 보여주는 자리에 씁니다. 실제 옷 색을 가리키므로 모드와 관계없이 같은 값입니다.
* 견본에는 항상 얇은 테두리를 둡니다(라이트 `text.primary` 15~20%, 다크 `text.primary` 20~35%).
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

| 역할 | 한국어·영어 | 일본어 | 크기 / 줄 간격 / 굵기 |
| --- | --- | --- | --- |
| 카드 문장 | 고운돋움 | Zen Maru Gothic | 17 / 1.65 / 400 |
| 일반 본문 (일기, 풀이) | 고운돋움 | Zen Maru Gothic | 15 / 1.6 / 400 |
| 화면 제목 | Pretendard | Pretendard JP | 20 / 1.3 / 600 |
| 소제목 | Pretendard | Pretendard JP | 16 / 1.4 / 600 |
| 라벨·칩·배지 | Pretendard | Pretendard JP | 12~14 / 1.3 / 500~600 |
| 캡션·날짜 | Pretendard | Pretendard JP | 11~12 / 1.3 / 500 |
| 원국표 한자 | Pretendard JP | Pretendard JP | 17 / 1 / 700 |

* 문장 글꼴은 400만 씁니다. 가짜 볼드를 만들지 않습니다.
* 원국표 한자는 언어와 관계없이 Pretendard JP입니다.
* 네 글꼴 모두 SIL OFL 1.1입니다.

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
