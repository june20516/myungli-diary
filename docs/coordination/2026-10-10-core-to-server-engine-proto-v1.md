---
from: core
to: server
kind: report
status: open
created: 2026-10-10
related: [D27, D31, D33, engine.proto v1, core/message_keys.json, core spec §9·§10·§11·§12]
---

# 엔진 gRPC 계약 v1(proto) 확정: 엔진 대역으로 개발을 시작할 수 있습니다

## 무엇을 했는가
엔진 gRPC 계약 v1을 commit했습니다. server는 이 계약으로 엔진 대역(stub/fake)을 만들어 개발을 시작할 수 있습니다.

* **proto 위치:** `proto/myungri/engine/v1/engine.proto`. buf 설정은 `proto/buf.yaml`(lint STANDARD, breaking FILE)입니다.
  * spec §9가 서비스·요청·응답 이름을 고정하므로 lint 규칙 `SERVICE_SUFFIX`, `RPC_REQUEST_STANDARD_NAME`, `RPC_RESPONSE_STANDARD_NAME`만 뺐습니다.
  * `option go_package`는 넣지 않았습니다. Go import 경로는 server가 정하는 값이므로 `buf.gen.yaml`의 managed mode(`go_package_prefix`)나 `M` 옵션으로 지정해 주세요. proto 파일에 넣어야 하면 `server-to-core` 요청으로 알려 주세요.
* **패키지:** `myungri.engine.v1`
* **서비스 `MyungriEngine`의 RPC 3개:**
  * `GetChart(ChartRequest) returns (ChartResponse)`: 나의 사주
  * `GetDaily(DailyRequest) returns (DailyResponse)`: 데일리
  * `GetMonthCalendar(MonthRequest) returns (MonthResponse)`: 월간 캘린더
* **생성 코드 위치 정책(D33):** 생성 코드는 서비스마다 자기 디렉터리에 commit합니다. core는 `core/src/myungri_engine/_gen/`(`core/tools/gen_proto.sh`로 생성)에 둡니다. server는 Go 생성 코드를 `server/` 안에 직접 생성해 commit해 주세요. core의 생성물을 가져다 쓰지 않습니다.
* **메시지 키 목록:** `core/message_keys.json`(정렬된 JSON 배열)입니다. `Judgment.message_key`(카드·용신·총운·가이드·`MonthDay.judgment` 포함), `featured_tags`, `all_tags`, `MonthDay.featured_tag`에 오는 값은 모두 이 목록에 있습니다. 콘텐츠 모듈 시드가 모든 키를 3개 언어(D28)로 갖는지 server 쪽 테스트로 검사할 수 있습니다.
* **`source_ref` 형식(spec §11):** `<자료 디렉터리>/<파일 이름(확장자 제외)>#<키 경로>`. 예: `gungtong-bogam/johu_evidence#甲.子`, `gungtong-bogam/five_elements#direction`. `Evidence.source_ref`에 들어가며, Pro 화면의 근거 표시에 씁니다.
* **점수 구성 id(`MonthDay.score_items[].id`):** `gwiin_day`, `yongsin_day`, `gisin_day`, `hap`, `chung_day_or_month`, `chung_other`, `hyeong`. **메시지 키가 아니라 식별자**이므로 `message_keys.json`에는 없습니다.
  * 역할 분담: `MonthDay.judgment`가 화면 문구용 판정입니다. `message_key`는 `calendar.<good|neutral|caution>`이고, `evidence`에 점수 구성 근거(rule_id 예 `calendar/score`, source_ref 예 `gungtong-bogam/five_elements#balance_principle`, `detail`에 구성)가 담깁니다. `score_items`는 같은 구성을 숫자로 다루기 위한 원본 값입니다(점수 막대 표시 등). 항목별 문구가 필요하면 콘텐츠 모듈에서 id를 직접 매핑해 주세요.
  * 집중 시간 가점 사유(`FocusSlot.reasons`: `gwiin`, `yongsin`, `huisin`, `hap`)도 같은 성격의 식별자입니다.
* **관례:**
  * enum 0번은 `<ENUM>_UNSPECIFIED`입니다. 요청에서 UNSPECIFIED(예: `GENDER_UNSPECIFIED`)는 `INVALID_ARGUMENT`이고, 응답에서 enum 필드의 "값 없음"은 항상 UNSPECIFIED입니다(예: `Relation.suppressed_by`, `YongsinInfo.johu_stem`).
  * 메시지 타입 필드는 그 자체로 값 유무를 구분하고(예: `MonthDay.solar_term`), 스칼라·문자열의 "없음"은 `optional`입니다(예: `BirthInfo.time`, `MonthDay.featured_tag`).
  * 시간 모름이면 `ChartResponse.pillars.hour`가 비어 있습니다.
  * 시각(`FocusSlot.start/end`, `SolarTerm.at`)은 `google.protobuf.Timestamp`(절대 시각)입니다. 표시할 때는 요청의 `current_timezone`으로 바꿔 주세요.
  * 오류 코드: 잘못된 입력 `INVALID_ARGUMENT`, 지원 범위(양력 1900-01-31 ~ 2099-12-31) 밖 `OUT_OF_RANGE`, 그 밖 `INTERNAL`. 계산되는 민감 상황은 오류가 아니라 `ResponseMeta.notices`입니다(D32).
  * `ResponseMeta.ruleset_version`은 일기 저장 시 태그와 함께 기록하고 캐시 키에 넣어 주세요(D31, spec §12).

## 왜
core `CLAUDE.md` "다음 할 일 4": proto v1이 확정되면 server가 엔진 실행을 기다리지 않고 대역으로 개발을 시작할 수 있습니다.

## 영향
* server: 이 계약으로 Go 코드 생성과 엔진 대역 구현을 시작할 수 있습니다.
* **엔진 구현은 아직 진행 중입니다.** 화면 단위 조립, gRPC 서버 실행(`uv run python -m myungri_engine --port 50051`), 회귀 스냅샷은 이후 task에서 진행하며, 완료되면 `core-to-root` 완료 보고로 알립니다. 그 전까지 실제 엔진 서버는 띄울 수 없습니다.
* 이후 proto 변경은 `buf breaking`(FILE)으로 검사하며, 하위 호환이 깨지는 변경은 `notice`로 따로 공지합니다.

## 처리 기록
<!-- 지휘 세션과 받는 쪽이 날짜와 함께 덧붙입니다. -->
