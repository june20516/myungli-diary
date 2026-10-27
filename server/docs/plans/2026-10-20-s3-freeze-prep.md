# S3(REST v1 freeze) 준비 점검

* 날짜: 2026-10-20
* 대상: `server/api/openapi.yaml` 1.0.0-draft.10 → draft.11, freeze 1.0.0(2026-10-23, S114)
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

## freeze 전에 남은 일 (2026-10-23 마침)

1. **app 생성 옵션(#347):** app이 답했습니다(A66). 계약 info "호환과 버전" 절의 열린 enum 목록을 읽어 그 enum에만 모르는 값 처리를 생성합니다. 그래서 절의 틀("열린 enum:" … "그 밖의 enum", 백틱 이름)을 유지합니다.
2. **`registerDevice`·`deleteDevice` 구현:** P8에서 합니다. 계약은 draft.11로 확정이라 freeze와 상관없습니다.
3. **예시(example):** 하위 호환 추가라 freeze 뒤 patch로 넣습니다. 우선 `Problem`(errors 포함), `ProfileResponse.warnings`, `LoginResponse`, `Daily`, `Chart` 순서로 넣고, 계약 테스트의 `doc.Validate`가 예시를 검사하는지 확인합니다.
4. **IA 대조:** 화면 40개(`docs/ia/screens.json`)를 계약 operation 49개와 끝까지 맞췄습니다. 하위 호환을 깨야만 고칠 수 있는 것은 아래 "freeze에서 고친 것"에 넣었고, 나머지는 "freeze 뒤 할 일"에 적었습니다.
5. **freeze PR:** `info.version` `1.0.0`, 계약 표 상태 "freeze", 결정 S114. 루트 로드맵 S3 갱신은 지휘에 보고합니다.

## freeze에서 고친 것 (1.0.0, S114)

| 영역 | 내용 |
| --- | --- |
| 열린 enum | `YongsinMethod`(통관·병약·격국 용신이 Phase 2), `SlotText.reaction`(반응 종류), `Language`(지원 언어)를 더함. `ElementRole`·`BirthTime.status`·`LuckLevel`은 늘 근거가 없어 닫힌 enum으로 둠 |
| 합치기 요약 | `MergeSummary.diaries`·`schedules`는 살아 있는 기록만 셈(D85 ⑦: 지운 기록은 화면에서 되살릴 수 없음). 지운 기록도 옮기는 것은 그대로 |
| 설명 | `ConsentDocument`(받은 값을 그대로 돌려보냄, 새 필수 문서는 최소 앱 버전과 함께), `listPurchases`(페이지 나누기를 더해도 그 필드 없이 부르면 전부), `listDiaries`(합친 날은 10편을 넘을 수 있어 `nextCursor`를 따라감), `AdFree.expiresAt`(이어 붙인 대기 구간까지 포함) |
| info | "(초안)"과 freeze 전 절차 문장을 freeze 뒤 문장으로 바꿈 |

## freeze 뒤 할 일

하위 호환 추가(minor)나 설명(patch)으로 풀 수 있는 것입니다.

* **계산 기준 값(minor):** 계산 기준 화면(`calc-basis`)이 쓰는 대표 경도·표준 자오선·보정 분·서머타임 분을 선택 필드로 더합니다(예 `Profile.birthCorrection`). app이 따로 계산하면 엔진과 값이 어긋날 수 있습니다(S46).
* **날짜 기록 읽기(minor):** 그날 일기를 다 지운 뒤 다시 쓸 때 화면의 가이드 질문과 저장되는 질문(S95: 날짜 기록은 남음)이 다를 수 있습니다. 날짜 기록(`guideQuestion`·태그)을 읽는 길이 필요합니다.
* **구매 종류(minor):** `Purchase`에 상품 종류(기간권·구독·기간 없는 상품)를 선택 필드로 더해, app 표에 없는 새 상품도 상태 문구를 고를 수 있게 합니다(D88 ②, D53 ③의 구독).
* **로그인 응답의 프로필 유무(minor, 급하지 않음):** 지금은 로그인 뒤 `getMe`로 확인합니다.
* **설명(patch):** 대표 태그가 없는 날 `Fortune.tag`가 없을 때 app 처리, `Chart.seun`의 연도 범위, 일기 "미래"의 기준 시간대(프로필 `currentTimezone`).
* **지휘에 올린 결정:** 일기 보기의 "그날 성격"을 쓸 때 기록한 값으로 보일지(필요하면 `Diary.dayKind` 추가), 미리보기 총운에 호칭을 넣을지(IA·writing 슬롯은 호칭 자리, S71은 호칭 없음). 어느 쪽이든 추가로 풉니다. (완료: D90 ①은 1.1.0 `Diary.dayKind`(S116), D90 ②는 호칭 없음 그대로)
* **다른 단위 몫:** IA `account-choice` 설명이 D85 ④보다 앞선 문장(지휘), `ui.purchase.status`에 `owned` 키 없음(writing, MVP 상품에는 안 나옴).
* **REST 밖:** 아침 알림 FCM 메시지 형식은 P8에서 app과 정합니다.
