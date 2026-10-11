# 원국 개인 해석 키, 출생 시진 RPC, 엔진 정보 RPC 설계

* 작성: core 세션, 2026-10-11
* 상태: 검토 대기
* 요청: Issue #51(원국 개인 해석 메시지 키, D60), #41(출생 시각의 시진, D58), #49(`ruleset_version` 조회)
* 관련 결정: D6, D13, D27, D28, D31, D58, D60, C1, C3, C8

## 1. 목적과 범위

| 요청 | 만드는 것 | 계약 영향 |
| --- | --- | --- |
| #51 | `ChartResponse.personal_readings`: 사주 표·만세력·대운 표·세운 표의 용어마다 "내 사주에서는" 메시지 키와 매개변수 | proto 추가(v1 유지), 메시지 키 60개 추가, `ruleset_version` 올림 |
| #41 | `GetBirthHour` RPC: 출생 시각이 속한 시진 하나와 그 절대 시각 구간 | proto 추가 |
| #49 | `GetInfo` RPC: 엔진·규칙 버전 | proto 추가 |

세 요청 모두 proto에 추가만 하므로 한 PR로 묶습니다. 이 PR에서 `buf breaking`이 실제로 비교되는지도 확인합니다(#5-1 후속).

범위 밖:
* 문장은 writing이 씁니다(D27). 엔진은 키, 매개변수, 근거만 돌려줍니다.
* 권한 확인과 응답에서 빼는 일은 server가 맡습니다(D60 ④).
* 용신 판정 근거(`YongsinInfo.judgment`)는 이미 있으므로 이번에 다루지 않습니다.
* 강약·오행 분포 같은 원국 전체 값은 `evidence-sheet.basis.body`(판정 근거)가 맡으므로 개인 해석 대상에서 뺍니다.

## 2. 원국 개인 해석 (#51)

### 2.1 개인화의 기준

같은 용어라도 **자리**와 **내 원국에서의 역할**에 따라 해석이 달라져야 합니다. explain 깊이의 일반 뜻과 구분되는 지점이 여기입니다(D60에서 잠긴 기능으로 둔 이유). 엔진이 이미 계산하는 값만 씁니다.

| 매개변수 | 값 | 뜻 |
| --- | --- | --- |
| `place` | `YEAR_STEM` ~ `HOUR_BRANCH`(원국 자리), `<지지 자리>_HIDDEN`(그 지지의 지장간) | 용어가 놓인 자리. 문장에서 자리별 의미(연주·월주·일주·시주, 천간·지지)를 고르는 데 씁니다 |
| `element` | `WOOD` 등 `Element` 이름 | 그 용어 글자의 오행 |
| `role` | `YONGSIN`, `HUISIN`, `GISIN`, `NEUTRAL` | 그 오행이 내 원국에서 맡는 역할. 위 순서로 먼저 맞는 것 하나. 통관은 희신과 같은 오행이라 따로 두지 않습니다 |
| `group_count` | 정수 | 원국(일간 제외 천간 + 지지 정기)에 같은 십성 묶음(비겁·식상·재성·관성·인성)이 몇 개 있는지. 태그의 십성 쏠림과 같은 계산입니다 |
| `strength` | `StrengthLevel` 이름 | 신강·신약 등급 |
| `yongsin`, `gisin` | `Element` 이름 | 일간 해석에 쓰는 용신·기신 오행 |
| `luck` | `DAEUN`, `SEUN` | 운의 종류 |
| `part` | `STEM`, `BRANCH` | 운 기둥의 천간·지지 |
| `current` | 참·거짓 | 그 대운·세운이 `as_of` 기준 지금인지 |

### 2.2 메시지 키 (C27)

**결정 C27: 키는 용어 단위로 두고, 자리는 매개변수(`place`)로 넘깁니다.** root가 물은 "자리별 키 vs 자리 매개변수"에 대한 답입니다.

* 이유 1, 규모: 자리별 키는 십성 70 + 12운성 48 + 신살 24 + 일간 10 = 152개이고 대운 표를 넣으면 더 늘어납니다. 용어 단위는 60개입니다. 3개 언어를 곱하면 456개 대 180개입니다.
* 이유 2, 결정권: 자리별로 문장을 얼마나 나눌지는 writing이 정합니다. writing은 `place` 값별로 변주를 둘 수도 있고, 자리 의미 조각과 용어 조각을 이어 쓸 수도 있습니다. 엔진 계약(키 집합)은 그 선택과 상관없이 고정됩니다.
* 이유 3, 일관성: 지금 키도 같은 방식입니다. 예를 들어 `fortune.<날의 성격>.<십성 묶음>`은 세부를 `ten_god`·`element` 매개변수로 넘깁니다.

| 키 묶음 | 개수 | 매개변수 | 대상 |
| --- | --- | --- | --- |
| `personal.day_master.<천간>` | 10 | `strength`, `yongsin`, `gisin` | 일간 |
| `personal.ten_god.<십성>` | 10 | `place`, `element`, `role`, `group_count`, `strength` | 원국 천간·지지(정기)의 십성, 지장간의 십성 |
| `personal.twelve_stage.<12운성>` | 12 | `place`, `element`, `role`, `strength` | 원국 지지의 12운성 |
| `personal.shinsal.<신살>` | 6 | `place`, `element`, `role` | 원국 신살(천을귀인·도화·역마·화개·양인·공망) |
| `personal.luck.ten_god.<십성>` | 10 | `luck`, `part`, `element`, `role`, `current` | 대운 천간·지지 십성, 세운 천간 십성 |
| `personal.luck.twelve_stage.<12운성>` | 12 | `element`, `role`, `current` | 대운 12운성 |

* `<천간>`·`<십성>`·`<12운성>`·`<신살>`은 도메인 enum 이름의 소문자입니다(예: `personal.day_master.gap`, `personal.ten_god.siksin`, `personal.twelve_stage.jewang`, `personal.shinsal.cheoneul_gwiin`).
* 원국과 운을 다른 키로 나눈 이유: 원국은 "타고난 바탕", 운은 "그 10년·그해"라서 문장의 틀이 다릅니다. 매개변수도 다릅니다(운에는 `current`가 있고 `group_count`·`place`가 없음).
* `message_keys.json`은 93개에서 153개로, `message_params.json`도 같이 늘어납니다.

### 2.3 응답 위치

`ChartResponse`에 목록 하나를 더합니다. server가 권한이 없을 때 **필드 하나만 빼면** 되도록, 표 메시지마다 흩어 넣지 않고 최상위 목록으로 둡니다.

```proto
// 원국 개인 해석("내 사주에서는")이 가리키는 용어 (D60).
enum PersonalTermKind {
  PERSONAL_TERM_KIND_UNSPECIFIED = 0;
  PERSONAL_TERM_KIND_DAY_MASTER = 1;          // 일간. position = DAY_STEM
  PERSONAL_TERM_KIND_TEN_GOD = 2;             // 원국 천간·지지의 십성. position
  PERSONAL_TERM_KIND_HIDDEN_TEN_GOD = 3;      // 지장간의 십성. position(지지) + index(지장간 순서, 0이 정기)
  PERSONAL_TERM_KIND_TWELVE_STAGE = 4;        // 원국 지지의 12운성. position
  PERSONAL_TERM_KIND_SHINSAL = 5;             // 원국 신살. position + shinsal
  PERSONAL_TERM_KIND_DAEUN_STEM_TEN_GOD = 6;  // index = DaeunTable.periods 순서
  PERSONAL_TERM_KIND_DAEUN_BRANCH_TEN_GOD = 7;
  PERSONAL_TERM_KIND_DAEUN_TWELVE_STAGE = 8;
  PERSONAL_TERM_KIND_SEUN_TEN_GOD = 9;        // index = ChartResponse.seun 순서
}

message PersonalReading {
  PersonalTermKind kind = 1;
  Position position = 2; // 원국 용어만. 대운·세운은 UNSPECIFIED
  int32 index = 3;       // HIDDEN·DAEUN·SEUN만 의미. 그 밖은 0
  Shinsal shinsal = 4;   // SHINSAL만. 그 밖은 UNSPECIFIED
  Judgment judgment = 5;
}

message ChartResponse {
  ...
  // evidence 깊이의 원국 개인 해석(D60). 열람 권한이 없으면 server가 이 필드를 응답에서 뺍니다.
  repeated PersonalReading personal_readings = 13;
}
```

* 앱은 누른 용어의 `(kind, position, index, shinsal)`로 해석을 찾습니다. 한 자리에 신살이 여럿이면 `shinsal`로 구분합니다.
* 목록 순서는 고정합니다: 일간 → 원국 십성(자리 순) → 지장간 → 12운성 → 신살 → 대운(구간마다 천간·지지·12운성) → 세운.
* 시간 모름이면 시주 자리 항목은 없습니다(원국 표와 같음).

### 2.4 근거

* 모든 판정에 근거가 있어야 한다는 불변 조건(spec §13.4)을 지킵니다.
* 각 Judgment의 근거는 두 가지입니다.
  * 규칙 근거: `rule_id`는 `personal/<묶음>` 형식입니다(예: `personal/ten_god`, `personal/luck_ten_god`). `detail`에는 자리·용어·오행·역할을 담습니다.
  * 역할 판정 근거: 용신 판정의 근거(`yongsin.evidence`)를 그대로 붙입니다.
* 자리 의미(궁위)를 다룬 원전 자료는 아직 없습니다. 그래서 C8처럼 `gungtong-bogam/five_elements#balance_principle`을 `source_ref`로 씁니다. 궁위 원전이 들어오면 규칙 근거만 바꿉니다(출력이 바뀌므로 그때 `ruleset_version`을 올림).

### 2.5 구조

* `rules/personal.py`(새 파일): 순수 함수만 둡니다.
  * `element_role(element, yongsin) -> str`: 역할을 정합니다.
  * 키 묶음마다 하나씩, Judgment를 만드는 함수를 둡니다.
* `composers/chart.py`: `compose_chart`가 원국·대운·세운을 돌며 `PersonalReading` 목록을 만들어 `ChartView.personal_readings`에 담습니다.
* `domain/models.py`: `PersonalReading`과 `PersonalTermKind`를 추가합니다. enum은 `domain/enums.py`에 둡니다.
* `grpc_api/mapping.py`: 도메인 값을 proto로 옮깁니다.
* 십성 묶음 개수 계산(`tags._natal_group_count`)은 공용 함수로 옮겨 태그와 개인 해석이 함께 씁니다. 동작은 바꾸지 않습니다.
* 키와 매개변수는 `KEY_PARAMS`에 선언합니다. `require(key, params)`가 실제 매개변수가 선언과 같은지 확인합니다(#38).

### 2.6 버전

원국 응답이 바뀌므로 `ruleset_version`을 `2026.10.1`에서 `2026.10.2`로 올리고 원국 스냅샷을 갱신합니다(README 절차). 데일리·월간 출력은 바뀌지 않습니다.

## 3. 출생 시진 RPC (#41)

```proto
rpc GetBirthHour(BirthHourRequest) returns (BirthHourResponse);

message BirthHourRequest {
  BirthInfo birth = 1; // time이 없으면 INVALID_ARGUMENT
}

// 출생 시각이 속한 시진. start·end는 절대 시각이며, 벽시계 표시는 server·app이 출생 시간대로 바꿉니다.
message BirthHourResponse {
  Branch branch = 1;
  google.protobuf.Timestamp start = 2;
  google.protobuf.Timestamp end = 3;
  ResponseMeta meta = 4; // 자시 경계·서머타임 공백·중복 notice 포함
}
```

* 계산은 원국과 같은 출생 시각 해석(`resolve_birth_moment`)을 씁니다. 따라서 다음이 원국과 똑같이 반영됩니다(C1·C3).
  * 서머타임(위키 §2.2 표의 시행 기간)
  * UTC+8:30 시기
  * 경도 보정: 입력 경도가 없으면 대표 경도
  * 공백·중복 시각 처리
* 시진 경계는 보정 시각의 홀수 정시(23:00, 01:00, …)입니다. 그 구간에서 경도 보정을 거꾸로 빼서 절대 시각으로 바꿉니다. 예: 서울 1990-05-05 04:00 출생이면 인시이고, 구간은 KST 03:30~05:30입니다.
* 자시는 자시 통합(D6)에 따라 보정 23:00~01:00 한 구간입니다.
* 시간 모름이면 `INVALID_ARGUMENT`(필드 `birth.time`)를 냅니다. 범위 밖 날짜는 다른 RPC와 같이 `OUT_OF_RANGE`입니다.
* 원국 전체를 계산하지 않으므로 호출 비용이 작습니다. 비로그인 온보딩에서도 쓸 수 있습니다.

## 4. 엔진 정보 RPC (#49)

```proto
rpc GetInfo(InfoRequest) returns (InfoResponse);

message InfoRequest {}

message InfoResponse {
  string engine_version = 1;
  string ruleset_version = 2;
}
```

* 계산 없이 상수만 돌려줍니다. server가 캐시 무효화 판단에 쓰며, 지금 쓰는 10분 주기 `GetChart` 우회책을 대신합니다.

## 5. 테스트

| 층 | 내용 |
| --- | --- |
| 규칙 단위 | `element_role`의 우선순위(용신 > 희신 > 기신 > 그 밖), 묶음별 키·매개변수·근거, `place` 표기(지장간 `_HIDDEN`) |
| composer | 원국 표의 모든 십성·지장간·12운성·신살 자리에 해석이 하나씩 있음. 대운 10구간 × 3, 세운 수만큼 있음. `current`가 `as_of`의 대운·세운 하나에만 참. 시간 모름이면 시주 자리 없음 |
| 불변 조건 | 무작위 원국에서 모든 해석에 근거가 있고 키가 등록돼 있음(`require`가 매개변수까지 확인) |
| 시진 | 서울 일반 시각(인시 03:30~05:30), 자시 통합 경계(보정 23:00 전후), 1987 서머타임, 1955 UTC+8:30, 경도 입력, 시간 모름 `INVALID_ARGUMENT` |
| gRPC 통합 | `GetChart`의 `personal_readings` 변환, `GetBirthHour`, `GetInfo`, 오류 코드 |
| 스냅샷 | 원국 스냅샷 갱신, `ruleset_version` 해시 기록 갱신 |
| 계약 | `buf lint`, `buf breaking`(이 PR에서 실제 비교되는지 확인), 생성 코드 일치, `message_keys.json`·`message_params.json` 갱신 |

## 6. 다른 쪽에 알릴 것

* **server**
  * `personal_readings`는 권한이 없으면 응답에서 뺍니다(D60 ④).
  * `GetBirthHour`를 비로그인 시진 확인으로 감쌉니다(#41).
  * `GetInfo`로 버전 확인 우회책을 바꿉니다(#49).
  * `ruleset_version`이 `2026.10.2`로 바뀝니다.
* **writing:** 키 60개와 매개변수가 늘어납니다. `place` 값 목록과 역할 값이 문장 설계의 기준입니다. W1 원고 범위로 씁니다.
* **root:** 계약 목록의 proto·메시지 키·매개변수 행을 갱신하고, #41·#49·#51을 닫습니다.
