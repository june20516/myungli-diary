# WB1 web 뼈대와 최소 판 랜딩 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 새 단위 `web/`의 workspace, 토큰 패키지, 검사(`web.yml`), 배포(`deploy-web.yml`, Terraform)를 세우고, 시안 전 최소 판 랜딩(세 언어, 배지 자리, 법적 문서 링크, OG, `app-ads.txt`)을 staging에 올립니다.

**Architecture:** `web/`은 pnpm workspace입니다. `packages/tokens`가 design DTCG 토큰을 CSS 변수 파일로 만들고(생성물 commit), `site`(Astro 정적 생성)가 그 CSS와 IA `docs/ia/site.json`의 슬롯, 원고를 읽어 `/ko/`, `/en/`, `/ja/`와 언어 고르는 `/`를 만듭니다. 빌드 산출물은 빌드 뒤 검사(페이지, OG, D93, 내부 링크)와 Firebase Hosting 에뮬레이터 위 Playwright로 확인하고, 배포는 web 전용 서비스 계정(WIF)으로 Firebase Hosting 새 사이트에 올립니다.

**Tech Stack:** Node 26.13.1(LTS), pnpm 12.23.0, TypeScript 6.0.3, Astro 7, Vitest 5, ESLint 10 + typescript-eslint, Playwright 1.65, satori + @resvg/resvg-js(OG), firebase-tools 15, Terraform(google, google-beta ~> 8.9), GitHub Actions

**Spec:** 준비 메모 `docs/specs/2026-11-25-web-landing-design.md`, 지휘 plan `docs/plans/2026-11-25-web-landing.md` Task 3 Step 3, 요청 #1331

## 정한 것 (준비 메모 §8, #1331 8번)

| 항목 | 정한 값 | 이유 |
| --- | --- | --- |
| Node | `26.13.1`(2026-10-28부터 Active LTS, nodejs.org `index.json` 확인 2026-11-25) | 출시 뒤 2029년 봄까지 보안 지원. `.nvmrc`와 `engines`에 고정 |
| pnpm | `12.23.0`, `packageManager` 필드 | Node 25부터 corepack이 빠져, 로컬은 `npm i -g pnpm@12.23.0`, CI는 `pnpm/action-setup`이 이 필드를 읽음 |
| TypeScript | `6.0.3` | `@astrojs/check` peer가 `^5 \|\| ^6`(7 미지원, 2026-11-25 확인) |
| Hosting 사이트 | prod `myungli-diary-landing`, staging `myungli-diary-staging-landing` | `<Firebase 프로젝트 id>-<표면>`. WB2는 `-social`로 같은 규칙. 두 이름 모두 2026-11-25 배포된 곳 없음(`web.app` 응답 "Site Not Found"). 전역 유일이라 이미 잡혀 있으면 apply가 실패하고 `-web` 접미로 바꿈 |
| 배포 계정 | 프로젝트마다 `web-deployer`, 역할 `roles/firebasehosting.admin`, `roles/serviceusage.serviceUsageConsumer`만 | server `deployer`(Cloud Run, SQL 등)와 나눔. Hosting 권한은 프로젝트 단위라 api 사이트도 배포할 수 있다는 한계는 README에 적음 |
| GitHub environment | `web-staging`(배포 브랜치 `staging`), `web-prod`(배포 브랜치 `main`, 필수 승인자) | WIF 속성 `env_ref`가 environment 이름까지 보므로, server의 `staging`/`prod` job은 `web-deployer`를, web job은 server `deployer`를 쓸 수 없음 |
| 인프라 코드 | `web/deploy/terraform/`(사이트, 커스텀 도메인, 계정, WIF 연결), state는 기존 bucket `<프로젝트>-tfstate`의 prefix `web` | server bootstrap과 같은 방식(사용자가 로컬에서 한 번 apply). WIF pool `github`은 server bootstrap 것을 이름으로만 가리킴 |
| PR preview channel | 두지 않음 | fork PR은 OIDC를 받지 못하고, 미리보기에 배포 권한을 PR에 열어야 함. PR은 에뮬레이터 Playwright로, 눈 확인은 staging으로 |
| 원고 | writing 생성물(#1329, 제안 경로 `docs/identity/writing/generated/web/<언어>.json`)을 읽고, 오기 전에는 `web/site/src/copy/placeholder/<언어>.json` | 최소 판을 막지 않기 위해. 생성물이 오면 자리 문구 파일을 지움 |
| 설정 한 곳 | `web/site/src/config/site.ts` | 스토어 주소, 출시 상태, 법적 문서 주소, `app-ads.txt` 줄, 환경별 origin |

## Global Constraints
* 언어는 `ko`, `en`, `ja`. 지원하지 않는 언어는 `en`(server S65, app `resolveAppLanguage`와 같음).
* 사용자에게 보이는 글(HTML 본문, `title`, `alt`, `aria-label`, `meta` 설명, OG 이미지 글)은 U+2014, U+2013, U+00B7을 쓰지 않습니다(D93).
* 법적 문서와 지원은 server 주소로 링크만: `https://api.myungli-diary.app/legal/terms?lang=<언어>`, `/legal/privacy?lang=<언어>`, `/support?lang=<언어>`(Task 3에서 server 라우트로 실제 경로를 확인해 고정).
* 외부 Action은 commit SHA로 고정합니다(D136 ③). 의존성은 lockfile 고정(`pnpm install --frozen-lockfile`).
* 공개 저장소(D74): 금액, 비공개 저장소 경로를 적지 않습니다. 프로젝트 id와 AdMob 게시자 id는 이미 공개(`deploy-server.yml`, `app/ios/Runner/Info.plist`)라 적어도 됩니다.
* SSR 없음(D144 ⑤). Astro `output: "static"`.
* 고칠 수 있는 곳은 `web/`, `.github/workflows/web.yml`, `.github/workflows/deploy-web.yml`, Issues뿐입니다.

## Review Focus
1. 브라우저 언어가 `fr`, `zh-TW`, 빈 목록: `/`에서 `/en/`으로, `ja-JP`는 `/ja/`, `ko-KR`은 `/ko/` → Task 4 단위 테스트, Task 7 Playwright.
2. JS를 실행하지 않는 크롤러가 `/`를 읽음: 세 언어 링크, `hreflang`(ko, en, ja, x-default), 기본 OG가 있어야 함 → Task 7 Playwright(JS 끔).
3. 공유 미리보기: 언어 페이지마다 `og:image`가 그 언어의 절대 주소(`https://<origin>/<언어>/og.png`)이고 파일이 실제로 있음 → Task 6 빌드 검사, Task 7.
4. `/app-ads.txt`가 리다이렉트 없이 200, `content-type: text/plain`, 본문이 설정의 줄과 같음 → Task 7(에뮬레이터), 배포 뒤 Task 9 확인.
5. 원고 파일에 슬롯이 빠지거나 IA에 없는 슬롯이 있음, 또는 D93 문자가 들어옴: 빌드가 실패해야 함 → Task 3 테스트.

---

### Task 1: workspace와 도구 체인

**Files:**
- Create: `web/package.json`(private, `packageManager: "pnpm@12.23.0"`, `engines.node: "26.13.1"`, 스크립트 `check`, `lint`, `typecheck`, `test`, `build`, `e2e`), `web/pnpm-workspace.yaml`(`packages/*`, `site`), `web/.nvmrc`(`26.13.1`), `web/.npmrc`(`engine-strict=true`), `web/tsconfig.base.json`(strict, `noUncheckedIndexedAccess`), `web/eslint.config.js`, `web/vitest.workspace.ts`, `web/.gitignore`(`node_modules/`, `site/dist/`, `site/.astro/`, `test-results/`, `playwright-report/`), `web/README.md`(설치와 명령)
- Modify: `web/CLAUDE.md` "검사 방법"

- [ ] **Step 1:** `nvm install 26.13.1 && nvm use && npm i -g pnpm@12.23.0`. Expected: `node -v` → `v26.13.1`, `pnpm -v` → `12.23.0`.
- [ ] **Step 2:** 위 파일 작성, `pnpm install`로 lockfile 생성. 의존성은 정확한 버전으로(`save-exact`).
- [ ] **Step 3:** Run: `cd web && pnpm lint && pnpm typecheck && pnpm test` Expected: 셋 다 성공(테스트 0개면 `--passWithNoTests`).
- [ ] **Step 4:** `web/CLAUDE.md` "검사 방법"에 위 명령과 `pnpm build`, `pnpm e2e`를 적음.
- [ ] **Step 5: Commit** `feat(web): pnpm workspace와 도구 체인(Node 26, pnpm 12)`

### Task 2: 토큰 패키지 (DTCG → CSS 변수)

**Files:**
- Create: `web/packages/tokens/package.json`(`@myungli/tokens`, `exports: {"./tokens.css": "./tokens.css"}`), `web/packages/tokens/src/dtcg.ts`, `web/packages/tokens/src/css.ts`, `web/packages/tokens/scripts/generate.ts`, `web/packages/tokens/tokens.css`(생성물, commit), `web/packages/tokens/test/css.test.ts`

**Interfaces:**
- Produces: `loadTheme(dir: string, mode: "light" | "dark", typography: "ko" | "ja"): ResolvedToken[]`(참조를 푼 토큰 `{ path: string[]; type: string; value: unknown }`), `toCssVariables(tokens: ResolvedToken[]): Map<string, string>`, `renderCss(input: { primitive; light; dark; ko; ja }): string`
- Produces: `tokens.css` 구조: `:root { 원시, 라이트 역할, ko 글자 }`, `@media (prefers-color-scheme: dark) { :root { 다크 역할 } }`, `:root:lang(ja) { ja 글자 }`. 변수 이름은 경로를 `-`로 이은 `--color-bg-base`, `--space-16`처럼.
- Produces: `node packages/tokens/scripts/generate.ts [--check]`. `--check`는 쓰지 않고 다르면 exit 1(Node 26 타입 지우기로 바로 실행).

- [ ] **Step 1: 실패하는 테스트**
  * 색 `{hex: "#47634c"}` → `#47634c`, `alpha: 0.7`이면 `rgb(71 99 76 / 0.7)`
  * 치수 `{value: 16, unit: "px"}` → `16px`, 시간 `{value: 320, unit: "ms"}` → `320ms`, `cubicBezier [0.2,0,0,1]` → `cubic-bezier(0.2, 0, 0, 1)`
  * 참조 `"{color.sage.700}"`가 풀린 값과 같음, 없는 참조는 오류
  * `typography` 복합 토큰은 `--type-body-ui-font-size` 등 낱개 변수로(`lineHeight`는 단위 없는 배수)
  * 그림자 → `0px 2px 8px 0px rgb(...)`
  * 그라데이션 `gradient.today` → `linear-gradient(160deg, ...)`(확장 `angle` 사용)
  * 실제 `docs/identity/design/tokens/`로 만든 결과가 commit된 `tokens.css`와 바이트 단위로 같음
- [ ] **Step 2:** Run: `cd web && pnpm --filter @myungli/tokens test` Expected: FAIL(모듈 없음)
- [ ] **Step 3:** 구현. 토큰 디렉터리 기본값은 저장소 루트 기준 `docs/identity/design/tokens`. 같은 이름이 두 파일에 있으면 오류(README "짝 파일" 규칙).
- [ ] **Step 4:** `node packages/tokens/scripts/generate.ts`로 `tokens.css` 생성 → 테스트 PASS, `--check` exit 0.
- [ ] **Step 5: Commit** `feat(web): 디자인 토큰 CSS 변수 생성(토큰 1.11.0)`

### Task 3: 사이트 설정과 원고 읽기

**Files:**
- Create: `web/site/src/config/site.ts`, `web/site/src/copy/load.ts`, `web/site/src/copy/placeholder/{ko,en,ja}.json`, `web/site/src/text/d93.ts`, `web/site/test/copy.test.ts`, `web/site/test/d93.test.ts`

**Interfaces:**
- Produces: `type Lang = "ko" | "en" | "ja"`, `LANGS: readonly Lang[] = ["ko", "en", "ja"]`, `DEFAULT_LANG: Lang = "en"`
- Produces: `siteConfig: { origin: string; release: "soon" | "live"; stores: { apple: string; google: string }; legal(lang: Lang): { terms: string; privacy: string; support: string }; appAdsTxt: string }`. `origin`은 빌드 환경 변수 `WEB_ORIGIN`(기본 `http://localhost:4321`). `appAdsTxt`는 `google.com, pub-5703509220233743, DIRECT, f08c47fec0942fa0`. 스토어 주소는 출시 전이라 빈 문자열이고 `release: "live"`인데 비어 있으면 오류.
- Produces: `loadCopy(lang: Lang, options?: { iaPath?: string; sourceDir?: string }): Copy`, `Copy = { text(slotId: string, params?: Record<string, string | number>): string }`. IA `web-landing` 슬롯 목록과 원고 키가 정확히 같아야 하고(빠짐, 남음 모두 오류), 매개변수 `{index}` 치환.
- Produces: `findD93(text: string): { char: string; index: number }[]`(U+2014, U+2013, U+00B7)

- [ ] **Step 1: 실패하는 테스트**: 자리 문구 세 언어가 IA 슬롯 12개와 정확히 맞음, 슬롯 하나 뺀 fixture는 `missing: web-landing.hero.body` 오류, IA에 없는 키는 `unknown` 오류, 값에 `—`가 있으면 오류, `shots.alt` `{index}` 치환, `findD93("a·b")`가 `[{char:"·", index:1}]`, `release: "live"` + 빈 주소는 오류.
- [ ] **Step 2:** Run: `cd web && pnpm --filter site test` Expected: FAIL
- [ ] **Step 3:** 구현. 원고 원천 고르기: writing 생성물 디렉터리(`docs/identity/writing/generated/web/`)에 그 언어 파일이 있으면 그것, 없으면 자리 문구(빌드 로그에 "자리 문구 사용" 경고). 자리 문구는 D93을 지키는 짧은 문장으로 쓰고 문서 머리에 "writing #1329 원고 전 임시" 키는 넣지 않음(키 일치 검사 때문). 법적 문서 경로는 `server/` 라우트(`grep -rn "/legal/" server/internal`)로 확인해 적음.
- [ ] **Step 4:** Run 같은 명령. Expected: PASS
- [ ] **Step 5: Commit** `feat(web): 사이트 설정 한 곳과 IA 슬롯 원고 읽기, D93 검사`

### Task 4: Astro 사이트와 언어 고르기

**Files:**
- Create: `web/site/package.json`(`site`), `web/site/astro.config.mjs`(`output: "static"`, `site: WEB_ORIGIN`, `trailingSlash: "always"`, `build.format: "directory"`), `web/site/tsconfig.json`, `web/site/src/i18n/pick.ts`, `web/site/src/layouts/Base.astro`, `web/site/src/components/{LangSwitch,StoreBadges,Footer}.astro`, `web/site/src/pages/index.astro`, `web/site/src/pages/[lang]/index.astro`, `web/site/src/pages/app-ads.txt.ts`, `web/site/src/pages/404.astro`, `web/site/public/robots.txt`, `web/site/test/pick.test.ts`

**Interfaces:**
- Consumes: Task 2 `@myungli/tokens/tokens.css`, Task 3 `siteConfig`, `loadCopy`, `LANGS`
- Produces: `pickLang(languages: readonly string[]): Lang`(앞에서부터 기본 언어 부분 `ko`/`en`/`ja`가 처음 맞는 것, 없으면 `en`)
- Produces: 언어 페이지 `<head>`: `<html lang>`, `title`, `meta description`, `link rel=canonical`, `link rel=alternate hreflang` ko/en/ja/x-default(x-default는 `/`), `og:title`, `og:description`, `og:image`(절대), `og:url`, `og:locale`, `twitter:card=summary_large_image`
- Produces: `/`는 정적 HTML. 본문에 세 언어 링크(JS 없이 보임), 기본 OG는 en, `<script>`가 `pickLang(navigator.languages)`로 `location.replace`. 스크립트는 인라인 한 덩어리(Astro `is:inline`이 아니라 번들, 같은 `pickLang` 사용)

- [ ] **Step 1: 실패하는 테스트** `pickLang(["fr"])` → `en`, `["zh-TW","ja"]` → `ja`, `["ko-KR"]` → `ko`, `[]` → `en`, `["EN-us"]` → `en`, `["ja-JP","ko"]` → `ja`
- [ ] **Step 2:** Run: `cd web && pnpm --filter site test` Expected: FAIL
- [ ] **Step 3:** 구현. 최소 판 화면: 앱 이름, `hero.tagline`, `hero.body`, 배지 자리(`release: "soon"`이면 `store.soon` 글만, 링크 없음), 언어 바꾸기(`aria-label`은 `lang.label`, 현재 언어 `aria-current`), 아래 법적 문서와 지원 링크. 스타일은 토큰 변수만(`--color-bg-base`, `--color-fg-primary` 등, 실제 이름은 `tokens.css`에서 고름). 앱 화면 사진은 시안 뒤.
- [ ] **Step 4:** Run: `cd web && pnpm test && pnpm --filter site build && pnpm --filter site exec astro check` Expected: PASS, `site/dist/{index.html,ko/index.html,en/index.html,ja/index.html,app-ads.txt,404.html}` 생김
- [ ] **Step 5: Commit** `feat(web): Astro 랜딩 최소 판(세 언어, 언어 고르기, app-ads.txt)`

### Task 5: 언어별 OG 이미지

**Files:**
- Create: `web/site/src/og/render.ts`, `web/site/src/pages/[lang]/og.png.ts`, `web/site/test/og.test.ts`
- Modify: `web/site/package.json`(`satori`, `@resvg/resvg-js`, `pretendard` 정확한 버전)

**Interfaces:**
- Produces: `renderOg(input: { lang: Lang; title: string; tagline: string; colors: { bg: string; fg: string } }): Promise<Uint8Array>`(1200×630 PNG). 글꼴은 `pretendard` 패키지의 OTF(ja는 Pretendard JP OTF), 색은 `tokens.css`가 아니라 Task 2 `loadTheme(..., "light", ...)` 값(공유 이미지는 라이트 고정, 토큰 README).

- [ ] **Step 1: 실패하는 테스트** 결과가 PNG 시그니처(`89 50 4E 47`)로 시작, 너비 1200 높이 630(IHDR 읽기), ja 입력도 성공, 글에 D93 문자가 있으면 오류.
- [ ] **Step 2:** Run: `cd web && pnpm --filter site test` Expected: FAIL
- [ ] **Step 3:** 구현(정적 endpoint `getStaticPaths`가 세 언어).
- [ ] **Step 4:** Run 테스트와 `pnpm --filter site build`. Expected: PASS, `dist/<언어>/og.png` 셋
- [ ] **Step 5: Commit** `feat(web): 언어별 OG 이미지 빌드 생성`

### Task 6: 빌드 뒤 검사

**Files:**
- Create: `web/site/scripts/check-dist.ts`, `web/site/test/check-dist.test.ts`, `web/site/test/fixtures/dist-*/`
- Modify: `web/site/package.json`(`build` = `astro build && node scripts/check-dist.ts`)

**Interfaces:**
- Consumes: Task 3 `findD93`, `LANGS`
- Produces: `checkDist(distDir: string, origin: string): string[]`(문제 목록, 비면 통과). 검사: 언어별 `index.html`과 `og.png`, 루트 `index.html`, `app-ads.txt`가 있음 / 각 언어 페이지의 `og:image`가 `${origin}/<언어>/og.png`이고 그 파일이 있음 / HTML 보이는 글과 `title`, `alt`, `aria-label`, `content`(meta)에 D93 문자 없음 / `href`, `src`의 같은 origin 경로가 `dist`의 파일로 풀림(외부 주소는 건너뜀). HTML 파싱은 `node-html-parser`.

- [ ] **Step 1: 실패하는 테스트** fixture마다: 정상 → `[]`, `ja/og.png` 없음 → 그 문제, 본문 `·` → D93 문제(파일과 글자), `<a href="/ko/missing/">` → 깨진 링크, `og:image`가 상대 주소 → 문제.
- [ ] **Step 2:** Run 테스트. Expected: FAIL
- [ ] **Step 3:** 구현. 문제가 있으면 목록을 출력하고 exit 1.
- [ ] **Step 4:** Run 테스트와 `pnpm --filter site build`. Expected: PASS, 빌드 끝에 `check-dist: OK`
- [ ] **Step 5: Commit** `feat(web): 빌드 뒤 페이지, OG, D93, 내부 링크 검사`

### Task 7: Hosting 설정과 Playwright

**Files:**
- Create: `web/deploy/firebase/firebase.json`, `web/deploy/firebase/.firebaserc`, `web/e2e/playwright.config.ts`, `web/e2e/landing.spec.ts`
- Modify: `web/package.json`(`firebase-tools`, `@playwright/test` 정확한 버전, `e2e` 스크립트)

**Interfaces:**
- Produces: `firebase.json`: `hosting.target: "landing"`, `public: "../../site/dist"`, `cleanUrls: false`, `trailingSlash: true`, `appAssociation: "NONE"`, 헤더 `/app-ads.txt` → `Content-Type: text/plain; charset=utf-8`, HTML `Cache-Control: no-cache`, `/_astro/**` `Cache-Control: public, max-age=31536000, immutable`. `.firebaserc` targets: `myungli-diary-staging` → `landing: [myungli-diary-staging-landing]`, `myungli-diary` → `landing: [myungli-diary-landing]`, 기본 프로젝트 `demo-myungli-web`(에뮬레이터용).
- Produces: `pnpm e2e` = 빌드 뒤 `firebase emulators:exec --only hosting --project demo-myungli-web "playwright test"`(포트 47291, 흔한 포트 피함)

- [ ] **Step 1: 실패하는 테스트**(`landing.spec.ts`)
  * 로케일 `fr-FR`, `zh-TW` 컨텍스트로 `/` → URL이 `/en/`, `ja-JP` → `/ja/`, `ko-KR` → `/ko/`
  * `javaScriptEnabled: false`로 `/`: 링크 `/ko/`, `/en/`, `/ja/`가 보이고 `link[hreflang]` 넷, `og:image` 있음, URL 그대로 `/`
  * 언어 페이지 셋: `og:image`가 `http://127.0.0.1:47291/<언어>/og.png`(빌드 `WEB_ORIGIN`을 에뮬레이터 주소로)이고 그 주소 요청이 200 `image/png`
  * `request.get("/app-ads.txt", { maxRedirects: 0 })` → 200, `content-type`이 `text/plain`으로 시작, 본문 trim이 `siteConfig.appAdsTxt`
  * 언어 바꾸기 링크로 `/ko/` → `/ja/`, `html[lang="ja"]`
  * 출시 전: 스토어 링크(`a[href*="apps.apple.com"]`, `play.google.com`) 없음
- [ ] **Step 2:** Run: `cd web && pnpm exec playwright install chromium && pnpm e2e` Expected: 설정 전 FAIL
- [ ] **Step 3:** 설정 작성
- [ ] **Step 4:** Run: `pnpm e2e` Expected: 모두 PASS
- [ ] **Step 5: Commit** `test(web): Hosting 설정과 랜딩 Playwright(언어, JS 없음, OG, app-ads.txt)`

### Task 8: `web.yml`

**Files:**
- Create: `.github/workflows/web.yml`

**Interfaces:**
- Produces: `on: workflow_call(inputs.mode: own|drift|gate, 기본 own)`, `workflow_dispatch`, 그리고 ci-gate web 갈래가 생기기 전까지만 `pull_request: paths: [web/**, .github/workflows/web.yml]`(ci-gate 머리 주석의 전환 순서 1단계, 지휘 Task 5 뒤 지움). 단계: checkout(fetch-depth 1) → `pnpm/action-setup`(packageManager 읽음) → `actions/setup-node`(`node-version-file: web/.nvmrc`, `cache: pnpm`) → `pnpm install --frozen-lockfile` → own: lint, typecheck, test, 토큰 `--check`, build(check-dist 포함), Playwright(chromium) / drift, gate: 토큰 `--check`, 원고 읽기 테스트, build(계약 파일이 토큰, `site.json`, writing 생성물이라 이 셋을 읽는 검사만). Playwright 브라우저와 firebase 에뮬레이터 캐시는 lockfile 해시 키, 저장은 staging push own에서만(§6.2).

- [ ] **Step 1:** 쓰는 Action의 최신 릴리스 commit SHA를 `gh api repos/<owner>/<repo>/git/ref/tags/<tag>`로 확인(checkout과 setup-node는 저장소에 이미 쓰는 SHA 재사용).
- [ ] **Step 2:** 작성. Run: `docker run --rm -v "$PWD":/repo -w /repo rhysd/actionlint:1.7.12 -color .github/workflows/web.yml` Expected: 출력 없음
- [ ] **Step 3:** 로컬에서 workflow 단계와 같은 명령을 차례로(`pnpm install --frozen-lockfile`부터 e2e까지) 끝까지 돌림. Expected: 모두 성공
- [ ] **Step 4: Commit** `ci(web): web.yml(own, drift, gate)`

### Task 9: 배포 인프라와 `deploy-web.yml`

**Files:**
- Create: `web/deploy/terraform/{versions.tf,variables.tf,main.tf,outputs.tf,staging.tfvars,prod.tfvars}`, `web/deploy/README.md`, `.github/workflows/deploy-web.yml`

**Interfaces:**
- Produces(Terraform, 변수 `project_id`, `environment`(`web-staging`|`web-prod`), `deploy_branch`, `site_id`, `domains`): `google_firebase_hosting_site.landing`(google-beta), `google_firebase_hosting_custom_domain`(staging: `staging.myungli-diary.app` / prod: `myungli-diary.app`, `www.myungli-diary.app`은 `redirect_target = "myungli-diary.app"`, `wait_dns_verification = false`), `google_service_account.web_deployer`(`web-deployer`), 위 두 역할, `google_service_account_iam_member`(`roles/iam.workloadIdentityUser`, member `principalSet://iam.googleapis.com/projects/<번호>/locations/global/workloadIdentityPools/github/attribute.env_ref/<environment>@refs/heads/<deploy_branch>`, 번호는 `data.google_project`). outputs: `web_deployer_email`, `dns_records`(각 도메인의 `required_dns_updates`).
- Produces(`deploy-web.yml`): `push: branches [staging, main], paths [web/**, .github/workflows/deploy-web.yml]`, `workflow_dispatch`, `pull_request` 같은 paths(검사만). job `checks`: actionlint, `terraform fmt -check`, `validate`(backend 없이). job `deploy`: staging 브랜치면 environment `web-staging`, main이면 `web-prod`. 저장소 변수 `WEB_DEPLOY_ENABLED == 'true'`일 때만. `google-github-actions/auth`(provider는 기존 `GCP_WIF_PROVIDER_STAGING`/`_PROD`, 계정은 `web-deployer@<프로젝트>.iam.gserviceaccount.com`) → 설치와 빌드(`WEB_ORIGIN` staging `https://staging.myungli-diary.app`, prod `https://myungli-diary.app`) → `pnpm exec firebase deploy --only hosting:landing --project <프로젝트> --non-interactive`(working-directory `web/deploy/firebase`). concurrency `deploy-web-<environment>`, 취소 안 함.

- [ ] **Step 1:** Terraform 작성. Run: `terraform -chdir=web/deploy/terraform init -backend=false && terraform -chdir=web/deploy/terraform validate && terraform fmt -check -recursive web/deploy/terraform` Expected: 성공
- [ ] **Step 2:** `deploy-web.yml` 작성, actionlint. Expected: 출력 없음
- [ ] **Step 3:** `web/deploy/README.md`: 사용자 절차(server bootstrap README 형식). ① `gcloud auth application-default login` ② 환경마다 `terraform init -reconfigure -backend-config="bucket=${project}-tfstate" -backend-config="prefix=web"` → `terraform apply -var-file=<env>.tfvars` ③ 출력 `dns_records`를 Cloudflare에 넣음(프록시 끔) ④ GitHub environment `web-staging`(배포 브랜치 `staging`), `web-prod`(배포 브랜치 `main`, 필수 승인자) ⑤ 저장소 변수 `WEB_DEPLOY_ENABLED=true` ⑥ 되돌리기(`terraform destroy`는 사이트와 도메인 연결까지 지움, 변수를 `false`로 하면 배포만 멈춤). Hosting 권한이 프로젝트 단위인 한계도 적음.
- [ ] **Step 4: Commit** `feat(web): 랜딩 배포 인프라(Terraform)와 deploy-web.yml`
- [ ] **Step 5: 넘김** E25 #1332에 사이트 이름, 계정, 절차(README 경로) 코멘트. server에 `to:server` `kind:request` Issue: `deploy-server.yml`의 paths `.github/workflows/deploy-*.yml`이 `deploy-web.yml` 변경에도 server 배포를 돌리므로 `!.github/workflows/deploy-web.yml` 제외 요청(D100 ① 작은 요청).

### Task 10: 마무리와 PR

- [ ] **Step 1:** `git merge origin/staging`, Task 8 Step 3 전체 다시.
- [ ] **Step 2:** `web/CLAUDE.md` 현재 상태(열린 PR, E25 대기, 시안과 원고 대기), 다음 할 일(① 사용자 E25 끝나면 staging 배포 확인 ② 원고 #1329 생성물 연결 ③ 시안 #1330 고른 안 구현, 앱 화면 사진, 공식 배지 ④ 지휘 Task 5 뒤 `web.yml`의 `pull_request` 트리거 지움).
- [ ] **Step 3:** 공개 저장소 확인(D74): 금액, 비공개 경로 없음.
- [ ] **Step 4:** PR `web/wb1-skeleton` → `staging`. 본문 `참고 #1331`(최소 판까지, 시안 구현은 남음. #1331이 단계 배포를 요구하므로 나눠 병합), 지휘에게 ci-gate web 갈래(지휘 plan Task 5) 알림.

## 이 plan 밖 (다음 web plan)
시안(#1330) 고른 안의 화면, 앱 화면 사진, Apple, Google 공식 배지와 출시 뒤 링크 전환, 웹 글꼴 묶음, writing 생성물 연결 뒤 자리 문구 삭제, prod 확인(지휘 승격 뒤). 그 PR에서 `Closes #1331`.
