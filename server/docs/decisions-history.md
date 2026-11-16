# server 결정 로그: 대체된 결정의 원문

[`decisions.md`](decisions.md)에서 통째로 대체된 결정의 원문 행입니다. 지금 효력은 decisions.md의 새 번호가 기준입니다(D131).

| # | 날짜 | 영역 | 결정 | 근거 / 문서 |
| --- | --- | --- | --- | --- |
| S16 | 2026-10-13 | 계정 | 삭제 대기(`pending_deletion`) 계정이 가진 access token으로는 `getMe`·`deleteMe`·`logout`만 됩니다. refresh는 거부하고, 같은 제공자로 다시 로그인해야 계정이 돌아옵니다. 복구 로그인은 같은 트랜잭션에서 그 계정의 이전 세션(refresh token)을 모두 폐기하고 새 세션만 발급합니다. 제공자 연결 해제는 외부 호출 직전에 계정이 아직 삭제 대기인지 확인합니다 (→ S105로 개정) | P2 계획 Task 8·10, 최종 review |
| S53 | 2026-10-20 | 일기 | `restoreDiary`는 그 날짜에 지운 일기 중 가장 늦게 지운 것을 되살립니다. 살아 있는 일기가 있으면 409 `diary.date_taken`, 지운 일기가 없으면 404 `diary.not_found`입니다 (→ S97로 대체) | P5 계획 P5-4 |
| S55 | 2026-10-20 | API | 일기 목록 cursor는 마지막 항목 날짜를 base64url(패딩 없음)로 감싼 불투명 문자열이고 keyset `date < cursor`로 넘깁니다(살아 있는 일기의 날짜는 계정 안에서 유일). 해석할 수 없으면 400 `request.invalid`입니다 (→ S98·S95로 대체) | P5 계획 P5-6 |
| S63 | 2026-10-20 | 데이터 | `diaries`의 목록 인덱스를 따로 두지 않습니다. partial unique `diaries_one_per_day (account_id, date) WHERE deleted_at IS NULL`이 역방향 스캔으로 날짜 내림차순 목록을 덮습니다. 태그 필터는 GIN이 쓰는 `all_tags @> ARRAY[...]`입니다 (→ S98·S95로 대체) | P5 Task 3 |
