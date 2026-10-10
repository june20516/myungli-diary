# writing — 라이팅 시스템

이 디렉터리에서 시작한 세션은 **writing 세션**입니다. 루트 [`CLAUDE.md`](../../../CLAUDE.md)와 [`docs/workflow.md`](../../workflow.md)의 공통 규약을 함께 따릅니다. 기준 문서는 [`docs/identity/README.md`](../README.md)(브랜드 기반)입니다.

## 범위
명리일기의 모든 문장(화면 문구와 콘텐츠 문장)이 따를 라이팅 시스템을 만들고, 그 시스템으로 콘텐츠를 씁니다. 상세는 [브랜드 기반 spec §8](../../specs/2026-10-10-brand-foundation-design.md)에 있습니다.

| 산출물 | 받는 쪽 | 마일스톤 |
| --- | --- | --- |
| 보이스·톤 가이드: README의 성격 표를 어휘·문장 구조·문장 맺음·구두점 규칙으로 옮긴 것 | 모두 | W0 |
| 슬롯 명세 틀, 그리고 IA(D39)가 나온 뒤 슬롯 목록 | server, app | W0 (목록은 IA 이후) |
| slop 패턴 목록 (원칙 0 기준, README의 8개 패턴에서 출발) | 모두 | W0 |
| 친숙도 검수 절차 | 지휘(사용자) | W0 |
| 검사기 (`tools/`): 슬롯 목적 인지 규칙 + 빈도·밀도 상한 | server 시드 CI, app CI | W0 |
| 호칭 접미사("님"·"さん")·조사 처리·호칭 입력 검증 규칙 | server 콘텐츠 모듈 | W0 |
| 사용자용 태그라인·스토어 문구 | 출시(I4) | W1 |
| 콘텐츠 3개 언어(D28) → 원어민 검수 → server 시드 파일 | server | W1 |

* **슬롯 명세가 담을 항목:** 사용 위치(화면·컴포넌트), 목적, 사용자 상태, 문장 구조, 문장 유형(`advice`·`state`·`care`, D40), 용어 범주(깊이 단계별 허용 용어, D37), 우선 문장 맺음, 톤 좌표, 언어별 글자 수 상한, 필수 정보와 엔진 파라미터, 변주 수와 순환 규칙, 목적별 허용 표현 범위, 금지 패턴, 좋은 예·나쁜 예, 잘림·스크린리더 처리.
* **참고할 접근법:** Mailchimp Content Style Guide(보이스와 톤 분리), NN/g 톤의 4차원, Torrey Podmajersky 『Strategic Writing for UX』(voice chart), Kinneret Yifrah 『Microcopy: The Complete Guide』, Sarah Richards·GOV.UK 콘텐츠 디자인, 토스 UX 라이팅 원칙(인용 전 원문 확인).
* **친숙도 검수:**
  * 사람 검수는 n지선다 라운드로 합니다. writing 세션이 선택지를 내고 사용자가 고릅니다.
    * 선택지에 "다 별로"를 항상 둡니다.
    * slop 대조군을 숨겨 섞고, 같은 문항을 순서를 바꿔 다시 냅니다.
    * 일부 선택지는 실제 커뮤니티·리뷰 표현에서 가져오고, 출처는 고른 뒤 공개합니다.
  * 한국어 레퍼런스: 브런치, 블라인드, 다음카페, 네이트판, 더쿠, 인스티즈 같은 온건한 커뮤니티와 커머스 리뷰.
    * 대량 수집(크롤링)은 하지 않고, 표현 단위로 검색해 실제 쓰임을 확인합니다.
    * 자동 빈도 비교에는 합법적으로 쓸 수 있는 말뭉치(국립국어원 모두의 말뭉치 등)를 씁니다.
  * 영어·일본어는 같은 기준으로 레퍼런스를 고르되, 원어민 검수를 대신하지 않습니다.

## 고칠 수 있는 곳
`docs/identity/writing/`, GitHub Issues(요청·보고 작성, `gh issue list --label to:writing`). 받은 notice: Issue #8(메시지 키 규모). 그 밖은 읽기만 합니다. 콘텐츠를 server 시드 파일로 넣는 일은 server가 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (슬롯 목록의 선행 조건) | 지휘 |
| 슬롯 명세 | **제공** | server, app |
| 검사기 | **제공** | server 시드 CI, app CI |
| 호칭·조사 처리 규칙 | **제공** (W0에서 형식을 정해 계약 등록을 요청) | server |
| 글자 수 상한 | **주고받음** (요청함) | design |
| `core/message_keys.json` | **사용** (W1, core C2 이후) | core |

## 현재 상태 (2026-10-10, 지휘 세션 작성)
* **설계 시작 전**입니다.
* IA(D39)는 지휘 세션이 아직 만들지 않았습니다. 그래서 W0은 슬롯 명세 틀, slop 패턴, 검수 절차, 검사기부터 시작합니다.

## 다음 할 일
1. 읽을 것:
   - [`../README.md`](../README.md)와 [브랜드 기반 spec](../../specs/2026-10-10-brand-foundation-design.md)
   - `docs/decisions.md`의 D13, D19~D24, D27, D28, D36~D40
   - `docs/background/` 00·03 (원문의 예시 문구는 slop 사례로 읽습니다)
2. worktree와 브랜치를 만들고 그 안으로 옮겨 세션을 시작합니다. 원래 checkout은 다른 세션이 다른 브랜치로 쓰고 있을 수 있고, 그 브랜치에는 `docs/identity/`가 없을 수 있습니다. 그래서 원래 checkout의 이 디렉터리로 들어가지 않고, 아래 명령을 저장소 루트에서 그대로 실행합니다.
   ```
   git fetch origin
   git worktree add ../myungli-diary-writing -b writing/system-foundation --no-track origin/main
   cd ../myungli-diary-writing/docs/identity/writing && claude
   ```
3. brainstorming으로 W0 spec을 작성합니다 → `docs/identity/writing/specs/`
4. 친숙도 검수 라운드는 사용자와 n지선다로 진행합니다.
