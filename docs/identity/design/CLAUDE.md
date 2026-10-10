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

## 현재 상태 (2026-10-10, design 세션 작성)
* **V0 시각 정체성 완료** (브랜치 `design/visual-identity`).
  * 기준 문서: [`visual-identity.md`](visual-identity.md). 시각에 관해서는 06을 대체합니다.
  * 근거: [V0 spec](specs/2026-10-10-visual-identity-design.md), 결정 V1~V7([`decisions.md`](decisions.md)).
  * 색 값의 출처: [`tools/palette.py`](tools/palette.py) (`--check`로 대비 검사, 32/32 통과).
  * 로고 원본: [`logo/`](logo/), 견본: [`specimen/index.html`](specimen/index.html), 시안 기록: [`artifacts/index.json`](artifacts/index.json).
* 테스트: 저장소 루트에서 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`
* 워드마크를 다시 만들려면 고운돋움 TTF가 필요합니다(`.suberpowers/fonts/`, 저장소에 넣지 않음). 받는 곳: `https://github.com/google/fonts/raw/main/ofl/gowundodum/GowunDodum-Regular.ttf`

## 다음 할 일
1. **V1 디자인 토큰 동결**
   - 토큰 데이터 형식과 Dart 코드 생성 방식을 app과 요청함으로 합의합니다. `palette.py`의 JSON 출력이 출발점입니다.
   - 날의 성격 배지 나머지 3종(귀인의 날·기신의 날·평범한 날)의 색을 정합니다.
   - 캘린더 길흉 점(엔진 `LuckLevel` 3단계)의 색 규칙을 정합니다.
   - 일본어 줄 간격을 실제 문장으로 확인합니다.
2. **V2 컴포넌트 명세**는 MVP 화면 목록(IA, D39)이 나온 뒤 시작합니다.
