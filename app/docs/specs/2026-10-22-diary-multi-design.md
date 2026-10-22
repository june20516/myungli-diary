# 일기 하루 여러 편 (D83) 설계

* 작성: app 세션, 2026-10-22
* 상태: 승인 (2026-10-22), 구현: 브랜치 `app/d83-diary`
* 요청: Issue #412 (drift), #437 (REST draft.13), #408 (일기 흐름), #424 (한 날짜 10편 상한), #418 (writing 원고 중 일기 키)
* 관련 결정: app A45·A47·A48·A50·A51(이 spec이 A67~A71로 갱신), 루트 D47 ②·D49·D83
* 쓰는 계약: REST API `server/api/openapi.yaml` `1.0.0-draft.13`(`createDiary`·`getDiary`·`updateDiary`·`deleteDiary`·`listDiaries`), server spec `server/docs/specs/2026-10-22-diary-multi-design.md` §4, IA 화면 `today`·`day-sheet`·`diary-list`·`diary-edit`·`diary-view`·`tag-diary`, writing ARB(#418·#424 코멘트의 키)
* 기다리는 것: design #410(`diary-row`의 같은 날 여러 편 모양). server 일기 구현(`server/d83-diary-impl`)은 아직 main에 없어 실제 API는 501입니다. 이 spec은 계약과 fake server로 검증합니다

## 1. 목적과 범위

일기를 하루 여러 편 쓰도록 app 일기 흐름을 바꾸고(D83), 이 단위에 쌓인 drift #412를 한 PR에서 맞춥니다. drift는 생성 코드 재생성만으로 끝나지 않습니다. draft.13 API 생성 코드가 날짜 기반 일기 저장소를 깨뜨리기 때문입니다. 그래서 일기 이전과 함께 합니다.

**성공 기준**
* ci-gate의 app drift 검사(생성 코드 4종 차이, ARB 문구, fixture, IA 커버리지, contract 테스트)와 app 전체 검사가 통과합니다.
* 같은 날 일기를 여러 편 쓰고, 보고, 고치고, 지울 수 있습니다(fake 모드).
* 그날 살아 있는 일기가 10편이면 쓰는 입구 세 곳이 막히고, 그래도 저장이 422 `diary.day_full`을 받으면 오류 문구로 알리고 초안을 남깁니다.
* 고치던 글과 새로 쓰던 글은 한 편 단위로 기기 초안에 남습니다(D47 ②).

**다루지 않는 것**
* `diary-row`의 같은 날 여러 편 모양(design #410): 답이 오기 전에는 지금 `diary-row`를 작성 순으로 이어 그립니다(§6).
* 지운 일기 되살리기(`restoreDiary`): IA에 자리가 없어 app에 되살리기 UI가 없습니다(A50). #424의 "되살리기 422"는 app에 해당하지 않습니다.
* `dialog` 첫 초점 변경(design V41): drift 검사 대상이 아니므로 계획 7 로그인 PR에서 합니다.
* D82 로그인 키: ARB 가져오기로 함께 들어오지만 쓰는 화면은 계획 7입니다.

## 2. drift 맞추기

* 다시 생성: `dart run tool/gen_ia.dart`(IA, `today`·`day-sheet`의 출구·역할·`diary-row`), `tool/gen_api.sh`(draft.13: `Diary.id`·`DiarySummary.id`·`createdAt`, `DiaryBodyInput`, 새 operation), `dart run tool/import_writing_arb.dart` 뒤 `flutter gen-l10n`(writing ARB 전체), `dart run tool/gen_tokens.dart`(바뀜 없음 확인).
* `problemMessages`(`lib/core/l10n/error_messages.dart`): `diary.day_full` → `errorDiaryDayFull`을 더하고 `diary.date_taken`을 지웁니다. `test/contract/problem_codes_contract_test.dart`가 계약의 `x-problem-codes`와 대조합니다. 반영 뒤 #418에 `errorDiaryDateTaken`을 더 쓰지 않는다고 알립니다(writing이 키를 지움).
* IA 커버리지: 새 출구 `today → diary-view`(오늘 쓴 일기 줄)를 흐름 테스트 `Covers`로 덮습니다.

## 3. 저장소 (`DiaryRepository`)

날짜 대신 id로 일기 한 편을 다룹니다. 실패 분류(`appErrorFrom`)와 빈 응답 처리는 지금과 같습니다.

| 메서드 | operation | 비고 |
| --- | --- | --- |
| `create(CalendarDate date, String body, {required String idempotencyKey}) → Diary` | `createDiary` | 422 `diary.future_date`·`diary.day_full`은 `ProblemError` |
| `update(String id, String body) → Diary` | `updateDiary` | 지운 일기는 404 `diary.not_found` |
| `find(String id) → Diary?` | `getDiary` | 404면 null |
| `delete(String id)` | `deleteDiary` | 지금과 같음 |
| `diariesOn(CalendarDate date) → List<DiarySummary>` | `listDiaries(from: date, to: date, limit: 100)` | 그날 살아 있는 일기, 작성 순(server 순서) |
| `datesIn(from, to) → Set<CalendarDate>` | `listDiaries` | `nextCursor`가 없을 때까지 이어 받음(§7) |
| `page(...)` | `listDiaries` | 지금과 같음 |

`existsOn`은 지웁니다(`diariesOn`이 대신함). 한 날짜 상한은 상수 `diaryDayLimit = 10`(D83 ②)이고, 계약의 기준은 server입니다(상수가 어긋나도 422가 막음).

fake server(`lib/core/api/fake/fake_diary_store.dart`)도 계약대로 id(uuid)·작성 순·10편 상한 422·`Idempotency-Key` 재전송 같은 응답·soft delete를 따릅니다.

## 4. 경로 (결정 A67)

| 화면 | 경로 | 뜻 |
| --- | --- | --- |
| `diary-view` | `/diary-view?id=<uuid>` | 그 일기 한 편. 제목의 날짜는 받은 `Diary.date` |
| `diary-edit` | `/diary-edit?date=YYYY-MM-DD` | 그날 새 일기 |
| `diary-edit` | `/diary-edit?id=<uuid>` | 그 일기 고치기 |

* query 이름 `id`는 상수 `diaryIdQuery`로 `app_router.dart`에 두고, 만드는 함수 `diaryPathOf(String screenId, String id)`를 둡니다(`datedPathOf`와 같은 모양).
* `diary-edit`에 둘 다 없거나 읽을 수 없으면 오늘 새 일기입니다(`dateQuery` 계약 그대로). `id`가 있으면 `date`보다 앞섭니다.
* `diary-view`에 `id`가 없으면 "일기를 찾지 못했어요" 상태(지금의 404와 같은 안내)입니다.
* 저장하면 `diary-view?id=<저장된 id>`로 바꿔 갑니다(`replace`, 지금 흐름과 같음).

## 5. 초안 (결정 A68)

D47 ②(오프라인은 로컬 초안만)와 A48 규칙은 그대로이고, 초안의 단위만 날짜에서 일기 한 편으로 바뀝니다.

* 테이블 `DiaryDrafts`에 `diaryId` 열을 더하고 키를 (계정, 날짜, 일기 id)로 바꿉니다. 새 일기는 `diaryId = ''`입니다. 날짜마다 "아직 저장하지 않은 새 일기" 초안이 하나 있습니다. 그날 새 일기를 다시 열면 그 초안으로 이어 씁니다(`draft` 상태). 고치는 일기의 초안은 그 일기 id에 붙습니다.
* `DiaryDraftStore`의 읽기·쓰기·지우기는 대상 `DiaryDraftTarget`을 받습니다: `DiaryDraftTarget.newOn(CalendarDate)`·`DiaryDraftTarget.existing(Diary)`(날짜와 id).
* DB `schemaVersion` 1 → 2. migration은 v1 날짜 초안을 그날 새 일기 초안(`diaryId = ''`)으로 옮깁니다. 글을 버리지 않기 위해서입니다(v1에서 기존 일기를 고치던 초안이었어도 글은 남고, 사용자가 새 일기로 저장하거나 지울 수 있음).
* 새 일기 저장에 성공하면 새 일기 초안을 지웁니다. 고치기 저장에 성공하면 그 일기 초안을 지웁니다.

## 6. 입구와 일기 줄 (결정 A69)

그날 일기 목록 provider `diariesOnProvider(CalendarDate) → List<DiarySummary>`(autoDispose family, 자동 재시도 끔)가 `todayDiaryExistsProvider`·`diaryExistsOnProvider`를 대신합니다. 실패 규칙은 지금과 같습니다: 실패하면 빈 목록(0편)으로 그려 쓰기를 막지 않고, 예상하지 못한 오류만 `CrashSummary`로 남깁니다. 마지막 방어선은 저장 422입니다.

**쓰기 버튼 상태**(입구 세 곳 공통, 순수 함수 `diaryWriteEntryOf(int count) → DiaryWriteEntry { first, more, full }`)

| 그날 편수 | 상태 | today | day-sheet | diary-list 날짜 골라 쓰기 |
| --- | --- | --- | --- | --- |
| 0 | `first` | `todayGuideCta` | `daySheetDiaryWriteCta` | `diaryListPickDateConfirm({date})` |
| 1~9 | `more` | `todayGuideCtaWritten` | `daySheetDiaryWriteCtaWritten` | `diaryListPickDateConfirm({date})` |
| 10 이상 | `full` | `todayGuideCtaFull`, 누를 수 없음 | `daySheetDiaryWriteCtaFull`, 누를 수 없음 | `diaryListPickDateConfirmFull`, 누를 수 없음 |

* 계정 합치기로 10편을 넘은 날도 `full`입니다(D83 ④).
* `first`·`more`는 언제나 `diary-edit?date=<그날>`(새 일기)입니다. "그날 일기가 있으면 보기로" 분기(A51)는 없앱니다.
* 목록을 받는 동안: `today`는 그날 일기 목록을 받은 뒤 그립니다(받는 동안 오늘 카드 입구를 그리지 않고 화면 로딩 상태입니다. 목록을 받지 못하면 0편으로 그려 `first`가 됩니다). `day-sheet`는 입구 자리에 지금처럼 skeleton을 둡니다. 날짜 골라 쓰기는 `first`로 그립니다.
* 누를 수 없는 버튼: `MonthDatePicker.onConfirm`을 nullable로 바꿔 null이면 비활성(버튼 전체 `opacity 0.4`, 다른 비활성과 같음)입니다. `day-sheet`는 `PrimaryButton` `disabled`입니다. `today`의 `GuideQuestionCard`는 `GuideQuestionState.full`이 버튼을 막습니다(§13).
* 상한을 채운 날의 시험용 fake 시나리오 `diary-day-full`(오늘 일기 10편)을 둡니다.

**일기 줄**
모양은 §13(A72)이 대신합니다. 아래 불릿의 "지금 `diary-row`"는 §13의 줄·묶음 카드로 읽습니다.
* `today`: 가이드 질문 카드 아래에 오늘 쓴 일기의 `diary-row`를 작성 순으로 둡니다. 누르면 `diary-view?id=`. 0편이면 줄이 없습니다.
* `day-sheet`: 그날 일기가 있으면 머리 `daySheetDiaryOpen(count)`(동작 링크가 아님) 아래에 `diary-row`를 작성 순으로 두고, 그 아래 쓰기 버튼입니다. 미래 날은 일기 입구가 없습니다(D49, 그대로).
* `diary-list`·`tag-diary`: server 순서(날짜 내림차순, 같은 날 작성 순)대로 지금 `diary-row`를 이어 그립니다. 줄마다 날짜를 보이므로 같은 날 여러 편도 구분됩니다. 같은 날은 §13의 묶음 카드 하나로 그리고, 한 날짜가 두 쪽에 나뉘면 다음 쪽을 받을 때 같은 묶음 카드가 커집니다.
* `diary-row`의 배지·그날 성격은 지금처럼 달 길흉 캐시에서 읽습니다(A46).

## 7. 달력 도장 (결정 A70)

`datesIn`은 지금 한 쪽(100)만 받습니다. 하루 10편까지면 달력 격자(42일)에 420편까지 있을 수 있어 한 쪽으로 끝나지 않습니다. `nextCursor`가 없을 때까지 이어 받아 날짜 집합을 만듭니다(최대 다섯 쪽). 실패 규칙(빈 집합으로 그리기)은 그대로입니다.

## 8. 쓰기 화면 (`diary-edit`, 결정 A71)

* family 값은 `DiaryEditTarget`입니다: `DiaryEditTarget.newOn(CalendarDate)` 또는 `DiaryEditTarget.existing(String id)`.
* 열 때: 새 일기는 그날 새 일기 초안과 `getDaily(date).guide`(A47)를 읽습니다. 고치기는 `find(id)`와 그 일기 초안을 읽고, 질문은 `Diary.guideQuestion`입니다. 새 일기에서 질문을 받지 못하면 쓰기를 막지 않고, 연결 오류면 `offline`입니다. 고치는 일기(`diary-edit?id=`)를 받지 못하면 날짜를 몰라 초안으로 열 수 없으므로, 연결 오류면 오류 상태를 보이고 404면 "일기를 찾지 못했어요" 안내입니다.
* 저장: 새 일기는 `create`, 고치기는 `update`입니다. 새 일기의 `Idempotency-Key`(uuid v4)는 화면 상태 하나에 하나이고 실패 뒤 다시 저장하면 같은 키를 씁니다. 시간 초과 뒤 다시 눌러도 일기가 두 편 생기지 않게 하기 위해서입니다(일정 만들기와 같음).
* 저장 실패: 422 `diary.day_full`은 `errorDiaryDayFull` 문구로 알리고(`toast`, 지금 저장 실패 알림과 같은 자리), 초안을 남기고 화면에 머뭅니다. 그 밖은 지금과 같습니다.
* 저장·삭제 성공 뒤 다시 받기: 그날 `diariesOnProvider`, 그 달 `diaryDatesProvider`, 일기 목록 쪽(A45), 고친 일기의 `diaryProvider(id)`.
* `diary-view`의 지우기는 `delete(id)` 뒤 같은 다시 받기를 합니다(A50 그대로).

## 9. 오류와 경계

* `diary-view?id=`의 일기가 다른 기기에서 지워졌으면 404 → "일기를 찾지 못했어요"(지금과 같음).
* 고치던 일기가 저장 때 404면 지금과 같은 "이미 없음" 처리이고 초안은 남깁니다.
* 미래 날짜 새 일기(`?date=`가 오늘 뒤)는 입구가 없지만 경로로 들어오면 저장이 422 `diary.future_date`이고 지금 문구로 알립니다.
* `diary-edit?id=`와 초안: 초안이 저장된 본문보다 앞섭니다(A48 그대로).

## 10. 결정 (app `docs/decisions.md`에 기록)

* **A67** 일기 화면 경로는 id 기반입니다: `diary-view?id=`, `diary-edit?id=`(고치기)·`?date=`(그날 새 일기). A51의 "일기가 있으면 보기" 분기를 대신합니다.
* **A68** 일기 초안은 (계정, 날짜, 일기 id) 단위이고 새 일기는 날짜마다 하나(`diaryId = ''`)입니다. v1 날짜 초안은 새 일기 초안으로 옮깁니다. A48을 갱신합니다.
* **A69** 쓰는 입구는 그날 일기 목록(`listDiaries` 같은 날짜 범위)의 편수로 `first`·`more`·`full`을 정합니다. 받지 못하면 0편으로 그리고 저장 422가 막습니다. `today`·`day-sheet`는 그날 일기 줄을 작성 순으로 둡니다. 목록 모양은 #410 전까지 지금 `diary-row`입니다.
* **A70** 달력 도장은 `nextCursor`를 끝까지 따라 받습니다. A33의 "한 쪽으로 끝남"을 대신합니다.
* **A71** 새 일기 저장은 화면 상태마다 `Idempotency-Key` 하나이고, `diary.day_full`은 초안을 남기고 오류 문구로 알립니다.
* **A72** 일기 줄 모양은 design 컴포넌트 2.8.0(V42·V43)을 따릅니다. 목록·태그 모아보기는 같은 날을 `diary-row` `day` 묶음 카드 하나로, 오늘·그날 시트는 `entries`(시각 + 한 줄 미리보기)로 그립니다. A69의 "#410 전까지 지금 `diary-row`"를 대신합니다(§13).

## 11. 테스트

* 저장소: operation·인자·실패 분류, `diariesOn`의 같은 날짜 범위, `datesIn`의 cursor 이어 받기(두 쪽 이상).
* fake server: id 발급, 같은 날 작성 순, 10편째 뒤 `createDiary` 422 `diary.day_full`, 같은 `Idempotency-Key` 재전송은 같은 일기, 지운 일기 404.
* 초안: 대상별 읽기·쓰기·지우기, v1 → v2 migration(날짜 초안이 새 일기 초안으로).
* `diaryWriteEntryOf`: 0·1·9·10·11편.
* 쓰기 상태: 새 일기 저장 → 초안 지움·같은 키 재시도, 고치기 저장, 422 `diary.day_full` → 초안 남음·오류.
* 화면·흐름: today(쓴 일기 줄 → `diary-view`, 10편이면 버튼 막힘), day-sheet(머리 편수·줄·버튼 세 상태), diary-list 날짜 골라 쓰기(언제나 새 일기, 10편이면 막힘), 같은 날 두 번째 일기 쓰기 → 저장 → 보기. 기존 일기 흐름·screenshot 테스트 갱신.
* contract: problem code 대조, ARB 검사, IA 커버리지.

## 12. 알릴 것

* #418: `errorDiaryDateTaken`을 더 쓰지 않음(writing이 지움).
* #424: 되살리기 UI가 없어(A50) 되살리기 422는 app에 해당 없음.
* #408: 목록의 날짜 묶음 모양은 design #410 답으로 맞춘다는 것.
* PR 본문: `Closes #412`, `Closes #437`, `Closes #424`, `Closes #408`.

## 13. design 2.8.0 맞추기 (결정 A72)

구현 중 main에 컴포넌트 명세 2.8.0·토큰 1.2.0(design #410 답, PR #458)과 IA `day-sheet`의 `depth-link` 제거(PR #460)가 들어왔습니다. 이 브랜치에서 main을 병합하고 맞춥니다(#408의 "모양은 #410 답을 따름"). 기준은 design spec `docs/identity/design/specs/2026-10-22-diary-row-multi-design.md`와 명세 `components/diary.json`(`diary-row`)·`today.json`(`guide-question-card`)·`input.json`(`date-picker`)·`sentence.json`(`depth-link`)·`calendar.md`, 토큰 `color.timeline.entry`입니다. 값은 명세에서 그대로 옮기고 이 절에는 app이 정하는 것만 적습니다.

**생성물:** `gen_ia`·`gen_tokens`·`gen-l10n` 재생성. 토큰 `color.timeline.entry`가 생깁니다.

**`diary-row` 컴포넌트**(`lib/design/components/diary/diary_row.dart`)
* 줄 하나 `DiaryEntryLine`(명세 `entry`): 시각·한 줄 미리보기·꺾쇠, 누르면 그 일기. 시각은 `createdAt`을 기기 시간대로 바꿔 `DateFormat.jm(locale)`로 만듭니다. `locale`은 `Localizations.localeOf(context).toLanguageTag()`입니다. 미리보기는 화면도 스크린리더도 본문의 첫 비지 않은 줄입니다(앞의 빈 줄은 건너뜀). 본문이 비면 한 줄 높이를 지키고 스크린리더는 시각만 읽습니다.
* 점선은 줄과 줄 사이에만, 줄 전체 너비로 그립니다(`CustomPainter`, 대시 4·간격 3, 1px).
* `day` 묶음 카드: 그날 일기가 한 편이면 지금 `DiaryRow` 그대로, 두 편 이상이면 같은 카드에 배지 → entry 줄들 → 태그 칩. 카드는 버튼이 아니고 `Semantics` 그룹("날짜 요일, 배지")입니다. 흐름 줄은 카드 높이만큼 이어집니다.
* `entries`: entry 줄만. 화면별 바탕(`today` 카드, `day-sheet` 없음)과 `day-sheet` 머리는 명세 `entries.parts.container.byScreen`·`head` 값입니다. 받는 동안은 줄 두 개 높이 skeleton.

**목록 묶음**(`diary-list`·`tag-diary`): 받은 쪽들을 이어 붙인 순서에서 날짜가 같은 이웃 요약을 한 묶음으로 만듭니다. 한 날짜가 두 쪽에 나뉘면 다음 쪽을 받은 뒤 같은 묶음 카드가 커집니다(줄이 따로 생기지 않음). 순서는 server 순서 그대로이고, 다시 정렬하지 않습니다. 묶음 함수는 순수 함수로 두고 단위 테스트합니다.

**화면**
* `today`: 가이드 질문 카드 아래 `entries`(오늘 카드 바탕), 0편이면 그리지 않습니다.
* `day-sheet`: 머리(`daySheetDiaryOpen(count)`, 명세 `head` 글자 스타일, 링크 아님) → `entries`(바탕 없음) → 쓰기 버튼. 0편이면 버튼만.
* 오늘·그날 시트의 줄에는 태그 칩이 없으므로 §6의 "표시용 태그 칩" 처리(`tagLinked: false`)는 entries에서 사라집니다. 목록의 묶음 카드 태그 칩은 지금처럼 `tag-diary`로 갑니다.

**`guide-question-card` `full`:** `GuideQuestionState.full`을 더합니다. `after` 모양(질문 흐림, 도장 유지)에 조용한 버튼 `disabled`(글자 `disabled.fg`, 명세 값). 눌러도 아무 일 없고 햅틱도 없습니다. `after`에서 `full`이 되는 순간에는 "더 쓸 수 없음"(명세 a11y `stateAnnounced`)을 기존 `todayGuideCtaFull`로 한 번 낭독하고(`before`에서 곧바로 `full`이면 `todayGuideWritten`에 이어 읽음), `full`로 다시 그릴 때와 처음부터 `full`일 때는 낭독하지 않습니다(새 ARB 키 없음, 도장 애니메이션은 `before`→쓴 모양에서만). §6의 "`onAction` null이면 비활성(opacity 0.4)"는 이 상태로 바뀝니다.

**`date-picker` `calendar`:** 상한을 채운 날도 고를 수 있고, 아래 버튼만 `disabled` + `diaryListPickDateConfirmFull`입니다(§6 표와 같음, 확인만).

**`depth-link` `navigate`:** `daySheetSlot` 인자나 분기가 남아 있으면 지웁니다.

**contract·테스트:** `component_contract_test`에 `diary-row` 변형 `day`·`entries`와 `entry` 값(시각 글자, 미리보기 1줄·간격, 꺾쇠, 높이, 점선), `guide-question-card` `full`, 토큰 `color.timeline.entry`를 대조합니다. golden: `diary-row` 한 편·묶음·entries(오늘 바탕·시트)·빈 본문, `guide-question-card` `full`(라이트·다크, 글자 크기 단계는 기존 golden 관례). widgetbook use case. screenshot 재생성.

