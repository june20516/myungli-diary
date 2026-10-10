---
from: writing
to: root
kind: report
status: done
created: 2026-10-11
related: [W0, W1~W15, root-to-writing-engine-keys-scale, W0 spec §11]
---

# W0 라이팅 시스템 기반 완료 보고

## 무엇이 필요한가 / 무엇을 했는가
W0이 끝났습니다. 브랜치는 `writing/system-foundation`이고 main에는 아직 병합하지 않았습니다.

**spec §11 완료 기준 충족 근거**
| # | 기준 | 근거 |
| --- | --- | --- |
| 1 | guide 3종, rules 4종, `_schema.yaml`, `slots/content/`가 있고 메시지 키 93개와 §4.3 식별자를 덮음 | `guide/{voice-tone,review-procedure,honorific-josa}.md`, `rules/{slop,limits,style,josa}.yaml`, `slots/_schema.yaml`, `slots/content/*.yaml` 5개(콘텐츠 슬롯 15개) |
| 2 | 라운드 R1~R7의 결과가 YAML과 W#에 반영 | `artifacts/index.json`, `artifacts/2026-10-11-round-R1~R7.md`, `decisions.md` W6~W15 |
| 3 | 검사기 명령이 동작하고 규칙별·묶음 테스트 통과, 한 주 고정 자료 포함 | pytest 251개 통과, `mlw check ... --partial` 종료 코드 0, 고정 자료 `tools/fixtures/week_samples.json` |
| 4 | `generated/` 최신, `writing.yml` 통과 | `mlw gen-docs --check` 종료 코드 0, `.github/workflows/writing.yml`과 같은 명령을 로컬에서 통과(Actions 실행 전) |
| 5 | 요청함 문서 작성, `CLAUDE.md` 현재 상태 갱신 | 이 문서와 요청함 문서 3건, `docs/identity/writing/CLAUDE.md` |

**검증 결과 (2026-10-11, 최종 review 반영 후)**
* 저장소 루트 `uv run --project docs/identity/writing/tools pytest -q docs/identity/writing/tools/tests`: 251 passed
* `mlw gen-docs --check`: 종료 코드 0
* `mlw check docs/identity/writing/content --partial`: 종료 코드 0
* tools 디렉터리 `uv run ruff check .`: 통과, `uv run mypy src tests`: 오류 없음(28개 파일)

**요청 `root-to-writing-engine-keys-scale` 처리:** 세 항목을 모두 처리했고 그 문서를 `done`으로 바꿨습니다.
* 키 규모와 변주: spec §4.2, 결정 W4
* 식별자 슬롯: spec §4.3, `calendar.score_item`, `calendar.solar_term`, `daily.focus_reason`
* 계산 기준 안내: `settings.calculation_basis`

**plan 밖에서 추가한 task**
* **11b:** 용어 토큰 `[[...]]`, 화면 상한 선택자(lexicon·token·token_entries), limits L5~L7, glossary relation. 이유는 W9(토큰 6범주, 화면 최대 2개)를 검사기로 표현하기 위해서입니다.
* **11c:** 연속 N일 창(`window`), R5 상한값, L8. 이유는 W12("괜찮아요" 이틀 연속 금지)와 W14(돌봄 하루·한 주 상한)를 검사기로 표현하기 위해서입니다.
  * 최종 review에서 돌봄 상한(L2·L3)은 검사기에서 빼고 server 유형 순환 계약으로 옮겼습니다. 유형은 원고가 아니라 순환이 정해 작가가 고칠 수 없기 때문입니다(`decisions.md` W14, `2026-10-11-writing-to-server-josa`).

**결정 W1~W15 요약** (원문은 `docs/identity/writing/decisions.md`)
* W1~W5 (구조): 세 장치 검수, Python + uv 검사기, YAML 원본 + 생성 문서, 문장 유형은 총운에만(잠정), 호칭 고정.
* W6~W8 (보이스): 모든 목적 해요체, 정보 카드 형태 혼합과 틀 반복 금지, 헤드라인은 짧은 한 문장.
* W9~W10 (용어·안내): 용어 토큰 6범주와 화면 최대 2개, 안내는 호칭 + 질문형.
* W11~W13 (콘텐츠): 조언은 이유 + 행동 하나, 돌봄은 지시 없이 마음 짚기, 가이드는 권유형·질문형 변주.
* W14~W15 (빈도·용어): 돌봄과 영어 호칭 상한, 깊이 단계 사용자용 이름.

## 왜
spec §9의 마지막 요청함 문서이고, §11 기준 5를 충족하기 위한 보고입니다.

## 영향
* 열려 있는 writing 발신 요청: `d40-scope`, `contracts`, `design-length`, `server-josa`.
* **미결 사항**
  * D40 범위 확인: 확인 전까지 W4는 잠정입니다.
  * 글자 수 상한: design 응답 전까지 `max_length`가 비어 있어 검사가 건너뜁니다.
  * `slots/ui/` 목록: IA(D39) 이후. 지금은 깊이 이름(`ui/depth.yaml`)만 있습니다.
  * LLM 판정 명령: W1 직전에 만듭니다.
  * 메시지 키별 매개변수: 슬롯 명세 `params` 맵(값 종류 포함)으로 정했고, core 쪽 목록과 대조하는 방안을 제안했습니다(`writing-to-root-contracts`).

## 처리 기록
- 2026-10-11 (writing): done — W0 완료. 근거는 위 표와 `git log 5bf3e42..HEAD`
