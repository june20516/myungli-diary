# 스토어 이미지 명세

App Store와 Google Play 등록정보의 스크린샷과 Play 그래픽 이미지를 만드는 기준입니다(D133, 결정 V133). 사실은 [`store.json`](store.json)에 있고, 이 문서는 그 설명입니다. 왜 이렇게 정했는지는 [spec](../specs/2026-11-16-store-screenshots-design.md)에 있습니다.

| 맡는 쪽 | 하는 일 |
| --- | --- |
| design | 이 명세(장면, 틀, 크기, 글 자리와 상한) |
| writing | 스크린샷 위 글(ko, en, ja, #1201) |
| app | 장면을 찍어 틀에 합성하는 생성 명령(#1203) |
| 지휘 | 두 스토어 콘솔에 올리기 |

명세 판은 `store.json` `version`(지금 1.0.0)입니다. 바꿀 때는 컴포넌트 계약과 같은 규칙으로 올립니다: 지움과 이름 바뀜은 주 버전, 더함은 부 버전, 값만 바뀌면 수 버전.

## 장면
두 스토어 같은 여섯 장, 같은 순서입니다. 앞 세 장이 검색 결과에 보입니다.

| 순서 | 키 | IA 화면 | 상태 | fixture 시나리오 | 보여 주는 것 |
| --- | --- | --- | --- | --- | --- |
| 1 | `today` | `today` | `default` | `member` | 내 사주로 조합한 오늘 |
| 2 | `evidence` | `evidence-sheet` | `unlocked` | `evidence-unlocked` | 판정 근거와 원전 |
| 3 | `calendar` | `calendar` | `default` | `member` | 한 달 길흉 |
| 4 | `daySheet` | `day-sheet` | `default` | `member` | 그날 길흉판정, 일정, 일기 |
| 5 | `mySaju` | `my-saju` | `default` | `member` | 원국과 오행 분포 |
| 6 | `share` | `share-preview` | `default` | `member` | 오늘 카드 공유 |

화면, 상태, 시나리오 세 값은 app 화면 렌더 사례(`app/test/screenshots/screens_test.dart`)의 이름입니다. 상태 이름은 IA 상태 목록이 아닙니다.

## 렌더 조건
* 논리 390×844, 배율 3(1170×2532 한 장). 한 장을 두 스토어 틀에 씁니다.
* 라이트 모드. 화면 안 글은 각 언어(ko, en, ja)로 찍고, 데이터는 시나리오의 대역 데이터 그대로입니다(실존 인물 아님). 가격이 보이는 화면은 장면에 없습니다(D74).
* 탭 화면 아래 배너 광고 자리와 상태 막대(시계, 배터리)는 빼고 찍습니다.
* 근거 시트는 반짝임 띠가 지나가지 않는 정지 순간이고, 열림 꼬리표는 끝 시각 문구(`evidenceSheetUnlockUntilTime`, D132)입니다.

## 틀
바탕은 `gradient.today` 라이트(`#eef4ef`에서 `#fbefee`, 160°)이고 기기 테두리는 두지 않습니다. 글은 위, 화면은 아래 둥근 판입니다.

| 칸 | App Store iPhone 6.9인치 | Play 휴대전화 |
| --- | --- | --- |
| 그림 크기 | 1320×2868 | 1080×1920 |
| 글 자리 위 | 200 | 120 |
| 글 자리 좌우 (폭) | 120 (1080) | 96 (888) |
| 글 크기 | 88 | 72 |
| 화면 판 위 | 560 | 400 |
| 화면 판 폭 (가운데) | 1080 | 700 |
| 화면 판 모서리 | 72 | 48 |
| 화면 판 그림자 (아래, 흐림) | 24, 64 | 16, 44 |

* 글: Pretendard SemiBold(600), 자간 −2%, 줄 높이 1.3, `text.primary` 라이트(`#2b2b2a`), 가운데 맞춤, 최대 두 줄.
* 그림자 색은 둘 다 `rgba(40, 50, 40, 0.14)`입니다.
* 화면 판은 렌더를 판 폭에 맞춰 줄이고(높이는 비율대로), 그림 아래로 넘치는 부분은 자릅니다.
* App Store는 1320×2868 하나만 냅니다(작은 iPhone 크기는 Apple이 줄여 씀). iPad는 내지 않습니다(D133 ①). Play는 긴 변이 짧은 변의 2배 이하여야 해서 1080×1920을 따로 냅니다.

## 글 자리와 상한
장면마다 글 하나, 최대 두 줄입니다. 줄바꿈은 writing이 원고에 직접 넣고, 한 줄씩 아래 상한을 지킵니다. 두 틀의 글 크기와 폭 비율이 같아 상한도 같습니다.

| 언어 | 한 줄 | 두 줄 |
| --- | --- | --- |
| ko | 14 | 28 |
| ja | 11 | 22 |
| en | 24 | 48 |

* 재는 법은 [`lengths.md`](../lengths.md)와 같습니다: ko는 띄어쓰기 없는 한글로 칸을 채운 수, ja는 전각 1em에서 금칙 여유 한 글자를 뺀 수, en은 글자 빈도 가중 평균 폭에서 줄바꿈 손실을 뺀 수입니다.
* 슬롯 이름과 키는 writing이 정합니다. 제안은 `store.screenshot.caption`이고 키는 위 장면 표의 키입니다.
* 이 상한은 `lengths.md` 상한 표에 넣지 않습니다. writing 검사가 그 표의 슬롯을 writing 슬롯에서 바로 찾기 때문입니다.

## Play 그래픽 이미지
* 1024×500, 바탕은 스크린샷과 같은 `gradient.today` 라이트 160°.
* 가로 조합 [`logo/lockup.png`](../logo/lockup.png)를 폭 472(높이는 비율대로 약 130)로 가로 세로 가운데에 둡니다.
* 글은 넣지 않고 세 언어에 같은 한 장을 씁니다. 워드마크는 한글이고, 언어별 앱 이름은 스토어가 글로 보여 줍니다.

## 검사
저장소 루트에서:

* `python3 docs/identity/design/tools/store.py`: 장면(IA 화면, app 렌더 사례, fixture 시나리오), 크기, 틀 수치, 로고 파일.
* `uv run --with fonttools==4.54.1 python docs/identity/design/tools/store.py --font-dir .suberpowers/fonts`: 위에 더해 상한 표를 실측과 대조합니다.
* 테스트는 `tools/test_store.py`입니다.
