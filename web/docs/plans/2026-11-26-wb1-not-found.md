# WB1 404 페이지와 원고 drift 따라잡기 Plan

> **agentic worker에게:** 이 plan을 task 단위로 구현하려면 suberpower:executing-plans를 사용하세요. Step은 checkbox(`- [x]`) 문법을 사용합니다.

**Goal:** writing PR #1363이 바꾼 웹 원고(drift #1366: 404 슬롯 넷, en 문장 수정)를 따라잡고, IA `web-not-found`(#1358)대로 브라우저 언어에 맞는 404를 냅니다.

**Spec:** IA `docs/ia/site.json` `web-not-found`(제목, 안내 한 문장, 랜딩 링크 하나, Accept-Language, 맞는 언어 없으면 en), 원고 `docs/identity/writing/generated/web/<언어>.json`

## 확인한 사실
| 사실 | 출처 |
| --- | --- |
| Hosting i18n 재작성은 `hosting.i18n.root` 아래 `<언어>_ALL/404.html`을 Accept-Language 품질 값 순서로 찾고, 없으면 `public/404.html`을 냄. 폴더 이름은 언어 소문자, `ALL` 대문자 | https://firebase.google.com/docs/hosting/i18n-rewrites |
| Hosting 에뮬레이터도 i18n 재작성을 따름: `ko-KR` → ko, `ja` → ja, `en-US,…,ko` → en, `fr-FR` → en(루트) | 로컬 에뮬레이터 curl |
| 에뮬레이터는 `de,ko;q=0.5`에 en(루트)을 냄. 문서대로라면 ko. 실제 Hosting은 staging에서 확인 | 로컬 에뮬레이터 curl |
| Astro는 루트 `/404`만 `404.html`로, 하위 폴더 404 페이지는 `404/index.html`로 냄 | `astro/dist/core/output-filename.js` |

## 정한 것
| 항목 | 정한 값 | 이유 |
| --- | --- | --- |
| 원고 검사 | IA 화면 `web-landing`, `web-not-found` 슬롯을 합쳐 원고 한 파일과 대조 | 원고 파일 하나에 두 화면이 들어 있음 |
| 언어별 404 | `i18n/<언어>_ALL/404.html`(en 포함) + 루트 `404.html`(en). 빌드 뒤 훅이 `404/index.html`을 `404.html`로 옮김 | JS 없이 Accept-Language로 고름. en 폴더가 있어야 `en, ko` 사용자가 en을 받음 |
| 화면 | 랜딩 바탕 띠와 같은 오늘 그라데이션, 가운데 제목(문장 글꼴), 안내, 랜딩 링크. 아이콘과 아래쪽 링크 없음 | IA "제목, 안내 한 문장, 링크 하나만". V137은 404를 정하지 않음 |
| 404 설명(meta description) | 랜딩 설명 슬롯 재사용 | 404 설명 슬롯이 없고, 공유될 일이 없음 |

### Task 1: 원고 따라잡기
- [x] `copy/load.ts` `siteSlotIds`(두 화면), 테스트(16 슬롯, 404 슬롯 누락)

### Task 2: 404
- [x] `config/not-found.ts`, `build/not-found.ts`(빌드 훅), `components/NotFound.astro`, `pages/404.astro`, `pages/i18n/[folder]/404.astro`
- [x] `firebase.json` `i18n.root`, 단위 테스트(폴더 이름, 루트 대조, 옮기기)
- [x] `check/dist.ts` 필요한 파일에 404 넷
- [x] e2e: 로캘 ko, ja, en, fr마다 404 상태, 그 언어 원고, 링크 하나, 링크로 랜딩

### Task 3: 마무리
- [x] web `CLAUDE.md` 현재 상태, 다음 할 일
- [x] PR: `참고 #1366`, `참고 #1331`
