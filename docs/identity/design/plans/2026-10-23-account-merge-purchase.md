# 계정 합치기 두 단계·구매 내역 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** D85 계정 합치기 두 단계와 D88 구매 내역(`purchase-row`)을 명세하고, #475 값 넷을 고쳐 컴포넌트 계약 3.0.0으로 올려 drift #480을 풉니다.

**Architecture:** 컴포넌트는 `components/<group>.json`(사실)과 `.md`(설명)에 적고 `tools/components.py`가 토큰·IA·패턴을 검사합니다. 글자 수는 `tools/lengths.py`의 `TARGETS`·`NO_LIMIT`로 재고, 그 출력을 `lengths.md`에 붙입니다. 테스트는 `tools/test_components.py`·`tools/test_lengths.py`입니다.

**Tech Stack:** Python 3 + pytest(저장소 루트에서 `uv run -q --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`), DTCG JSON

**Spec:** `docs/identity/design/specs/2026-10-23-account-merge-purchase-design.md`

## Global Constraints

* 고칠 수 있는 곳은 `docs/identity/design/`, `docs/contracts/README.md`의 컴포넌트 명세 행, GitHub Issues뿐입니다.
* 공개 저장소(D74): 가격·수익 수치, 실제 상품 id를 적지 않습니다.
* 문구 원고를 쓰지 않습니다. 문구는 슬롯·키 이름으로만 가리킵니다. 다른 계정은 "가져올 계정"이라고 부릅니다.
* MD의 "쓰는 화면" 줄은 IA 컴포넌트 목록과 같아야 합니다(`test_md_used_on_matches_ia_components`). IA `login-methods`에 `primary-button`이 들어오기 전까지 `action.md` `primary-button` 줄에 `login-methods`를 적지 않습니다.
* 커밋 꼬리: `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`, `Claude-Session: https://claude.ai/code/session_015UuApz6Ye5AAbvaZtRPFvh`.

## Review Focus

* `account-choice`에서 지운 부품(`facts`·`diaryCount`·`providers`)이나 키(`accountChoiceDiaryCount`·`accountChoiceProviderSeparator`)를 MD·규칙·테스트가 아직 가리키는지.
* 인증 단계의 `social-login-button`이 `connected`로 그려질 여지가 남았는지(로그인 화면과 같은 버튼이어야 함).
* 가져올 기록이 모두 0일 때 요약 상자가 사라지는 문장이 없는지.
* 상품 이름이 두 줄일 때 `status`가 첫 줄에 붙는지(`purchase-row` `status.align`).
* `offer-card` `offline`에서 `history`가 막히지 않는지.

---

### Task 1: 로그인 수단 입구·계정 합치기 두 단계·`account-choice` (V44)

**Files:**
- Modify: `components/input.json`(`account-choice`), `components/input.md`(`## account-choice`, `### account-merge 화면 배치`)
- Modify: `components/action.json`(`social-login-button` `rules`), `components/action.md`(`## social-login-button` 쓰는 화면 줄, `### login-methods 화면 배치`)
- Modify: `components/feedback.json`(`dialog` `notice` `when`), `components/feedback.md`(`notice` 문단)
- Test: `tools/test_components.py`

**Interfaces:**
- Produces: `account-choice.parts.other`(`slot` `ui.account-merge.choice`, `key` `accountChoiceOther`). 가져올 기록 상자는 컴포넌트 부품이 아니라 화면 배치(MD)이고 슬롯은 `ui.account-merge.summary`입니다. Task 2가 `SLOTS_OUTSIDE_IA`에 이 슬롯을 더합니다.

- [ ] **Step 1: 실패하는 test 작성**
  * `test_account_choice_card_lines` 고침:
    * `parts`에 `facts`·`diaryCount`·`providers`가 없음.
    * `parts["other"]`는 `current`와 `type`·`fg`·`border`·`radius`·`paddingX`가 같고, `slot == "ui.account-merge.choice"`, `key == "accountChoiceOther"`.
    * `card`·`current`·`saju`·`mark` 단언은 그대로.
  * `test_d82_writing_keys_are_named`에서 `providers` 단언을 지움(`connected` 단언만 남김).
  * 새 `test_account_choice_chooses_profile_not_account`:
    * `summary`에 "사주 정보·호칭·설정"과 "V44"가 들어 있음.
    * `rules`에 "처음부터 어느 쪽도 골라 두지 않는다"가 남고, 그 문장에 "지워져"가 들어 있음.
  * 새 `test_account_merge_two_steps_layout`(`input.md`의 `### account-merge 화면 배치` 절):
    * "인증 단계"와 "요약·고르기 단계"가 있음.
    * `account-merge.auth.body`·`account-merge.not-other.body`·`ui.account-merge.summary`가 있음.
    * "0이어도"가 있음.
    * "합치지 않기" 버튼이 없다는 문장(`"합치지 않기\" 버튼이 없습니다"`)이 있음.
    * "뒤로 가기는 동작하지 않습니다"가 있음.
    * `account-merge.cta.cancel`은 IA 삭제 요청 문장 안에만 있음.
  * 새 `test_login_methods_merge_entry`(`action.md`의 `### login-methods 화면 배치` 절):
    * `login-methods.merge.cta`와 `quiet`가 있음.
    * `login-methods.in-use.body`와 `notice`가 있음.
    * "저절로 넘어가지 않습니다"가 있음.
    * 옛 문장 "`account-merge`로 넘어갑니다"가 없음.
  * 새 `test_dialog_notice_covers_d85_bodies`: `dialog` `notice` 변형의 `when`에 `login-methods.in-use.body`와 `account-merge.not-other.body`가 있음.
- [ ] **Step 2: 실행** — `... pytest docs/identity/design/tools/test_components.py -q -k "account_choice or account_merge or login_methods_merge or dialog_notice or d82_writing"` / Expected: 새·고친 test FAIL(KeyError `other`, 문장 없음)
- [ ] **Step 3: 구현** — spec §2·§3대로.
  * `input.json` `account-choice`:
    * `summary`를 spec §3.3 문장으로.
    * `facts`·`diaryCount`·`providers`를 지움.
    * `other`를 더함: `current`와 같은 모양, `key` `accountChoiceOther`, `onlyWhen` "가져올 계정 카드", `position` "호칭 뒤 같은 줄".
    * `current.onlyWhen`은 "지금 계정 카드"로.
    * `rules`: 첫 문장 이유를 "고르지 않은 쪽의 사주 정보·호칭·설정은 지워져 되돌릴 수 없다"로. 수단 이름 규칙 둘(로고·감기)을 지움. "카드 순서는 지금 계정 → 가져올 계정" 규칙을 더함.
  * `input.md`:
    * `## account-choice` 절을 spec §3.3으로.
    * `### account-merge 화면 배치`를 spec §3.1·§3.2로 바꿈. 결정 V40·V44.
    * IA 삭제 요청 문장: "`account-merge.cta.cancel` 슬롯과 출구는 IA에서 지우도록 지휘에 요청했습니다".
  * `action.md`:
    * `## social-login-button` 쓰는 화면 줄을 `login, login-methods, account-merge`로.
    * 인증 단계 메모 한 줄: account-merge에서는 `connected`를 쓰지 않음.
    * `### login-methods 화면 배치`를 spec §2로. 옛 "넘어갑니다" 문장을 지움.
  * `action.json` `social-login-button` `rules`에 "account-merge 인증 단계는 login과 같은 버튼이고 connected를 쓰지 않는다"를 더함.
  * `feedback.json` `dialog` `notice` `when`에 두 슬롯을 더함. `feedback.md`의 `notice` 문단도 같게.
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 이 task의 test PASS. `test_md_used_on_matches_ia_components`의 `social-login-button` 실패가 사라짐. 남는 실패는 `purchase-row`(Task 2)·`ad-free.restore.cta`(Task 2)·글자 수(Task 4)뿐.
- [ ] **Step 5: Commit** — `feat(design): 계정 합치기 두 단계와 account-choice 쓰임 바뀜 (V44, #483)`

### Task 2: `offer-card` 구매 내역 버튼·`purchase-row`·구매 내역 배치 (V45)

**Files:**
- Modify: `components/action.json`(`offer-card`, 새 `purchase-row`), `components/action.md`(`## offer-card`, 새 `## purchase-row`와 `### purchase-history 화면 배치`)
- Test: `tools/test_components.py`

**Interfaces:**
- Consumes: Task 1의 `ui.account-merge.summary` 이름
- Produces: 컴포넌트 `purchase-row`(`action` 묶음), 부품 `product`·`status`·`meta`·`row`·`group`. IA 밖 슬롯 `ui.purchase-row`

- [ ] **Step 1: 실패하는 test 작성**
  * `test_generic_groups_contain_spec_components`의 `action` 기대에 `purchase-row`를 더함.
  * `SLOTS_OUTSIDE_IA`에 `ui.account-merge.summary`·`ui.purchase-row`를 더함.
  * `test_offer_card_states`에 단언을 더함:
    * `"restore" not in offer["parts"]`
    * `offer["parts"]["history"] == {"component": "primary-button", "variant": "quiet", "slot": "ad-free.history.cta"}`
    * `"history" not in offer["states"]["offline"]["parts"]`
    * `any("구매 내역 버튼은 상태와 관계없이 늘 보인다" in r for r in offer["rules"])`
    * `offer["haptic"] == [{"when": "구매 완료", "strength": "light"}]`
  * 새 `test_purchase_row`:
    * `parts.product`: `type == "{type.subtitle}"`, `overflow == "wrap"`, `fallback`에 "스토어"가 들어 있음.
    * `parts.status`: `active == {"element": "tag.status"}`, `other["type"] == "{type.label.md}"`, `other["fg"] == "{color.text.secondary}"`, `align == "product-first-line"`.
    * `parts.meta`: `type == "{type.caption.lg}"`, `fontFeatures == ["tnum"]`, `periodOnlyWhen`에 "기간"이 들어 있음.
    * `parts.row.divider == {"color": "{color.line}", "width": {"value": 1, "unit": "px"}, "between": "rows-only"}`.
    * `parts.group`: `bg == "{color.bg.sheet}"`, `radius == "{radius.lg}"`.
    * `"pressed" not in states`, `states["loading"]["component"] == "skeleton"`.
    * `rules`에 "server" 순서 문장과 "합치기" 출처를 표시하지 않는다는 문장이 있음.
  * 새 `test_purchase_history_layout`(`action.md`의 `### purchase-history 화면 배치` 절):
    * `purchase-history.missing.notice`와 "늘 보입니다"가 있음.
    * `receipt`, `empty-state`가 있음.
- [ ] **Step 2: 실행** — `... -k "generic_groups or offer_card or purchase"` / Expected: FAIL
- [ ] **Step 3: 구현** — spec §4·§5대로.
  * `offer-card`:
    * `restore` → `history`. `offline.parts`에서 `restore`를 뺌.
    * `rules`와 `haptic`을 고침.
    * `action.md` `## offer-card`(카드 구성 문장, 상태 표 `offline`, 늘 보임 문장)를 고침.
  * `purchase-row`:
    * `summary` "산 상품의 구매 한 건 (D88 ②, 결정 V45)", `uses` `["tag.status", "skeleton.bone"]`.
    * 부품 값은 spec §5.1 표 그대로. `product`: `slot` `ui.purchase-row`, `key` `purchaseProduct*`, `fallback` "스토어의 현지화된 상품 이름".
    * `a11y` `{ "role": "none", "label": "상품 이름, 상태, 구매일, 사용 기간" }`.
  * `action.md` 새 `## purchase-row` 절:
    * 첫 줄 `* 쓰는 화면: purchase-history`.
    * 그 아래 `### purchase-history 화면 배치`(spec §5.2).
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q`와 `python3 docs/identity/design/tools/components.py` / Expected: 이 task의 test PASS, 검사기의 "purchase-row: 명세가 없음"이 사라짐. 남는 실패는 글자 수(Task 4)뿐.
- [ ] **Step 5: Commit** — `feat(design): 구매 내역 purchase-row와 offer-card 구매 내역 버튼 (V45, #494)`

### Task 3: #475 값 넷 (V46)

**Files:**
- Modify: `components/action.json`(`social-login-button` `connected` `logo.badge.kakao.symbol`, `line` 변형 `label.width`), `components/action.md`(카카오 배지 색, LINE 글자 폭)
- Modify: `components/diary.json`(`diary-row` `parts.entry.time.format`, `parts.entry.chevron.marginStart`), `components/diary.md`(`entry` 표)
- Modify: `components/calendar.json`(`event-row` `time`에 `format`), `components/calendar.md`(`event-row` 한 줄)
- Test: `tools/test_components.py`

- [ ] **Step 1: 실패하는 test 작성** — 새 `test_issue_475_values`:
  * 카카오 배지: `badge["kakao"] == {"bg": "#FEE500", "symbol": "#191919", "shape": "{radius.xs}"}`.
  * LINE: `line` 변형 `parts.label.width == {"value": 198, "unit": "px"}`, `parts.label.widthSource`에 "공식"이 들어 있음.
  * `entry.chevron.marginStart == "{space.8}"`.
  * `entry.time.format == "HH:mm"`, `entry.time.hourCycle == "h23"`.
  * `event-row`의 `time` 부품도 `format == "HH:mm"`·`hourCycle == "h23"`.
  * `diary.md`에서 "기기 locale의 짧은 시각"이 사라짐.
- [ ] **Step 2: 실행** — `... -k issue_475` / Expected: FAIL
- [ ] **Step 3: 구현** — spec §6 표대로.
  * `entry.time`: `format` "HH:mm", `hourCycle` "h23", `note` "event-row와 같은 24시간제, 앞 0 채움(V46)".
  * `action.md` `connected` 문단의 "카카오 `#FEE500` 위 검정"을 "`#191919`(공식 자산)"로.
  * LINE 항목에 "글자 자리 198px(공식 자산 구분선 비율, V46)".
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 이 task의 test PASS
- [ ] **Step 5: Commit** — `fix(design): 카카오 배지·LINE 글자 폭·entry 꺾쇠 간격·24시간제 시각 (V46, #475)`

### Task 4: 글자 수 (`tools/lengths.py`, `lengths.md`)

**Files:**
- Modify: `tools/lengths.py`, `lengths.md`
- Test: `tools/test_lengths.py`

**Interfaces:**
- Produces: `KEY_TARGETS: dict[tuple[str, str], Target]`(슬롯, 키 → 그 키만 따로 재는 칸). `render_table`은 이 칸의 측정값을 "키별 상한" 표에 언어마다 한 행씩 냅니다(writing 파서가 읽는 같은 행 모양 `| 언어 | \`슬롯\` | \`키\` | **상한** | 이유 |`).

- [ ] **Step 1: 실패하는 test 작성**
  * `test_d82_ia_slots_are_measured`의 화면 목록에 `ad-free`·`purchase-history`를 더함. 단, `purchase-history.empty.body`는 빼고 봄(빈 상태 문장은 재지 않음, spec §8).
    * `places["login-methods.merge.cta"]`·`places["ad-free.history.cta"]`가 `primary-button`으로 시작.
    * `"ad-free.restore.cta"`가 어느 target에도 없음.
  * `test_every_requested_slot_has_a_value_or_no_limit`:
    * 기대 집합에서 `ad-free.restore.cta`를 빼고, `ISSUE_480` 집합을 더함: `login-methods.merge.cta`, `ad-free.history.cta`, `account-merge.auth.body`, `purchase-history.missing.notice`, `ui.account-merge.summary`, `ui.purchase-row`.
    * `NO_LIMIT` 기대에 `login-methods.in-use.body`, `account-merge.not-other.body`를 더함.
  * 새 `test_line_label_is_measured_at_198`:
    * `lengths.KEY_TARGETS[("ui.login.provider", "loginLineLabel")].width == 198`
    * `font == "ui-600"`, `size == 14`.
  * `test_latin_ja_label_takes_en_limit`의 `KEY_LIMITS` 단언은 그대로.
- [ ] **Step 2: 실행** — `... pytest docs/identity/design/tools/test_lengths.py -q` / Expected: FAIL
- [ ] **Step 3: 구현** — spec §8 표대로.
  * `primary-button` target: `ad-free.restore.cta`를 `ad-free.history.cta`로 바꾸고 `login-methods.merge.cta`를 더함(주석 "D85·D88 (#480)").
  * 새 `Target`:
    * `account-merge.auth.body`: `ui-400`, 14, −0.28, `CONTENT_WIDTH`, 3, True
    * `purchase-history.missing.notice`: `ui-400`, 13, −0.26, `CONTENT_WIDTH - 8`, 2, True
    * `ui.account-merge.summary`: `ui-400`, 14, −0.28, `CONTENT_WIDTH - 32 - 56`, 1, False. 값 자리 56은 "광고 제거 남은 기간"의 값 "30일"(본문 14px)보다 넉넉한 폭.
    * `ui.purchase-row`: 상태 낱말 꼬리표 폭 기준. `ui-500`, 12, −0.24, `80 - 16`, 1, False. meta 줄은 날짜가 대부분이라 이 슬롯의 이름 자리 낱말만 잽니다.
  * `NO_LIMIT`에 두 확인 창 본문을 더함. 이유는 "확인 창 본문(창이 늘어남)".
  * `KEY_TARGETS`: `("ui.login.provider", "loginLineLabel")` → `Target(("ui.login.provider",), "LINE 버튼 글자 (공식 자산 구분선 비율 198px, V46)", "ui-600", 14, -0.28, 198, 1, False, None)`.
  * `render_table`이 `measure(...)`의 `KEY_TARGETS` 결과를 키별 상한 표에 ko·ja·en 세 행으로 더함. `measure`를 한 번 더 부르도록 `main`에서 넘김.
  * 저장소 루트 `.suberpowers/fonts`가 없으면 `python3 docs/identity/design/tools/fonts.py`로 받은 뒤, `python3 docs/identity/design/tools/lengths.py --font-dir .suberpowers/fonts` 출력으로 `lengths.md`의 표를 바꿈.
  * `lengths.md` 설명에 3.0.0 문단 한 줄을 더함(바뀐 행·LINE 키별 폭·`cta.cancel`은 IA에서 지워질 때까지 남김).
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 전체 PASS(글꼴 test 포함, skip 없음)
- [ ] **Step 5: Commit** — `feat(design): 계정 합치기·구매 내역 글자 수와 LINE 라벨 198px (#480, #475)`

### Task 5: 컴포넌트 계약 3.0.0

**Files:**
- Modify: 모든 `components/*.json` `version`, `tools/components.py` `CONTRACT_VERSION`, `components/README.md`(계약 줄, 버전 표 3.0.0 행, 결정 범위 V13~V46), `../../contracts/README.md` 컴포넌트 명세 행
- Test: `tools/test_components.py`

- [ ] **Step 1: 실패하는 test 작성** — `test_contract_version_is_2_8`을 `test_contract_version_is_3_0`(`VERSION == "3.0.0"`)으로.
- [ ] **Step 2: 실행** — `... -k contract_version` / Expected: FAIL
- [ ] **Step 3: 구현** — 버전 일괄 변경.
  * README 3.0.0 행: "D85·D88(#480·#483·#494): `account-choice` 쓰임 바뀜(`facts`·`diaryCount`·`providers` 삭제, `other` 추가), `account-merge` 두 단계·`login-methods` 합치기 입구(V44), `offer-card` `restore` → `history`, `purchase-row` 새 컴포넌트(V45), #475 값(V46). 부품 삭제라 major".
  * 계약 행에 같은 요지와 "app은 지운 부품을 쓰는 곳을 고쳐야 함" 한 문장.
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q`와 `python3 docs/identity/design/tools/components.py` / Expected: 전체 PASS, 검사기 문제 0
- [ ] **Step 5: Commit** — `feat(design): 컴포넌트 계약 3.0.0 (#480)`

### Task 6: 결정·시안 기록·현재 상태

**Files:**
- Modify: `decisions.md`(V44·V45·V46, spec §9 문장, 근거 칸에 `사용자 영향:` 표시), `artifacts/index.json`(`design-v2-account-merge-purchase`, status `chosen`, decisions V44·V45, screens `login-methods`·`account-merge`·`ad-free`·`purchase-history`), `CLAUDE.md`(현재 상태 맨 앞 항목, 다음 할 일에서 #480·#483·#494·#475 제거)
- Create: `artifacts/2026-10-23-v2-account-merge-purchase.png`(시안 HTML을 doctype·meta로 감싸 Chrome headless로 캡처)

- [ ] **Step 1:** 시안 PNG 캡처(라이트, 전체 페이지).
- [ ] **Step 2:** 기록 세 파일 수정.
- [ ] **Step 3: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 전체 PASS
- [ ] **Step 4: Commit** — `docs(design): V44~V46 결정과 시안 기록 (#480)`

### Task 7: 요청 Issue와 마무리

- [ ] 지휘 Issue(`from:design`, `to:root`, `kind:request`), spec §7:
  * IA `login-methods`에 `primary-button`을 더함.
  * IA `account-merge`에서 `account-merge.cta.cancel`과 "합치지 않기" 출구를 지움.
  * server 요약 항목을 전달.
- [ ] writing Issue(`from:design`, `to:writing`, `kind:request`), spec §7 ①~⑥.
- [ ] `CLAUDE.md` 다음 할 일에 두 Issue의 대기 항목을 적고 commit.
- [ ] 최종 review 뒤 `git push -u origin design/catchup-480-d85-d88`, PR 생성. 본문은 `Closes #480`·`#483`·`#494`·`#475`와 참고 줄만.
