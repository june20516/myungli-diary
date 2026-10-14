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

## 현재 상태 (2026-10-14, writing 세션 작성)
* **W0 완료**(PR #36), 원국 개인 해석 슬롯(PR #73), 로마자 표기 정리(PR #77)가 main에 있습니다.
* **IA 슬롯 정렬**(브랜치 `writing/ia-slots`, spec `specs/2026-10-13-ia-slots-design.md`, 계획 `plans/2026-10-13-ia-slots.md`)
  * IA 124자리(ui 91, content 33)를 모두 슬롯 명세에 담았습니다. 검사기 v0.2.0이 `docs/ia/screens.json`과 대조합니다(`ia.*`).
  * 슬롯 명세 v1.1: `ia`·`components`·`select`·`vocative`, 값 종류 `text`(W20). ui 키는 IA id의 lowerCamelCase + 숫자·상태 이름(#90).
  * ui 원고는 `content/<lang>/ui.yaml`(en·ja는 원어민 검수 전 초안), ARB는 `generated/arb/app_<lang>.arb`(`mlw gen-docs`).
  * 호칭·조사 규칙 v1.1: 호칭 덩어리와 생략(W18, #69), 용어 id 77개와 `[[글자|용어 id]]`(W19).
  * 라운드 R8로 브랜드·정책 ui 문구와 앱 이름(ko 명리일기, en Myungli Diary, ja 命理日記)을 정했습니다(W17).
  * #54 글자 수 상한을 반영했습니다. 근거 슬롯 셋은 core 목록을 기다리는 키 없는 틀입니다(W21).
* 산출물 위치
  * 가이드: `guide/` (보이스·톤, 검수 절차, 호칭·조사)
  * 규칙: `rules/` (slop, limits, style, josa)
  * 슬롯 명세: `slots/_schema.yaml`, `slots/content/`, `slots/ui/`
  * 검사기: `tools/` (`mlw`), 원고: `content/<lang>/`
  * 생성 문서: `generated/`(슬롯 목록, IA 대응표, ARB 등), 라운드 기록: `artifacts/`, 설계·결정: `specs/`, `plans/`, `decisions.md`
* 검사기는 저장소 루트에서 실행합니다: `uv run --project docs/identity/writing/tools mlw <check | gen-docs | check-arb>`.
  * 원고 검사: `mlw check docs/identity/writing/content --partial`. 슬롯 `params`를 `core/message_params.json`과, 슬롯 자리를 IA와 대조합니다.
  * 생성 문서·ARB 최신 여부: `mlw gen-docs --check`
* 결정은 W1~W21입니다(`decisions.md`). 지휘가 정한 것 중 writing에 닿는 것: D57(문장 유형은 총운 슬롯만), D59(콘텐츠 렌더는 server, ARB는 app), D60(evidence 잠금), D62(아침 알림 호칭 없음), D66(server 웹 페이지 문구도 content 슬롯).
* 요청함은 GitHub Issues입니다(D44, `docs/workflow.md` §5.2).

## 다음 할 일
1. **IA 슬롯 정렬 PR을 병합**합니다. 병합되면 #15·#27·#42·#69·#90·#94·#116·#122가 닫힙니다. #52는 원국 개인 해석 원고(W1)가 남아 열어 둡니다.
2. **보낸 요청의 응답을 기다립니다.**
   - core #130: `rule_id`·`source_ref` 목록 → `explain.today_reason`·`evidence.basis`·`evidence.source`의 키를 채웁니다.
   - design #131: ui 이름 자리와 새 content 슬롯의 글자 수 상한 → `max_length`에 넣고 넘치는 원고를 고칩니다.
   - server #129(호칭 생략·용어 id·새 슬롯), #55(조사 렌더러·시드 CI)
   - app #128(공지): ARB를 가져가는지, `@@x-generated`가 문제없는지 확인합니다.
3. **지휘 확인 대상**: `consent.optional.label`의 선택 동의 항목(지금 "새 기능 소식 받기"), 계약 목록 갱신(슬롯 명세 v1.1, 호칭·조사 v1.1, 검사기 v0.2.0). 출시 전 `evidence-sheet.lock.reward`의 AdMob 보상 고지 문구(라운드 R8-4 선택에 "끝까지"가 없음)를 다시 봅니다.
4. **W1 직전에** LLM 판정 명령(slop 1차 거르기, W1 결정)을 만듭니다.
5. **W1:** 콘텐츠 3개 언어 원고(원국 개인 해석, 용어 뜻 77개, 일간 소개, 날의 성격 이유 포함)를 쓰고 원어민 검수를 받습니다. ui en·ja 초안도 함께 검수합니다. 스토어 태그라인은 R8-6("내 사주로 푼 오늘, 명리일기")에서 출발합니다.
   - W1 원고가 다 차면 `.github/workflows/writing.yml`의 `mlw check ... --partial`에서 `--partial`을 뺍니다.
