# web — 랜딩, social, 어드민

이 디렉터리에서 시작한 세션은 **web 세션**입니다. 루트 [`CLAUDE.md`](../CLAUDE.md)와 [`docs/workflow.md`](../docs/workflow.md)의 공통 규약을 함께 따릅니다. 서브 프로젝트 세션과 같은 규칙입니다.

## 범위
명리일기의 웹 표면을 만듭니다(D144).

| 표면 | 주소 | 마일스톤 |
| --- | --- | --- |
| 랜딩 | `myungli-diary.app` (staging `staging.myungli-diary.app`) | WB1 |
| 바이럴 셀프 테스트 | `social.myungli-diary.app` | WB2 |
| 어드민 | 별도 주소와 인증 경계 | WB3 |

* 스택: TypeScript, pnpm workspace. 공개 사이트는 Astro(정적 생성, SSR 없음), 어드민은 React(D144 ⑤).
* 법적 문서와 지원 페이지는 server가 냅니다(`https://api.myungli-diary.app/legal/*`, `/support?lang=`). web은 링크만 합니다.
* 사용자에게 보이는 글은 D93(긴 대시, 범위 대시, 가운뎃점 금지)을 지킵니다. 문구는 writing 원고(D66)로 받습니다.

## 고칠 수 있는 곳
`web/`, `.github/workflows/web.yml`, `.github/workflows/deploy-web.yml`, GitHub Issues(요청과 보고 작성, `gh issue list --label to:web`). 그 밖은 읽기만 합니다. `ci-gate.yml`과 `.github/dependabot.yml`은 지휘 몫이라 필요하면 요청합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 웹 화면 목록 (IA, `docs/ia/site.json`, D146) | **사용** | 지휘 |
| 디자인 토큰 (`docs/identity/design/tokens/`) | **사용** | design |
| 웹 원고 생성물 (경로는 writing이 정함, #1329) | **사용** | writing |

계약 버전과 상태는 [`docs/contracts/README.md`](../docs/contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.

## 현재 상태
진행 중인 일만 적고, 병합하면 지웁니다(`docs/workflow.md` §3 마무리 2번).

* **WB1 뼈대와 최소 판(#1331, 브랜치 `web/wb1-skeleton`):** workspace, 토큰 CSS, 최소 판 랜딩(세 언어, 언어 고르기, OG, `app-ads.txt`), `web.yml`, `deploy-web.yml`, 배포 Terraform. PR은 `참고 #1331`이고 병합은 사용자. 실제 배포는 사용자 E25(#1332, Firebase 사이트와 DNS, 배포 권한) 뒤 저장소 변수 `WEB_DEPLOY_ENABLED`로 켭니다.
* 원고는 writing 생성물(#1329) 전이라 자리 문구(`site/src/copy/placeholder/`, 스토어 문구에서 가져옴)로 빌드합니다. 빌드 로그에 "자리 문구 사용" 경고가 납니다.

## 기준 문서와 도구
* WB1 준비 메모: [`docs/specs/2026-11-25-web-landing-design.md`](../docs/specs/2026-11-25-web-landing-design.md)
* 지휘 plan: [`docs/plans/2026-11-25-web-landing.md`](../docs/plans/2026-11-25-web-landing.md)(web 몫은 Task 3 Step 3)
* web 자기 spec과 plan은 `web/docs/specs/`, `web/docs/plans/`에 둡니다. WB1 뼈대 plan: [`docs/plans/2026-11-25-wb1-skeleton.md`](docs/plans/2026-11-25-wb1-skeleton.md)
* 배포 절차와 환경 표: [`deploy/README.md`](deploy/README.md)

## 검사 방법
`web/`에서 실행합니다. Node와 pnpm 준비는 [`README.md`](README.md)입니다.

| 명령 | 하는 일 |
| --- | --- |
| `pnpm install --frozen-lockfile` | 설치(lockfile 고정) |
| `pnpm lint` | ESLint |
| `pnpm typecheck` | 패키지마다 타입 검사(`astro check` 포함) |
| `pnpm test` | Vitest 단위 테스트 전체 |
| `pnpm build` | 사이트 빌드와 빌드 뒤 검사 |
| `pnpm e2e` | 빌드 뒤 Hosting 에뮬레이터 위 Playwright |

## 다음 할 일
1. **staging 배포 확인:** 사용자 E25(#1332)가 끝나면 `deploy-web`을 staging에서 돌려 `https://staging.myungli-diary.app/`(세 언어, `app-ads.txt`, OG)를 확인합니다. 절차는 [`deploy/README.md`](deploy/README.md).
2. **ci-gate 전환:** 지휘가 ci-gate에 web 갈래를 넣으면 `web.yml`의 `pull_request` 트리거를 지웁니다.
3. **원고 연결(#1329):** writing 생성물이 오면 형식을 맞추고 `site/src/copy/placeholder/`를 지웁니다.
4. **시안 구현(#1330):** 고른 안의 화면, 앱 화면 사진, Apple, Google 공식 배지, 웹 글꼴(@font-face), 404 안내 문구(슬롯 요청). 다음 web plan으로 쓰고 그 PR에서 `Closes #1331`.
5. 출시 때 `site/src/config/site.ts`의 `release`를 `live`로, 두 스토어 주소를 넣습니다.
