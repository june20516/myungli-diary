# WB1 랜딩 A안 구현 Plan

> **agentic worker에게:** 이 plan을 task 단위로 구현하려면 suberpower:executing-plans를 사용하세요. Step은 checkbox(`- [x]`) 문법을 사용합니다.

**Goal:** writing 웹 원고(#1349) 형식을 따라잡고(drift #1351), design 명세 V137(`docs/identity/design/web/README.md`, A안 "오늘의 바탕")대로 랜딩을 다시 짭니다. 웹 글꼴, 화면 사진, 두 스토어 공식 배지(출시 뒤 그림)를 넣습니다.

**Spec:** `docs/identity/design/web/README.md`(V137), 요청 #1331 5번, drift #1351, 원고 `docs/identity/writing/generated/web/<언어>.json`

## 정한 것

| 항목 | 정한 값 | 이유 |
| --- | --- | --- |
| 원고 형식 | `{ 슬롯: { 키: 문장 } }`. `copy.text(slot)`은 키가 하나인 슬롯, `copy.text(slot, key)`는 키를 고름 | writing 생성물 형식(#1349). 키 하나짜리 슬롯에서 키 이름을 페이지가 알 필요가 없게 함 |
| 자리 문구 | `site/src/copy/placeholder/`와 자리 문구 경로를 지움. 생성물이 없으면 빌드 실패 | 생성물이 staging에 있음. 조용히 다른 글로 빌드되는 길을 남기지 않음 |
| 매개변수 채우기(`{index}`) | 지움 | 새 원고는 사진마다 키가 따로라 매개변수가 없음 |
| 웹 글꼴 | 빌드 때 design과 같은 고정 주소, sha256의 원본을 받아(`web/.cache/fonts/`) 그 페이지 글자만 남긴 woff2로 만듦(`subset-font`). 파일 이름에 내용 해시, `/fonts/`에 둠(`firebase.json`에 immutable 캐시. Astro 라우트는 `_`로 시작하는 폴더를 만들지 않음) | Google Fonts 같은 외부 요청 없음(개인정보, 가용성). 정적 글만 있어 부분 집합이 작음 |
| 글꼴 묶음 | ko, en: Pretendard 400, 500, 600, 고운돋움 400. ja: Pretendard JP 400, 500, 600, Zen Maru Gothic 400 | 토큰 굵기(body 400, label-md 500, label-lg와 title 600)와 `:root:lang(ja)` 글꼴 |
| 이미지 | `astro:assets`(sharp)로 아이콘 1024 PNG를 56px 배율 1, 2, 3 webp로, 화면 사진은 원본 webp 그대로 해시 이름 | 명세 "배율 2 이상", 캐시 |
| 워드마크 | `<picture>`에 `prefers-color-scheme: dark` source | 명세 "다크는 -dark 파일" |
| Apple 배지 | `toolbox.marketingtools.apple.com`(developer.apple.com 마케팅 안내가 가리키는 곳) 검은 배지 SVG, ko-kr, en-us, ja-jp를 그대로 commit | 명세 "공식 파일 그대로" |
| Google 배지 | `play.google.com/intl/en_us/badges/` 언어별 PNG에서 바깥 투명 여백만 잘라 commit(그림은 그대로) | 언어마다 투명 여백이 달라(en 사방 41, ko와 ja 위아래 29) 그대로는 App Store와 같은 높이가 안 됨 |
| 404 | 지금 구성(언어 링크) 유지, 전역 글꼴과 규칙만. 안내 문구 슬롯은 지휘에 요청(#1358) | IA에 404 슬롯이 없음 |
| 언어 고르기(`/`) | 그대로(JS 없는 크롤러용 링크) | 명세 밖 |

## 확인한 값
명세 "확인한 값" 표와 같은 방법(줄 수, 사진 시작, 페이지 높이)으로 headless Chromium에서 쟀습니다. 390 × 844는 세 언어 모두 표와 같습니다. 1280 × 820은 세 언어 모두 사진 시작과 페이지 높이가 표보다 4px 작지만, 같은 브라우저에서 시안 원본 `a.html`도 같은 값(ko 사진 시작 502.9, 높이 1096)이라 측정 환경 차이입니다.

## Review Focus
1. 원고에 슬롯이나 키가 빠지거나 남거나 D93 문자가 들어오면 빌드 실패 → Task 1 테스트.
2. 세 언어, 390과 1280 폭에서 가로 넘침 없음, 사진 세 장이 그 언어 파일이고 `alt`가 장면 키 → Task 5 Playwright.
3. 출시 전에는 안내 알약 하나, 배지와 스토어 링크 없음. 출시 뒤(설정)에는 배지 둘, 접근성 이름 → Task 3 단위 테스트(설정 함수), Task 5.
4. 글꼴 파일이 페이지 글자를 모두 담음(빠진 글자 없음) → Task 2 테스트.

---

### Task 1: 원고 형식 따라잡기 (#1351)
- [x] `copy/load.ts`: 슬롯 → 키 → 문장 읽기, 검사(missing, unknown, empty, D93, 키 없음), `text(slot, key?)`, `keys(slot)`
- [x] 자리 문구 폴더와 import 지움, 테스트 고침
- [x] Commit `fix(web): writing 웹 원고 형식(슬롯 → 키 → 문장) 따라잡기 (#1351)`

### Task 2: 웹 글꼴
- [x] `og/fonts.ts`의 받기 함수를 `fonts/source.ts`로 옮기고 원본 목록에 고운돋움, Zen Maru Gothic, Pretendard Medium, SemiBold, Pretendard JP Medium, SemiBold를 더함(sha256 고정)
- [x] `fonts/subset.ts`: 언어마다 페이지 글자를 모아 부분 집합 woff2와 `@font-face` CSS를 만듦, 엔드포인트 `/fonts/[name].woff2`
- [x] 테스트: 글자 모음, 이름 해시, 부분 집합에 페이지 글자가 다 있음
- [x] Commit

### Task 3: 화면 (V137)
- [x] 배지 파일, 아이콘, 워드마크, 화면 사진을 assets로
- [x] `AppName`, `ShotFan`, `StoreSlot`, `PageFoot`, `LangSwitch` 컴포넌트, 페이지와 전역 CSS
- [x] 404와 `/`는 구성 그대로 전역 규칙과 글꼴만
- [x] Commit

### Task 4: 빌드 검사
- [x] `check/dist.ts`: 언어 페이지마다 사진 세 장, 글꼴 `@font-face`의 파일이 있음

### Task 5: Playwright
- [x] 푸터 링크와 언어 바꾸기 선택자, 가로 넘침, 사진 alt, 출시 전 알약

### Task 6: 마무리
- [x] `web/CLAUDE.md` 계약 표(design 웹 랜딩 명세), 현재 상태, 다음 할 일
- [x] 404 슬롯 요청 Issue(`to:root`, #1358)
- [x] PR: `참고 #1351`, `참고 #1331`
