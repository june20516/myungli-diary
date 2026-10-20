# S3(REST v1 freeze) 준비 점검

* 날짜: 2026-10-20
* 대상: `server/api/openapi.yaml` 1.0.0-draft.10 → draft.11
* 기준: freeze 뒤에는 하위 호환 추가만 합니다(workflow §6.1, S93).

## draft.11에서 고친 것

| 영역 | 내용 | 결정 |
| --- | --- | --- |
| 알림 기기 | `registerDevice` 200(이미 등록된 토큰, 같은 `id`)·201, 계정당 활성 10대, 부르는 때, `Idempotency-Key`와의 관계. `deleteDevice` 멱등 204와 404 `device.not_found`, 로그아웃 전 호출 | S92 |
| 호환 정책 | info에 "호환과 버전" 절(하위 호환 변경의 범위, `/v2`, 버전 올림 규칙) | S93 |
| 열린 enum | 값이 늘 수 있는 응답 enum 목록과 app의 처리(모르는 값은 건너뜀) | S93 |
| 동의 전 허용 | `deleteDevice`를 동의 전 허용 operation에 추가(코드 `allowedWhileConsentRequired`와 `agreeConsents` 설명) | S93 |
| 오류 설명 | `FieldError.code`의 `invalid`와 스키마 밖 `request.invalid`, `revenuecatWebhook` 401 `auth.token_invalid`, `getBirthHour` 422 code, `LunarOrSolarDate`의 없는 음력 날짜 code(프로필 `birth.invalid`, 변환·시진 `date.invalid`), `putDiary` 422 `date.out_of_range` | - |
| 응답 목록 | `completeAppleWebLogin` 429 제거(나지 않음), `admobRewardCallback` 400·500 추가(나는데 없었음) | S93 |
| 동작 설명 | `logout`(모르는 토큰도 204), `getDiary`·`deleteDiary` 404, `listSchedules` 정렬과 `range.too_long` field `to` | - |
| 생략 조건 | `Schedule.memo`(빈 문자열은 생략), `Diary.guideQuestion`, `AdFree.expiresAt`(`active`일 때만), `SlotText.evidence`(근거가 있을 때만) | - |
| 공통 규약 | cursor는 불투명·같은 필터와 함께, `nextCursor` 없음 = 마지막, `listCities`는 `limit`만, 모든 응답의 `X-Trace-Id`, `Problem.type` 대신 `code`로 구분 | S93 |

## 그대로 두는 것

* **이름 차이:** `Glossary.lang`·`Profile.language`, `CalendarDay.level`(문장)·`luckLevel`(enum), `BirthHour.start`·`end`(HH:MM)·`FocusSlot.start`·`end`(date-time), namespace 없는 `rate_limited`·`internal`·`not_implemented`, `SlotText.variant`의 `'1'`·`'2'`. 스키마 설명으로 구분되고, 바꾸면 하위 호환을 깨 app 생성 코드를 다시 맞춰야 해 얻는 것보다 비용이 큽니다(S93).
* **어느 route에서나 날 수 있는 413·404·405:** route마다 적지 않고 `default`가 덮습니다.
* **요청 검증은 OpenAPI 3.0.3으로 낮춰 돌림:** 3.1 전용 keyword를 쓰지 않는 동안 문제가 없습니다. 새 keyword를 쓸 때 다시 봅니다.

## freeze 전에 남은 일

1. app에 요청: 생성 옵션 `enumUnknownDefaultCase`(열린 enum의 모르는 값을 decode 실패로 보지 않음)와 알림 기기 호출 시점. #347로 요청했고, 답을 받은 뒤 freeze PR을 올립니다.
2. `registerDevice`·`deleteDevice` 구현(P8). 계약은 draft.11로 확정입니다.
3. 예시(example): 하위 호환 추가라 freeze 뒤에도 넣을 수 있습니다. 우선 `Problem`(errors 포함), `ProfileResponse.warnings`, `LoginResponse`, `Daily`, `Chart` 순서로 넣고, 계약 테스트의 `doc.Validate`가 예시를 검사하는지 확인합니다.
4. IA 화면별 슬롯과 계약 데이터의 끝까지 대조(이번 점검에서 다 하지 못함).
5. freeze PR: `info.version` `1.0.0`, 계약 표 상태 "freeze", 루트 로드맵 S3 갱신은 지휘에 보고.
