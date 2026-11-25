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

* 단위를 막 열었습니다(2026-11-25). 코드는 아직 없습니다.

## 기준 문서와 도구
* WB1 준비 메모: [`docs/specs/2026-11-25-web-landing-design.md`](../docs/specs/2026-11-25-web-landing-design.md)
* 지휘 plan: [`docs/plans/2026-11-25-web-landing.md`](../docs/plans/2026-11-25-web-landing.md)(web 몫은 Task 3 Step 3)
* web 자기 spec과 plan은 `web/docs/specs/`, `web/docs/plans/`에 둡니다.

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
1. **WB1 뼈대와 랜딩 #1331:** 자기 plan을 쓰고, workspace, 토큰 패키지, `web.yml`, `deploy-web.yml`, 최소 판 staging 배포. 사이트 이름과 배포 계정 절차를 사용자 E25 #1332에 코멘트로.
2. 시안(design #1330)과 원고(writing #1329)가 오면 랜딩 구현과 Playwright.
