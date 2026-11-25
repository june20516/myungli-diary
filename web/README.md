# web

명리일기 웹 표면(랜딩, social, 어드민)의 pnpm workspace입니다. 범위와 규칙은 [`CLAUDE.md`](CLAUDE.md)를 봅니다.

| 경로 | 내용 |
| --- | --- |
| `packages/tokens/` | design 토큰(DTCG)을 CSS 변수 파일로 만듭니다(생성물 commit) |
| `site/` | Astro 정적 사이트(랜딩) |
| `e2e/` | Firebase Hosting 에뮬레이터 위 Playwright |
| `deploy/` | Hosting 설정(`firebase/`)과 배포 인프라(`terraform/`) |

## 준비

```sh
nvm install && nvm use          # .nvmrc(26.13.1)
npm i -g pnpm@12.23.0           # Node 25부터 corepack이 빠져 직접 설치합니다
pnpm install --frozen-lockfile
```

명령은 [`CLAUDE.md`](CLAUDE.md) "검사 방법"에 있습니다.
