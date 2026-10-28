# design — 디자인 시스템

이 디렉터리에서 시작한 세션은 **design 세션**입니다. 루트 [`CLAUDE.md`](../../../CLAUDE.md)와 [`docs/workflow.md`](../../workflow.md)의 공통 규약을 함께 따릅니다. 기준 문서는 [`docs/identity/README.md`](../README.md)(브랜드 기반)입니다.

## 범위
명리일기의 시각 정체성, 디자인 토큰, 컴포넌트 명세를 만듭니다. 구현(Flutter)은 app이 합니다. 상세는 [브랜드 기반 spec §7·§9](../../specs/2026-10-10-brand-foundation-design.md)에 있습니다.

| 산출물 | 받는 쪽 | 마일스톤 |
| --- | --- | --- |
| 시각 정체성: 로고 방향, 그라데이션 규칙, 오행 팔레트, 타이포 | 모두 | V0 |
| 디자인 토큰 (`tokens/`, 데이터 파일) | app (Dart 코드 생성) | V1 freeze |
| 캘린더 길흉 표시 규칙 (엔진 spec §8 `LuckLevel` 3단계, 루트 미결에서 이관). 점이 아니라 날짜 칸 채우기(결정 V10) | app | V1 |
| 컴포넌트 명세 (`components/`): IA 컴포넌트 + 상호작용 패턴·요소 | app | V2 |

* 비공개 기록 `background/06-design-system.md`(D74)는 V0의 입력이었습니다. V0 결과가 정체성 기준으로 06을 대체합니다.
* 그라데이션은 조건부 선택입니다(README "시각 방향"). 토큰 하나로 묶어, 리뉴얼할 때 그 토큰만 바꾸면 되게 합니다.
* 사용자는 제품 작업을 컴포넌트부터 설계하기를 원합니다. app의 UI 구현은 V2 뒤에 시작합니다.

## 고칠 수 있는 곳
`docs/identity/design/`, GitHub Issues(요청·보고 작성, `gh issue list --label to:design`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (V2의 선행 조건) | 지휘 |
| 디자인 토큰 (`tokens/`) | **제공** (V1 freeze, 그 뒤는 추가만) | app |
| 컴포넌트 명세 (`components/`) | **제공** | app |
| 글자 수 상한 | **주고받음** (요청함) | writing |

계약 버전과 상태는 [`docs/contracts/README.md`](../../contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.

## 현재 상태 (2026-10-28, design 세션 작성)
* **사주 표 십성 라벨·피드백 표시·윤달 사주 줄 #353·#354·#587** (브랜치 `design/feedback-saju-353-354-587`, 결정 V48~V51).
  * #353(V49): `daeun-table` 대운 기둥에 천간·지지 십성과 12운성(`term-token` `label`, 줄 순서 `order`), 세운은 천간 십성 하나. 라벨은 칸 폭 안 두 줄 줄바꿈, 넘치면 `type.caption.sm`까지 줄임, 줄마다 높이 맞춤. `manse-table` 지장간은 "한자와 독음 / 십성" 두 줄 묶음을 늘 쓰고, 12운성·신살 값은 `term-token` `inline`. 십성 라벨 상한 행은 두지 않음(`glossary.value_name`이 다른 자리와 같은 슬롯).
  * #354(V50·V51): `notice-banner` `error`(`cloud-warning`, 버튼 없음, 다시 시도는 화면 저장 버튼), `stateMap.error`에 배너 추가, `settings-row` `groupNote`(묶음 카드 위 안내, `profile-edit.recalc.notice`, 상한 62·46·104), toast는 아래 고정 버튼 위 16px.
  * #587(V48): `account-choice` 사주 줄은 달력 종류 뒤에 윤달 낱말(`dayCellLeapMonth`와 같은 낱말). 256px 안(en 시각 모름 248.8px). 틀은 writing 차례.
  * 근거: [spec](specs/2026-10-28-feedback-saju-labels-design.md). 시안 없이 app 임시 구현을 기준으로 정함.
* **구매 줄 두 줄·광고 제거 새 슬롯 #564·#548** (브랜치 `design/purchase-meta-564`, W44, 컴포넌트 계약 3.1.0).
  * `purchase-row` `meta`: 구매일 줄 아래 `space.2`에 사용 기간 줄, 구분자 `join`(`purchaseMetaSeparator`) 삭제, `loading` bone 세 줄(결정 V47). 글자 수는 키마다 한 줄이라 `ui.purchase.meta` 상한 그대로.
  * `offer-card` `buy` → `ad-free.buy.cta`, `period` → `ad-free.offer.period`. 카드 안 버튼(구매, 구매 내역)은 240px 행으로 따로 잼(`ad-free.history.cta` 23·19·42 → 20·16·35), 기간 고지는 280px 한 줄. `lengths.md` 상한 없음 표의 겹친 윤달 표지 행 정리.
* **계정 합치기 두 단계·구매 내역 #480·#483·#494·#475** (브랜치 `design/catchup-480-d85-d88`, D85·D88, 컴포넌트 계약 3.0.0).
  * `account-merge` 한 화면 두 단계(인증 → 가져올 기록·구매 상자 + `account-choice` + 합치기 버튼), "합치지 않기" 없이 뒤로 가기. `account-choice`는 프로필 고르기(`facts`·`diaryCount`·`providers` 삭제, `other` 알약 추가). `login-methods`에 합치기 입구, 연결 안 함 안내는 `dialog` `notice`(V44).
  * `offer-card` `restore` → `history`, `purchase-row` 새 컴포넌트(상품 이름 → 구매일·사용 기간, 상태 오른쪽, V45, 지휘 #502로 상품 이름 추가).
  * #475: 카카오 배지 `#191919`, LINE 글자 198px(`lengths.py` `KEY_TARGETS`), `entry` 꺾쇠 앞 `space.8`, 시각 24시간제(V46).
  * 근거: [spec](specs/2026-10-23-account-merge-purchase-design.md), 결정 V44~V46, 시안 `design-v2-account-merge-purchase`.
* **같은 날 여러 편 #410** (브랜치 `design/diary-row-multi`, D83, 컴포넌트 계약 2.8.0·토큰 1.2.0).
  * `diary-row` 변형 `day`(목록·태그 모아보기: 한 편이면 지금 모양, 두 편 이상이면 날짜 하나에 카드 하나 — 배지 위·태그 아래 한 번씩, 사이에 `entry` 줄)와 `entries`(오늘·그날 시트: `entry` 줄만). `entry`는 작성 시각 + 한 줄 미리보기 + 꺾쇠, 줄 사이 1px 점선(대시 4·간격 3, 새 토큰 `color.timeline.entry`, V42).
  * 상한을 채운 날 입구: `guide-question-card` `full`(도장 남기고 버튼만 막음), 그날 시트 버튼·날짜 시트 버튼 `disabled` + writing `…Full` 키(V43). "쓴 일기 보기" 표기를 writing 키로 고침(D83 ③). 그날 시트 일기 입구는 머리(`entries.head`) + 줄 + 쓰기 버튼으로 V37을 개정하고 `depth-link` `navigate`의 `daySheetSlot`을 지움(IA day-sheet의 `depth-link`는 지휘가 PR #460으로 뺌, drift #461).
  * writing #441 키 이름 채움: `connected` "연결됨" `loginMethodsRowConnected`, 수단 구분자 `accountChoiceProviderSeparator`.
  * 근거: [spec](specs/2026-10-22-diary-row-multi-design.md), 결정 V42·V43, 시안 `design-v2-diary-row-multi`.
* **영문 ja 로그인 라벨 상한 #446** (브랜치 `design/login-label-ja`): `lengths.py` `KEY_LIMITS`(키별 상한 표)로 `ui.login.provider` ja `loginKakaoLabel`(영문 "Login with Kakao", #143)은 en 상한. IA가 `login-methods`에서 `settings-row`를 빼(PR #442) `USED_ON_EXCEPTIONS`를 지움. app #311에 2.7.0 요약을 남김.
* **로그인 수단·계정 합치기 #389** (PR #439 병합, D82·D83, 컴포넌트 계약 2.7.0, drift #395).
  * `social-login-button`: `line`·`google` 변형(각 사 가이드 값), 언어별 순서 `parts.stack.order`(맨 위만 ko 카카오·ja LINE·en Google), 상태 `connected`(중립 줄 + "연결됨", 마지막 하나는 누를 수 없음, 결정 V39). login-methods 화면 배치는 `action.md`.
  * `account-choice`(새 컴포넌트, `input`): 처음엔 고르지 않음(`none`), 카드에 호칭·"현재 계정"·사주 요약(`ui.account-merge.saju`)·일기 수·수단 이름(로고 없음). account-merge 배치는 `input.md`: 겹치는 날 안내는 경고 표시 없는 안심 안내, 강조는 최종 확인 `dialog` `destructive` 한 곳(V40).
  * `dialog`: 버튼 두 개짜리 확인 창의 첫 초점 규칙을 지움, `destructive`의 뒤로 가기는 취소(V41, #354 ②의 답).
  * `day-cell` 윤달 표지 슬롯 `ui.day-cell.lunar`(#260), `diary-row` 쓰는 화면에 today·day-sheet(D83, 모양은 #410).
  * 글자 수 상한 11행, 윤달 표지는 상한 없음(폭 44px로 확인), `ui.login.provider`는 가운데 정렬 232px로 다시 잼(`lengths.md` 2.7.0). #419 원고 중 확인 창 제목 키·ja 알약이 상한을 넘어 writing에 줄이기 요청. IA `login-methods`의 `settings-row`는 지휘가 PR #442로 뺌(#440).
  * 근거: [spec](specs/2026-10-22-login-methods-account-merge-design.md), 결정 V39~V41, 시안 `design-v2-login-methods`·`design-v2-account-merge`.
* **검사 범위 정리 #362** (PR #371 병합, D81): `design.yml` `mode`(`own` 전체, `drift`·`gate`는 계약 검사만), 측정 글꼴 CI 받기·캐시, D79 기본 깊이 행 삭제.
* **규칙 정합성 점검 #284** (브랜치 `design/rules-audit`, D78).
  * 글자 수 상한: D77 IA 자리 9개를 writing 슬롯(W33, `ui.*`에 `ia`) 기준으로 기존 행에 더함(값 그대로). `settings.calculation_basis` → `calc-basis.longitude.body`(W21). #191은 W26 `unbounded`·`key_max_length`로 끝남.
  * MD "쓰는 화면"을 IA에 맞추고 테스트가 대조함. 예외 `diary-editor` diary-view는 IA 보완 요청 #290.
  * V19·V37 개정 표시, `lucky-card` 칩 줄 전체 최대 6개, `visual-identity.md`는 계약 표를 가리킴.
  * #141 끝남: app에 V31 목표 모양 요청 #292(#282 3번과 같은 항목).
* **app 계획 4 확인 #218·drift #252·#257** (브랜치 `design/calendar-answers`).
  * `date-picker` `solar`(일정 날짜 양력만), `text-field` `multiline`(6줄까지, 줄바꿈 키), `dialog` `destructive`에 일정 삭제.
  * `event-row`: 일정에 길이가 없음(시각 일정은 진행 중 아님), '외 N개'는 라벨 끝 목록 구분자, summary `twoLines`, list `timeColumn.overflow`·`add`·`failed`.
  * `day-cell`: 높이는 1.3배 글자까지만 늘어나는 최소 높이(V36), 윤달 초하루 표지(V38, 문구는 writing #260)·윤달 라벨은 윤달 모든 날.
  * 그날 시트 일기 입구(V37): 보기 `depth-link` `navigate`(`daySheetSlot`), 쓰기 `primary-button` `filled`.
  * 근거 여럿은 문단·상자를 `space.12`로 쌓음(`repeat`), 풀이 시트 한자는 `font.family.hanja`, 원전 인용은 한자만 `fontFallback`.
  * drift: `lengths.py` 측정 말뭉치를 R8까지로 고정(`MEASURED_LAST_ROUND`). 확정값이 라운드에 따라 움직이지 않고, 테스트는 개수를 `lengths.md` 근거 문장에서 읽음.
* **오늘 화면 대표 태그 칩 #239** (브랜치 `design/today-tag`, D76): `lucky-card` 변형 `tag`(글자 굵기 600 + 앞 아이콘 `tag` 본문색, 길흉 색 없음, 결정 V35), 칩 줄 맨 앞, 공유 이미지 제외. 글자 수 `daily.tag_label`은 이 칩 폭으로 다시 잼(확정값 그대로).
* **app 질문 #195·#211** (브랜치 `design/app-questions`): `city-search` 고른 뒤 저장 중 `saving`(고른 줄 끝 점 숨쉬기, 결정 V34), 지역 구분자 `region.join`(ja `、`), `input-step` `preface` 간격 `space.24`, `skeleton` 글줄 `type`, 안내 글 본문 레이아웃(`frame.md`, IA 컴포넌트 아님).
* **구현 대응·IA v3·글자 수 상한** (브랜치 `design/spec-followups`, Issue #118·#142·#154·#159·#131).
  * app 구현 차이 판단을 명세에 확정: 링크 화살표는 아이콘 `caret-right`로 컴포넌트가 그림, 고정 높이는 최소 높이, `dialog` `notice`, `segmented` `none`, 윤달 대체 모양, 탭 아이콘, 시간 형식, 근거 시트 빈 구역 생략, 요소 값 3개.
  * IA v3: 출생지 → 계산 기준 링크 `depth-link` `navigate`(슬롯 `birthplace.standard.link`).
  * 글자 수 상한: ui 이름 자리와 새 content 슬롯 칸을 더함, 상한 없음 표, 확인 창 슬롯은 제목·버튼 키만. 기존 확정값 그대로.
  * 명세를 바꾸지 않는 Flutter 대응(의미 표시 등)은 각 `.md`의 구현 힌트에 적음.
  * 근거: [spec](specs/2026-10-15-spec-followups-design.md), 결정 V29~V33.
* **용신 근거 줄 이름 슬롯** (브랜치 `design/yongsin-title`, Issue #81): `sentence-block` `a11y.lockedNameSlot` = `saju-chart.yongsin.title`(잠김 라벨의 구역 이름).
* **문장 조각 용어 표시·근거 잠금 슬롯** (브랜치 `design/lock-slots`, Issue #68, PR #83).
  * `sentence-block.parts.segments`: `term` 조각은 `term-token`이 있는 화면에서만 칩(`term-token` `inline`), 그 밖은 일반 글자. 용어와 붙은 조사는 한 덩어리로 줄바꿈.
  * IA v1 추가분(#70) 슬롯: `sentence-block` 열기(`saju-chart.yongsin.open`), 근거 시트 구역 제목 3개·해제 실패 toast·접근성 문구 3개.
  * 슬롯 이름과 `term-token` 화면 목록은 테스트가 IA에서 읽어 비교합니다.
  * 근거: [spec](specs/2026-10-13-term-segments-lock-slots-design.md), 결정 V28.
* **V2 후속: 근거 깊이 잠금·글자 수 상한** (브랜치 `design/v2-followups`, Issue #53·#54).
  * 근거 시트 구성과 잠김 상태 4개(`depth-link.evidenceSheet`), 요소 `lock.veil`, `sentence-block` `locked`. 풀이 시트의 개인 해석 상자와 `term-token` 잠김은 뺌(D60).
  * 공통 규칙: 동작 = 둥근 사각, 표시·고르기 = 알약(예외 없음), 화면 좌우 여백 `space.20`.
  * 글자 수 상한: [`lengths.md`](lengths.md), 도구 `tools/lengths.py`(측정 글꼴은 `tools/fonts.py`로 `.suberpowers/fonts`에 받음).
  * 근거: [spec](specs/2026-10-11-depth-lock-lengths-design.md), 결정 V25~V27.
* **마일스톤 V2 컴포넌트 명세** (브랜치 `design/components`).
  * 명세: [`components/`](components/README.md) JSON(사실) + MD(설명) 11쌍. 공통 `interaction`(패턴 12개)·`elements`(요소 15개, 근거 잠금에서 16개).
  * 검사: 저장소 루트에서 `python3 docs/identity/design/tools/components.py`(IA 41개·토큰 참조·요소·패턴·상태 대응표·짝 MD).
  * 근거: [V2 spec](specs/2026-10-11-components-design.md), 결정 V13~V24. 대비 검사 86/86(비활성 글자 3:1).
* **마일스톤 V1 디자인 토큰 freeze** (브랜치 `design/tokens`).
  * 토큰: [`tokens/`](tokens/README.md) 다섯 파일. 생성: 저장소 루트에서 `python3 docs/identity/design/tools/tokens.py`. 손으로 고치지 않습니다.
  * 근거: [V1 spec](specs/2026-10-11-design-tokens-design.md), 결정 V8~V12. 대비 검사 52/52.
  * 길흉 표시는 점이 아니라 칸 채우기입니다(결정 V10).
* **V0 시각 정체성 완료** (PR #10).
  * 기준 문서: [`visual-identity.md`](visual-identity.md). 시각에 관해서는 06을 대체합니다.
  * 근거: [V0 spec](specs/2026-10-10-visual-identity-design.md), 결정 V1~V7([`decisions.md`](decisions.md)).
  * 색 값의 출처: [`tools/palette.py`](tools/palette.py) (`--check`로 대비 검사).
  * 로고 원본: [`logo/`](logo/), 견본: [`specimen/index.html`](specimen/index.html), 시안 기록: [`artifacts/index.json`](artifacts/index.json).
* 테스트: 저장소 루트에서 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`(1초 안쪽)
  * 반복 중 빠른 경로: 바꾼 도구의 테스트 파일만 돌립니다. 예: 명세는 `... pytest docs/identity/design/tools/test_components.py -q` + `python3 docs/identity/design/tools/components.py`, 글자 수는 `test_lengths.py`, 토큰은 `test_tokens.py test_dtcg.py`.
* 측정 글꼴(고운돋움·Zen Maru Gothic·Pretendard)은 저장소에 넣지 않습니다. 받기: `python3 docs/identity/design/tools/fonts.py --font-dir .suberpowers/fonts`(주소·sha256 고정).
  * 로컬에서 글꼴이 없으면 글자 수 표 비교·워드마크 테스트 4개가 **skip**됩니다. CI는 글꼴을 받아 돌리고, 없으면 실패합니다(`DESIGN_FONTS_REQUIRED=1`).
* 로고 원본(`logo/`)을 바꾸면 순서대로 다시 만듭니다.
  1. 워드마크·가로 조합: `uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py --font .suberpowers/fonts/GowunDodum-Regular.ttf --out-dir docs/identity/design/logo`
  2. 로고 모음 산출물: `python3 docs/identity/design/tools/logo_sheet.py`. 다시 만들지 않으면 `test_logo_sheet_matches_committed_artifact`가 실패합니다.

## 다음 할 일
1. **#546 design 몫(D93·W44):** `today.json`·`today.md` `lucky-card` 시간 칸 형식 `HH:mm–HH:mm`과 ` · ` 잇기. app은 `HH:mm~HH:mm`과 쉼표 잇기로 바꿨지만, W44(한 줄에 값을 구분 글자로 잇지 않음)와 겹쳐 여러 구간을 줄로 나눌지 사용자 확인이 필요합니다.
2. **#353·#354·#587 마무리:** PR 병합 뒤 app·writing 확인을 받아 닫습니다. #587은 writing이 윤달 틀을 주면 닫힙니다.

그 밖에는 대기합니다. 아래 일이 생기면 엽니다.
3. **V31 목표 모양 #292:** app이 바꾸거나 유지할 이유(연도 단위 윤달 조회 필요 등)를 알리면 확인합니다.
4. **app 대응 지원:** app이 명세로 만들 수 없는 곳이나 저사양 Android 성능 결과를 `to:design` Issue로 보내면 컴포넌트 계약 버전 규칙대로 고칩니다. notice는 #82입니다.
5. W1 원어민 검수 문장이 나오면 일본어 줄 간격(1.75 / 1.7)을 다시 확인합니다.
6. app이 토큰 형식 변경을 요청하면 계약 버전 규칙(`tokens/README.md`)대로 대응합니다.
