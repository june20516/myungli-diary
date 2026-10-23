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
| 콘텐츠 3개 언어(D28) → server 시드 파일. 원어민 검수는 사용자가 감수자를 구하면 하는 보강 단계(D70) | server | W1 |

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
`docs/identity/writing/`, `.github/workflows/writing.yml`(검사기 CI), `docs/contracts/README.md`의 writing 행(슬롯 명세·호칭 조사·검사기·라운드 원고), GitHub Issues(요청·보고 작성, `gh issue list --label to:writing`). 그 밖은 읽기만 합니다. 콘텐츠를 server 시드 파일로 넣는 일은 server가 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (슬롯 목록의 선행 조건) | 지휘 |
| 슬롯 명세 | **제공** | server, app |
| 검사기 | **제공** | server 시드 CI, app CI |
| 호칭·조사 처리 규칙 | **제공** (계약 표에서 확정) | server |
| 글자 수 상한 표 (`docs/identity/design/lengths.md`) | **사용** (슬롯 `max_length` 원본, 테스트가 대조, W26). 상한 조정은 요청함 | design |
| 라운드 원고 (`artifacts/*-round-R*.md`) | **제공** (design `tools/lengths.py`가 고른 문장으로 상한을 잼, R1~R8 고정) | design |
| `core/message_keys.json` | **사용** (W1) | core — C2 완료로 사용 가능 |
| `core/message_params.json` | **사용** (슬롯 `params` 대조) | core |
| `core/evidence_rules.json`·`core/evidence_sources.json` | **사용** (근거 슬롯 키·`detail` 매개변수·원전 원문 대조, W25) | core |
| 엔진 gRPC API (`engine.proto`) | **사용** (검사기 생성 코드 `tools/gen_proto.sh`, #144) | core |

## 현재 상태 (2026-10-23, writing 세션 작성)
* 계약 버전과 상태는 [`docs/contracts/README.md`](../../contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.
* **W0 완료**(PR #36), 원국 개인 해석 슬롯(PR #73), 로마자 표기 정리(PR #77), IA 슬롯 정렬(PR #132), IA v2(PR #138), ci-gate 1단계(PR #145), 공용 ui 문구(PR #155), 오늘·근거 시트 문구(PR #162), IA v3(PR #185), drift·근거 슬롯(PR #228), W1 전 정리(PR #230), LLM 판정(PR #235), W1-1 오늘 화면(PR #249), W1-2 사주·개인 해석(PR #254)이 main에 있습니다.
* **맺음 검사 없앰**(W43, 검사기 v0.10.0): `style.S3`·`style.S8`과 슬롯 `register`를 지우고, 맺음 현황 명령 `mlw endings`(화면별 해요체·합니다체 분포, 막지 않음)를 더했습니다. 맺음은 쓸 때 문장마다 고릅니다. 라운드 R18(`artifacts/2026-10-23-round-R18.md`): 계산 기준 화면의 규칙 문장과 계정 삭제 확인의 고지 문장을 합니다체로 바꿨습니다(키 이름 그대로).
* **합치기 토큰 오류**(#482, REST draft.15, 라운드 R17 `artifacts/2026-10-23-round-R17.md`, W42): `merge.token_invalid` 문구 `errorMergeTokenInvalid`("가져올 계정을 다시 인증해 주세요")를 더하고, code가 없어진 `errorAuthIdentityPendingDeletion`을 지웠습니다. `merge.same_account`·`merge.no_account`는 `account-merge.not-other.body`(`Self`·`None`)가 맡습니다.
* **D85·D86·D88 원고**(drift #479, #482·#487·#495, 라운드 R15 `artifacts/2026-10-23-round-R15.md`, W40): IA 새 슬롯 10개(인증 수단 연결 거절, 합치기 입구·인증·합칠 계정 없음, 구매 내역, 미리보기 다시 입력, 대운수)와 구매 줄 낱말·상품 이름, `ad-free.restore.cta` 삭제, 합치기 제목·설명·묶음 이름, 계정 삭제 안내(보관 고지), 시간 모름 안내(시주를 뺀 계산). 맺음은 슬롯 `register`로 나눕니다(W40, 검사기 v0.9.0). design #509(라운드 R16, W41): 합칠 다른 계정은 "가져올 계정", 요약 상자 `ui.account-merge.summary`, 구매 줄 `ui.purchase.status`·`ui.purchase.meta`·`ui.purchase.product`. `account-merge.cta.cancel`은 IA에서 빠져 지웠습니다(#511).
* **REST draft.14 오류 문구**(#468, 라운드 R14 `artifacts/2026-10-22-round-R14.md`, W39): `ui.error.code`에 인증 수단 오류 키 5개를 더했고, `merge.token_invalid`는 `accountMergeError`를 썼습니다(→ W42). 따로 쓰던 "수단"을 "인증 수단"으로 바꿨습니다(기존 키 세 개의 문구).
* **ui 원고의 조사**(spec `specs/2026-10-22-ui-josa-design.md`, 계획 `plans/2026-10-22-ui-josa.md`, W38): ko ui 원고에 조사 표기를 쓸 수 있고, ARB 생성 때 ICU `select`(`pJosa`)로 펼칩니다. app은 `josaClass`로 채웁니다(호칭·조사 규칙 v1.2, 검사기 v0.8.0). 원고에 처음 쓰는 것은 app의 `josaClass` 완료 보고 뒤입니다.
* **계정 합치기 원고 보완·상한**(design #441, drift #443, 라운드 R13 `artifacts/2026-10-22-round-R13.md`): `lengths.md` 2.7.0 상한을 D82 슬롯에 넣고, 떼기 확인을 제목·본문 키로 나눴습니다(`loginMethodsUnlinkConfirmBody`). 수단 줄은 `social-login-button` connected(`loginMethodsRowConnected` "연결됨", `loginMethodsRowLink` 삭제), "현재 계정", 사주 요약 슬롯 `ui.account-merge.saju`, 수단 구분자, 합치기 오류는 `dialog`. 확인 창의 "기본 선택은 취소"를 지웠습니다(V41). ja 카카오 라벨 "Login with Kakao"(16자)가 새 상한 15자를 넘어 design에 다시 재 달라고 했습니다(#446). 그 전에는 `mlw check`가 막힙니다.
* **D83 ② 상한 문구**(#425, 라운드 R12 `artifacts/2026-10-22-round-R12.md`, W37): 상한을 채운 날의 쓰는 입구 `todayGuideCtaFull`·`daySheetDiaryWriteCtaFull`·`diaryListPickDateConfirmFull`과 오류 `errorDiaryDayFull`("충분히 썼어요", 상한 수치 없음). 이미 쓴 날의 버튼을 "새 일기 쓰기"로 바꿨습니다. `errorDiaryDateTaken`은 server가 `diary.date_taken`을 없애고 app이 쓰지 않게 되면 지웁니다.
* **D82·D83 원고**(#388·#409, 라운드 R11 `artifacts/2026-10-22-round-R11.md`, W36): 로그인 수단·계정 합치기 IA ui 슬롯 13개(`slots/ui/account.yaml`, app-bar 제목 2개는 `app-bar.yaml`)의 키와 3개 언어 원고, LINE·Google 로그인 라벨(제공자 가이드 문구), IA 밖 `ui.*` 4개(제공자 이름·연결 동작, 합칠 계정 요약, 합치기 실패, 설정 줄). D83: 쓰는 입구는 언제나 새 일기라 `todayGuideCtaWritten`·`diaryListPickDateConfirm`을 쓰기 문구로, `daySheetDiaryOpen`을 편수 머리(`count`)로 바꾸고 `daySheetDiaryWriteCtaWritten`을 더했습니다. W36: 안내·확인 문구는 막는 말 대신 남는 것·필요한 것. drift #413(PR #416)은 생성 ARB 갱신. 상한은 design 측정 전이라 `null`입니다.
* **IA D77 따라잡기**(PR #279, W33, #278·#275 일부): IA ui 슬롯 9개를 `ia` 필드로 담고(ARB 키 이름 그대로), `ui.event-edit.form`의 버튼·안내 4개를 키별 슬롯으로 나눴습니다. 일기 저장 버튼·삭제 toast 원고(`diaryEditSave`·`diaryViewDeleted`).
* **검사 범위 정리**(PR #369, D81, W35, #361): `writing.yml`에 `mode` 입력(`own`·`drift`·`gate`), `drift`·`gate`는 계약 검사만(`pytest -m contract`·`mlw check`·`gen-docs --check`·proto 대조). 테스트 세션 캐시로 전체 테스트 42초 → 14초.
* **생일 음력 입력 문구**(PR #328, W34, #313): 양력 확인 줄 `datePickerSolarConfirm({date})`, 음력 안내를 월 휠 윤달 방식으로 고침, 윤달 체크 `leapMonth` 삭제.
* **기본 깊이 설정 삭제**(PR #326, D79, #317·#323): 설정 이름·설명과 설정에만 쓰던 단계 이름(요약·원리) 원고를 3개 언어에서 지우고 W15를 개정했습니다. `depthExplain`(풀이 시트 접근성 라벨)·`depthLinkEvidence`는 남깁니다. design이 `lengths.md`에서 해당 행을 지우고 `ui.depth.explain`을 상한 없음으로 둔 것을 따라잡았습니다(PR #371, #372).
* **규칙 정합성 점검·남은 ui 원고**(PR #297, D78, #283·#268·#260·#275): W20 개정(D77 예외), 원어민 검수는 보강 단계(D70), 가이드 질문 W31 ③ 기준을 voice-tone에, 사용 계약 행 정리. 오류 문구 `errorCityNotFound`·`errorTimezoneInvalid`, 윤달 초하루 표지 `dayCellLeapNewMoon`(en `L{month}.1`은 칸 폭 때문에 한 글자 표지), 일기 보기 아이콘 라벨과 태그 칩 틀·길흉 낱말.
* **jev 판정 평가**(PR #263, `artifacts/2026-10-20-jev-evaluation.md`, W32): `mlw judge` 본 판정은 `claude -p` 그대로입니다. jev는 갈린 문장 17건 중 15건이 오탐이었습니다. `--shadow jev`와 기록은 남깁니다. `claude -p`도 사람이 문제로 본 문장을 많이 놓쳐, W1-3 라운드에서 judge 표시와 사용자 선택을 함께 봅니다.
* **W1-2 사주·개인 해석**(PR #254, 계획 `plans/2026-10-16-w1-2-chart.md`, W31, #52·#237)
  * 명식(`chart.*` 24)·원국 개인 해석(`personal.*` 60)과 그 문장에 끼우는 값 이름 조각 35개(element·color·place·role·strength·luck·part, W1-3에서 당김)의 3개 언어 원고. ja 조각은 W24 용어 표기 그대로이고, 빈 3개(閑神·極身弱·極身強)는 W1-3.
  * 라운드 R10(`artifacts/2026-10-17-round-R10.md`, W31): 개인 해석 둘째 문장은 오행 역할 사실, 오행 목·화·토·금·수, 역할 "나와 잘 맞는 기운"류. 가이드 질문 기준 ①②(과거형, 전제 없음) 확정과 3개 언어 23건 반영.
  * #237 오류 문구 3건(`ui.error.code`).
* **W1-1 오늘 화면·엔진 안내**(PR #249, spec `specs/2026-10-16-w1-content-design.md`, 계획 `plans/2026-10-16-w1-1-today.md`, W28~W30, #232·#240)
  * 오늘 화면 content 슬롯(총운·가이드·카드·태그·이유·달력)과 새 엔진 안내 슬롯 `system.notice`의 3개 언어 원고(en·ja는 원어민 검수 전 초안). 오늘 화면 대표 태그 뜻은 `term.tag.*`(D76).
  * 라운드 R9(`artifacts/2026-10-16-round-R9.md`): 총운 state만 호칭, 보조 문장 토큰 없음. 가이드 질문 기준·태그라인은 보류.
  * `mlw judge --shadow jev`(W30)와 첫 라운드 판정 쌍 `artifacts/judge-shadow/`. 대체 가능성 평가는 위 jev 판정 평가(W32). jev 키는 저장소 밖 `~/.config/myungli/typesafe.key`.
* **LLM 판정 명령**(PR #235, W27): `mlw judge`가 `judge: llm` slop 규칙을 루브릭으로 `claude -p`에 물어 의심 문장을 `warn`으로 표시합니다(로컬 1차 거르기, 막지 않음, CI 밖). 사용법은 `guide/review-procedure.md`.
* **W1 전 정리**(PR #230, W26, #191·#217·#226)
  * design 글자 수 상한(`docs/identity/design/lengths.md`)을 슬롯 91개에 넣었습니다. 상한 없음은 `unbounded`, 확인 창은 키별 상한 `key_max_length`입니다. 테스트가 lengths.md와 대조합니다.
  * 달력·일정 공용 문구(`ui.calendar.nav`·`ui.day-cell.a11y`·`ui.event-row.label`·`ui.event-edit.form`)와 일정 요약 키 `todayEventSummaryNextAt`·`AllPast`.
  * 용어 한자 표기 `content/hanja.yaml`(63개)과 검사(`hanja.*`).
* **drift·근거 슬롯·서머타임**(PR #228, W25): 근거 슬롯 키를 core 근거 목록으로 채우고 검사기가 대조(`evidence.*`), app-bar 제목 24개, 서머타임 경도 키, 옛 키 `calcBasisLongitudeBody` 제거.
* **IA v3·D70~D72**(PR #185, W24): IA v3 ui 슬롯 3개, 출생 시간대별 경도 키, glossary ja 근거 표기(91개, 閑神·極身弱·極身強은 비움), D72 규칙 `style.S7`.
* **공용 ui 문구·ICU plural**(PR #155, spec `specs/2026-10-15-ui-leftovers-design.md`, 계획 `plans/2026-10-15-ui-leftovers.md`, W22): 공용 ui 슬롯(`slots/ui/common.yaml`), glossary 지지·날의 성격·방향 이름(`content/<lang>/glossary.yaml`, ARB로도 나감), ICU plural(`icu.plural`, ui 원고만), glossary ARB 내보내기(`arb.duplicate_key`). `writing.yml`은 ci-gate만 부릅니다(#148).
* **IA 슬롯 정렬**(spec `specs/2026-10-13-ia-slots-design.md`, 계획 `plans/2026-10-13-ia-slots.md`)
  * IA의 모든 자리를 슬롯 명세에 담고, 검사기가 `docs/ia/screens.json`과 대조합니다(`ia.*`). IA ui 자리는 149개입니다(IA v4, app-bar 제목 PR #205, D77 9개와 날짜 시트 버튼 #298, D82 13개, D85·D86·D88 10개 포함, D79로 기본 깊이 설명, D88로 구매 복원 버튼, #511로 합치지 않기 버튼 빠짐).
  * 슬롯 명세 필드 `ia`·`components`·`select`·`vocative`, 값 종류 `text`(W20). ui 키는 IA id의 lowerCamelCase + 숫자·상태 이름(#90). D77로 IA에 올린 기존 문구는 키를 바꾸지 않고 `ui.*` 슬롯에 `ia`로 적습니다(W20 개정, W33).
  * ui 원고는 `content/<lang>/ui.yaml`(en·ja는 원어민 검수 전 초안), ARB는 `generated/arb/app_<lang>.arb`(`mlw gen-docs`). 용어 한자는 언어와 상관없이 `content/hanja.yaml` 한 벌입니다.
  * 호칭·조사 규칙: 호칭 덩어리와 생략(W18, #69), 용어 id 77개와 `[[글자|용어 id]]`(W19).
  * 라운드 R8로 브랜드·정책 ui 문구와 앱 이름(ko 명리일기, en Myungli Diary, ja 命理日記)을 정했습니다(W17).
  * #54 글자 수 상한을 반영했습니다. 근거 슬롯 셋은 core 목록을 기다리는 키 없는 틀입니다(W21).
* 산출물 위치
  * 가이드: `guide/` (보이스·톤, 검수 절차, 호칭·조사)
  * 규칙: `rules/` (slop, limits, style, josa)
  * 슬롯 명세: `slots/_schema.yaml`, `slots/content/`, `slots/ui/`
  * 검사기: `tools/` (`mlw`), 원고: `content/<lang>/`
  * 생성 문서: `generated/`(슬롯 목록, IA 대응표, ARB 등), 라운드 기록: `artifacts/`, 설계·결정: `specs/`, `plans/`, `decisions.md`
* 검사기는 저장소 루트에서 실행합니다: `uv run --project docs/identity/writing/tools mlw <check | gen-docs | check-arb | judge>`.
  * 원고 검사: `mlw check docs/identity/writing/content --partial`. 슬롯 `params`를 `core/message_params.json`과, 근거 슬롯 키를 `core/evidence_*.json`과, 슬롯 자리를 IA와 대조합니다.
  * `engine.proto`가 바뀌면 `tools/gen_proto.sh`로 생성 코드를 다시 만듭니다(CI가 차이를 막습니다).
  * 생성 문서·ARB 최신 여부: `mlw gen-docs --check`
  * LLM 1차 거르기: `mlw judge docs/identity/writing/content --lang ko [--slot <id>]`(로컬 `claude` CLI 필요)
  * **로컬 빠른 경로(반복 중, D81):** 바뀐 범위만 돌리고, PR 전에 한 번 전체를 돌립니다.
    * 원고·슬롯 명세만 고쳤을 때: `mlw check docs/identity/writing/content --partial`과 `mlw gen-docs --check`(ui 원고면 `mlw check-arb docs/identity/writing/generated/arb/*.arb`도)
    * 검사기 코드를 고쳤을 때: `docs/identity/writing/tools`에서 `uv run pytest -q tests/test_<모듈>.py`, PR 전에 `uv run pytest -q`(전체 약 15초)와 `uv run ruff check .`·`uv run mypy src`
    * 계약(IA·core JSON·proto·design `lengths.md`)이 바뀌었을 때: `uv run pytest -q -m contract`와 위 원고 검사. CI `drift`·`gate`도 이 범위만 돕니다(`writing.yml`)
    * 테스트는 한 실행 안에서 같은 원고 읽기와 묶음 검사 결과를 다시 씁니다(`tests/session_cache.py`, 키는 파일 내용 해시). 공유 원고를 고치는 테스트는 `tmp_path` 사본을 쓰고, 고치면 세션 끝 확인이 실패합니다
* 결정은 W1~W41입니다(`decisions.md`). 지휘가 정한 것 중 writing에 닿는 것: D57(문장 유형은 총운 슬롯만), D59(콘텐츠 렌더는 server, ARB는 app), D60(evidence 잠금), D62(아침 알림 호칭 없음), D66(server 웹 페이지 문구도 content 슬롯), D70~D72(ja 용어 근거, 계산 기준 표현, 부정 신호와 잠금), D74(공개 저장소), D76(오늘 화면 대표 태그 칩), D77(ui 문구를 IA 슬롯으로 둘지의 기준), D78(규칙 정합성 점검: 일부 처리 Issue는 `참고 #`, D77 문구는 ARB 키 유지).
* 요청함은 GitHub Issues입니다(D44, `docs/workflow.md` §5.2).

## 다음 할 일
1. **열린 `drift` Issue가 있으면 먼저 맞춥니다**(`gh issue list --label drift --label to:writing`, `docs/workflow.md` §6.1).
2. **ui 조사 후속**: app이 `josaClass`를 구현했다고 보고하면, 회피 때문에 어색해진 ui 문구부터 조사 표기로 고칩니다(키마다 app에 알림).
3. **D82·D83 후속**: app이 D82·D83 키 변화(`daySheetDiaryOpen({count})`, `loginMethodsRowLink` 삭제, `loginMethodsUnlinkConfirmBody` 등, #418)를 따라잡는지 봅니다. `errorDiaryDateTaken`은 app이 쓰지 않게 되면 지웁니다.
   - 다음은 #355(`force-update` 사유별 키, 사유 `select`)와 #331(app 임시 문구 28개, 사주 사전 범주, 사주 맥락 근거 시트 제목)입니다.
4. **W1-2는 PR #254로 병합됐습니다(지휘 2026-10-20).** server는 사주·개인 해석 원고를 시드에 넣습니다. 단 ja glossary의 빈 3개(role.neutral·strength.very_weak·strength.very_strong)를 W1-3에서 채우기 전에는 ja 개인 해석이 그 값에서 렌더되지 않습니다(#52 코멘트). app은 오류 문구 3건을 씁니다(#237).
5. **#217 후속:** app이 `todayEventSummary`·`todayEventSummaryDone`을 쓰지 않는다고 알려 주면 writing이 지웁니다. server는 `content/hanja.yaml`로 `Glossary.hanja`를 채웁니다.
6. **W1-3**(지금 할 일. core #258(원전 `quote` 번체 원문 여부) 답은 기다리지 않고 지금 `quote`를 글자 그대로 씁니다. spec `specs/2026-10-16-w1-content-design.md` §2): W1-3 용어·근거(용어 뜻 나머지 62개, glossary 값 이름, 근거 basis·source). 묶음마다 ko → `mlw judge`(실행 전 호출 수·토큰 예고) → 라운드 → en·ja. 라운드 기록에 judge 표시와 사용자 선택을 함께 남겨 루브릭을 다듬을지 봅니다(W32). 스토어 태그라인(R8-6과 R9-11이 다름)을 다음 라운드에서 확정합니다. ja glossary의 빈 3개 값과 en 지장간 자리 표기("year hidden stem")도 W1-3에서 봅니다. R9-15 재성 가이드("오늘 돈을 쓴 곳 하나…")는 W31 ② 전제 기준에 걸리므로 다음 라운드에서 다시 묻습니다. 콘텐츠 3개 언어 원고를 쓰고, `mlw judge`로 거른 뒤 의심 문장을 검수 라운드로 봅니다. 원어민 검수는 완료 조건이 아니라 사용자가 감수자를 구하면 하는 보강 단계입니다(D70, W1 spec §7). 근거 basis의 매개변수 종류는 spec §4대로 바꿉니다(core `detail` 값 형식은 조사 완료). ui en·ja 초안도 함께 검수합니다. 스토어 태그라인은 R8-6("내 사주로 푼 오늘, 명리일기")에서 출발합니다.
   - W1 원고가 다 차면 `.github/workflows/writing.yml`의 `mlw check ... --partial`에서 `--partial`을 뺍니다.
7. **보낸 요청의 응답을 기다립니다.**
   - server #129(호칭 생략·용어 id·새 슬롯), #55(조사 렌더러·시드 CI)
   - 지휘 #158 코멘트: 閑神·極身弱·極身強 근거 보강, 용어집의 忌神 읽기 통일(きじん)
8. **지휘 확인 대상**: 출시 전 `evidence-sheet.lock.reward`의 AdMob 보상 고지 문구(라운드 R8-4 선택에 "끝까지"가 없음)를 다시 봅니다.
