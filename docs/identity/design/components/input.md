# input: 입력 (`input.json`)

* 근거: [V2 spec](../specs/2026-10-11-components-design.md) §6.3, [구현 대응 spec](../specs/2026-10-15-spec-followups-design.md) §2.4·§2.5·§2.8·§2.9, 결정 V13·V14·V31
* 시안: `design-v2-birth-date`(휠 + 윤달), `design-v2-birth-time`(휠 + 모름), `design-v2-select`(스밈 이동 15%), `design-v2-focus`(포커스 테두리), `design-v2-rest`(달력 날짜 고르기)

## input-step

* 쓰는 화면: onboard-call, onboard-birth, onboard-time, onboard-gender, birthplace, notify-ask
* 위에서부터: 진행 막대(온보딩만, 3px) → 질문(`type.title`) → 머리말(`preface`, 있을 때만) → 입력 → 도움말(`type.caption.lg`) → 오류 줄 → 아래 고정 주 버튼(키보드 위에 붙음).
* 오류 줄(`out-of-range` 등)은 빨간색 없이 `mark.caution` + 본문색입니다. 오류가 있으면 아래 버튼은 disabled.
* 고르면 바로 다음으로 넘어가는 단계(지금은 `birthplace`의 도시 결과 줄)에는 아래 버튼을 두지 않습니다(`bottomAction.omitWhen`). 비활성 버튼이 늘 떠 있으면 "무언가 더 해야 한다"로 읽히기 때문입니다.
* 머리말(`preface`): 질문과 입력 사이 안내입니다(지금은 `birthplace`의 한국 표준 소개 `birthplace.standard.note` + `depth-link` `navigate`). 글자는 도움말과 같은 스타일이고, 위(질문 아래)·아래(입력 위) 모두 `space.24`입니다.

## text-field

* 쓰는 화면: onboard-call, event-edit
* `bg.sheet`, 1px `line`, `radius.md`, 높이 52px, 글자 17px(ui 글꼴 400).
* 포커스는 `focus.ring`(1px `line` → 2px `action.primary`). 바탕은 바뀌지 않습니다. 다크 모드에서도 같은 규칙입니다.
* Material 힌트: `InputDecoration`의 `filled: true`, `fillColor: bg.sheet`, `OutlineInputBorder` 두 벌(평소·포커스).
* **여러 줄(`multiline`, #218):** event-edit 메모(2000자)처럼 줄바꿈이 필요한 칸입니다. 최소 높이 52를 지키며 글이 길어지면 6줄까지 늘고, 그 뒤로는 칸 안에서 스크롤합니다. 첫 줄은 한 줄 칸의 글자와 같은 자리이고, 지우기 아이콘은 첫 줄 높이에 둡니다. 키보드는 여러 줄 입력, 키보드 동작은 줄바꿈(완료가 아님)입니다. 바탕·테두리·포커스·글자 수·지우기 규칙은 한 줄 칸과 같습니다.

## date-picker

* 쓰는 화면: onboard-birth(`birth`), event-edit(`solar`), diary-list(`calendar`)
* `birth`: 년·월·일 휠 + 위에 양력·음력 segmented. 휠 선택 띠는 `status.bg`.
  * 음력이고 그해에 윤달이 있을 때만 월 휠에서 해당 달 바로 다음에 "윤N월"이 끼어듭니다.
  * 음력이면 아래에 양력 확인 줄이 `appear.seep`으로 나타납니다.
  * **윤달 대체(결정 V31):** 위 두 줄이 목표 모양입니다. 휠이어야 없는 윤달을 고를 수 없고, 확인 줄이 있어야 음력 입력이 맞는지 확인할 수 있습니다. 다만 음력→양력·윤달 조회(server #141)가 계약에 없으면 월 휠에 윤달을 끼우지 않고, 음력일 때 휠 아래에 `check-row` `inline` "윤달" 하나를 둡니다(`leapMonthFallback`). 확인 줄은 그리지 않고 그 자리도 비워 두지 않습니다. 없는 윤달을 고르면 저장할 때 server 오류로 input-step 오류 줄에 보입니다. 조회가 계약에 들어오면 목표 모양으로 바꿉니다.
  * 지원 범위(1900-01-31~2099-12-31) 밖은 input-step 오류 줄.
* `solar`(#218): 일정 날짜는 양력뿐이라 `birth`에서 양력·음력 segmented와 윤달·양력 확인 줄을 뺀 모양입니다. 휠·선택 띠·지원 범위는 `birth`와 같습니다.
* `calendar`: 시트 안 달력. calendar-month와 같은 표시(일기 쓴 날 옅은 도장, 오늘 윤곽, 선택 굵은 숫자 + 밑줄)이고 길흉 칸 채우기만 뺍니다. 미래 날짜는 흐리게 막습니다. 아래 버튼 글자에 고른 날짜가 들어갑니다(문구는 writing).
* 휠 눈금이 넘어갈 때마다 햅틱 selection.

## time-picker

* 쓰는 화면: onboard-time(`birth`), notify-ask·event-edit·settings(`notify`)
* `birth`: 오전·오후·시·분 휠 + "모름" 체크. 모름을 켜면 휠이 흐려지고(투명도 0.35, 흐림 1.5px) 안내가 `appear.seep`으로 나옵니다.
  * 출생 기록의 벽시계 시각을 그대로 받습니다.
  * 시진 확인 줄(슬롯 `onboard-time.hour.confirm`)은 **기기 지역이 한국일 때만** 보입니다. 이 단계에서는 출생지를 아직 받지 않으므로 엔진이 대표 경도·`Asia/Seoul`로 계산한 시진과 그 벽시계 범위를 씁니다(D58). 휠이 멈추면 새 값이 `appear.seep`.
  * 한국 밖(`outsideKorea`)이거나 모름을 켜면 확인 줄을 그리지 않습니다.
* `notify`: 모름이 없고 분은 5분 단위.

## segmented

* 쓰는 화면: onboard-gender, event-edit, saju-chart(원국·오행 / 만세력·대운), share-preview(공유 비율)
* `bg.sheet` + 1px `line` 알약 트랙, 선택 표시는 `action.primary` 알약 + 흰 글자.
* 선택이 바뀌면 `select.seep-slide`: 새 표시가 이전 자리 쪽에서 거리의 15%만 미끄러지며 선명해지고, 이전 표시는 제자리에서 번지며 사라집니다. 햅틱 selection.
* 항목 2~4개, 같은 너비, 글자 한 줄.
* `none`: 아직 아무것도 고르지 않은 상태(성별 고르기 전)입니다. 표시 막대가 없고 글자는 모두 `text.secondary`입니다. 처음 고를 때 표시 막대는 미끄러지지 않고 그 자리에 스며 나타납니다(`appear.seep`). 이 상태에서 input-step 아래 버튼은 disabled.
* 구현 힌트(Flutter): 그룹은 `radioGroup`, 항목은 `checked` + `inMutuallyExclusiveGroup` 의미 표시입니다.

## city-search

* 쓰는 화면: birthplace
* 검색칸(text-field + 돋보기) + 결과 묶음 카드(settings-row와 같은 모양: 도시 `type.body.ui` + 나라·지역 `type.caption.md`). 입력과 일치하는 부분은 600.
* 불러오는 중 skeleton 줄 3개, 결과 없음 empty-state.
* **고른 뒤 저장 중(`saving`, 결정 V34):** 아래 버튼이 없는 단계라 처리 중 표시를 고른 줄이 맡습니다. 고른 줄 오른쪽 끝에 점 숨쉬기(`loading.breathe`, `text.secondary`)가 나타나고, 다른 줄은 누를 수 없습니다. 스크린리더는 "처리 중"을 알립니다(`primary-button` `loading`과 같은 문구). 저장이 실패하면 input-step 오류 줄로 돌아갑니다.
* `region`은 "행정 구역, 나라" 이름입니다. 둘은 언어별 구분자로 잇습니다(`region.join`: ko·en `, `, ja `、`). 나라 코드(`KR`)를 그대로 보이지 않습니다. 지역 이름이 없으면 `region` 줄을 그리지 않고, 결과 줄 최소 높이 56px는 그대로입니다.
* 구현 힌트(Flutter): `combobox` 역할은 적용하지 않습니다(flutter#159741). 결과 수 알림은 그대로 둡니다.

## check-row

* 쓰는 화면: consent
* 변형 `card`(동의 항목: 줄마다 떨어진 카드) / `inline`(시간 '모름'처럼 다른 입력 아래 붙는 체크 하나, 바탕·보기 링크 없음).
* `card`는 줄마다 떨어진 카드(`bg.sheet`, `radius.md`). 24px 체크 상자(`radius.sm`): 켜면 `action.primary`로 채워지고 흰 체크가 그어집니다(200ms). 오른쪽 "보기" 링크는 따로 초점을 받고, 눌러도 체크는 바뀌지 않습니다.

## account-choice

* 쓰는 화면: account-merge
* 합칠 두 계정 가운데 남길 쪽을 고르는 카드 두 장입니다(D82 ⑥, 결정 V40). 카드 사이 `space.12`, 카드는 `bg.sheet`·`radius.md`·안쪽 `space.16`·줄 사이 `space.8`입니다.
* 카드 안 줄(위에서 아래): ① 호칭(`type.subtitle`) + 현재 로그인한 계정이면 알약 "현재 계정"(`ui.account-merge.choice` `accountChoiceCurrent`, `type.caption.sm`, `line` 테두리, `radius.full`) ② 사주 요약 한 줄(`ui.account-merge.saju`: 생년월일·달력 종류·출생 시각, 모르면 "시간 모름", 사주가 없으면 "사주 정보 없음") ③ 일기 수(`accountChoiceDiaryCount`)와 연결된 수단 이름(`loginProvider*`를 구분자로 이음). 이 줄이 넘치면 말줄임 없이 다음 줄로 감습니다. 합칠 계정을 판단하는 데 필요한 수단 이름을 가리지 않기 위해서입니다.
* 연결된 수단은 로고 없이 이름 글자로 보입니다. Google 가이드가 "G"만 단독으로 쓰는 것을 막고, 스크린리더도 이름을 그대로 읽습니다.
* 고름 표시는 카드 오른쪽 위 22px 알약 동그라미입니다(V26). `selected`는 카드 테두리 `action.primary` 2px + 동그라미 안 점 12px, 바뀔 때 이동 없이 스밉니다(처음 고를 때 `appear.seep`). 햅틱 selection.
* **처음부터 어느 쪽도 골라 두지 않습니다**(`none`). 되돌릴 수 없는 합치기라 남길 계정은 사용자가 직접 고르고, 그 전에는 합치기 버튼이 `disabled`입니다.
* `disabled`: 합치는 중(최종 확인 뒤 합치기 버튼 `loading`)에는 고름을 잠가 카드를 누를 수 없습니다. 모양은 그대로이고 실패하면 풀립니다. 화면에 보인 고름과 실제로 남는 계정이 어긋나지 않게 합니다.
* `loading`(IA `account-merge:loading`): 카드 두 장 크기의 빈 카드가 `loading.breathe`로 숨쉽니다. `skeleton` 컴포넌트를 따로 쓰지 않습니다.
* 스크린리더: 묶음은 radio-group(이름 `account-merge.choice.label`), 카드는 radio이고 카드 안 글자를 위에서 아래 순서로 읽습니다. 터치 영역은 카드 전체입니다.

### account-merge 화면 배치

app-bar 아래로 차례대로 놓습니다(결정 V40).

1. `account-merge.title.head`(`type.title`, 위 `space.12`, 아래 `space.8`)
2. `account-merge.title.body`(`type.body.ui`, `text.secondary`, 아래 `space.24`)
3. `account-merge.choice.label`(`type.caption.md`, `text.secondary`, 아래 `space.8`)
4. `account-choice` 카드 두 장
5. `account-merge.overlap.notice`: 같은 날 일기가 겹칠 때만. 위 `space.16`, 앞 아이콘 `check-circle`(Light 16, `text.secondary`) + `type.caption.lg` `text.secondary`, 사이 `space.8`. `mark.caution`을 쓰지 않고 바탕 상자도 두지 않습니다. 같은 날 일기도 지우지 않고 모두 옮긴다는 안심 안내이기 때문입니다(D83 ④).
6. 화면 아래(내용이 짧으면 바닥에 붙음): `primary-button` `filled` `account-merge.cta.merge`(고르기 전 `disabled`) → `primary-button` `quiet` `account-merge.cta.cancel`, 사이 `space.4`

* 합치기 버튼을 누르면 `dialog` `destructive`(`account-merge.merge.confirm`)가 열립니다. **강조는 이 확인 창 한 곳입니다.** 화면의 합치기 버튼은 평소 무게(`filled`)로 둡니다.
* 확정 뒤 확인 창이 닫히고 합치기 버튼이 `loading`, `account-choice`는 `disabled`(고름 잠금)입니다. 끝나면 `login-methods`로 돌아갑니다.
* 실패(`account-merge:error`)는 `ui.account-merge.error`를 `dialog` `notice`로 보입니다. 고른 계정은 그대로 두어 버튼을 다시 누르면 됩니다. 화면 전체를 오류로 바꾸지 않습니다(IA `account-merge` 컴포넌트에 `error-state`가 없음).
