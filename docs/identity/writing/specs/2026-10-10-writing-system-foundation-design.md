# 라이팅 시스템 기반 (W0) — 설계

* 작성: writing 세션, 2026-10-10
* 상태: 사용자 검토 대기
* 기준 문서: [`docs/identity/README.md`](../../README.md)(브랜드 기반), [브랜드 기반 spec](../../../specs/2026-10-10-brand-foundation-design.md) §8
* 관련 결정: D13, D19~D24, D27, D28, D36, D37, D40, D42
* 받은 요청: [`root-to-writing-engine-keys-scale`](../../../coordination/2026-10-10-root-to-writing-engine-keys-scale.md)

## 1. 목적과 성공 기준

앞으로 명리일기의 문장은 대부분 AI가 초안을 씁니다. W0은 **사람과 AI가 같은 기준으로 문장을 만들고 검수하는 장치**를 만듭니다.

성공 기준:
1. W1에서 AI가 슬롯 명세와 보이스·톤 가이드만 읽고 콘텐츠 초안을 쓸 수 있습니다.
2. 기계로 판정할 수 있는 slop은 검사기가 CI에서 막습니다.
3. 기계로 판정할 수 없는 것은 판정 기준(루브릭, 좋은 예·나쁜 예)이 문서로 남아 있고, 사용자의 n지선다 검수로 최종 판정합니다.
4. 사람이 읽는 문서와 검사기가 읽는 규칙이 어긋나지 않습니다.

## 2. 세 장치의 역할

| 장치 | 역할 | 성격 | 실행 위치 | W0 범위 |
| --- | --- | --- | --- | --- |
| 규칙 검사기 | **관문.** 통과하지 못하면 머지·시드 반영을 막습니다 | 결정적 | writing CI, server 시드 CI, app CI | 구현 |
| LLM 판정 | **1차 거르기.** 의미 판단이 필요한 패턴에 의심 표시를 합니다 | 확률적, 막지 않음 | 로컬(초안 작성 시) | 판정 기준만 작성, 명령은 W1 직전 |
| n지선다 검수 | **최종 판단과 규칙 수립.** 사용자가 고르고, 반복된 선택을 규칙으로 굳힙니다 | 사람 | 터미널 | 절차 작성 + 라운드 R1~R7 진행 |

* 규칙 데이터 한 벌에서 패턴마다 `judge: rule | llm`을 표시합니다. CI는 `rule`만 실행하고, LLM 명령은 `llm` 패턴을 루브릭으로 읽습니다. 패턴이 `llm`에서 `rule`로 옮겨 가도 한 곳만 고칩니다.
* n지선다는 840개 넘는 문장을 하나씩 보는 데 쓰지 않습니다. W0에서는 규칙과 예시를 세우는 데, W1에서는 슬롯별 표본과 LLM 판정이 의심 표시한 문장을 보는 데 씁니다.
* Phase 2의 LLM 코멘트(D23)는 실행 중에 생성되므로 server가 응답 직전에 같은 규칙을 적용해야 할 수 있습니다. 규칙을 언어 중립 데이터(YAML)로 두는 이유 가운데 하나입니다. 그 구현은 이 spec의 범위 밖입니다.

## 3. 디렉터리 구조

```
docs/identity/writing/
  CLAUDE.md  decisions.md (W#)
  specs/  plans/
  guide/                     사람이 직접 쓰는 문서. 규칙은 ID로만 가리킵니다
    voice-tone.md            보이스·톤 가이드
    review-procedure.md      친숙도 검수 절차
    honorific-josa.md        호칭·조사 규칙 (server 계약)
  rules/                     원본 데이터 (YAML)
    slop.yaml                slop 패턴
    limits.yaml              빈도·밀도 상한
    style.yaml               구두점·문장 맺음·어휘 규칙
    josa.yaml                조사 쌍, 받침 판정 규칙, 예시
  slots/                     원본 데이터 (YAML)
    _schema.yaml             슬롯 명세 틀
    content/*.yaml           콘텐츠 슬롯 (메시지 키·식별자 기반)
    ui/*.yaml                UI 문구 슬롯 (IA 이후)
  content/<lang>/*.yaml      콘텐츠 원고 (W1). W0에는 예시 원고만 둡니다
  generated/                 검사기가 만드는 Markdown. 직접 고치지 않습니다
    slop-patterns.md  slot-catalog.md  josa-table.md
  tools/                     검사기 (Python + uv)
  artifacts/                 검수 라운드 기록 + index.json (workflow §7)
```

**원본 규칙:** `rules/`와 `slots/`의 YAML이 원본입니다. 사람이 읽는 표(slop 목록, 슬롯 목록, 조사 표)는 `generated/`에 생성하고, CI가 최신인지 확인합니다. 서술 중심 문서(`guide/`)는 직접 쓰되 규칙의 내용을 옮겨 적지 않고 ID(`slop.P3`, `style.S2` 등)로 가리킵니다.

## 4. 슬롯 명세

### 4.1. 슬롯 명세 틀 (`slots/_schema.yaml`)

브랜드 기반 spec §8의 항목을 필드로 옮깁니다.

| 필드 | 내용 |
| --- | --- |
| `id` | 슬롯 식별자 (예: `daily.fortune.head`) |
| `where` | 사용 위치: 화면·컴포넌트 (IA 이후 IA 화면 id로 연결) |
| `purpose` | `info`(정보) · `guide`(안내·기능 설명) · `care`(위로·공감) — 원칙 0의 허용 범위를 정하는 축 |
| `user_state` | 언제, 어떤 상태로 보는가 |
| `structure` | 문장 구조 (문장 수, 순서) |
| `types` | 적용하는 문장 유형 (`advice`·`state`·`care`) 또는 없음 |
| `depth` | 깊이 단계(D37)와 단계별 허용 용어 범주 |
| `endings` | 우선 문장 맺음 (`style.yaml` 참조) |
| `tone` | 톤 좌표: 진지·격식·존중·담백 각 1~5 |
| `max_length` | 언어별 글자 수 상한 (design과 조정) |
| `keys` | 메시지 키 또는 식별자 목록, 키별 매개변수 |
| `variants` | 유형별 변주 수, 순환 규칙 |
| `allowed` | 목적별 허용 표현 (원칙 0 예외로 허용하는 slop 패턴 ID) |
| `forbidden` | 이 슬롯에서 추가로 금지하는 패턴 ID |
| `examples` | 좋은 예·나쁜 예 (언어별, 이유 포함) |
| `co_display` | 같은 화면에 함께 나오는 슬롯 (빈도·밀도 검사용) |
| `a11y` | 잘림 처리, 스크린리더 읽기 |

### 4.2. 문장 유형과 변주 (요청 1 처리)

| 슬롯 | 키 | 유형 3종 | 변주 | 언어당 문장 수 |
| --- | --- | --- | --- | --- |
| 총운 헤드라인 | `fortune.<날의 성격>.<십성 그룹>` 20 | 적용 | 유형당 1 | 60 |
| 총운 보조 | `fortune.tag.*` 15 | 적용 | 유형당 1 | 45 |
| 가이드 질문 | `guide.*` 20 | 미적용 (질문이라 유형 구분이 맞지 않음) | 2 | 40 |
| 정보 슬롯 | `color.*` 4, `direction.*` 4, `number.*` 4, `focus_time.*` 5, `yongsin.*` 3, `calendar.*` 3, `tag.*` 15 | 미적용 | 1 (매개변수로 채움) | 38 |
| 식별자 문구 | §4.3 | 미적용 | 1 | 약 36 |

* 합계: 언어당 약 219개, 3개 언어로 약 660개입니다. 모든 키에 유형을 적용하면(약 840개 + 식별자) 정보 슬롯에도 조언·상태·돌봄 버전을 억지로 만들어야 합니다.
* 정보 슬롯은 같은 문장이 반복되는 편이 "구체적이다"·"차분하다"에 맞습니다(정보의 위치와 형태가 일정함).
* **순환 규칙:** 유형 적용 슬롯은 같은 키가 나올 때마다 `advice → state → care` 순으로 돕니다. 순환 상태는 사용자별로 server가 관리합니다. 변주가 2개 이상인 슬롯은 같은 방식으로 변주를 돕니다.
* 변주 수는 슬롯마다 `variants`로 정하므로 나중에 늘릴 수 있습니다.
* **D40 범위 확인:** D40은 "콘텐츠 문장은 문장 유형 축"이라고 적습니다. 유형을 총운에만 적용하는 것은 D40의 해석을 좁히는 일이라, `writing-to-root-d40-scope`로 지휘 세션에 확인을 요청합니다(§8). 확인 전까지 이 표는 잠정입니다.

### 4.3. 식별자 문구와 값 이름 (요청 2·3 처리)

| 슬롯 | 식별자 | 수 |
| --- | --- | --- |
| 월간 점수 구성 | `MonthDay.score_items[].id`: `gwiin_day`, `yongsin_day`, `gisin_day`, `hap`, `chung_day_or_month`, `chung_other`, `hyeong` | 7 |
| 집중 시간 가점 사유 | `FocusSlot.reasons`: `gwiin`, `yongsin`, `huisin`, `hap` | 4 |
| 절기 이름 | `SolarTermKind` 24종 | 24 |
| 계산 기준 안내 (D42) | `notice.calculation_basis`: "동경 127.5° 기준 -30분 보정, 진태양시 미적용". `evidence` 단계 또는 설정. 우선순위 낮음 | 1 |
| 값 이름 | 매개변수로 들어가는 오행·색·방향·십성·천간·지지·신살의 언어별 이름. 용어 토큰 대상 여부 표시 | 슬롯 1개, 항목은 enum 수만큼 |

* 값 이름은 문장이 아니라 사전입니다. 그래서 유형·변주는 없고, 검사는 완결성과 조사 판정(받침)만 합니다.

### 4.4. 슬롯 목록의 범위

* **W0에서 완성:** 콘텐츠 슬롯(§4.2, §4.3) 전체. 메시지 키 93개와 식별자는 엔진에서 이미 정해졌으므로 IA를 기다리지 않습니다.
* **IA 이후:** `slots/ui/` (ARB 화면 문구). 예외로 R7에서 정하는 깊이 단계 이름과 "기본 깊이" 이름은 W0에서 `ui/depth.yaml`에 둡니다.

## 5. 규칙 데이터

### 5.1. `slop.yaml`

```yaml
- id: slop.P1
  name: 목적 없는 자리의 과한 추상화
  judge: llm
  severity: warn
  rubric: 기능·정보 슬롯에서 무엇이, 언제, 어떻게인지 말하지 않는 문장인가
  exempt_purposes: [care]          # 원칙 0
  examples:
    hit:  [{lang: ko, slot_purpose: info, text: "흐름이 보여요."}]
    pass: [{lang: ko, slot_purpose: care, text: "마음이 무거웠다면 오늘은 조금 쉬어 가도 괜찮아요."}]
- id: slop.P8
  name: 들뜬 강조
  judge: rule
  severity: error
  detect: {kind: regex, pattern: "[!！]|\\p{Extended_Pictographic}"}
  exempt_purposes: []
```

* README의 8개 패턴에서 출발합니다. 판정 방식 초안: P2(정의형)·P5(번역 슬로건)·P7(균형 병렬)·P8(들뜬 강조)·P4의 기획 용어 노출은 `rule`(틀 매칭·어휘 목록), P1(추상화)·P3(사물 주어 의인화)·P6(자기 성격 형용)·P4의 시점 혼재는 `llm`입니다. 틀 매칭이 오탐을 많이 내면 `llm`으로 옮깁니다.
* `detect.kind`는 `regex`, `lexicon`(어휘 목록), `template`(틀) 세 가지로 시작합니다. 형태소 분석은 실제로 필요해질 때 추가합니다.

### 5.2. `limits.yaml`

```yaml
- id: limit.L1
  name: 호칭은 한 화면에 한 번
  scope: screen                    # sentence | slot | screen | day | week
  count: {placeholder: name}
  max: 1
  severity: error
- id: limit.L2
  name: 돌봄 표현 빈도
  scope: week
  count: {type: care}
  max: null                        # R5에서 정함
  severity: warn
```

### 5.3. `style.yaml`, `josa.yaml`

* `style.yaml`: 문장 맺음, 구두점, 문장 길이, 괄호 풀이 금지, 어휘(한자어·기획 용어) 규칙. R1~R3의 결과가 들어갑니다.
* `josa.yaml`: §7의 조사 쌍, 받침 판정 규칙(숫자·영문·한자 읽기 포함), 입력 검증 규칙, 그리고 `examples`(입력 → 기대 출력). server 구현의 테스트 자료로도 씁니다.

## 6. 검사기 (`tools/`)

### 6.1. 명령

실행: `uv run --project docs/identity/writing/tools mlw <명령>`

| 명령 | 하는 일 | 쓰는 곳 |
| --- | --- | --- |
| `check <원고 경로>` | 콘텐츠 원고 검사 | writing CI, server 시드 CI |
| `check-arb <ARB 경로>` | ARB 화면 문구를 `slots/ui/` 기준으로 검사 | app CI |
| `gen-docs [--check]` | `generated/` 생성. `--check`는 최신인지만 확인 | writing CI |
| `gen-week-fixture --engine <주소>` | 한 주 검사용 고정 자료를 다시 만듦 (엔진 gRPC 호출) | 로컬, 엔진 규칙이 바뀌었을 때 |

### 6.2. 원고 형식 (`content/<lang>/*.yaml`)

```yaml
- slot: daily.fortune.head
  key: fortune.yongsin_day.siksang
  type: advice          # 유형 미적용 슬롯은 생략
  variant: 1
  text: "{name}님, 오늘은 떠오른 생각을 바로 적어 두기 좋은 날이에요."
```

* 자리표시자는 `{매개변수}`, 조사는 `{color}(이)가`처럼 표기만 하고 렌더러가 정합니다(§7).
* server는 이 원고를 시드 파일로 변환합니다. 시드 CI는 변환 전 원고에 `check`를 돌립니다.

### 6.3. 검사 층

1. **완결성:** `core/message_keys.json`과 슬롯 명세 기준으로 키 × 언어 × 유형 × 변주가 모두 있는지, 키의 매개변수에 없는 자리표시자를 쓰지 않았는지 확인합니다.
2. **문장 단위:** `style.yaml` 규칙, `slop.yaml`의 `judge: rule` 패턴(슬롯 `purpose`가 `exempt_purposes`에 있으면 건너뜀), 언어별 글자 수 상한(자리표시자는 가장 긴 값으로 채워 계산), 조사 표기 문법.
3. **묶음 단위 (빈도·밀도):**
   * **화면·하루:** 슬롯의 `co_display`와 엔진의 키 선택 규칙(날의 성격 4종 × 십성 그룹 5종 × 대표 태그 유무)으로 하루 화면에 나올 수 있는 조합을 모두 만들고, 유형 순환 위치마다 `limits.yaml`을 확인합니다.
   * **한 주:** 실제 날짜 순서가 필요하므로 `tools/fixtures/week_samples.json`(원국 표본 × 연속 7일의 메시지 키 나열)을 고정 자료로 둡니다. `gen-week-fixture`가 엔진 gRPC를 호출해 만듭니다. core 코드를 import하지 않으므로 계약(`proto` v1) 밖으로 기대지 않습니다.

### 6.4. 결과와 테스트

* 출력: `파일:줄 규칙ID 심각도 메시지`. `error`가 있으면 종료 코드 1, `warn`은 보고만 합니다.
* 테스트: 규칙마다 YAML의 `examples`(`hit`, `pass`)를 pytest가 읽어 검사기를 돌립니다. 규칙 데이터가 곧 테스트 자료입니다. 묶음 단위 검사는 작은 예시 원고 묶음으로 따로 테스트합니다.

## 7. 호칭·조사 규칙 (server 계약)

**조사 표기:** 원고에는 다음 6쌍만 씁니다. 렌더러가 앞 값의 마지막 글자로 받침을 판정해 고릅니다.

| 표기 | 받침 있음 | 받침 없음 | 예외 |
| --- | --- | --- | --- |
| `(이)가` | 이 | 가 | |
| `(은)는` | 은 | 는 | |
| `(을)를` | 을 | 를 | |
| `(과)와` | 과 | 와 | |
| `(으)로` | 으로 | 로 | ㄹ 받침이면 "로" |
| `(이)에요` | 이에요 | 예요 | |

* 숫자·영문·한자로 끝나는 값은 읽는 소리 기준으로 판정합니다(예: 1 → "일" → 받침 있음). 판정할 수 없으면 병기형 "이(가)"를 씁니다.

**호칭:**
* 한국어: 항상 `{name}님`. 님 뒤라 조사는 받침형으로 고정됩니다. 접미사 선택 기능은 두지 않습니다.
* 일본어: 항상 `{name}さん`.
* 영어: `{name}`만. 영어 슬롯은 호칭 빈도 상한을 한국어보다 낮게 둡니다(`limits.yaml`의 언어별 값).

**호칭 입력 검증:**
* 길이: 한국어·일본어 1~10자, 영어 1~20자
* 앞뒤 공백 제거
* 끝의 "님"은 떼고 저장합니다. 끝의 さん·様·ちゃん은 떼지 않고 경고합니다.
* 이모지·제어문자는 거부합니다.

**구현 분담:** server가 Go로 구현합니다. `josa.yaml`의 `examples`를 server 테스트 자료로 그대로 써서 두 쪽 판정이 같게 유지합니다.

## 8. 보이스·톤 가이드와 친숙도 검수

### 8.1. 가이드 뼈대 (`guide/voice-tone.md`)
* **보이스(고정):** README 성격 표 5항목을 어휘·문장 구조·문장 맺음·구두점 규칙으로 옮기고, 각 규칙은 `style.yaml` ID로 가리킵니다.
* **톤(슬롯별):** NN/g 4차원(유머↔진지, 격식↔캐주얼, 존중↔파격, 열정↔담백)을 좌표로 씁니다. 목적(`info`·`guide`·`care`)별 기본 좌표를 두고 슬롯이 조정합니다.
* 외부 접근법(Mailchimp, NN/g, Podmajersky, Yifrah, GOV.UK, 토스)은 원문을 확인한 것만 인용합니다.
* 영어·일본어: 구두점, 경칭, 한국어 대비 길이 비율 같은 언어별 대응만 정합니다. 원어민 검수(W1)를 대신하지 않는다고 명시합니다.

### 8.2. 검수 절차 (`guide/review-procedure.md`)
* 터미널에서 4~5지선다로 진행합니다. 선택지에는 항상 "다 별로"를 둡니다.
* 라운드마다 숨긴 slop 대조군 1개를 섞고, 앞 라운드 문항 1개를 순서를 바꿔 다시 냅니다(일관성 확인).
* 일부 선택지는 실제 커뮤니티·리뷰 표현에서 가져옵니다. 표현 단위로 검색해 쓰임을 확인하고, 크롤링은 하지 않습니다. 출처는 고른 뒤 공개합니다.
* 판정자는 사용자 한 명입니다. 같은 성격의 선택이 반복되면 규칙으로 굳혀 W#에 기록하고 YAML에 반영합니다.
* 대조군이 걸러지거나 사용자가 새 slop을 지적하면 `slop.yaml`에 패턴을 추가합니다.
* 라운드 기록: `artifacts/YYYY-MM-DD-round-<번호>.md` (`kind: copy-sample`), `artifacts/index.json`에 등록합니다.

### 8.3. W0 라운드

| # | 정할 것 | 반영 위치 |
| --- | --- | --- |
| R1 | 문장 맺음: 해요체·합니다체, 슬롯 목적별로 섞을지 | `style.yaml`, 가이드 |
| R2 | 구두점·리듬: 쉼표, 말줄임, 문장 길이, 한 슬롯의 문장 수 | `style.yaml` |
| R3 | 어휘: 한자어와 고유어, 용어 토큰으로 표시할 명리 용어 범위 | `style.yaml`, 슬롯 `depth` |
| R4 | 총운 유형별 예문: 조언·상태·돌봄의 좋은 예·나쁜 예 | 슬롯 `examples` |
| R5 | 돌봄 표현 빈도 상한: 하루·한 주 | `limits.yaml` |
| R6 | 가이드 질문의 형태: 열린 질문·선택 질문, 길이 | 슬롯 `structure` |
| R7 | 사용자에게 보이는 이름: "기본 깊이"와 단계 3개 (D37 위임분) | `slots/ui/depth.yaml` |

## 9. 계약과 요청함

**제공 계약 (등록 요청 대상)**
| 계약 | 원본 위치 | 사용 |
| --- | --- | --- |
| 슬롯 명세 | `docs/identity/writing/slots/` | server, app |
| 라이팅 검사기 | `docs/identity/writing/tools/` (`mlw` CLI) | server 시드 CI, app CI |
| 호칭·조사 처리 규칙 | `docs/identity/writing/guide/honorific-josa.md`, `rules/josa.yaml` | server 콘텐츠 모듈 |

**사용 계약:** 브랜드 기반(`docs/identity/README.md`), 메시지 키 목록(`core/message_keys.json`), 엔진 gRPC v1(한 주 고정 자료 생성용).

**요청함 문서**
| 문서 | 받는 쪽 | 내용 | 시점 |
| --- | --- | --- | --- |
| `writing-to-root-d40-scope` | 지휘 | 문장 유형을 총운에만 적용하는 해석 확인 (§4.2) | spec 승인 직후 |
| `writing-to-root-contracts` | 지휘 | 제공 계약 3개의 원본 위치·버전 등록 | 계약 파일이 생긴 뒤 |
| `writing-to-design-length` | design | 슬롯별 글자 수 상한 초안 전달, 레이아웃 기준 조정 요청 | 슬롯 명세 초안 뒤 |
| `writing-to-server-josa` | server | 호칭·조사 규칙과 원고 → 시드 변환 안내 | 규칙 확정 뒤 |
| `writing-to-root-w0-done` | 지휘 | W0 완료 보고. `root-to-writing-engine-keys-scale`을 `done`으로 | 마무리 |

## 10. CI

`.github/workflows/writing.yml` (writing 소유), 경로 필터 `docs/identity/writing/**`:
1. 검사기 pytest
2. `mlw gen-docs --check`
3. `mlw check content/` (W0에서는 예시 원고)

server·app CI에 검사기를 넣는 단계는 각자 소유이므로 이 spec의 범위 밖입니다.

## 11. 완료 기준

1. `guide/` 3종, `rules/` 4종, `slots/_schema.yaml`, `slots/content/`가 있고, 콘텐츠 슬롯이 메시지 키 93개와 §4.3 식별자를 모두 덮습니다.
2. 라운드 R1~R7의 결과가 YAML과 W#에 반영되어 있습니다.
3. 검사기 명령 4개가 동작하고, 규칙별 예시 테스트와 묶음 단위 테스트가 통과합니다. 한 주 고정 자료가 들어 있습니다.
4. `generated/`가 최신이고 `writing.yml`이 통과합니다.
5. §9의 요청함 문서를 작성했고, `CLAUDE.md`의 "현재 상태"를 고쳤습니다.

## 12. 범위 밖

* `slots/ui/` 목록 (IA 이후, 단 R7의 깊이 이름은 포함)
* W1 콘텐츠 원고, 태그라인·스토어 문구
* LLM 판정 명령 (W1 직전)
* server·app CI 연결, server의 조사 렌더러 구현
* Phase 2 LLM 코멘트의 실행 중 검사
