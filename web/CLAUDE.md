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
| 웹 원고 생성물 (`docs/identity/writing/generated/web/<언어>.json`, #1329) | **사용** | writing |
| 웹 화면 명세와 화면 사진 (`docs/identity/design/web/`, V137) | **사용** | design |

계약 버전과 상태는 [`docs/contracts/README.md`](../docs/contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.

## 현재 상태
진행 중인 일만 적고, 병합하면 지웁니다(`docs/workflow.md` §3 마무리 2번).

* **파비콘(브랜치 `web/favicon`):** `favicon.ico`(16, 32, 48), `icon-192.png`, `apple-touch-icon.png`(180)을 design 앱 아이콘에서 빌드 때 만듦. 병합은 사용자.
* **배포:** E25(#1332)가 끝나 `WEB_DEPLOY_ENABLED=true`입니다. 랜딩(#1340, #1359), 404(#1368), 배포 경로 고침(#1380)은 staging에 병합됐습니다.

## 기준 문서와 도구
* 랜딩 화면 기준: design 명세 [`docs/identity/design/web/README.md`](../docs/identity/design/web/README.md)(V137). design 원본(로고, 화면 사진)은 복사하지 않고 별칭 `@design/`으로 그 자리에서 읽습니다.
* 글꼴: 원본 주소와 sha256은 `site/src/fonts/source.ts`(design `tools/fonts.py`와 같은 주소), 언어별 글꼴 묶음은 `site/src/fonts/web.ts`. 원본은 `web/.cache/fonts/`에 받습니다.
* 파비콘: `site/src/icons/favicon.ts`. 48px 이하는 design `logo/icon-small.png`, 그보다 크면 `icon-large.png`(design visual-identity "앱 아이콘").
* 스토어 배지: `site/src/assets/badges/`. Apple은 `toolbox.marketingtools.apple.com` 검은 배지 SVG 그대로, Google은 `play.google.com/intl/en_us/badges/` PNG의 바깥 투명 여백만 잘라 냄. 바꾸면 `site/src/assets/badges.ts` 크기 표도 고칩니다(테스트가 대조).
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
1. **staging 배포 확인:** `deploy-web`이 staging에서 돈 뒤 `https://staging.myungli-diary.app/`(세 언어, `app-ads.txt`, OG, 글꼴, 언어별 404, 파비콘)를 확인합니다. 404는 `Accept-Language`를 바꿔 봅니다. 에뮬레이터는 첫 언어가 지원 밖이면(`de,ko;q=0.5`) 둘째 언어 대신 en을 냈는데, 문서는 품질 값 순서대로 찾는다고 해 실제 Hosting 동작을 확인합니다. 절차는 [`deploy/README.md`](deploy/README.md). prod 승격(지휘) 뒤 `myungli-diary.app`이 열리면 #1331의 끝나는 조건입니다.
2. **원어민 검수(E18):** writing이 en, ja 원고를 바꾸면 같은 경로라 빌드만 다시 하면 됩니다. 줄 수가 크게 바뀌면 390, 1280 폭 화면을 다시 봅니다.
3. 출시 때 `site/src/config/site.ts`의 `release`를 `live`로, 두 스토어 주소를 넣습니다. Apple 상표 고지 줄 슬롯(지휘가 출시 무렵 더함)을 아래쪽 링크 묶음 아래에 둡니다(V137 "스토어 자리").
