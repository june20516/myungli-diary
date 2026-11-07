# DS1 2단계: 확정 화면 대조와 등록 (#801, D105, D107, D108)

* 날짜: 2026-11-05, design 세션
* 입력: #801 지휘 코멘트(시안 B, A, F, D, C, E, G 확정, 고유 요소 등록, 2단계 당부), origin 이미지 비공개 기록 `review/shots/2026-11-05/ia-final/`(2판, 내용을 옮기지 않음), IA v5(PR #812, `docs/ia/screens.json` version 5), drift #815, 1단계 spec [`2026-11-05-ds1-rules-design.md`](2026-11-05-ds1-rules-design.md)
* 질문 답: 질문 비교 시안 `design-ds1-questions`(1판, 2판), 아래 §2
* 결과(예정): 토큰 1.4.0, 컴포넌트 계약 5.0.0(요소 `section.header`, `explain.sheet`를 컴포넌트로 옮겨 지움), 결정 V69~
* 범위: 구성은 origin과 IA v5를 따르고, 세부 모양은 1단계 규칙과 이 spec이 최종입니다. IA를 바꿀 이유는 #801 코멘트로만 알립니다.

## 1. IA v5 대조 (관문 2)

IA v5는 새 컴포넌트 15개와 새 화면 둘(`tag-sheet`, `color-rule-sheet`)을 더했고, `day-character`를 today, day-sheet, diary-view에서 뺐습니다. plan 초안에서 요소로 두려던 것은 IA id를 받은 대로 컴포넌트로 둡니다.

| IA v5 컴포넌트 | 명세 파일 | 쓰는 화면 | 출처 결정 |
| --- | --- | --- | --- |
| `section-header` | frame | today, day-sheet, my-saju, saju-chart | Q1 ③, 1단계 V59 |
| `hanja-tag` | sentence | today, explain-sheet, tag-sheet, evidence-sheet, day-sheet, color-rule-sheet, diary-list, diary-view, my-saju, saju-chart | D108 ②, Q4, Q4-2 |
| `explain-sheet` | frame | today, saju-chart | 1단계 V62 |
| `date-header` | today | today, day-sheet | A, D |
| `tag-sentence-list` | today | tag-sheet | A |
| `fortune-verdict` | calendar | day-sheet | D |
| `score-row` | calendar | day-sheet, color-rule-sheet | D |
| `score-scale` | 쓰지 않음(IA 제거 요청) | color-rule-sheet | D, 관문 답 2026-11-07 Q4 |
| `date-block` | diary | diary-edit | C |
| `diary-summary` | diary | my-saju | B |
| `luck-pillar` | saju | my-saju, saju-chart | B, E |
| `birth-info-row` | saju | saju-chart | E |
| `band-table` | saju | saju-chart | E |
| `stage-strip` | saju | explain-sheet, saju-chart | E |
| `scroll-hint` | frame | saju-chart | E |

* 요소로 남는 것: `button.pair`, `list.divider`, `hanja-tag`가 쓰는 천간 오행 색 칩(요소 `stem.chip`, `band-table` 지장간 칸. 2026-11-07 정정: 원국 칸과 대운 칸은 `ohaeng.cell` 자체라 쓰지 않음, V89), 띠 머리줄(`band-table` 부품 `bandHeader`).
* 요소 `section.header`와 `explain.sheet`는 같은 이름의 컴포넌트로 옮기고 지웁니다(주 버전). 1단계 테스트는 새 위치를 봅니다.
* IA에 남은 `day-character`는 공유 이미지(`share-image`) 등 남은 자리만 쓰고, 날의 성격 표시는 `hanja-tag`로 갑니다.
* **IA에 알릴 것:** 없음(대조에서 어긋남이 나오면 #801 코멘트).

## 2. 질문 답과 규칙

| # | 답 | 규칙 |
| --- | --- | --- |
| Q1 | ③ | `section-header` 제목은 어디서나 `type.label.lg` 600 본문색. 선택 설명 줄 `type.caption.md` `text.secondary`(제목 아래 `space.2`). 오른쪽 자리 `trailing`은 꺾쇠 링크(화면 이동)와 아이콘 동작(좋아요, +) 둘만. 시작선은 카드 바깥 가장자리(화면 좌우 `space.20`, 시트 안은 `space.24`). 제목과 내용 사이 `space.12`, 섹션 사이 `space.32` |
| Q2 | ② | 달력 범례 끝 입구는 용어 칩 모양(`term-token` 칩과 같은 바탕과 글자색), 누르면 `color-rule-sheet`. ⓘ 없음. 문구는 "색" 대신 그날의 길흉을 가리키는 말(writing, 가안 "길흉은 어떻게 정해지나요") |
| Q3 | ③ | **잠긴 것을 여는 입구는 모든 곳에서 자물쇠(`lock-simple` Regular, 옆 글자 단계) + "열기".** 꺾쇠를 쓰지 않음. `sentence-block` `locked`의 열기, 원국 개인 해석, 근거 시트 잠금 안내가 같음 |
| Q4 | ③ + ① | `hanja-tag` 톤: 날의 성격(貴 用 忌 平)은 길흉 톤(V8 배지 매핑). 그 밖의 사주 용어(십성 묶음, 합충형, 신살)는 기본 초록(`term`). 길흉 톤(좋음 coral, 나쁨 neutral)은 `fortune-verdict`와 `color-rule-sheet`의 `score-row` 안에서만(더함과 뺌을 보이는 자리) |
| Q4-2 | ① | 날의 성격 강조 변형 `emphasis`는 데이터로: 용신의 날만 진한 채움(`badge.good`), 귀인의 날 옅은 coral, 기신의 날 옅은 회색, 평범한 날 테두리(V8, D20 그대로). 쓰는 자리: 그날 시트 머리와 오늘 총운 결정 태그 |
| Q5 | ① | `lucky-card` 칩은 `bg.sheet` 바탕 + 1px `color.line` 테두리. 연 칩은 테두리가 1.5px `action.primary`로 바뀜. 오늘 카드, 나 탭 카드, 공유 이미지(그라데이션 위), 다크 모드에서 테두리로 구분됨 |
| Q6 | ② | 달력 오늘은 낙관 도장 윤곽 26px 그대로(V19) |
| Q7 | ② | 일기 목록 줄은 V42 그대로. 태그만 `hanja-tag`(초록). **관문 답(사용자 결정 2026-11-06):** 카드 맨 위에 날의 성격 `hanja-tag`(길흉 톤, `DiarySummary.dayKind` D96, 없으면 숨김, 있을 때만 아래 `space.8`), 맨 아래에 그날의 대표 태그(`default` 초록, 엔진이 일진으로 정함 D108 ①). tag-diary 안 줄은 대표 태그만 숨기고 날의 성격은 보임 |
| Q8 | V68 유지 | 일기 쓰기도 키보드 내리기 버튼. 키보드 높이(OS 자동완성과 추천 줄 포함, 플랫폼 키보드 inset) 위로 `space.12`. 붙여넣기 막대와 겹치는지는 QA에서 확인 |
| 刑 | 사용자 결정 2026-11-07 | D108 ② 한자 목록 누락 보완: 刑(형)을 `hanja-tag` 글자 목록(relation)에 더해 17자. 사주 용어라 기본 `term` 초록, 길흉 톤은 `fortune-verdict`, `score-row` 안 규칙 그대로. 자리값 표시 없음 |

**1단계 버그(이번에 고침):** 확인 창 취소 버튼 바탕 `chip.bg`는 반투명 흰색(라이트 70%)이라 흰 확인 창(`bg.sheet`) 위에서 보이지 않습니다(V65). 새 역할 색 `color.fill.soft`(라이트 neutral-100, 다크 대응 값)로 바꾸고, 명세 전체에서 `bg.sheet` 위에 `chip.bg`를 놓는 곳이 없도록 검사합니다.

## 3. 토큰 1.4.0 (추가만)

| 토큰 | 규칙 |
| --- | --- |
| `color.calendar.level.great` | 아주 잘 풀리는 날. hue 30(coral). 라이트는 `good`과 함께 맑게(회색 섞임 없음, 흰색만 섞은 coral)이고 `good`보다 진하게(명도 낮고 채도 높음). 다크는 `good`과 명도 차 0.005 이하에 채도가 더 높음. **사용자 결정 2026-11-07(관문 Q1 ⑤):** 잘 풀리는 날이 탁해 보이면 부정적으로 읽혀 라이트 #ffd2ca, #ffe4df, #d4d4d3 |
| `color.calendar.level.good` | 잘 풀리는 날. 기존 `color.calendar.good.bg`(coral-100)는 그대로 두고 새 이름이 새 값 |
| `color.calendar.level.caution` | 조심할 날. 회색(채도 0.003 이하), 명도를 낮춰 `good`과 구분 |
| `color.fill.soft` | 흰 표면 위 옅은 채움(확인 창 취소 등). 라이트 neutral-100, 다크는 `bg.sheet` 위에서 같은 구분 |

* 구분 검사: 라이트, 다크 각각 이웃 쌍(great-good, good-무난(바탕 `bg.base`), good-caution, caution-무난)의 OKLab 거리 0.03 이상. 네 바탕 위 날짜 숫자 대비 4.5:1 이상(V3).
* 기존 `color.calendar.good.bg`, `color.calendar.caution.bg`는 값 그대로 두고, `day-cell`은 새 이름을 가리킵니다.

## 4. 컴포넌트별 정할 것 (task가 테스트로 고정)

* `date-header`: 날짜와 요일(`type.subtitle`), 그 아래 `space.2` 음력과 일진 줄(`type.caption.lg` `text.secondary`). 그날 시트는 일진 없이. 음력이 계약에 없으면 그 줄을 빼지 않고 일진만(server #806 전).
* `hanja-tag`: 높이 30, 왼쪽 안쪽 4, 오른쪽 `space.12`, 한자 원 22(`bg.sheet` 바탕, 한자 `font.family.hanja` 12 700), 원과 이름 사이 `space.4`, 이름 `type.label.md`. 변형 `default`, `emphasis`(Q4-2), `selected`(둘레 1.5px `action.primary`). 누르면 `explain-sheet`나 `tag-sheet`(IA 출구). 스크린리더 이름은 이름 글자(한자는 읽지 않음). **사용자 결정 2026-11-06:** 누르면 어디서나 시트이고 화면 이동 예외가 없음(일기 줄, 일기 보기 태그 칩, 나 탭 회고 포함, V73). 대표 태그의 뜻 시트에만 본문 아래 꺾쇠 링크 `diaryLink`("<태그>이 붙은 내 일기 보기", 편수 없음, → `tag-diary` `page.push`), 날의 성격 시트는 뜻만.
* `explain-sheet`: 요소 `explain.sheet` 값을 그대로 옮김(내용 높이 half, 제목 `type.subtitle`, 본문 `sentence-block` `body`, 배치 안에 끼우지 않음). 12운성은 본문 아래 `stage-strip`.
* `tag-sentence-list`: 머리 `type.label.md` `text.secondary`, 줄마다 왼쪽 이름 칸(보조 문장, 오늘의 질문) 52 + 문장, 줄 사이 `list.divider`. 없으면 안내 한 줄(writing 슬롯). 아래 출구는 꺾쇠 링크(`tag-diary`, "<태그>이 붙은 내 일기 보기", 조사는 writing `josa`). 편수를 보이지 않고 늘 보임, 일기가 없으면 tag-diary 빈 상태(사용자 결정 2026-11-06, "편수는 매력 없는 정보에 기술 부담만").
* `fortune-verdict`: 위치 막대(트랙 높이 4, 왼쪽 조심할 날 `level.caution`에서 오른쪽 잘 풀리는 날 `level.great`로 그라데이션 새 역할, 위치 표시 원 18 흰 바탕 + 2px `action.primary`), 아래 세 이름(조심할 날, 무난한 날, 잘 풀리는 날), 그 아래 `score-row` 줄들(`list.divider`). 카드 `bg.base` 바탕(시트 안). 동작 줄이기에서 위치 표시는 움직이지 않음.
* `score-row`: `hanja-tag`(길흉 톤 허용) + 뜻(`type.caption.lg`, 두 줄까지) + 점(지름 8, 사이 3, 더함은 `badge.good.bg`, 뺌은 `text.secondary`) 앞에 + 또는 −. 점 개수는 점수 절댓값(최대 3, 그 이상은 3과 +). 스크린리더 "이름, 뜻, 더함 둘".
* `score-scale`: **쓰지 않음(관문 답 2026-11-07 Q4).** 같은 척도를 그날 시트 막대와 색 규칙 시트 네 칸으로 두 번 그리지 않고, 색 규칙 시트는 설명 문장과 점수표만 둡니다. 명세를 쓰지 않고 IA에 제거를 요청합니다(`tools/components.py` `IA_REMOVAL_REQUESTED`). 색 규칙 시트 내용 높이는 59.6%(511 / 858)라 IA대로 half.
* **묶음 D 관문 답(사용자 결정 2026-11-07):** 달력 칸 색은 위 §3(라이트 맑은 coral), 범례는 견본 셋(무난한 날 없음), `fortune-verdict` 막대 이름은 셋, 그날 시트 일기 섹션 제목은 쓴 일기가 없어도 보임, 刑(형)은 한자 목록에 더함(§2 刑).
* `date-block`: 일 숫자 44 700, 옆 `space.12`에 월과 요일(`type.label.lg`), 그 아래 일진(`type.caption.md`).
* `diary-summary`: 큰 편수(28 700) + 단위 글자, "어떤 날에 썼나" 막대(날의 성격 넷, 막대 높이 8 `radius.full`, 색은 날의 성격 톤, 오른쪽 수), "자주 붙은 태그"(`hanja-tag` + 수, 최대 3). 태그를 누르면 뜻 시트이고, 시트 아래 꺾쇠 링크로 그 태그의 일기 모아보기(`tag-diary`). 사용자 결정 2026-11-06(처음 tag-diary 직행에서 같은 날 뜻 시트 경유로 바뀜). 기록이 적을 때(5편 미만) 안내 한 줄과 막대 숨김.
* `luck-pillar`: 천간, 지지 칸(`ohaeng.cell` 작은 크기 40), 위 나이 또는 연도, 십성 칩(`term-token` `label`). 사주 표 대운, 세운 줄에서 지금 대운, 올해 세운 칸은 `status.bg` 바탕 + 아래 "지금", "올해" 꼬리표(여러 칸 중 지금을 가림). 나 탭은 세로 두 줄(대운, 세운) 요약 모양 변형 `compact`이고, 두 줄이 모두 지금이라 강조 바탕이 없음(origin, 사용자 확인 2026-11-06). 사주 표 줄의 꼬리표는 강조 바탕 밖 아래(2026-11-07, 관문 질문 Q1 권장, V90).
* `birth-info-row`: 칸 셋(2026-11-07 정정, origin과 IA 역할 문장, V88)(달력 종류 꼬리표 + 날짜, 시진 `hanja-tag` + 시간, 성별 알약), 칸 사이 세로 구분선(1px 높이 16 `color.line`, 좌우 `space.12`), 쉼표 없음. 넘치면 칸 단위로 다음 줄. 시간 모름이면 시진 칸에 "시간 모름" 알약.
* `band-table`: 열 머리(시주, 일주(나), 월주, 연주), 열 구분선이 모든 띠를 관통(0.5px `color.line`), 일주 열 `status.bg` 옅은 바탕, 띠 머리줄(`bandHeader`: 네 열에 걸친 가운데 줄, 흰 바탕 + 위아래 0.5px 선 + 가운데 용어 칩). 띠: 지장간(`stem.chip` + 십성), 12운성(`term-token`), 신살(`term-token`, 없는 칸은 비움 표시 "-" 글자 대신 짧은 가로선 12×1 `text.secondary`).
* `stage-strip`: 12칸 막대(칸 높이 6, 사이 2, 내 자리 칸은 `action.primary`, 나머지 `color.line`), 위에 자리 꼬리표(시, 일, 월, 연, 원형 `action.primary`), 아래 단계 이름(`type.caption.sm`). 스크린리더 "장생, 월주와 연주 ..."(2026-11-07 정정: 하늘님 값은 "장생, 월주 / 목욕, 연주 / 관대, 시주 / 양, 일주", 같은 단계에 자리가 둘일 때만 "월주와 연주", V91).
* `scroll-hint`: 데이터가 더 있는 쪽 끝만 흐림(끝 24 그라데이션 `bg.sheet`로), 아래 줄 좌우 «  » 아이콘(`caret-double-left/right` Light 16, 더 없는 쪽은 숨김). 글자 없음, 스크린리더는 목록 role.
* `stem.chip`(요소): 한자 칸 22, `ohaeng.cell` 글자색과 바탕색, 한자 `font.family.hanja` 13 700.
* 그 밖의 바뀜: `lucky-card` Q5, `dialog` 취소 `color.fill.soft`, `day-cell` `luckFill` 4단계 새 토큰, 달력 범례(`calendar-month` 부품 `legend`와 `ruleEntry`), `sheet` `day-sheet`는 처음부터 `full` 높이, `primary-button` `leadingIcon`(아이콘 `adjacent-text`, 사이 `space.8`), 일기 목록 아래 고정 버튼(목록이 있을 때 떠 있음, 빈 상태는 가운데), `app-bar` 가운데 상태 글자(`draft-indicator`를 상단 바 가운데, 글자 수 포함)와 오른쪽 글자 버튼(저장), `diary-editor` 인용 질문(왼쪽 3px `term.bg` 선, `type.sentence.body` `text.secondary`, 사용자 결정 2026-11-06으로 글자 14: 문장 글꼴 14 토큰이 없어 크기만 덮어씀, 본문 15 그대로) + 질문 바꾸기 아이콘(`arrows-clockwise` Light 20, 터치 44), 일기 보기는 저장된 질문(getDiary `guideQuestion`)을 같은 인용 모양으로 바꾸기 없이(사용자 결정 2026-11-06), 일기 목록 쓰기 버튼 문구는 "일기 쓰기"(origin, IA 가안, 사용자 의견 2026-11-06, writing 원고 변경 요청), `lock.veil` G1(앞 단어 또렷, 자리값 줄 수 판정 근거 3, 원전 2, 사주 표 용신 판정 근거 2(2026-11-07, 관문 질문 Q2 권장, V92)), 근거 시트 머리(정한 태그 + 대상 문장 `type.caption.lg`).

## 5. 진행

* PR 하나(drift #815와 #801 2단계). 화면 묶음 B → A와 G → F와 C → D → E마다 토큰 CSS를 읽는 시안으로 사용자 확인(관문).
* 아직 명세가 없는 IA 컴포넌트는 `tools/components.py` 대기 목록에 두고, 묶음마다 줄여 마지막에 비어야 합니다.
* 다른 단위: server #806(길흉 내역, 오늘 음력, 일진 십성 묶음, 아주 잘 풀리는 날), #797(잠긴 문장 앞부분), core #804(태그 근거), writing(새 슬롯과 상한, 범례 입구 문구), app #796·#808.
