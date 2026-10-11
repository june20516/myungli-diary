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
| `core/message_keys.json` | **사용** (W1) | core — C2 완료로 사용 가능 |

## 현재 상태 (2026-10-11, writing 세션 작성)
* **W0이 끝났고 main에 병합했습니다**(PR #36 `7698f52`). 계약 3개(슬롯 명세 v1, 호칭·조사 v1, 검사기 v0.1.0)가 `docs/contracts/README.md`에 등록됐습니다.
* 산출물 위치
  * 가이드: `guide/` (보이스·톤, 검수 절차, 호칭·조사)
  * 규칙: `rules/` (slop, limits, style, josa)
  * 슬롯 명세: `slots/_schema.yaml`, `slots/content/`(콘텐츠 슬롯 15개), `slots/ui/depth.yaml`
  * 검사기: `tools/` (`mlw`), 예시 원고: `content/ko/example.yaml`
  * 생성 문서: `generated/`, 라운드 기록: `artifacts/`, 설계·결정: `specs/`, `decisions.md`
* 검사기는 저장소 루트에서 실행합니다: `uv run --project docs/identity/writing/tools mlw <check | gen-docs | ...>`.
  * 원고 검사: `mlw check docs/identity/writing/content` (미완성 원고는 `--partial`). 슬롯 `params`를 `core/message_params.json`과 대조합니다.
  * 생성 문서 최신 여부: `mlw gen-docs --check`
* 결정은 W1~W15입니다(`decisions.md`). 라운드 R1~R7 결과가 반영되어 있습니다. W4는 D57로 확정됐습니다.
* 지휘가 정한 것 중 writing에 닿는 것
  * D57: 문장 유형은 총운 슬롯에만 씁니다. 반응은 사용자 성향 자료입니다.
  * D59: 콘텐츠 문장의 저장·선택·렌더는 server가 합니다. 돌봄 상한(W14)도 server 선택 기록이 지킵니다. UI 문구(ARB)는 app이 합니다.
  * D60: evidence의 해석은 잠깁니다. 원국 개인 해석 원고가 W1에 더해집니다.
  * ARB 메시지 이름은 lowerCamelCase입니다.
* 요청함은 GitHub Issues입니다(D44, `docs/workflow.md` §5.2). `docs/coordination/`의 W0 요청 문서는 모두 처리됐거나 Issue로 옮겼습니다.

## 다음 할 일
1. **writing 앞으로 온 Issue**(`gh issue list --label to:writing`)를 처리합니다. 모두 `slots/`(특히 `slots/ui/`)에 반영할 일입니다. 지금은 깊이 이름(`ui/depth.yaml`)만 있습니다.
   - #15: IA v1 슬롯 목록(지금 109개)에 맞춥니다.
   - #27: 광고 제거권 ui 슬롯 6개를 반영합니다.
   - #42: V2 새 슬롯 3개(`onboard-time.hour.confirm`은 content)와 기존 슬롯 변형 3개를 반영합니다.
   - #52: D60 잠금 ui 슬롯 5개와 `evidence-sheet.personal.body`를 반영합니다. `ad-free.offer.head`는 역할이 바뀌었습니다.
2. **지휘가 전달할 server 질문에 답합니다**(#48)
   - 항목 4: 로그인 없는 미리보기에서 호칭이 든 문장을 어떻게 보일지 정합니다.
   - 항목 1: 아침 알림 슬롯(호칭 없음)은 IA에 추가되면 반영합니다.
3. **보낸 요청의 응답을 기다립니다.**
   - design #54: 글자 수 상한. 값이 오면 `slots/*.yaml`의 `max_length`에 반영합니다.
   - server #55: 조사 렌더러와 시드 CI
4. **W1 직전에** LLM 판정 명령(slop 1차 거르기, W1 결정)을 만듭니다.
5. **W1:** 콘텐츠 3개 언어 원고를 쓰고 원어민 검수를 받습니다. 원국 개인 해석과 사용자용 태그라인·스토어 문구도 W1입니다.
   - W1 원고가 다 차면 `.github/workflows/writing.yml`의 `mlw check ... --partial`에서 `--partial`을 뺍니다.
