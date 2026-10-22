# 같은 날 여러 편 일기 줄 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** `diary-row`에 같은 날 여러 편 모양(`day` 묶음 카드·`entries`)과 10편을 채운 날의 입구 상태를 명세하고, 점선 색 토큰을 더해 컴포넌트 2.8.0·토큰 1.2.0으로 올립니다.

**Architecture:** 토큰은 `tools/palette.py`(역할 값)·`tools/tokens.py`(설명)에서 생성하고, 컴포넌트는 `components/<group>.json`(사실)과 `.md`(설명)에 적습니다. `tools/components.py`가 토큰 참조·IA·패턴을 검사하고 `test_components.py`·`test_tokens.py`가 값을 고정합니다.

**Tech Stack:** Python 3 + pytest(`uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`, 저장소 루트에서), DTCG JSON

**Spec:** `docs/identity/design/specs/2026-10-22-diary-row-multi-design.md`

## Global Constraints

* 고칠 수 있는 곳은 `docs/identity/design/`, `docs/contracts/README.md`의 디자인 토큰·컴포넌트 명세 행, GitHub Issues뿐입니다.
* 공개 저장소(D74): 가격·수익 수치를 적지 않습니다.
* 문구 원고는 쓰지 않습니다. 입구 문구는 writing 키 `todayGuideCtaFull`·`daySheetDiaryWriteCtaFull`·`diaryListPickDateConfirmFull`을 이름으로만 가리킵니다.
* 점선: 1px, 대시 4px·간격 3px, `color.timeline.entry`(라이트 `{color.neutral.300}`, 다크 `{color.neutral.700}`).
* 커밋 꼬리: `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`, `Claude-Session: https://claude.ai/code/session_015UuApz6Ye5AAbvaZtRPFvh`.

## Review Focus

* 한 편인 날의 `day` 카드가 2.7.0과 달라지지 않았는지(부품 값·a11y 라벨 그대로).
* 묶음 카드에서 카드 전체가 버튼으로 남아 있지 않은지(누를 곳은 `entry` 줄과 태그 칩뿐).
* `guide-question-card` `full`이 `after`의 도장을 지우지 않는지.
* 토큰을 더한 뒤 생성 파일·README·계약 행의 버전이 모두 1.2.0으로 맞는지.
* MD의 "쓰는 화면" 줄이 IA 컴포넌트 목록과 맞는지(`test_md_used_on_matches_ia_components`).

---

### Task 1: 토큰 `color.timeline.entry` (토큰 1.2.0)

**Files:**
- Modify: `tools/palette.py`(라이트·다크 역할 사전, `tag.neutral.border` 옆), `tools/tokens.py`(설명 사전 `timeline.line` 옆, 머리 주석 1.2.0)
- Modify: `tokens/color.light.tokens.json`, `tokens/color.dark.tokens.json`(생성), `tokens/README.md`(계약 버전 1.2.0, 이력 행, 역할 설명)
- Modify: `../../contracts/README.md` 디자인 토큰 행(1.2.0, 이력)
- Test: `tools/test_tokens.py`

**Interfaces:**
- Produces: 토큰 이름 `color.timeline.entry`(두 모드). Task 2가 `{color.timeline.entry}`로 참조합니다.

- [ ] **Step 1: 실패하는 test 작성** — `test_tokens.py`:
  * `test_readme_states_version_and_lists_files`의 기대를 `"계약 버전: 1.2.0"`으로.
  * 새 `test_timeline_entry_role`: 라이트 `color.timeline.entry` `$value == "{color.neutral.300}"`, 다크 `== "{color.neutral.700}"`.
- [ ] **Step 2: 실행** — `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools/test_tokens.py -q` / Expected: 두 test FAIL(KeyError·버전 불일치)
- [ ] **Step 3: 구현** — `palette.py` 역할에 `"timeline.entry": neutral[300]`(라이트)·`neutral[700]`(다크). `tokens.py` 설명 "같은 날 일기 사이 점선". 생성기로 토큰 파일 다시 씀(`test_committed_files_match_generator`가 통과하도록 저장소의 생성 명령 사용). README 1.2.0, 이력 행 `| 1.2.0 | 2026-10-22 | 추가: \`color.timeline.entry\`(같은 날 일기 사이 점선, #410) |`. 계약 행 버전 1.2.0과 이력 한 문장.
- [ ] **Step 4: 실행** — 같은 명령 / Expected: PASS(test_tokens 전체)
- [ ] **Step 5: Commit** — `feat(design): 토큰 color.timeline.entry, 토큰 계약 1.2.0 (#410)`

### Task 2: `diary-row` 변형 `day`·`entries`와 `entry` 줄 (V42)

**Files:**
- Modify: `components/diary.json`, `components/diary.md`
- Test: `tools/test_components.py`

**Interfaces:**
- Consumes: `{color.timeline.entry}`(Task 1)
- Produces: `diary-row` 변형 id `day`·`entries`, 부품 `entry`(`time`·`preview`·`chevron`·`divider`)

- [ ] **Step 1: 실패하는 test 작성** — 새 `test_diary_row_same_day_entries`:
  * 변형 id가 `["day", "entries"]`.
  * `parts.entry.divider == {"style": "dashed", "width": {"value": 1, "unit": "px"}, "dash": {"value": 4, "unit": "px"}, "gap": {"value": 3, "unit": "px"}, "color": "{color.timeline.entry}", "between": "entries-only"}`.
  * `parts.entry.preview` `maxLines == 1`, `parts.entry.preview.emptyKeepsLineHeight is True`, `parts.entry.time.fontFeatures == ["tnum"]`, `parts.entry.time.source == "createdAt"`, `parts.entry.time.wrap is False`, `parts.entry.minHeight == {"value": 48, "unit": "px"}`.
  * `rules`에 "server 순서" 문장이 있음(같은 분에 쓴 일기도 app이 다시 정렬하지 않음).
  * `day` 변형의 `group.pressable is False`, `group.order == ["badge", "entries", "tag"]`.
  * `entries` 변형의 `parts.dateColumn.visible is False`, `parts.badge.visible is False`, `parts.tag.visible is False`.
  * 기존 부품 `card.padding == "{space.16}"`, `preview.component == "sentence-block"`, `a11y.label`이 2.7.0 값 그대로(한 편 모양 유지).
- [ ] **Step 2: 실행** — `... pytest docs/identity/design/tools/test_components.py -q -k diary_row` / Expected: FAIL
- [ ] **Step 3: 구현** — spec §2·§3대로 `diary.json`에 `variants`(`day`: `when` "목록·태그 모아보기, 한 편이면 지금 모양, 두 편 이상이면 묶음 카드", `group` 부품; `entries`: `when` "오늘·그날 시트", `container` `{"today": "card", "day-sheet": "none"}`), 공통 `parts.entry`, `states.pressed`·`loading` 보강, `a11y`에 `groupRole`/`entryLabel`, `rules` 추가(작성 순, 접지 않음, 점선은 사이에만, 시각 형식은 app locale). `chevron`은 `icon: "caret-right"`, `size` 16, `weight: "light"`, `fg: "{color.text.secondary}"`. `diary.md` `## diary-row`를 spec §2·§3 요약으로 고치고 "쓰는 화면" 줄은 `diary-list, tag-diary, today, day-sheet`(D83 메모는 V42로 바꿈).
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 전체 PASS
- [ ] **Step 5: Commit** — `feat(design): diary-row 같은 날 여러 편 (day 묶음 카드·entries, V42, #410)`

### Task 3: 10편을 채운 날의 입구 (V43)

**Files:**
- Modify: `components/today.json`·`today.md`(`guide-question-card` `full`), `components/input.json`·`input.md`(`date-picker` `calendar` 규칙), `components/action.md`(`primary-button` 상한 메모)
- Test: `tools/test_components.py`

- [ ] **Step 1: 실패하는 test 작성** — 새 `test_full_day_entrances`:
  * `guide-question-card.states.full.parts.action == {"component": "primary-button", "variant": "quiet", "state": "disabled", "align": "center"}`, `states.full.parts.seal`이 `states.after.parts.seal`과 같음, `states.full.parts.question.fg == "{color.text.secondary}"`, `states.full.labelKey == "todayGuideCtaFull"`.
  * `date-picker` `calendar` 변형 `parts.bottomAction.whenFull == {"state": "disabled", "labelKey": "diaryListPickDateConfirmFull"}`.
  * `guide-question-card.a11y.stateAnnounced`에 "더 쓸 수 없음"이 들어 있음.
- [ ] **Step 2: 실행** — `... -k full_day` / Expected: FAIL
- [ ] **Step 3: 구현** — spec §4대로. `today.md`에 상태 표 행 `full`, `input.md` date-picker 규칙 한 줄(상한 채운 날도 고를 수 있음, 고른 뒤 버튼만 막힘), `action.md` primary-button에 "그날 시트 이날 일기 쓰기는 상한을 채우면 `disabled` + `daySheetDiaryWriteCtaFull`" 한 줄. 누를 수 없을 때 햅틱 없음 규칙을 `guide-question-card.rules`에.
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 전체 PASS
- [ ] **Step 5: Commit** — `feat(design): 상한을 채운 날의 쓰는 입구 (V43, #410)`

### Task 4: 컴포넌트 계약 2.8.0

**Files:**
- Modify: 모든 `components/*.json` `version`, `tools/components.py` `CONTRACT_VERSION`, `components/README.md`(버전 행·토큰 1.2.0 이상·결정 범위 V13~V43), `../../contracts/README.md` 컴포넌트 명세 행
- Test: `tools/test_components.py`

- [ ] **Step 1: 실패하는 test 작성** — `test_contract_version_is_2_7`을 `test_contract_version_is_2_8`(`VERSION == "2.8.0"`)로.
- [ ] **Step 2: 실행** — `... -k contract_version` / Expected: FAIL
- [ ] **Step 3: 구현** — 버전 일괄 변경, README 행, 계약 행에 2.8.0 이력 한 문장(`diary-row` `day`·`entries`, `guide-question-card` `full`, `date-picker` 상한 규칙, 토큰 1.2.0 이상 기대).
- [ ] **Step 4: 실행** — `... pytest docs/identity/design/tools -q` 와 `python3 docs/identity/design/tools/components.py` / Expected: 전체 PASS, 검사기 문제 0
- [ ] **Step 5: Commit** — `feat(design): 컴포넌트 계약 2.8.0 (#410)`

### Task 5: 결정·시안 기록·현재 상태

**Files:**
- Modify: `decisions.md`(V42·V43, spec §7 문장), `artifacts/index.json`(`design-v2-diary-row-multi`, status `chosen`, decisions V42·V43, screens `diary-list`·`tag-diary`·`today`·`day-sheet`), `CLAUDE.md`(현재 상태, 다음 할 일에서 #410 제거)
- Create: `artifacts/2026-10-22-v2-diary-row-multi.png`(시안 HTML 캡처)

- [ ] **Step 1:** 시안 PNG 캡처(라이트, 전체 페이지).
- [ ] **Step 2:** 기록 세 파일 수정.
- [ ] **Step 3: 실행** — `... pytest docs/identity/design/tools -q` / Expected: 전체 PASS
- [ ] **Step 4: Commit** — `docs(design): V42·V43 결정과 시안 기록 (#410)`

### Task 6: 마무리

- [ ] 최종 review 뒤 `git push -u origin design/diary-row-multi`, PR 생성(본문 `Closes #410`, 참고 줄만).
