# design — 디자인 시스템

이 디렉터리에서 시작한 세션은 **design 세션**입니다. 루트 [`CLAUDE.md`](../../../CLAUDE.md)와 [`docs/workflow.md`](../../workflow.md)의 공통 규약을 함께 따릅니다. 기준 문서는 [`docs/identity/README.md`](../README.md)(브랜드 기반)입니다.

## 범위
명리일기의 시각 정체성, 디자인 토큰, 컴포넌트 명세를 만듭니다. 구현(Flutter)은 app이 합니다. 상세는 [브랜드 기반 spec §7·§9](../../specs/2026-10-10-brand-foundation-design.md)에 있습니다.

| 산출물 | 받는 쪽 | 마일스톤 |
| --- | --- | --- |
| 시각 정체성: 로고 방향, 그라데이션 규칙, 오행 팔레트, 타이포 | 모두 | V0 |
| 디자인 토큰 (`tokens/`, 데이터 파일) | app (Dart 코드 생성) | V1 동결 |
| 캘린더 길흉 점의 색 규칙 (엔진 spec §8 `LuckLevel` 3단계, 루트 미결에서 이관) | app | V1 |
| 컴포넌트 명세 (`components/`): 데일리 카드(L1 레이아웃), 용어 토큰, 날의 성격 배지, 칩, 깊이 시트 단계 | app | V2 |

* `docs/background/06-design-system.md`는 V0의 입력입니다. V0 결과가 정체성 기준으로 06을 대체합니다.
* 그라데이션은 조건부 선택입니다(README "시각 방향"). 토큰 하나로 묶어, 리뉴얼할 때 그 토큰만 바꾸면 되게 합니다.
* 사용자는 제품 작업을 컴포넌트부터 설계하기를 원합니다. app의 UI 구현은 V2 뒤에 시작합니다.

## 고칠 수 있는 곳
`docs/identity/design/`, `docs/coordination/`(요청·보고 작성). 그 밖은 읽기만 합니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (V2의 선행 조건) | 지휘 |
| 디자인 토큰 | **제공** (V1에서 동결) | app |
| 컴포넌트 명세 | **제공** | app |
| 글자 수 상한 | **주고받음** (요청함) | writing |

## 현재 상태 (2026-10-10, 지휘 세션 작성)
* **설계 시작 전**입니다.
* 브랜드 기반 시안은 지휘 세션 로컬(`.suberpowers/brainstorm/`, git 제외)에만 있습니다. V0에서 정식 시안으로 다시 그립니다. 시안 색 값은 README "시각 방향"에 있습니다.

## 다음 할 일
1. 읽을 것:
   - [`../README.md`](../README.md)와 [브랜드 기반 spec](../../specs/2026-10-10-brand-foundation-design.md) §7·§9
   - `docs/background/06-design-system.md`
   - `docs/decisions.md`의 D16, D19, D20, D36, D37
2. 저장소 루트에서 worktree와 브랜치를 만들고, 그 worktree의 `docs/identity/design`에서 세션을 시작합니다.
   ```
   git worktree add ../myungli-diary-design -b design/visual-identity --no-track main
   ```
3. brainstorming으로 V0 spec을 작성합니다 → `docs/identity/design/specs/`
4. 토큰 파일 형식(JSON 등)과 Dart 코드 생성 방식은 app과 요청함으로 합의합니다.
