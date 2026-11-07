# 태그 근거 다시 세우기 (#804) Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** #804(D108) 다섯 항목을 한 PR로 끝냅니다. ① `tag.big_change`를 일지 충, 월지 충 두 태그로 나눔 ② 태그 판정 전용 원전(원문으로 확인한 것만) ③ `GetDaily`에 일진 천간 십성과 십성 묶음 ④ 달력 길흉 수준 "아주 잘 풀리는 날" ⑤ 오늘의 질문 후보 목록.

**Architecture:** 태그 근거는 공통 근거 하나(`tags/select`, C8)에서 **태그마다 `Evidence` 하나**로 바뀝니다. 원전은 위키문헌 원문을 저장소에 그대로 저장하고, 인용(`quote`)이 그 원문에 글자 그대로 있는지 테스트로 묶습니다. 원전이 없는 태그는 `source_ref`가 빈 문자열입니다. proto는 필드와 enum 값을 **추가만** 하고, 키 `tag.big_change` 계열을 없애는 것이 하위 호환을 깨는 부분입니다(`kind:notice`).

**Tech Stack:** Python 3(uv, pytest, syrupy 스냅샷), protobuf/buf, 위키문헌 MediaWiki API(`action=raw`).

**Spec:** Issue #804 본문과 지휘 코멘트 2개, `core/docs/specs/2026-10-10-myungli-engine-design.md`(§7.7 태그, §7.8 총운·가이드, §8 월간, §11 근거, §12 버전), `core/docs/references/README.md`.

## Global Constraints
* 엔진은 문장을 만들지 않습니다(D27). 새 이름의 문구, 원전 뜻 문장, "원전 없음" 해석 문장은 writing 몫입니다.
* **원전은 원문으로 확인한 것만 넣습니다.** 저장한 원문에 없는 글자는 `quote`·`passage`에 쓰지 않습니다. 찾지 못하면 "원전 없음"이고, 공통 문장(C8)으로 채우지 않습니다.
* 원문은 위키문헌 원본을 글자 그대로 저장합니다(간체·번체 변환 금지, README "언어" 절). 출처 URL, 수집일, revision id를 남깁니다(CC BY-SA 표기).
* 달력 점수 규칙(일지·월지 충 -2 등)은 바꾸지 않습니다. 새 수준 "아주 잘 풀리는 날"은 점수 3 이상입니다(지금 최고점이 3: 귀인·용신의 날 2 + 합 1).
* 가이드 질문 원고 변주(키당 2개)는 콘텐츠 쪽이 고릅니다. 엔진은 **키 단위 후보**만 냅니다(아래 C30).
* proto는 추가만(`buf breaking` 통과). 출력이 바뀌므로 `RULESET_VERSION`을 `2026.11.0`으로 올립니다.
* 공개 저장소(D74): 내부 수치 없음. 사용자에게 보이는 글자에 긴 대시, 범위 대시, 가운뎃점을 쓰지 않습니다(D93, `evidence_sources.json`의 `note` 포함).

## 확인한 사실 (2026-11-05)
| 사실 | 출처 |
| --- | --- |
| `tag.big_change`는 일진 지지가 원국 일지 또는 월지와 충일 때 하나로 붙음 | `rules/tags.py:76` |
| 태그·총운·가이드 근거는 모두 `five_elements#balance_principle` | `rules/tags.py`, `rules/messages.py`, C8 |
| 총운 첫 판정에 이미 `params.ten_god`, `evidence.detail.group`이 있음. 전용 필드는 없음 | `rules/messages.py:42`, `engine.proto` `DailyResponse` |
| proto에 `TenGodGroup` enum이 없음 | `engine.proto` |
| 달력 최고점은 3, 수준은 `GOOD`(2 이상)·`NEUTRAL`·`CAUTION`(-2 이하) | `rules/calendar_luck.py` |
| 가이드 키는 20개, 변주 1·2는 writing 원고 구조 | `message_keys.json`, `slots/content/daily.yaml` `daily.guide` |
| 위키문헌에 `淵海子平`, `三命通會`, `滴天髓` 문서가 있음(HTTP 200). `子平真詮`은 없음(404, 검색에도 없음) | `zh.wikisource.org` 조회 |

## 이 PR의 core 결정
* **C28** 태그 근거는 태그마다 `Evidence` 하나(`rule_id` `tags/<태그 이름>`). 합 태그는 그날 활성인 합 종류(천간합, 지지합)마다 하나. 원전이 없으면 `source_ref`는 빈 문자열이고 계산 내역만 `detail`에 둡니다. C8은 "태그와 태그를 근거로 한 판정(`fortune/tag`, 태그 기반 `guide/question`)은 공통 근거를 쓰지 않음"으로 개정합니다.
* **C29** 충 태그 키: `tag.clash_day_branch`(일지 충), `tag.clash_month_branch`(월지 충), 연지·시지는 `tag.clash`. 같은 날 둘 다면 둘 다 붙고 순서는 일지, 월지, 그 밖. `fortune.tag.*`, `guide.*`도 같은 이름으로 나뉩니다(가이드 키 20 → 21개).
* **C30** 가이드 후보: `DailyResponse.guide_candidates`(키 중복 없음, 순서 ① 지금 기본 질문 ② 대표 태그 2순위 ③ 일진 십성 묶음). 첫 항목은 `guide`와 같습니다. "지금 키의 다른 변주"는 같은 키의 원고 변주이므로 콘텐츠 쪽(server)이 첫 키에서 펼칩니다.

## Review Focus
1. 일지와 월지가 같은 지지라 한 일진이 두 자리와 동시에 충인 원국: 두 태그가 모두 붙고, 대표 태그 2개가 그 둘로 차며, 근거도 두 개여야 합니다.
2. 탐합망충으로 무효가 된 충만 있는 날: 충 태그가 붙지 않고, 합 태그와 그 근거만 남아야 합니다.
3. 대표 태그가 없는 날(태그 0개, 보조 태그도 없는 평일): 가이드 후보는 십성 묶음 하나이고 `guide`와 같아야 합니다.
4. 대표 태그 1순위와 2순위의 가이드 키가 십성 묶음 키와 겹치지 않아도, 2순위가 없는 날 후보가 2개로 줄어야 합니다(빈 항목 없음).
5. 원전 없는 태그의 빈 `source_ref`가 근거 원전 목록 검증(`validate_refs`, `test_evidence_catalog`)과 `evidence_rules` 대조에서 오류가 되지 않아야 합니다.

---

### Task 1: 원전 수집과 대조 (코드 변경 전, 결과가 Task 3의 데이터)

**Files:**
- Create: `core/docs/references/<자료>/source.wikitext`(원전마다, 수정 금지 원본), `core/docs/references/<자료>/PROVENANCE.md`(URL, 수집일, revision id)
- Create: `core/docs/references/tag-sources-survey.md`(태그별 대조 기록: 찾은 조목, 원문 줄, 못 찾은 이유)

자료 디렉터리 이름: `yeonhae-japyeong`(淵海子平), `sammyeong-tonghoe`(三命通會), `jeokcheonsu`(滴天髓). 로마자는 기존 `gungtong-bogam` 방식.

- [ ] **Step 1:** 각 원전의 권(卷) 문서 목록을 `action=raw`로 받아 필요한 권만 저장합니다. 조사 대상 조목: 천간합(五合), 지지합(六合), 충(六沖), 천을귀인, 도화(咸池), 역마, 화개, 공망, 월령(월지)의 무게, 일지(궁위).
- [ ] **Step 2:** 태그마다 조목 제목과 대표 문장을 원문에서 찾아 `tag-sources-survey.md`에 적습니다. 원문 줄을 그대로 복사하고, 그 줄이 저장 파일에 있는지 `grep -F`로 확인합니다. 지휘 후보(자평진전의 월령)는 위키문헌에 없으므로 같은 뜻의 조목을 다른 세 원전에서 찾고, 없으면 "원전 없음"으로 둡니다.
- [ ] **Step 3:** 태그별 결론을 표로 정리합니다(원전, 조목, 원문 확인 여부). 이 표가 Task 3의 입력이고, 끝나면 Issue에 남깁니다(Task 7).
- [ ] **Step 4:** Commit `docs(core): #804 태그 원전 원문 수집과 대조 기록`

### Task 2: 충 태그 나누기와 태그별 근거

**Files:**
- Modify: `core/src/myungli_engine/rules/tags.py`, `core/src/myungli_engine/constants/message_keys.py`, `core/src/myungli_engine/constants/evidence_rules.py`
- Test: `core/tests/unit/rules/test_tags.py`

**Interfaces:**
- Produces: 상수 `TAG_CLASH_DAY_BRANCH = "tag.clash_day_branch"`, `TAG_CLASH_MONTH_BRANCH = "tag.clash_month_branch"`. `TagResult.evidence`는 `tags/select` 하나(전체 목록, `source_ref` 빈 문자열) 뒤에 태그마다 하나. `tag_source_ref(tag_key: str, hap_kind: RelationKind | None = None) -> str`(Task 3이 채움, 이 Task에서는 빈 문자열을 돌려주는 자리)
- Evidence 규칙: `tags/<이름>`(`clash_day_branch`, `clash_month_branch`, `clash`, `harmony`, 신살 5, `ten_god_rush`, `gwiin_day`, `yongsin_day`). `detail` 키: 충은 `natal_position`·`day_branch`·`natal_branch`, 합은 `relation_kind`·`natal_position`, 신살은 `shinsal`·`day_branch`, 몰림은 `group`·`natal_count`·`stem_ten_god`·`branch_ten_god`

- [ ] **Step 1: 실패하는 테스트**: `test_day_branch_clash_tags_clash_day_branch`, `test_month_branch_clash_tags_clash_month_branch`, `test_day_and_month_clash_both_tags_day_first`(Review Focus 1), `test_suppressed_clash_gives_no_clash_tag`(Review Focus 2), `test_each_tag_has_own_evidence`(태그 수 + 1 = 근거 수, 합은 종류마다), `test_rush_evidence_has_empty_source_ref`.
- [ ] **Step 2:** `uv run pytest -q tests/unit/rules/test_tags.py` → FAIL
- [ ] **Step 3:** 구현. `tag.big_change` 계열 키를 `TAG_KEYS`·`fortune.tag.*`·`guide.*`에서 빼고 새 키를 넣습니다.
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** Commit `feat(core): #804 일지 충과 월지 충 태그를 나누고 태그마다 근거를 붙임`

### Task 3: 태그 전용 원전 데이터와 빈 근거 허용

**Files:**
- Create: `core/src/myungli_engine/references/data/<자료>/tags.json`(Task 1 결론. 키 → `section`, `quote`, `passage`, `note`)
- Modify: `references/loader.py`(`_DATA_PACKAGES`에 새 자료, `TAG_SOURCE_REF: Mapping[str, str]`, `all_refs()`에 포함), `references/sources.py`(원전 이름 상수와 항목 생성), `rules/tags.py`(`tag_source_ref`), `rules/messages.py`(`fortune/tag`, 태그 기반 `guide/question`은 태그 근거)
- Test: `core/tests/unit/references/test_tag_sources.py`, `tests/snapshots/test_evidence_catalog.py`

**Interfaces:**
- Consumes: Task 2의 `tag_source_ref` 자리
- Produces: `TAG_SOURCE_REF`(태그 이름 → `source_ref`, 원전 없는 태그는 키 없음). 귀인의 날은 천을귀인 ref, 용신의 날은 `yongsin.evidence`의 ref를 그대로 씀.

- [ ] **Step 1: 실패하는 테스트**: `test_every_tag_quote_is_verbatim_in_saved_source`(각 `quote`와 `passage` 문단이 `core/docs/references/<자료>/source.wikitext`에 글자 그대로 있음), `test_untagged_rush_has_no_source`, `test_empty_source_ref_is_allowed_only_for_tag_rules`(Review Focus 5: 빈 값은 `tags/*` 규칙에서만 허용, 다른 규칙은 여전히 실패), `test_gwiin_day_uses_cheoneul_gwiin_ref`.
- [ ] **Step 2:** `uv run pytest -q tests/unit/references` → FAIL
- [ ] **Step 3:** 구현. 빈 `source_ref` 허용은 gRPC 응답 검증과 불변 조건 테스트에서 `rule_id`가 `tags/`로 시작할 때만 둡니다.
- [ ] **Step 4:** 같은 명령 → PASS
- [ ] **Step 5:** Commit `feat(core): #804 태그 전용 원전 근거`

### Task 4: 달력 수준 "아주 잘 풀리는 날"

**Files:**
- Modify: `rules/calendar_luck.py`(`VERY_GOOD_THRESHOLD = 3`, `_level_of`), `domain/enums.py`(`LuckLevel.VERY_GOOD`), `proto/.../engine.proto`(`LUCK_LEVEL_VERY_GOOD = 4`), proto 변환부, `message_keys.py`(`calendar.very_good`)
- Test: `core/tests/unit/rules/test_calendar_luck.py`

- [ ] **Step 1: 실패하는 테스트**: `test_score_three_is_very_good`(귀인의 날 + 합), `test_score_two_stays_good`, 월간 응답 `judgment.message_key == "calendar.very_good"` 통합 테스트 1건.
- [ ] **Step 2:** → FAIL
- [ ] **Step 3:** 구현, `buf lint`·`buf breaking`과 생성 코드 갱신(README 절차).
- [ ] **Step 4:** → PASS
- [ ] **Step 5:** Commit `feat(core): #804 달력 길흉 수준 VERY_GOOD`

### Task 5: GetDaily에 일진 천간 십성과 가이드 후보

**Files:**
- Modify: `engine.proto`(`enum TenGodGroup`(UNSPECIFIED, BIGYEOP, SIKSANG, JAESEONG, GWANSEONG, INSEONG), `DailyResponse.day_stem_ten_god = 14`(`TenGod`), `day_stem_ten_god_group = 15`(`TenGodGroup`), `repeated Judgment guide_candidates = 16`), `rules/messages.py`, `composers/daily.py`, gRPC 변환부
- Test: `core/tests/unit/rules/test_messages.py`, `core/tests/integration/`의 GetDaily 테스트

**Interfaces:**
- Produces: `guide_candidates(day: Pillar, natal_day_stem: Stem, featured: Sequence[str]) -> tuple[Judgment, ...]`. `guide_question`은 `guide_candidates(...)[0]`을 돌려주게 남깁니다.

- [ ] **Step 1: 실패하는 테스트**: `test_candidates_order_tag1_tag2_group`, `test_candidates_without_featured_is_group_only`(Review Focus 3), `test_candidates_with_one_featured_has_two`(Review Focus 4), `test_candidates_dedup_keys`, `test_first_candidate_equals_guide`, GetDaily 응답의 `day_stem_ten_god`·`day_stem_ten_god_group`이 총운 `params.ten_god`·`detail.group`과 같음.
- [ ] **Step 2:** → FAIL
- [ ] **Step 3:** 구현
- [ ] **Step 4:** → PASS
- [ ] **Step 5:** Commit `feat(core): #804 일진 천간 십성 묶음과 가이드 후보를 GetDaily에 담음`

### Task 6: 계약 파일, 버전, 스냅샷, 문서

**Files:**
- Modify: `core/message_keys.json`, `core/message_params.json`, `core/evidence_rules.json`, `core/evidence_sources.json`(생성 명령으로), `version.py`(`2026.11.0`), 스냅샷과 `RULESET_HASH`, `core/docs/decisions.md`(C28~C30, C8 개정), spec §7.7·§7.8·§8·§9·§11, `core/docs/references/README.md`(새 원전 절), `core/docs/engine-logic-wiki.md`(태그 절), `core/CLAUDE.md`(알려진 한계의 C8 줄, 현재 상태), `docs/contracts/README.md` core 행(엔진 gRPC API, 메시지 키 목록, 엔진 버전, 매개변수, 근거 규칙, 근거 원전)

- [ ] **Step 1:** 계약 파일 재생성(README 명령), `uv run pytest -q -m contract`
- [ ] **Step 2:** `uv run pytest -q tests/snapshots --snapshot-update`. 데일리 스냅샷은 파일 하나(약 2.5MB)라 줄 단위로 읽지 않습니다. 옛 스냅샷과 새 스냅샷을 `(원국, 날짜, 필드 경로)`로 비교하는 일회용 스크립트(scratchpad, 저장소에 넣지 않음)로 바뀐 필드 경로별 개수를 세고, 바뀐 것이 충 태그, 태그 근거, 총운·가이드 근거, `day_stem_ten_god*`, `guide_candidates`, 월간 수준뿐인지 확인합니다. 그 표를 PR 본문에 넣습니다. 스냅샷 분할(#59-2)은 이 PR에서 하지 않습니다(2026-11-05 사용자 결정, 이동과 값 변경이 한 diff에 섞이지 않게).
- [ ] **Step 3:** 전체 `uv run pytest -q -m "not slow"`, `tools/slow_scope.py`가 내는 slow 묶음, `buf lint`·`buf breaking` 통과
- [ ] **Step 4:** Commit `docs(core): #804 계약 파일, ruleset 2026.11.0, 결정 C28~C30`

### Task 7: PR과 Issue 보고
- [ ] **Step 1:** `git push -u origin core/804-tag-evidence`, PR 본문 `Closes #804`
- [ ] **Step 2:** #804에 태그별 표 코멘트: 태그 키 | 원전 | 조목 | 원문 확인(저장 원문에 글자 그대로 있음) 또는 "원전 없음". 가이드 변주 펼치기는 server 몫(C30), 새 키 원고(충 태그 이름, `calendar.very_good`)는 writing 몫임을 함께 적습니다.
- [ ] **Step 3:** `kind:notice` Issue(`to:server`, `to:writing`): `tag.big_change`·`fortune.tag.big_change`·`guide.big_change` 삭제와 대체 키, 태그 근거가 태그마다로 바뀜, 빈 `source_ref`의 뜻.
