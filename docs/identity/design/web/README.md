# 웹 랜딩 명세 (WB1, 결정 V137)

`myungli-diary.app` 랜딩(IA `docs/ia/site.json` 화면 `web-landing`)을 web이 구현하는 기준입니다. 사용자가 고른 시안 A안 "오늘의 바탕"(#1330)을 옮긴 것입니다.

* 시안 원본: [`artifacts/2026-11-26-web-landing/a.html`](../artifacts/2026-11-26-web-landing/a.html)과 [`landing.css`](../artifacts/2026-11-26-web-landing/landing.css). 시안 기록 `design-web-landing-questions`.
* 시안과 이 문서가 다르면 이 문서가 기준입니다. 시안의 해시 상태 전환, 다크 규칙 옮기기, 슬롯 id 표시는 비교용이라 옮기지 않습니다.

## 재료
| 재료 | 위치 | 비고 |
| --- | --- | --- |
| 토큰 | `web/packages/tokens/tokens.css` 변수 | 아래 표의 변수 이름은 그 파일 이름 그대로 |
| 글 | writing 생성물 `docs/identity/writing/generated/web/<언어>.json` | 슬롯 id는 IA `site.json` |
| 앱 이름(en, ja) | writing 생성물 `docs/identity/writing/generated/store/listing.json`의 `store.app-name` | `site.json`에 이름 슬롯이 없어 스토어 원고를 씀 |
| 화면 사진 | [`landing/shots/<언어>-<장면>.webp`](landing/shots/) | 아래 "화면 사진" |
| 아이콘 | [`logo/icon-large.png`](../logo/icon-large.png) | 1024 원본. 표시 56px, 배율 2 이상으로 줄여 씀 |
| 워드마크 | [`logo/wordmark.svg`](../logo/wordmark.svg), [`logo/wordmark-dark.svg`](../logo/wordmark-dark.svg) | ko만. 글꼴로 다시 쓰지 않음 |
| 스토어 배지 | Apple, Google 공식 배지 파일(언어별) | 출시 뒤에만. 아래 "스토어 자리" |

## 구성
한 페이지, 위에서 아래로 두 덩어리입니다.

1. **바탕 띠**(`--gradient-today`, 화면 폭 끝까지): 이름, 한 줄 소개(`h1`), 소개 문장, 스토어 자리를 가운데 정렬로 쌓고, 그 아래 화면 사진 세 장을 겹쳐 세웁니다. 띠는 `overflow: hidden`이라 사진 아래쪽이 띠 끝에서 잘립니다(스토어 스크린샷 틀 V133과 같은 넘침).
2. **아래쪽**(`--color-bg-base`): 법적 문서와 지원 링크, 언어 바꾸기.

페이지 바탕은 `--color-bg-base`, 기본 글자는 `--type-body-ui-font-family` 16px, 줄 높이 1.55입니다.

## 폭별 값
폭 경계는 600px 하나입니다. 600 이하를 "좁음"으로 씁니다. `clamp()`는 그대로 옮깁니다.

| 자리 | 넓음 | 좁음 (≤600) |
| --- | --- | --- |
| 가장자리 여백(좌우) | `max(var(--space-20), 5vw)` | 같음 |
| 바탕 띠 위 여백 | `clamp(var(--space-32), 7vw, 88px)`, 아래 0 | 같음 |
| 글 묶음 | 최대 폭 720, 가운데, 줄 사이 `--space-20`, 가운데 맞춤 | 같음 |
| 아이콘 | 56×56, 모서리 13px | 같음 |
| 아이콘과 이름 사이 | `--space-12` | 같음 |
| 워드마크(ko) | 높이 30 | 같음 |
| 앱 이름 글자(en, ja) | `--type-title-font-family`, 26px, `--type-title-font-weight`, `--type-title-letter-spacing`, 줄 높이 1 | 같음 |
| 한 줄 소개 | `--font-family-sentence` 400, `clamp(28px, 4.2vw, 44px)`, 줄 높이 1.35, 자간 −0.01em, `text-wrap: balance`, 위 바깥 여백 `--space-8` | 26px |
| 소개 문장 | 17px, 줄 높이 1.65, `--color-text-secondary`, 최대 폭 34em, `text-wrap: pretty` | 16px |
| 스토어 자리 | 위 바깥 여백 `--space-8`, 가운데, 사이 `--space-12` | 같음 |
| 화면 묶음 | 폭 `min(100%, 860px)`, 높이 `clamp(360px, 46vw, 500px)`, 위 바깥 여백 `clamp(var(--space-32), 5vw, 64px)` | 높이 330 |
| 가운데 사진(오늘) | 폭 `clamp(210px, 28vw, 300px)`, 위 0, 가운데, 앞 | 폭 200 |
| 양옆 사진(왼쪽 근거, 오른쪽 달력) | 폭 `clamp(180px, 24vw, 260px)`, 위 `clamp(28px, 4vw, 48px)`, 가운데에서 좌우로 `clamp(130px, 22vw, 250px)` 옮김, 뒤 | 폭 168, 위 28, 좌우 118 |
| 아래쪽 | 위 선 `--border-width-hairline` `--color-line`, 여백 위 `--space-16` 아래 `--space-32`, 안쪽 최대 폭 1120 가운데. 링크 묶음과 언어 묶음을 양 끝에, 줄바꿈 허용, 사이 `--space-16` `--space-32` | 세로로 쌓고 왼쪽 맞춤 |

* 좁음에서 양옆 사진은 화면 밖으로 일부 나갑니다(의도). 가로 스크롤은 생기지 않아야 합니다(`body { overflow-x: clip }`).
* 글자 색은 따로 적지 않은 곳이 `--color-text-primary`입니다.

## 화면 사진
* 장면은 왼쪽부터 `evidence`(근거 시트), `today`(오늘, 가운데 앞), `calendar`(달력). 언어마다 그 언어 사진을 씁니다.
* 파일은 폭 600, 높이 1282 webp입니다. 스토어 스크린샷(App Store 틀, `store/store.json` `frames.appStore`)의 화면 판을 그림 아래 끝까지 잘랐고, 위 두 모서리는 판 모서리(72/1080)대로 투명합니다. 사진 원본은 빌드 11 금빛 판 스토어 이미지입니다.
* 표시: 모서리 `--radius-xl`, 그림자 `--shadow-raised`, 바탕 `--color-bg-sheet`, `aspect-ratio: 600 / 1282`, `alt`는 슬롯 `web-landing.shots.alt`의 장면 키.
* 다크에서도 사진은 라이트 그대로입니다.
* 스토어 이미지가 바뀌면 design이 다시 만듭니다: `uv run --with pillow==11.0.0 python docs/identity/design/tools/landing_shots.py <app 스토어 이미지 폴더>`(검사 `test_landing_shots.py`).

## 스토어 자리
출시 전과 뒤 중 하나만 그립니다. 한 페이지에 한 번만 둡니다.

| 상태 | 그림 |
| --- | --- |
| 출시 전 | 안내 알약 하나(`web-landing.store.soon`). 링크 없음. 배지는 쓰지 않음 |
| 출시 뒤 | App Store 배지, Google Play 배지 순서로 나란히. 각 스토어 페이지 링크, 접근성 이름은 `web-landing.store.apple`, `web-landing.store.google` |

* 안내 알약: 최소 높이 44, 안쪽 여백 위아래 `--space-8` 좌우 `--space-20`, 모서리 `--radius-full`, 바탕 `--color-chip-bg`, 테두리 `--border-width-hairline` `--color-badge-ordinary-border`, 글 `--type-label-lg-font-size`, `--type-label-lg-font-weight`, `--type-label-lg-letter-spacing`, `text-wrap: balance`(en, ja는 두 줄이 됨). 글 앞에 지름 8 점 `--color-badge-good-bg`, 점과 글 사이 `--space-8`.
* 배지(2026-11-26 두 회사 공식 규정 확인): 공식 파일 그대로(색, 모양, 글을 고치거나 기울이거나 움직이지 않음), 페이지 언어의 배지, Apple은 검은 배지. 높이 48(Apple 최소 40, Google 최소 28), Google Play는 App Store와 같은 높이. 둘레 여백은 배지 높이의 1/4 이상이라 둘 사이 `--space-16`.
* 출시 뒤 Apple 상표 고지 줄(예: "App Store는 Apple Inc.의 상표")이 필요합니다. 슬롯은 지휘가 출시 무렵 `site.json`에 더하고, 자리는 아래쪽 링크 묶음 아래 `--type-caption-md` `--color-text-secondary`로 둡니다.

## 아래쪽
* 글은 `--type-label-md-font-size`, `--type-label-md-font-weight`, `--color-text-secondary`입니다.
* 링크(약관, 처리방침, 지원)는 최소 높이 44, 좌우 안쪽 여백 `--space-8`, 밑줄 없음. 마우스를 올리면 `--color-text-primary`와 밑줄(간격 3px). 주소는 지휘 대장의 server 주소(`/legal/terms`, `/legal/privacy`, `/support`)에 페이지 언어를 붙입니다.
* 언어 바꾸기: `nav`(접근성 이름 `web-landing.lang.label`) 안에 "한국어", "English", "日本語"(각 언어 이름은 그 언어로, 원고 아님) 링크가 `/ko/`, `/en/`, `/ja/`로 갑니다. 지금 언어는 `aria-current`, `--color-action-primary`, `--type-label-lg-font-weight`.

## 글자와 줄바꿈
* ko: `word-break: keep-all`, `overflow-wrap: break-word`(어절 중간에서 줄을 바꾸지 않음).
* ja: `word-break: auto-phrase`(지원하는 브라우저에서 구 단위 줄바꿈, 나머지는 기본). 글꼴은 토큰의 `:root:lang(ja)` 값(`Zen Maru Gothic`, `Pretendard JP`)이 따라옵니다. `html lang`을 페이지 언어로 둡니다.
* `font-synthesis: none`(없는 굵기를 가짜로 만들지 않음).
* 사용자에게 보이는 글에 긴 대시, 범위 대시, 가운뎃점을 쓰지 않습니다(D93).

## 테마, 포커스, 움직임
* 다크는 `prefers-color-scheme`로 토큰이 바뀌고, 워드마크는 `-dark` 파일로 바꿉니다. 바탕 띠는 다크 `--gradient-today`가 됩니다.
* 포커스: `:focus-visible`에 2px `--color-action-primary` 테두리, 바깥 간격 3px, 모서리 `--radius-xs`.
* 움직임은 없습니다. 사진 겹침도 정지입니다.

## 확인한 값 (시안, 2026-11-26)
writing 원고(#1349)로 Chrome에서 잰 값입니다. 세 언어 모두 가로 넘침이 없고, 첫 화면 안에서 사진이 시작됩니다.

| 폭 × 높이 | 언어 | 한 줄 소개 줄 수 | 소개 문장 줄 수 | 사진 시작 | 페이지 높이 |
| --- | --- | --- | --- | --- | --- |
| 390 × 844 | ko | 2 | 3 | 389 | 872 |
| 390 × 844 | en | 1 | 4 | 398 | 881 |
| 390 × 844 | ja | 2 | 4 | 433 | 960 |
| 1280 × 820 | ko | 2 | 2 | 507 | 1100 |
| 1280 × 820 | en | 1 | 3 | 476 | 1069 |
| 1280 × 820 | ja | 2 | 3 | 535 | 1128 |

## 이 문서 밖
* 공유 미리보기(OG) 이미지는 이 결정에 들지 않았습니다. 필요하면 지휘가 design에 따로 요청합니다.
* 검색 결과와 탭 제목은 슬롯 `web-landing.meta.title`, `web-landing.meta.description`을 그대로 씁니다.
