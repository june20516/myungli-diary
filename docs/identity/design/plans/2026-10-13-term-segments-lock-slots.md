# 문장 조각 용어 표시·근거 잠금 슬롯 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 컴포넌트 명세를 2.1.0으로 올려 `sentence-block`의 `term` 조각 그리기 규칙과 근거 잠금 ui 슬롯 8개를 적습니다.

**Architecture:** 명세는 `components/*.json`(사실)과 같은 이름의 `.md`(설명)입니다. 검사기 `tools/components.py`가 IA·토큰·버전을 확인하고, `tools/test_components.py`가 명세 값을 고정합니다. 새 테스트는 `term-token` 화면 목록과 슬롯 이름을 IA(`docs/ia/screens.json`)에서 계산해 명세와 비교합니다.

**Tech Stack:** JSON, Markdown, Python 3 표준 라이브러리, pytest 8.3.5

**Spec:** `docs/identity/design/specs/2026-10-13-term-segments-lock-slots-design.md`

## Global Constraints

* 명령은 저장소 루트(`/Users/bran/personal/myungli-diary-design`)에서 실행합니다. 테스트: `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`
* 고칠 수 있는 곳은 `docs/identity/design/`과 GitHub Issues뿐입니다.
* 추가만 합니다. 기존 구성 요소·필드의 이름이나 값의 형태를 바꾸지 않습니다(부 버전 2.1.0). 예: `a11y.lockedLabel` 문자열은 그대로 두고 `lockedLabelSlot`을 더합니다.
* 새 토큰 참조는 없습니다.
* 문서는 한국어 경어체, 기술 용어는 원어(freeze, slot 등)를 씁니다.
* 커밋 메시지 끝에 다음 두 줄을 붙입니다.
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01M5j9pAd5XdCPfS6sQDutR4
  ```

## Review Focus

1. 명세의 슬롯 이름 오타(예: `evidence-sheet.section.basic`): app이 없는 키로 문구를 찾습니다. 모든 새 슬롯이 IA `evidence-sheet`·`saju-chart` 슬롯에 있어야 합니다. Task 2·3 테스트가 확인합니다.
2. IA가 나중에 `term-token` 화면을 바꿈: 명세의 `segments.term.screens`가 IA와 어긋납니다. Task 2 테스트가 IA에서 계산한 집합과 같은지 봅니다.
3. 잠겼을 때 구역 제목까지 흐려짐: `locked` 상태의 `evidenceSheet`에 제목 구성 요소가 `lock.veil`로 들어가면 안 됩니다. Task 3 테스트가 확인합니다.
4. 버전을 일부 파일만 올림: 검사기가 잡습니다(`test_committed_component_files_pass_all_checks`). Task 1에서 돌립니다.
5. 기존 2.0.0 필드가 바뀜(주 버전 위반): Task 2·3 테스트가 `a11y.lockedLabel` 등 기존 문자열이 그대로인지 봅니다.

---

### Task 1: 계약 버전 2.1.0

**Files:**
- Modify: `docs/identity/design/tools/components.py:20` (`CONTRACT_VERSION`)
- Modify: `docs/identity/design/components/*.json` 11개의 최상위 `"version"`(icon set의 `"version": "2.1.2"`는 건드리지 않음)
- Modify: `docs/identity/design/components/README.md` (첫 줄 계약 버전, 버전 표)
- Test: `docs/identity/design/tools/test_components.py:430`

**Interfaces:**
- Produces: `components.CONTRACT_VERSION == "2.1.0"`

- [ ] **Step 1: 테스트 고치기.** `test_contract_version_is_2`를 `test_contract_version_is_2_1`로 바꾸고 `assert VERSION == "2.1.0"`로 고칩니다.
- [ ] **Step 2: 실패 확인.** `... pytest docs/identity/design/tools/test_components.py::test_contract_version_is_2_1 -q` → FAIL(`'2.0.0' == '2.1.0'`)
- [ ] **Step 3: 구현.**
  * `CONTRACT_VERSION = "2.1.0"`
  * JSON 11개의 최상위 `"version": "2.0.0"` → `"2.1.0"`
  * README 첫 줄을 `컴포넌트 계약 2.1.0 · 토큰 계약 1.1.0 이상을 기대합니다.`로 고칩니다.
  * README 버전 표에 다음 행을 더합니다.
    ```
    | 2.1.0 | 2026-10-13 | 문장 조각(`segments`)의 용어 표시: 칩은 `term-token`이 있는 화면에서만(V28). 근거 잠금 ui 슬롯: `sentence-block` 열기, 근거 시트 구역 제목·해제 실패 toast·접근성 문구 |
    ```
  * README 근거 줄에 `[문장 조각·잠금 슬롯 spec](../specs/2026-10-13-term-segments-lock-slots-design.md)`을 더하고 `V13~V27`을 `V13~V28`로 고칩니다.
- [ ] **Step 4: 전체 테스트 통과.** pytest 전체와 `python3 docs/identity/design/tools/components.py`가 문제 없이 끝나야 합니다(출력 없음, 종료 코드 0).
- [ ] **Step 5: Commit.** `chore(design): 컴포넌트 계약 2.1.0`

### Task 2: `sentence-block` 조각 그리기와 열기 슬롯

**Files:**
- Modify: `docs/identity/design/components/sentence.json` (`sentence-block`)
- Modify: `docs/identity/design/components/sentence.md` (근거 줄, `## sentence-block`)
- Modify: `docs/identity/design/components/saju.md:49`
- Test: `docs/identity/design/tools/test_components.py` (끝에 추가)

**Interfaces:**
- Consumes: Task 1의 버전
- Produces: `sentence-block.parts.segments`(아래 값), `states.locked.parts.open.slot`, `a11y.lockedLabelSlot`

- [ ] **Step 1: 실패하는 테스트 작성.** IA를 읽는 도우미를 하나 두고 두 테스트를 더합니다.

```python
def ia_screens():
    return {screen["id"]: screen for screen in json.loads(IA_PATH.read_text(encoding="utf-8"))["screens"]}


def ia_slot_ids(screen_id):
    return {slot["id"] for slot in ia_screens()[screen_id]["slots"]}


# 문장 조각과 잠금 슬롯 (term-segments spec §2·§3)
def test_term_segments_draw_chip_only_where_term_token_is():
    block = components_by_id(BRAND_GROUPS)["sentence-block"]
    term = block["parts"]["segments"]["term"]
    assert term["component"] == "term-token" and term["variant"] == "inline"
    expected = {sid for sid, screen in ia_screens().items() if "term-token" in screen.get("components", [])}
    assert set(term["screens"]) == expected
    assert term["elsewhere"] == "plain"
    assert block["parts"]["segments"]["plain"] == {"style": "same-as-text"}


def test_locked_sentence_open_slot():
    block = components_by_id(BRAND_GROUPS)["sentence-block"]
    assert block["states"]["locked"]["parts"]["open"]["slot"] == "saju-chart.yongsin.open"
    assert block["a11y"]["lockedLabelSlot"] == "evidence-sheet.a11y.locked"
    assert block["a11y"]["lockedLabel"] == "구역 이름 + '잠김', 열기는 따로 초점(link)"
    assert {"saju-chart.yongsin.open"} <= ia_slot_ids("saju-chart")
    assert "evidence-sheet.a11y.locked" in ia_slot_ids("evidence-sheet")
```

- [ ] **Step 2: 실패 확인.** 두 테스트 → FAIL(`KeyError: 'segments'`, `KeyError: 'slot'`)
- [ ] **Step 3: `sentence.json` 구현.** `sentence-block.parts`에 다음 `segments`를 더합니다.

```json
"segments": {
  "join": "조각을 순서대로 한 문단으로 잇는다. 경계에 공백·줄바꿈을 넣지 않는다",
  "plain": { "style": "same-as-text" },
  "term": {
    "component": "term-token",
    "variant": "inline",
    "screens": ["today", "day-sheet", "tag-diary", "my-saju", "saju-chart"],
    "elsewhere": "plain",
    "wrap": "용어 안에서 끊지 않음. 한국어는 공백 없이 붙은 앞뒤 글자(조사)까지 한 덩어리, 일본어는 용어 앞뒤만 글자 단위 + 금칙. 용어가 한 줄보다 길 때만 용어 안에서 끊음"
  }
}
```

  * `states.locked.parts.open`에 `"slot": "saju-chart.yongsin.open"`을 더합니다.
  * `a11y`에 `"lockedLabelSlot": "evidence-sheet.a11y.locked"`, `"plainTerm": "일반 글자로 그린 term 조각은 따로 초점 없이 문장과 함께 읽음"`을 더합니다.
  * `rules`에 다음 세 줄을 더합니다.
    * `"term 조각은 term-token이 있는 화면(segments.term.screens)에서만 term-token inline으로 그린다. 그 밖의 화면과 공유 이미지에서는 일반 글자다(결정 V28)."`
    * `"term-token 라벨은 화면에 보이는 text를 쓴다. term 값은 풀이를 찾는 키라 읽지 않는다."`
    * `"근거 잠금은 term 표시를 바꾸지 않는다. 잠긴 내용은 오지 않고, 풀이 시트는 무료다(D60)."`
  * 예시 화면 목록은 IA와 맞춥니다(테스트가 확인).
- [ ] **Step 4: `sentence.md` 구현.**
  * 근거 줄에 `[문장 조각 spec](../specs/2026-10-13-term-segments-lock-slots-design.md)`과 `V28`을 더합니다.
  * `## sentence-block`에 다음 소절을 더합니다.
    * **"문장 조각(`segments`)"**: spec §2.1 표, §2.2 이어 붙이기, §2.3 줄바꿈, §2.4 접근성, §2.5 잠금과 무관함을 짧게 적습니다. 예시는 `{"text":"편관","term":"편관"}`입니다.
    * 고르지 않은 안 두 개를 한 줄씩 적습니다.
  * `locked` 설명에 "열기" 문구 슬롯 `saju-chart.yongsin.open`을 적습니다.
- [ ] **Step 5: `saju.md:49` 고치기.** "IA `saju-chart`의 컴포넌트 목록에 `sentence-block`을 넣어 달라고 지휘에 요청했습니다." 문장을 지우고, "열기" 슬롯 `saju-chart.yongsin.open`을 적습니다.
- [ ] **Step 6: 통과 확인.** 새 테스트 2개와 전체 pytest가 통과하고, 검사기 종료 코드가 0이어야 합니다.
- [ ] **Step 7: Commit.** `docs(design): sentence-block 문장 조각 용어 표시와 열기 슬롯 (V28)`

### Task 3: 근거 시트 슬롯 (`depth-link`)

**Files:**
- Modify: `docs/identity/design/components/sentence.json` (`depth-link`)
- Modify: `docs/identity/design/components/sentence.md` (`### 근거 시트`, `### 잠김과 해제`)
- Test: `docs/identity/design/tools/test_components.py` (끝에 추가)

**Interfaces:**
- Consumes: Task 2의 `ia_slot_ids(screen_id) -> set[str]`
- Produces: `evidenceSheet.basisTitle|sourceTitle|personalTitle`, `states.unlocking.parts.evidenceSheet.failedToast`, `a11y.lockedLabelSlot|unlockingLabelSlot|unlockedAnnouncementSlot`

- [ ] **Step 1: 실패하는 테스트 작성.**

```python
def test_evidence_sheet_section_titles_and_slots():
    link = components_by_id(BRAND_GROUPS)["depth-link"]
    sheet = link["parts"]["evidenceSheet"]
    titles = {"basisTitle": "evidence-sheet.section.basis", "sourceTitle": "evidence-sheet.section.source",
              "personalTitle": "evidence-sheet.section.personal"}
    assert {name: sheet[name]["slot"] for name in titles} == titles
    assert sheet["personalTitle"]["when"] == sheet["personal"]["when"]
    locked = link["states"]["locked"]["parts"]["evidenceSheet"]
    assert not set(titles) & set(locked)  # 제목은 잠겨도 또렷함
    toast = link["states"]["unlocking"]["parts"]["evidenceSheet"]["failedToast"]
    assert toast == {"component": "toast", "slot": "evidence-sheet.unlock.failed"}
    a11y = link["a11y"]
    assert (a11y["lockedLabelSlot"], a11y["unlockingLabelSlot"], a11y["unlockedAnnouncementSlot"]) == (
        "evidence-sheet.a11y.locked", "evidence-sheet.a11y.checking", "evidence-sheet.a11y.unlocked")
    assert a11y["lockedLabel"] == "구역 이름 + '잠김'" and a11y["unlockingLabel"] == "확인 중"
    used = set(titles.values()) | {toast["slot"], a11y["lockedLabelSlot"], a11y["unlockingLabelSlot"],
                                   a11y["unlockedAnnouncementSlot"]}
    assert used <= ia_slot_ids("evidence-sheet")
```

- [ ] **Step 2: 실패 확인.** → FAIL(`KeyError: 'basisTitle'`)
- [ ] **Step 3: `sentence.json` 구현.**
  * `evidenceSheet`의 `sectionTitle` 바로 뒤에 다음을 더합니다.
    * `"basisTitle": { "style": "sectionTitle", "slot": "evidence-sheet.section.basis" }`
    * `"sourceTitle"`: 같은 형태, slot은 `evidence-sheet.section.source`
    * `"personalTitle"`: 같은 형태, slot은 `evidence-sheet.section.personal`, `"when"`은 `personal.when`과 같은 문자열
  * `states.unlocking.parts.evidenceSheet`에 `"failedToast": { "component": "toast", "slot": "evidence-sheet.unlock.failed" }`를 더합니다.
  * `a11y`에 세 `*Slot` 필드를 더합니다.
  * `rules`에 `"구역 제목(basisTitle·sourceTitle·personalTitle)은 잠겨도 흐리지 않는다. lock.veil은 본문에만 씌운다."`를 더합니다.
- [ ] **Step 4: `sentence.md` 구현.**
  * 근거 시트 표의 3~5행에 구역 제목 슬롯을 적고, "구역 제목은 잠겨도 또렷함"을 적습니다.
  * "확인이 오지 않음" 줄의 "(문구 슬롯은 지휘에 요청함)"을 `toast`(`evidence-sheet.unlock.failed`)로 바꿉니다.
  * 접근성 문구 슬롯 세 개를 한 줄로 적습니다.
- [ ] **Step 5: 통과 확인.** 새 테스트와 전체 pytest가 통과하고, 검사기 종료 코드가 0이어야 합니다. 기존 `test_evidence_sheet_lock_states`도 그대로 통과해야 합니다.
- [ ] **Step 6: Commit.** `docs(design): 근거 시트 구역 제목·해제 실패·접근성 슬롯`

### Task 4: 결정 기록·세션 문서·Issue

**Files:**
- Modify: `docs/identity/design/decisions.md` (V27 아래에 V28)
- Modify: `docs/identity/design/CLAUDE.md` ("현재 상태" 맨 위 항목, "다음 할 일" 2번)

- [ ] **Step 1: V28 추가.** 기존 행 형식(번호·날짜·분야·내용·근거)을 따릅니다.
  ```
  | V28 | 2026-10-13 | 문장 | **문장 조각(`segments`)의 `term` 조각은 `term-token`이 있는 화면(today·day-sheet·tag-diary·my-saju·saju-chart)에서만 `term-token` `inline` 칩으로 그리고, 그 밖의 화면과 공유 이미지에서는 일반 글자로 그립니다.** 칩은 누를 수 있다는 표시이고, 시트 안 용어를 누르게 하면 깊이 순서가 돕니다. 용어와 붙은 조사는 한 덩어리로 줄바꿈합니다. 근거 잠금은 표시를 바꾸지 않습니다. 컴포넌트 계약 2.1.0 | 사용자 결정 (#68 brainstorming, A안), [spec](specs/2026-10-13-term-segments-lock-slots-design.md) |
  ```
- [ ] **Step 2: `CLAUDE.md` 갱신.**
  * "현재 상태" 맨 위에 다음 항목을 더합니다: **문장 조각 용어 표시·근거 잠금 슬롯**(브랜치 `design/lock-slots`, 컴포넌트 계약 2.1.0, Issue #68, 결정 V28, spec 링크).
  * 기존 V2 후속 항목의 "컴포넌트 계약 2.0.0"은 "그때 2.0.0. 지금은 위 2.1.0"으로 고칩니다.
  * "다음 할 일" 2번(지휘 요청 결과 반영)은 끝났으므로 지우고 번호를 다시 매깁니다.
- [ ] **Step 3: 전체 검사.** pytest 전체와 검사기를 돌립니다. skip 2개(글꼴 없음)는 정상이며, 보고에 그대로 적습니다.
- [ ] **Step 4: Commit.** `docs(design): 결정 V28, CLAUDE.md 갱신`
- [ ] **Step 5: push·PR·Issue.** 먼저 사용자에게 확인을 받습니다.
  * `git push -u origin design/lock-slots`
  * PR(base `main`)을 엽니다. 본문에 `Closes #68`을 넣습니다. `kind:request`는 병합될 때 자동으로 닫힙니다(`docs/workflow.md` §5.2).
  * #68에 답 코멘트를 남깁니다: spec §2 요약, 명세 위치(`sentence.json` `sentence-block.parts.segments`), 결정 V28, PR 링크.
  * app 앞 notice를 만듭니다(`from:design`, `to:app`, `kind:notice`): 컴포넌트 계약 2.1.0, 바뀐 것 두 줄, spec 링크. A1 구현은 이미 app의 할 일이므로 request가 아니라 notice입니다. 받는 쪽이 `CLAUDE.md`에 반영한 뒤 닫습니다.
