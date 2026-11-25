# WB1 랜딩과 web 단위 세우기 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** I4 전에 `myungli-diary.app`에 세 언어 랜딩을 띄우고, WB2와 WB3가 얹힐 새 단위 `web/`을 세웁니다.

**Architecture:** 소유 경로(`docs/workflow.md` §2)대로 나눕니다. 지휘는 IA(`docs/ia/site.json`, D146), 소유 표, 계약 표, `ci-gate`, 외부 준비물, 요청과 착수 안내를 맡습니다. writing은 원고와 검사기, design은 시안, web은 `web/` 안의 구현과 자기 workflow를 맡고 자기 plan을 `web/docs/plans/`에 씁니다. 사용자는 Firebase 사이트와 DNS(E25), 시안 고르기, prod 승인을 맡습니다.

**Tech Stack:** IA JSON과 Python 검사기(`tools/docs-check`), GitHub Actions(`ci-gate.yml`), 단위 몫은 TypeScript, pnpm, Astro, Firebase Hosting

**Spec:** `docs/specs/2026-11-25-web-landing-design.md`

## Global Constraints
* 결정: D143, D144, D145, D146(IA는 같은 형식, 표면별 파일).
* 언어는 ko, en, ja. 지원하지 않는 언어는 `en`(server S65, app `resolveAppLanguage`와 같음).
* 사용자에게 보이는 글은 D93(긴 대시, 범위 대시, 가운뎃점 금지).
* 법적 문서와 지원 페이지는 server 주소(`https://api.myungli-diary.app/legal/*`, `/support?lang=`)로 링크만 합니다.
* 지휘는 단위 소유 경로를 고치지 않습니다. 단위 몫은 요청 Issue로 보냅니다. 예외: 착수 안내 때 지휘가 `web/CLAUDE.md`를 처음 만듭니다(§2 "단위의 `CLAUDE.md`" 행).
* 외부 Action은 commit SHA로 고정합니다(D136 ③).
* 저장소 설정, Firebase, DNS, 배포 권한 같은 외부 설정은 사용자가 하거나 지휘가 명령과 바뀌기 전 값을 보여 드리고 승인받은 뒤 합니다.
* 금액, 계정 id는 공개 저장소에 적지 않습니다(D74).

## Review Focus
1. 브라우저 언어가 ko, en, ja가 아님(예: `zh-TW`, `fr`): `/`에서 `/en/`으로 가야 함 → Task 3 web 요청의 Playwright 항목.
2. 자바스크립트를 실행하지 않는 크롤러와 공유 미리보기가 `/`를 읽음: 빈 페이지가 아니라 세 언어 링크와 `hreflang`, 기본 OG가 있어야 함 → Task 3 web 요청.
3. 카카오톡과 X 공유 미리보기: `og:image`가 절대 주소이고 언어별 페이지마다 따로 있어야 함 → Task 3 web 요청.
4. AdMob이 `https://myungli-diary.app/app-ads.txt`를 읽음: `www`에서 본 도메인으로 보내는 규칙과 상관없이 본 도메인에서 리다이렉트 없이 `text/plain` 200 → Task 3 web 요청, Task 7 Step 2 확인.
5. `site.json` 슬롯 id가 `screens.json`과 겹침: 문서 검사가 실패해야 함 → Task 1 테스트.

---

### Task 1: IA 표면별 파일과 랜딩 화면 (지휘)

**Files:**
- Create: `docs/ia/site.json`
- Modify: `docs/ia/README.md`(표면별 파일 규칙), `tools/docs-check/docs_check.py`, `docs/decisions.md`(D146)
- Test: `tools/docs-check/` 기존 테스트 파일에 사례 추가

**Interfaces:**
- Produces: `docs/ia/site.json`, 최상위 `version`, `tabs`(빈 배열), `components`(빈 배열), `screens`. 화면 `web-landing`(`presentation: "system"`, `auth: "any"`, `tab: null`, `decisions: ["D144", "D145", "D146"]`). 슬롯은 모두 `source: "content"`:
  `web-landing.meta.title`, `web-landing.meta.description`, `web-landing.hero.tagline`, `web-landing.hero.body`, `web-landing.shots.alt`(매개변수 `index`), `web-landing.store.soon`, `web-landing.store.apple`, `web-landing.store.google`, `web-landing.footer.terms`, `web-landing.footer.privacy`, `web-landing.footer.support`, `web-landing.lang.label`. 각 `role`에 무엇을 쓰는지 한 줄.
- Produces: 문서 검사가 `docs/ia/*.json`을 모두 같은 형식으로 검사하고, 화면 id와 슬롯 id가 파일 사이에서 겹치면 실패.

- [ ] **Step 1: 실패하는 테스트** 두 IA 파일에 같은 슬롯 id가 있으면 `docs_check`가 문제를 내는지, `site.json` 형식이 틀리면(최상위 키 빠짐) 문제를 내는지 단언하는 사례 둘.
- [ ] **Step 2: 실행해 실패 확인** Run: `cd tools/docs-check && python3 -I -m unittest -q` Expected: 새 두 사례 FAIL
- [ ] **Step 3: 구현** `IA_PATH` 한 파일 검사를 `docs/ia/*.json` 목록 검사로 바꾸고, 파일 사이 id 중복을 모아 보고합니다.
- [ ] **Step 4: 통과 확인** 같은 명령. Expected: OK
- [ ] **Step 5: `site.json`과 README** 위 Interfaces대로. README에 "`screens.json`은 앱과 server가 내주는 페이지, `site.json`은 랜딩과 social, `admin.json`은 WB3에서. 형식은 같고 id는 파일 사이에서도 유일" 절.
- [ ] **Step 6: D146** `docs/decisions.md` 끝에 D146(IA는 형식과 도구 하나, 표면별 파일, 사용자 결정 2026-11-25, 어드민 IA를 원고로 둘지는 WB3).
- [ ] **Step 7: 문서 검사** Run: `python3 -I tools/docs-check/docs_check.py .` Expected: `OK: docs 검사 통과`
- [ ] **Step 8: Commit** `docs(root): D146 IA 표면별 파일, site.json web-landing`

### Task 2: 소유 표, 세션 규칙, 계약 표, 외부 준비물 (지휘)

**Files:**
- Modify: `docs/workflow.md` §2, 루트 `CLAUDE.md`("나는 어떤 세션인가", 문서 위치 표), `docs/contracts/README.md`, `docs/external-prep.md`

- [ ] **Step 1: §2 소유 표** 행 추가: `web/`는 web, `.github/workflows/web.yml`과 `.github/workflows/deploy-web.yml`은 web. "`deploy-*.yml`은 server" 행에 "`deploy-web.yml`은 빼고"를 붙임. `docs/ia/`가 지휘 소유인 행은 그대로(파일이 늘어도 지휘).
- [ ] **Step 2: 루트 `CLAUDE.md`** "작업 디렉터리가 `web/` 아래면 web 세션(서브 프로젝트 세션과 같은 규칙)" 한 줄.
- [ ] **Step 3: 계약 표** 받는 쪽에 web: 디자인 토큰, IA `site.json`, writing 웹 원고 생성물(`docs/identity/writing/generated/web/<언어>.json`, Task 3에서 writing에 요청하는 경로). 버전 칸은 주는 쪽 기존 값 그대로.
- [ ] **Step 4: E25** 외부 준비물 행: Firebase Hosting 사이트 두 개, Cloudflare DNS(본 도메인, `www`, `staging`, 프록시 끔), 배포 서비스 계정과 Workload Identity, GitHub environment, 랜딩이 뜬 뒤 `app-ads.txt` 확인과 스토어 웹사이트 주소 변경. 막는 것 WB1, 상태 준비 전, Issue 칸은 Task 3에서 채움.
- [ ] **Step 5: 문서 검사** Run: `python3 -I tools/docs-check/docs_check.py .` Expected: OK
- [ ] **Step 6: Commit** `docs(root): web 단위 소유와 세션 규칙, 계약 표, E25`

Task 1과 Task 2는 한 PR(`root/wb1-ia-ownership`)로 올리고 `ci-gate` 통과 뒤 병합합니다.

### Task 3: 요청 Issue 넷 (지휘)

각 Issue 본문은 무엇이 필요한지, 왜, 끝나는 조건, 관련(준비 메모 경로, D번호)으로 씁니다.

- [ ] **Step 1: writing** `[root→writing] WB1 랜딩 원고와 site.json 읽기`
  1. 검사기(`mlw`)가 `docs/ia/site.json`도 읽게(IA 파일 목록). 슬롯 명세와 원고 검사가 두 파일을 함께 봄.
  2. `web-landing` 슬롯 원고 ko, en, ja. 스토어 문구와 톤을 맞추고 기능 나열보다 찾는 순간과 얻는 것(R49 답지).
  3. web이 읽을 생성물 `docs/identity/writing/generated/web/<언어>.json`(슬롯 id → 문장). 다른 경로나 형식이 낫다면 writing이 정하고 계약 표 자기 행에 적음.
- [ ] **Step 2: design** `[root→design] WB1 랜딩 웹 시안 2~3안(D105)` 토큰을 직접 읽는 웹 시안, 세 언어 중 ko 기준과 en 하나, 모바일과 데스크톱 폭. 스토어 스크린샷(빌드 11 금빛 판) 재사용 가능. 공식 스토어 배지 사용 규정(Apple, Google 배지 가이드) 지킴. 시안 비교 페이지를 게시해 사용자가 고름.
- [ ] **Step 3: web** `[root→web] WB1 web 단위 뼈대와 랜딩` web이 자기 plan(`web/docs/plans/`)을 쓰고 진행:
  1. pnpm workspace, Node 버전 고정, `web/packages/tokens`(토큰 → CSS 변수, 생성물 commit, CI가 재생성 비교), `web/site`(Astro).
  2. `web.yml`은 다른 단위처럼 `workflow_call`과 `mode` 입력을 받음. 검사: 타입, lint, 단위 테스트, 빌드, D93 글 검사, 내부 링크.
  3. `deploy-web.yml`: staging push는 staging, main 승격은 prod(environment 승인), Hosting 배포 권한만 가진 계정.
  4. 시안 전 최소 판(원고, 배지 자리, 링크)으로 staging 배포까지 먼저 확인.
  5. 시안 고른 뒤 구현. Playwright로 Review Focus 1~4: 지원 밖 언어는 `/en/`, JS 없이 `/`에 세 언어 링크와 `hreflang`, 언어별 절대 주소 `og:image`, 본 도메인 `app-ads.txt`가 리다이렉트 없이 `text/plain` 200.
  6. 스토어 주소와 출시 전후 배지 상태는 설정 한 곳.
  7. web plan에서 정할 것(준비 메모 §8): Hosting 사이트 이름, PR preview channel 여부, Node 버전.
- [ ] **Step 4: 사용자 E25** `[root→user] E25 랜딩 호스팅: Firebase 사이트, DNS, 배포 권한` `kind:prep`. 사이트 이름과 배포 계정 절차는 web이 자기 plan에서 정해 이 Issue에 코멘트로 넘김(지휘가 확인 뒤 사용자에게 안내).
- [ ] **Step 5: 외부 준비물과 로드맵** E25 행 Issue 칸, 로드맵 "현재 진행 순서" WB1 줄을 Issue 번호로. 루트 PR, `ci-gate` 뒤 병합.

### Task 4: 착수 안내 (지휘)

**Files:**
- Create: `web/CLAUDE.md`(현재 상태, 다음 할 일, 읽을 문서: 루트 `CLAUDE.md`, 준비 메모, 이 plan, §2)

- [ ] **Step 1: `web/CLAUDE.md`** 다른 단위 `CLAUDE.md`의 머리 형식을 따름. 다음 할 일 맨 앞은 Task 3 Step 3 Issue.
- [ ] **Step 2: 착수 명령** 사용자에게 web, writing, design 세 단위의 한 덩어리 명령(`docs/workflow.md` 착수 안내 규칙: `cd ../myungli-diary-<단위>` 또는 `git worktree add ../myungli-diary-web -b web/wb1-skeleton --no-track origin/staging` → `git push -u origin <브랜치>` → `cd <시작 디렉터리> && claude`). 동시 단위 세션은 둘까지(D78)이므로 순서를 함께 안내(writing과 web 먼저, design은 그 뒤 또는 writing 끝난 뒤).
- [ ] **Step 3: Commit** `docs(root): web 단위 착수 안내` (Task 3 Step 5 PR에 함께)

### Task 5: `ci-gate` web 갈래 (지휘, web의 첫 PR에 `web.yml`이 생긴 뒤)

**Files:**
- Modify: `.github/workflows/ci-gate.yml`

- [ ] **Step 1: 판정 줄** `unit web "$code_changed" '^web/' '^docs/identity/design/tokens/|^docs/ia/site\.json$|^docs/identity/writing/generated/web/'`. writing 갈래의 계약 경로에 `^docs/ia/site\.json$`를 더함.
- [ ] **Step 2: job** `web: needs: changes, if: needs.changes.outputs.web == 'true', uses: ./.github/workflows/web.yml, with: mode`. 최종 판정 job의 `needs`와 결과 모음에 web 추가.
- [ ] **Step 3: 로컬 검사** Run: `python3 -c "import yaml,sys;yaml.safe_load(open(sys.argv[1]))" .github/workflows/ci-gate.yml && (command -v actionlint >/dev/null && actionlint .github/workflows/ci-gate.yml || true)` Expected: 오류 없음. drift 도구 테스트 Run: `cd tools/drift && python3 -I -m unittest -q` Expected: OK
- [ ] **Step 4: Dependabot** `.github/dependabot.yml`에 `npm`(`directory: /web`, `open-pull-requests-limit: 0`, 보안 업데이트만) 항목. 다른 생태계와 같은 주석.
- [ ] **Step 5: Commit과 PR** `ci(root): ci-gate에 web 갈래, web 보안 업데이트`. PR에서 web 갈래가 `gate` 모드로 돌아 통과하는지 확인(Expected: web job success).

### Task 6: 시안 관문 (design → 사용자)

- [ ] **Step 1:** design 시안 비교 페이지가 오면 사용자에게 안 하나씩 질문(관문 질문은 하나씩). 고른 안을 design 결정(V번호)으로 기록하도록 design에 남김.
- [ ] **Step 2:** 고른 안을 web Issue에 코멘트로 넘김.

### Task 7: staging 확인, 승격, 마무리 (지휘 + 사용자)

- [ ] **Step 1: staging** `https://staging.myungli-diary.app/`에서 세 언어 페이지, 언어 바꾸기, 법적 문서 링크, OG 미리보기(카카오톡 공유 디버거 또는 같은 도구). Expected: 모두 열림.
- [ ] **Step 2: 승격** 승격 PR(본문에 지난 승격 뒤 PR과 "prod에 랜딩 첫 배포"), 병합 뒤 `deploy-web` prod 승인은 사용자. 확인 Run: `curl -sI https://myungli-diary.app/app-ads.txt` Expected: `HTTP/2 200`, `content-type: text/plain`. `curl -sI https://www.myungli-diary.app/` Expected: 본 도메인으로 301 또는 308.
- [ ] **Step 3: E25 4번(사용자)** AdMob `app-ads.txt` 확인, 두 스토어 등록정보 웹사이트를 `https://myungli-diary.app`으로. 출시 때 배지를 스토어 링크로 바꾸는 일은 web Issue에 남김.
- [ ] **Step 4: 기록** 로드맵 WB1 완료와 행을 history로(D131), I4 준비물의 랜딩 줄 지움, 준비 메모 상태 "끝남".
