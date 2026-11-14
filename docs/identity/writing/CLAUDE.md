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

로컬 값은 [`docs/local-values.md`](../../local-values.md)(D98)를 따릅니다. 원본은 `$MYUNGLI_LOCAL_DIR/writing/<환경>/`, 키는 경로로만 넘기고 내용을 출력하지 않습니다.

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


## 검사 방법
* 검사기는 저장소 루트에서 실행합니다: `uv run --project docs/identity/writing/tools mlw <check | gen-docs | check-arb | judge>`.
  * 원고 검사: `mlw check docs/identity/writing/content`(W1 원고가 다 차서 `--partial` 없이 돌립니다. 일부러 비워 둔 원고는 슬롯 `pending`, W49). 슬롯 `params`를 `core/message_params.json`과, 근거 슬롯 키를 `core/evidence_*.json`과, 슬롯 자리를 IA와 대조합니다.
  * `engine.proto`가 바뀌면 `tools/gen_proto.sh`로 생성 코드를 다시 만듭니다(CI가 차이를 막습니다).
  * 생성 문서·ARB 최신 여부: `mlw gen-docs --check`
  * LLM 1차 거르기: `mlw judge docs/identity/writing/content --lang ko [--slot <id>]`(로컬 `claude` CLI 필요)
  * **로컬 빠른 경로(반복 중, D81):** 바뀐 범위만 돌리고, PR 전에 한 번 전체를 돌립니다.
    * 원고·슬롯 명세만 고쳤을 때: `mlw check docs/identity/writing/content`와 `mlw gen-docs --check`(ui 원고면 `mlw check-arb docs/identity/writing/generated/arb/*.arb`도)
    * 검사기 코드를 고쳤을 때: `docs/identity/writing/tools`에서 `uv run pytest -q tests/test_<모듈>.py`, PR 전에 `uv run pytest -q`(전체 약 15초)와 `uv run ruff check .`·`uv run mypy src`
    * 계약(IA·core JSON·proto·design `lengths.md`)이 바뀌었을 때: `uv run pytest -q -m contract`와 위 원고 검사. CI `drift`·`gate`도 이 범위만 돕니다(`writing.yml`)
    * 테스트는 한 실행 안에서 같은 원고 읽기와 묶음 검사 결과를 다시 씁니다(`tests/session_cache.py`, 키는 파일 내용 해시). 공유 원고를 고치는 테스트는 `tmp_path` 사본을 쓰고, 고치면 세션 끝 확인이 실패합니다

## 산출물 위치
* 가이드: `guide/` (보이스·톤, 검수 절차, 호칭·조사)
* 규칙: `rules/` (slop, limits, style, josa)
* 슬롯 명세: `slots/_schema.yaml`, `slots/content/`, `slots/ui/`
* 검사기: `tools/` (`mlw`), 원고: `content/<lang>/`
  * ui 원고는 `content/<lang>/ui.yaml`(en·ja는 원어민 검수 전 초안), ARB는 `generated/arb/app_<lang>.arb`(`mlw gen-docs`). 용어 한자는 언어와 상관없이 `content/hanja.yaml` 한 벌입니다.
  * ui 키는 IA id의 lowerCamelCase + 숫자·상태 이름(#90). D77로 IA에 올린 기존 문구는 키를 바꾸지 않고 `ui.*` 슬롯에 `ia`로 적습니다(W20 개정, W33).
  * 글자 수 상한은 design `lengths.md` 값이고 테스트가 대조합니다(W26). 상한 없음은 `unbounded`, 확인 창은 키별 상한 `key_max_length`, design 측정 전은 `null`입니다.
* 생성 문서: `generated/`(슬롯 목록, IA 대응표, ARB 등), 라운드 기록: `artifacts/`, 설계·결정: `specs/`, `plans/`, `decisions.md`
* 결정은 `decisions.md`(W#)입니다. 통째로 대체된 결정의 원문은 `decisions-history.md`에 있습니다. 지휘가 정한 것 중 writing에 닿는 것: D57(문장 유형은 총운 슬롯만), D59(콘텐츠 렌더는 server, ARB는 app), D60(evidence 잠금), D62(아침 알림 호칭 없음), D66(server 웹 페이지 문구도 content 슬롯), D70~D72(ja 용어 근거, 계산 기준 표현, 부정 신호와 잠금), D74(공개 저장소), D76(오늘 화면 대표 태그 칩), D77(ui 문구를 IA 슬롯으로 둘지의 기준), D78(규칙 정합성 점검: 일부 처리 Issue는 `참고 #`, D77 문구는 ARB 키 유지), D93(사용자에게 보이는 글에 긴 대시·범위 대시·가운뎃점 금지, `style.S9`).
* 요청함은 GitHub Issues입니다(D44, `docs/workflow.md` §5.2).

## 현재 상태
* 계약 버전과 상태는 [`docs/contracts/README.md`](../../contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.
* 여기에는 진행 중인 일(브랜치, 열린 PR, 막힌 것)만 적고, 병합하면 지웁니다(`docs/workflow.md` §3 마무리 2번). 병합된 일의 경과는 PR 본문, `decisions.md`, git에 있습니다.
* **진행 중:** H1 기준 문서 정리(#1167, D131), 브랜치 `writing/h1-slimming-1167`.

## 다음 할 일
1. **열린 `drift` Issue가 있으면 먼저 맞춥니다**(`gh issue list --label drift --label to:writing`, `docs/workflow.md` §6.1).
2. **`null` 상한 채우기:** design 상한이 나오면 슬롯 `max_length`의 `null`을 채웁니다. IA v5 새 슬롯, `login.save.note`, DS1 2단계 새 슬롯(`ui.saju.luck-period`, `ui.my-saju.record`, `ui.tag-sheet.sentence-kind`), 미리보기 입력 확인과 질문 떼기 슬롯(W64)이 대상입니다.
3. **W51 후속:** ATT 본문은 AdMob IDFA 안내 게시 문구와 어긋나지 않는지 확인이 남았습니다(사용자가 콘솔에서 확인).
4. **ui 조사 후속:** app이 `josaClass`를 구현했습니다(#570). 회피 때문에 어색해진 ui 문구부터 조사 표기로 고칩니다(키마다 app에 알림).
5. **쓰지 않는 키 정리:** `errorDiaryDateTaken`은 app이 쓰지 않게 되면 지웁니다(D83). app이 `todayEventSummary`·`todayEventSummaryDone`을 쓰지 않는다고 알려 주면 지웁니다(#217).
6. **server 확인:** server CI(`server.yml`)의 `mlw check --partial`은 server가 뺄 수 있다고 알립니다. 근거 basis 매개변수 종류가 바뀌어(W48) server 시드가 새 원고를 쓰는지 봅니다. server는 `content/hanja.yaml`로 `Glossary.hanja`를 채웁니다.
7. **재출제 대기:** en 지장간 자리 표기("year hidden stem"), R9-15 재성 가이드(W31 ② 전제 기준).
8. **지휘 확인 대상:** 출시 전 `evidence-sheet.lock.reward`의 AdMob 보상 고지 문구(라운드 R8-4 선택에 "끝까지"가 없음)를 다시 봅니다.
