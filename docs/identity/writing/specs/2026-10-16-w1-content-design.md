# W1 콘텐츠 원고 설계

* 날짜: 2026-10-16
* 다루는 요청: #232(엔진 안내 문구 슬롯과 원고, server), #52(원국 개인 해석 원고, 지휘)
* 근거: W0 spec §2(판정 세 장치)·§8, 브랜드 기반 spec §8, D28·D37·D40·D57·D70, W1·W16·W22·W25·W27, `core/evidence_rules.json`·`core/evidence_sources.json`, core 엔진 코드의 `detail` 값(2026-10-16 조사), REST 계약 1.0.0-draft.5(`Evidence`, `Notice`)

## 1. 목표

1. 콘텐츠 슬롯의 빈 원고를 3개 언어로 모두 채웁니다. 시작 시점에 26개 슬롯, ko 약 560건, 합계 1,690건입니다(`mlw check` `complete.missing`).
2. server 요청 #232의 엔진 안내 슬롯을 만들고 원고를 씁니다.
3. 마지막 PR에서 `--partial` 없이 `mlw check`가 통과하고, CI(`writing.yml`)에서도 `--partial`을 뺍니다.
4. 스토어 태그라인 3개 언어를 정합니다. 출발점은 R8-6 "내 사주로 푼 오늘, 명리일기"입니다.

바꾸지 않는 것: 기존 슬롯 id·키(새 슬롯 추가만), ui 원고, REST 계약 형식, 검사기 규칙의 판정 방식.

## 2. 묶음과 PR 순서

| PR | 묶음 | 슬롯 | ko 건수 | 함께 처리 |
| --- | --- | --- | --- | --- |
| W1-1 | 엔진 안내 + 오늘 화면 | `system.notice`(새 슬롯), `daily.*` 10개, `character.reason`, `explain.today_reason`, `calendar.day_level`·`calendar.score_item` | 약 220 | #232, jev shadow 판정 경로(§6.2) |
| W1-2 | 사주·개인 해석 | `chart.*` 4개, `personal.*` 5개, 그 문장에 끼우는 `glossary.value_name` 조각 35개(element·color·place·role·strength·luck·part, W1-3에서 당김) | 약 120 | #52, #237(오류 문구 3건), 가이드 질문 기준 확정(W31) |
| W1-3 | 용어·근거 | `term.meaning`, `glossary.value_name`, `evidence.basis`, `evidence.source` | 약 295 | `--partial` 제거, 스토어 태그라인 |

* W1-1이 먼저입니다. 오늘 화면은 사용자가 매일 보는 곳이고, 첫 라운드에서 굳힌 목소리 규칙이 이후 묶음에 그대로 적용됩니다. #232는 server가 기다리는 요청입니다.
* 묶음마다 `origin/main`에서 새 브랜치를 만듭니다. 다음 묶음은 이전 PR이 병합된 뒤 시작해, 굳힌 규칙을 main에서 이어받습니다.
* W1-3 전 PR은 지금처럼 `--partial`로 통과합니다.

## 3. 엔진 안내 슬롯 `system.notice` (#232)

* 위치: `slots/content/system.yaml`. `components: [notice-banner]`(오늘·명식·월간 응답의 `notices`).
* 키 7개, 매개변수 없음(core `Notice.detail`은 7개 모두 빈 맵).

| 키 | 나오는 조건(core) |
| --- | --- |
| `notice.ambiguous_local_time` | 출생 현지 시각이 서머타임 전환으로 두 번 있음. 앞 시각으로 계산 |
| `notice.nonexistent_local_time` | 출생 현지 시각이 전환 공백이라 없음. 뒤로 밀어 계산 |
| `notice.zi_hour_next_day` | 경도 보정한 출생 시각이 23시·0시 |
| `notice.time_unknown` | 출생 시각 없음. 정오로 계산 |
| `notice.near_solar_term` | 절입과 120분 이내(시각을 모르면 절입일과 같은 날) |
| `notice.dayun_start_approximate` | 출생 시각을 몰라 대운 시작이 근삿값 |
| `notice.focus_time_fallback` | 집중 시간 후보가 모두 원국과 충이라 대체 시진을 냄 |

* 목적 `info`. 계산을 어떻게 처리했는지 한두 문장으로 알리고, 사용자가 할 일이 있을 때만 덧붙입니다(예: 시각을 넣으면 더 정확해짐). 걱정을 키우는 말은 쓰지 않습니다.
* `notice.time_unknown`은 ui 슬롯 `saju-chart.time-unknown.notice`와 표현을 맞춥니다.

## 4. 근거 basis 매개변수 (W25의 `none` 바꾸기)

검사기(`evidence.param_mismatch`)는 슬롯 매개변수 집합이 규칙의 `detail` 키 집합과 같기를 요구합니다. 키는 모두 선언하고, 문장에 쓸 키만 종류를 바꿉니다. 값 형식은 core 코드 조사(2026-10-16) 결과입니다.

| 값 형식 | 키 | 종류 |
| --- | --- | --- |
| enum 대문자 이름 | `element`·`yongsin`·`gisin`, `day_kind`, `direction`, `ten_god`, `group`, `strength`·`strength_level`, `role`, `place`, `luck`, `part`, `parity` | glossary 범주(W16과 같은 방식). 범주가 없는 것은 원고를 쓸 때 기존 범주(날의 성격 이름 등)로 맞추고, 맞출 범주가 없으면 문장에 쓰지 않습니다(`none`) |
| 한자 | `day_branch`, `day_stem`, `month_branch` | `text` |
| 정수 | `number`, `group_count` | `number` |
| 기계용 문자열 | `breakdown`, `picks`, `all`, `featured`, `basis`(guide), `note` | `none` |
| 소수 점수 | `share`, `threshold`, `strength_score`, `score`(calendar) | `none` |
| 그 밖 | `current`, `deity` | `none`. 방위신은 문장에서 "이날 길한 방위"로 풀어 씁니다 |

* 점수 구성·시간 후보는 근거 시트의 표·칩이 이미 보여 주므로 문장에 다시 쓰지 않습니다.
* server가 enum 대문자 값을 glossary 키(소문자)로 바꿔 렌더하는지 W1-3 전에 server에 확인합니다(W16과 같은 방식인지).

## 5. 작성 기준

모든 원고는 보이스·톤 가이드, 슬롯 명세(구조·톤·상한·예시), slop·문체 규칙, 결정 W1~W27을 따릅니다. 아래는 W1에서 새로 정하는 것입니다.

### 5.1 오늘 화면 (W1-1)
* `daily.fortune.head`(날 종류 4 × 십성 묶음 5 = 키 20, 유형 3 = 60건): 같은 키의 세 유형은 같은 사실을 다른 자세로 말합니다(advice 할 일, state 오늘의 모습, care 마음 쓰기). 쓰기 전에 키별 "오늘의 핵심 한 가지" 표를 먼저 만들어, 키 20개 사이에 문장 틀이 반복되지 않게 합니다.
* `daily.fortune.tag`(태그 15 × 유형 3): 헤드라인 바로 아래에 붙으므로 헤드라인과 겹치지 않는 정보(태그가 뜻하는 일)만 씁니다.
* `daily.guide`(키 20 × 변주 2): 답할 수 있는 구체적인 질문입니다. 막연한 안부 질문은 쓰지 않습니다.
* 카드(색·방향·숫자·집중 시간), 태그 이름, 날의 성격 이유, 오늘 그런 이유, 달력 등급·점수 항목, 엔진 안내: 슬롯 상한 안의 짧은 정보 문장입니다.

### 5.2 사주·개인 해석 (W1-2)
* `chart.ilgan_head`·`chart.ilgan_body`(일간 10개): 사람을 단정하지 않고 자연의 비유 하나로 말합니다("~를 닮았어요", R10-1). 성격을 "기운을 품고 있어요"처럼 추상으로 말하지 않습니다.
* `personal.*`: W16대로 값 이름 조각(`{place}`·`{role}` 등)을 끼우고, 키마다 언어별 문장은 하나입니다.

### 5.3 용어·근거 (W1-3)
* `term.meaning`(77개): 처음 보는 사람이 읽는다고 보고 한두 문장으로 씁니다. 뜻을 먼저 말하고, 그다음에 오늘과의 관계를 씁니다.
* `glossary.value_name`: 명사구입니다. ja는 근거 용어집 신뢰도 상 표기를 씁니다(D70). 근거를 보강하기 전까지 비워 둔 3개(閑神·極身弱·極身強)는 그대로 두고, `--partial`을 뺄 때 빠짐을 허용하는 방식을 W# 결정으로 정합니다.
* `evidence.basis`(24개): "어떤 기준으로 이렇게 판정했는지"를 §4의 매개변수로 씁니다.
* `evidence.source`(124개):
  * 형식은 `원전 「대목」` + 원문 한 구절 + 뜻 한 문장입니다(사용자 결정).
  * 원문 한 구절은 core `quote`에서 판정에 쓴 부분을 글자 그대로 옮깁니다.
  * 원문은 세 언어가 같고 뜻 문장만 언어별로 씁니다.
  * 뜻 문장은 원문에 없는 내용을 더하지 않고, core `note`가 있으면 그 해석을 따릅니다.
  * 조후 120칸은 원문이 같은 틀이라 뜻 문장도 같은 틀을 쓰되, 칸마다 다른 용신 순서를 정확히 옮깁니다.
  * core `quote`는 간체입니다. 글자는 core 그대로 쓰고, 번체 원문이 있는지는 core에 Issue로 묻습니다. writing이 직접 바꾸면 后/後처럼 대응이 갈리는 글자에서 근거와 어긋날 수 있기 때문입니다.

### 5.4 en·ja
* ko를 직역하지 않습니다. 같은 정보와 톤 좌표로 그 언어 화면에 맞게 씁니다.
* 호칭·조사 규칙, 언어별 상한, glossary 용어 표기를 지킵니다.
* en·ja는 원어민 검수 전 초안입니다(ui와 같음).

## 6. 검수 흐름

### 6.1 묶음 하나
1. **ko 초안:** writing 세션이 직접 씁니다. `mlw check --partial` error가 0이 되어야 다음 단계로 갑니다.
2. **LLM 판정:** `mlw judge --lang ko`를 돌립니다.
   * 돌리기 전에 그 회차의 호출 수, 예상 토큰, 세션 대비 비율을 사용자에게 먼저 알립니다. 계산 기준은 2026-10-16 측정값으로, `claude -p` 호출당 약 37k입니다(고정분 약 34k는 1시간 캐시, 나머지는 프롬프트).
   * 맞는 지적은 바로 고칩니다. 애매한 것은 라운드 문항으로 올리고, judge가 틀렸다고 보는 것은 이유를 라운드 기록에 남깁니다.
3. **라운드 1회(문항 8~12개):**
   * 문항은 세 가지입니다.
     * 슬롯별 표본: 분량이 큰 슬롯은 2~3문항, 짧은 정보 슬롯은 묶어 1문항
     * judge 의심 문장
     * 앞 라운드 문항의 재출제
   * 선택지마다 "다 별로"를 두고 숨긴 대조군을 하나 섞습니다(`guide/review-procedure.md`).
   * 기록은 `artifacts/<날짜>-round-R9.md`부터 남기고 `index.json`에 넣습니다.
4. **반영:** 같은 성격의 선택이 두 번 나오면 규칙으로 굳히고(W# 결정, 규칙·슬롯 예시), 그 규칙으로 해당 슬롯 전체를 다시 확인합니다.
5. **en·ja:** 굳은 ko와 슬롯 명세를 슬롯 묶음별 subagent 두세 개에 병렬로 맡깁니다. 돌아온 원고는 writing 세션이 `mlw check`와 `mlw judge --lang en`·`--lang ja`로 확인하고 고칩니다.
6. **PR:** CI 전체와 공개 확인을 거치고, 처리한 Issue를 닫습니다.

### 6.2 jev shadow 판정 (사용자 결정 2026-10-16)
* **목적:** 앞으로 판정 작업을 TypeSafe jev로 대체할 수 있는지 판단할 자료를 모읍니다. jev는 확률을 돌려주는 판정형 모델이고, 입력 토큰 단가가 낮습니다. 다만 문서상 영어가 가장 정확하고 CJK는 동등하지 않아 바로 쓰기에는 위험이 있습니다.
* **첫 라운드(W1-1)만:** 본 판정은 `claude -p`로 하고, 같은 문장을 jev에도 병렬로 보냅니다. jev는 한도에 걸릴 때까지(재시도 뒤에도 `429`가 이어지거나 크레딧 소진 오류) 계속 돌립니다. jev 결과는 저장만 하고 고칠지, 라운드에 올릴지 판단하는 데는 쓰지 않습니다.
* **W1-2부터:** `claude -p`만 씁니다.
* **준비할 리소스**
  1. **jev 판정 경로(W1-1 PR, TDD):** `mlw judge`에 jev caller와 `--shadow jev` 옵션을 더합니다.
     * 문장 하나에 요청 하나를 보냅니다. `state`는 문장·슬롯 위치·목적입니다.
     * 해당하는 llm 규칙마다 `noul` 질문을 붙입니다. `instructions`는 `rubric`, `criteria`는 규칙 예시입니다.
     * 키는 환경 변수 `TYPESAFE_API_KEY`로만 받습니다. 키 파일은 저장소 밖에 둡니다.
     * shadow는 본 판정의 결과와 종료 코드를 바꾸지 않습니다.
  2. **비교 자료:** `artifacts/judge-shadow/`에 문장 단위 기록을 남깁니다(문장, 슬롯, 규칙, `claude -p` 표시와 이유, jev `noul` 확률, 모델 버전). 키·계정 정보는 넣지 않습니다.
* **균질성 검사와 대체 판단은 이번 W1에서 하지 않습니다.** 별도 계획 `plans/2026-10-16-jev-judge-evaluation.md`에 두고 나중에 실행합니다.

## 7. 완료 기준 (W1-3 병합 시점)
* `mlw check`가 `--partial` 없이 error 0이고, CI에서도 `--partial`을 뺐습니다.
* 세 언어 모두 `mlw judge` 의심 표시를 처리했습니다(고침, 라운드에서 판단, 또는 기록).
* 라운드 R9~R11 기록과 굳힌 규칙이 있습니다.
* 스토어 태그라인 3개 언어가 있습니다.
* 원어민 검수는 완료 기준이 아닙니다. 사용자가 감수자를 구하면 하는 보강 단계입니다(D70).

## 8. 보낼 요청
* core: 원전 `quote`의 번체 원문이 있는지 묻습니다(W1-3 전).
* server: enum 대문자 `detail` 값을 glossary 키로 바꿔 렌더하는지 확인합니다(W1-3 전).
