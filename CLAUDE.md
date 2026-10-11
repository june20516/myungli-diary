# 명리일기 모노레포

이 파일은 저장소의 **모든 세션**이 읽습니다. 서브 프로젝트 디렉터리에서 시작한 세션도 함께 읽습니다. 상세 규약은 [`docs/workflow.md`](docs/workflow.md)에 있으며, 작업을 시작하기 전에 반드시 읽습니다.

## 나는 어떤 세션인가
* 작업 디렉터리가 **저장소 루트**면 → **지휘 세션**입니다. 아래 "지휘 세션" 절을 따릅니다.
* 작업 디렉터리가 `core/`, `server/`, `app/` 아래면 → 그 **서브 프로젝트 세션**입니다. 그 디렉터리의 `CLAUDE.md`를 따르고, 자기 소유 경로(`docs/workflow.md` §2) 밖은 고치지 않습니다.
* 작업 디렉터리가 `docs/identity/writing/` 또는 `docs/identity/design/` 아래면 → 그 **작업 단위 세션**(writing / design)입니다. 서브 프로젝트 세션과 같은 규칙을 따릅니다.

## 공통 규칙
* 서브 프로젝트끼리는 **계약 파일**(`docs/contracts/README.md`)과 **요청함**(GitHub Issues, `docs/workflow.md` §5.2)으로만 주고받습니다. 상대 서브 프로젝트의 코드를 직접 고치지 않습니다.
* 제품 결정의 기준은 [`docs/decisions.md`](docs/decisions.md)(D1~)입니다. 서브 프로젝트 결정이 이와 부딪히면 구현을 멈추고 요청함으로 올립니다.
* spec과 계획은 서브 프로젝트의 `docs/specs/`, `docs/plans/`에 둡니다. 작업 단위는 `docs/identity/<writing|design>/specs/`, `plans/`에 둡니다. suberpowers 기본 경로(`docs/suberpowers/…`)는 쓰지 않습니다.
* 같은 작업 디렉터리에서 세션 두 개를 동시에 돌리지 않습니다. 동시에 진행하려면 `git worktree`를 씁니다.

## 지휘 세션
* 맡는 일: 통합 로드맵([`docs/roadmap.md`](docs/roadmap.md)), 계약 목록 관리, 요청함(Issues) 분류(`accepted`/`rejected` 라벨), 둘 이상에 걸친 결정 기록, 서브 프로젝트 착수 안내(각 `CLAUDE.md`의 "현재 상태"와 "다음 할 일" 초안), 통합 시점 판단.
* 하지 않는 일: 서브 프로젝트 코드를 구현하지 않습니다.
* **정기 일과**(세션을 열 때마다): ① 열린 Issue 분류(`gh issue list`) ② `docs/roadmap.md` "현재 진행 순서" 갱신 ③ 제품 지도 갱신(`tools/product-map/README.md`).

## 문서 위치
| 문서 | 위치 |
| --- | --- |
| 제품 배경 (00~06) | `docs/background/` |
| 제품·아키텍처 결정 | `docs/decisions.md` |
| 통합 로드맵 | `docs/roadmap.md` |
| 제품 아이디어 함 | `docs/ideas.md` |
| 수익화 결정 체계 | `docs/business/` |
| 계약 목록 | `docs/contracts/README.md` |
| 제품 지도 (비공개 페이지) | https://claude.ai/artifact/GFLHjAufPE6F4qPyssdfsC (갱신: `tools/product-map/README.md`) |
| 요청함 | GitHub Issues (이관 전 문서 보관: `docs/coordination/`) |
| 엔진 위키·spec·계획·원전 근거 | `core/docs/` |
| 정체성 기준 (브랜드·라이팅·디자인) | `docs/identity/` |
