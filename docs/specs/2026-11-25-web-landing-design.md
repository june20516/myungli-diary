# WB1 랜딩과 web 단위 세우기: 준비 메모

* 작성: 지휘 세션, 2026-11-25
* 상태: 승인(사용자, 2026-11-25). plan은 `docs/plans/2026-11-25-web-landing.md`
* 근거 결정: D143(광고 측정 없음, 무료 유입 경로 주력), D144(web 단위 방향), D145(시점: 랜딩은 I4 전)
* 범위 밖: WB2(첫 셀프 테스트), WB3(어드민 웹)은 각자 준비 메모를 따로 씁니다. 이 메모는 그 둘이 얹힐 단위의 뼈대까지만 정합니다

## 1. 목적

I4 전에 `myungli-diary.app`에 앱 랜딩을 띄웁니다. 랜딩이 하는 일은 넷입니다.

1. 스토어 등록정보의 웹사이트 주소
2. AdMob `app-ads.txt` 위치(개발자 웹사이트 도메인 루트)
3. App Store 피처링 신청(E23)과 크레딧 광고(E24)의 도착 페이지
4. 앱을 한눈에 설명하고 두 스토어로 보냄

그리고 WB2, WB3가 얹힐 새 단위 `web/`을 세웁니다.

## 2. 지금 상태 (2026-11-25 확인)

| 항목 | 상태 |
| --- | --- |
| `myungli-diary.app`, `www` | 응답 없음(연결된 호스팅 없음). DNS는 Cloudflare(E6) |
| `api.`, `api-staging.` | Firebase Hosting 커스텀 도메인이 모든 경로를 Cloud Run `server`로 넘김(server S117) |
| 법적 문서, 지원 페이지 | server가 `/legal/*`, `/support?lang=`으로 냄(D134). 스토어에 이 주소가 등록돼 있음 |
| 웹 코드 | 저장소에 없음. Node 도구 체인 없음 |
| 배포 workflow 소유 | `.github/workflows/deploy-*.yml`은 모두 server 소유(`docs/workflow.md` §2) |

## 3. 랜딩 구성 (사용자 승인 2026-11-25)

| 항목 | 내용 |
| --- | --- |
| 화면 | 한 페이지. 앱 이름과 한 줄 소개, 앱 화면 3~4장, App Store와 Google Play 배지, 아래쪽에 약관, 처리방침, 지원 링크 |
| 언어 | ko, en, ja. 브라우저 언어로 고르고 직접 바꿀 수 있음. 경로는 `/`(브라우저 언어로 보냄), `/ko/`, `/en/`, `/ja/` |
| 법적 문서와 지원 | server 주소(`/legal/*`, `/support`)로 링크만. 옮기지 않음 |
| 공유 미리보기 | 언어별 OG 이미지 한 장 |
| 출시 전 | 스토어 배지 자리는 "곧 출시". 출시 때 스토어 링크로 바꿈 |
| 사용자에게 보이는 글 | D93(긴 대시, 범위 대시, 가운뎃점 금지)을 지킴 |

### 만드는 흐름
* **IA:** 지휘가 `docs/ia/screens.json`에 웹 화면 `web-landing`과 슬롯을 더합니다(D66처럼 웹 페이지 문구도 슬롯).
* **writing:** 슬롯 원고 세 언어. 스토어 문구와 톤을 맞춥니다(R49 답지: 기능 나열보다 찾는 순간과 얻는 것).
* **design:** 토큰을 읽는 웹 시안 2~3안(D105). 사용자가 고릅니다. 스토어 스크린샷(빌드 11 금빛 판)을 재사용할 수 있습니다.
* **web:** 고른 안을 구현합니다.

## 4. web 단위 구성

### 폴더와 소유
| 경로 | 내용 |
| --- | --- |
| `web/site/` | Astro 정적 사이트. 지금은 랜딩, WB2에서 social이 같은 빌드나 별도 사이트로 들어옴(WB2 메모에서 정함) |
| `web/packages/tokens/` | design 토큰(DTCG)을 CSS 변수로 생성. 생성물은 commit하고 CI가 다시 생성해 비교(app `gen_tokens`와 같은 방식) |
| `web/packages/ui/` | 공용 컴포넌트(WB2, WB3가 함께 씀) |
| `web/admin/` | WB3에서 만듦. 지금은 두지 않음 |
| `web/deploy/firebase/` | 사이트 Hosting 설정(`firebase.json`, 사이트별 target) |
| `.github/workflows/web.yml`, `.github/workflows/deploy-web.yml` | web 소유. §2의 "`deploy-*.yml`은 server" 규칙에 web 배포 예외를 더함 |

`docs/workflow.md` §2 소유 표, 루트 `CLAUDE.md` "나는 어떤 세션인가"(작업 디렉터리가 `web/` 아래면 web 세션), `web/CLAUDE.md`(현재 상태, 다음 할 일)를 지휘가 착수 안내 때 만듭니다.

### 스택 (사용자 승인 2026-11-25)
TypeScript, pnpm workspace. 사이트는 Astro(정적 생성), 상호작용이 필요한 조각만 React island. 패키지 관리자와 Node 버전은 저장소에 고정합니다(`packageManager`, `.nvmrc` 또는 같은 역할).

### 받는 계약
| 계약 | 주는 쪽 | 방식 |
| --- | --- | --- |
| 디자인 토큰 | design | `docs/identity/design/tokens/`를 빌드 때 읽음. 버전은 `docs/contracts/README.md` 표 |
| 원고 | writing | 웹 화면 슬롯 원고(형식은 writing이 app용 원고와 같은 원천에서 정함). writing 생성물을 web이 읽음 |
| 스토어 주소, 법적 문서 주소 | 지휘(대장) | 설정 파일 한 곳 |

`docs/contracts/README.md` 표에 web을 받는 쪽으로 더합니다. web은 아직 계약을 주지 않습니다.

## 5. 검사와 배포

### CI (`web.yml`, `web/**`가 바뀌면)
1. 설치(lockfile 고정), 타입 검사, lint, 단위 테스트
2. 토큰 생성물이 commit된 것과 같은지
3. Astro 빌드. 언어별 페이지와 OG 이미지가 다 생겼는지, 빠지면 실패
4. 화면 글 검사(D93), 깨진 내부 링크 검사
5. Playwright: 언어별 랜딩이 열리고, OG 태그가 있고, `app-ads.txt`가 루트에서 나옴

`ci-gate`에 web 갈래를 더합니다(변경 경로 판정, 필수 검사 이름은 그대로 `ci-gate`).

### 배포 (`deploy-web.yml`)
* staging 브랜치 push(`web/**`): staging Firebase 프로젝트의 Hosting 사이트에 배포.
* main 승격: prod Firebase 프로젝트에 배포. server처럼 GitHub environment 승인.
* 인증은 server 배포와 같은 Workload Identity 방식, 권한은 Hosting 배포만(server 배포 계정과 나눔).
* PR에서는 Hosting preview channel로 미리보기를 낼지 plan에서 정합니다(외부 PR 권한 고려).

### 호스팅과 주소
| 환경 | Firebase 프로젝트 | Hosting 사이트 | 주소 |
| --- | --- | --- | --- |
| staging | 기존 staging 프로젝트 | 새 사이트 | `staging.myungli-diary.app` |
| prod | 기존 prod 프로젝트 | 새 사이트 | `myungli-diary.app`, `www`는 본 도메인으로 |

Firebase Hosting은 한 프로젝트에 여러 사이트, 사이트마다 도메인, 본 도메인 연결, 도메인당 서브도메인 20개까지를 지원합니다(공식 문서, 2026-11-25 확인). WB2의 `social.`도 같은 방식으로 붙일 수 있습니다.

## 6. 사용자 준비물 (외부 준비물 E25로 안내)
1. 두 Firebase 프로젝트에 Hosting 사이트 추가(이름은 plan에서 정함)
2. Cloudflare DNS: `myungli-diary.app`(본 도메인), `www`, `staging` 기록을 Firebase가 주는 값으로. 프록시는 끔(인증서 발급)
3. 배포용 서비스 계정과 Workload Identity 연결, GitHub environment(staging, prod) 값. 절차는 web이 plan에서 server의 bootstrap 방식을 따라 씀
4. 랜딩이 prod에 뜬 뒤: AdMob 콘솔에서 `app-ads.txt` 한 줄 확인, 두 스토어 등록정보의 웹사이트 주소를 `https://myungli-diary.app`으로

## 7. 순서 (I4 전)
1. 지휘: 이 메모 승인 → plan → IA `web-landing` 슬롯, 로드맵, 소유 표, 착수 안내
2. 동시에:
   * writing: 원고
   * design: 시안 2~3안
   * 사용자: E25 1~3
   * web: 뼈대(workspace, 토큰 패키지, CI, 배포, 빈 랜딩)
3. 사용자가 시안을 고름 → web 구현 → staging 확인
4. 승격 → prod 확인 → E25 4

**끝나는 조건:** prod `myungli-diary.app`이 세 언어로 열리고 `app-ads.txt`가 루트에서 나오며, 두 스토어 등록정보의 웹사이트가 이 주소입니다.

## 8. 위험과 정할 것
* **Node 도구 체인이 처음 들어옴:** 의존성 갱신은 Dependabot 보안 업데이트만(다른 생태계와 같게), lockfile 고정.
* **시안 일정:** design 시안과 사용자 고르기가 늦으면 I4를 막습니다. 늦어지면 최소 판(텍스트, 배지, 링크)을 먼저 올리고 디자인을 뒤에 입힐 수 있게 뼈대 단계에서 최소 판도 배포 가능하게 둡니다.
* **plan에서 정할 것:** Hosting 사이트 이름, 원고 파일 형식, preview channel 여부, Node 버전.
