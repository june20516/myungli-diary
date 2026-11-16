# 스토어 스크린샷과 Play 그래픽 이미지 명세 (#1202, D133)

## 1. 목적과 범위
* 두 스토어 등록정보의 스크린샷과 Play 그래픽 이미지를 **app이 명령 하나로 다시 만들 수 있게** 장면, 틀, 크기, 글 자리를 정합니다(D133 ②, app #1203).
* 스크린샷 위 글은 writing이 씁니다(#1201). design은 글 자리와 언어별 글자 수 상한을 넘깁니다(D133 ③).
* 제약: 가격 없음(D74), 실존 인물 출생 정보 없이 데모 데이터만(D133 ④), 글에 긴 대시, 범위 대시, 가운뎃점 없음(D93). iPad 스크린샷은 내지 않습니다(D133 ①).
* 범위 밖: 이미지 생성 코드(app), 글(writing), 콘솔 업로드(지휘), 미리보기 영상.

## 2. 관문 결정 (사용자, 2026-11-16)
| 질문 | 고른 안 | 시안 |
| --- | --- | --- |
| 장면과 순서 | A 오늘 먼저 | `artifacts/2026-11-16-store-scenes-questions.html` |
| 틀 | F1 둥근 판(글 위, 화면 아래, 기기 테두리 없음) | `artifacts/2026-11-16-store-frame-questions.html` |
| Play 그래픽 이미지 | G1 가로 조합 로고만 | `artifacts/2026-11-16-store-feature-graphic-questions.html` |

## 3. 산출물
* `store/store.json`: 장면, 렌더 조건, 틀 수치, 그래픽 이미지 수치(사실). app 생성 도구가 읽습니다.
* `store/README.md`: 설명과 글자 수 상한 표(writing이 읽음).
* `tools/store.py`: `store.json` 검사와 상한 계산. 저장소 루트에서 `python3 docs/identity/design/tools/store.py`(검사), `--font-dir .suberpowers/fonts`면 상한을 재어 README 표와 대조합니다.
* `tools/test_store.py`: 위 검사의 테스트. 글꼴이 없으면 상한 대조만 skip(CI는 글꼴을 받음).
* 계약 목록(`docs/contracts/README.md`) 행은 지휘가 정합니다(PR 본문으로 물음). 그 전까지 `store.json`의 `version`은 `1.0.0`이고 바뀌면 컴포넌트 계약과 같은 규칙(지움과 이름 바뀜은 주, 더함은 부, 값은 수)으로 올립니다.

## 4. 장면 (A안)
두 스토어 같은 여섯 장, 같은 순서입니다(App Store 최대 10, Play 2~8). 앞 세 장이 검색 결과에 보입니다.

| 순서 | IA 화면 | 상태 | fixture 시나리오 | 보여 주는 것 |
| --- | --- | --- | --- | --- |
| 1 | `today` | `default` | `member` | 내 사주로 조합한 오늘 |
| 2 | `evidence-sheet` | `unlocked` | `evidence-unlocked` | 판정 근거와 원전 |
| 3 | `calendar` | `default` | `member` | 한 달 길흉 |
| 4 | `day-sheet` | `default` | `member` | 그날 길흉판정, 일정, 일기 |
| 5 | `my-saju` | `default` | `member` | 원국과 오행 분포 |
| 6 | `share-preview` | `default` | `member` | 오늘 카드 공유 |

* 화면, 상태, 시나리오 세 값은 app 화면 렌더 사례(`app/test/screenshots/screens_test.dart`)와 같은 이름입니다. app은 같은 사례를 스토어 조건으로 다시 찍습니다.

## 5. 렌더 조건
* 화면 크기는 지금 렌더와 같은 논리 390×844, 배율 3(1170×2532 한 장)입니다. 한 장을 두 스토어 틀에 씁니다.
* 라이트 모드. 화면 안 글은 각 언어(ko, en, ja)로 찍습니다. 데모 데이터는 시나리오의 대역 데이터 그대로입니다(실존 인물 아님).
* 탭 화면 아래 배너 광고 자리는 빼고 찍습니다(탭 막대만 남음). 상태 막대(시계, 배터리)는 넣지 않습니다.
* 근거 시트는 반짝임(`unlock.glint`) 띠가 지나가지 않는 정지 순간에 찍습니다. 열림 꼬리표는 D132의 끝 시각 문구(`evidenceSheetUnlockUntilTime`)입니다.

## 6. 틀 (F1)
바탕은 `gradient.today` 라이트(`#eef4ef` → `#fbefee`, 160°)입니다. 기기 테두리는 두지 않습니다.

| 칸 | App Store 6.9인치 | Play 휴대전화 |
| --- | --- | --- |
| 그림 크기 | 1320×2868 | 1080×1920 (9:16) |
| 글 자리 위 | 200 | 120 |
| 글 자리 좌우 (폭) | 120 (1080) | 96 (888) |
| 글 크기 / 줄 높이 | 88 / 1.3 | 72 / 1.3 |
| 화면 판 위 | 560 | 400 |
| 화면 판 폭 (가운데) | 1080 | 700 |
| 화면 판 모서리 | 72 | 48 |
| 화면 판 그림자 | 0 24 64, rgba(40, 50, 40, 0.14) | 0 16 44, rgba(40, 50, 40, 0.14) |

* 글: Pretendard SemiBold(600), 자간 −2%, `text.primary` 라이트(`#2b2b2a`), 가운데 맞춤, 최대 두 줄.
* 화면 판: 렌더를 폭에 맞춰 줄이고(높이는 비율대로), 그림 아래로 넘치는 부분은 자릅니다.
* Play 크기 규칙(긴 변이 짧은 변의 2배 이하)은 1920 / 1080 = 1.78로 맞습니다. App Store 1320×2868은 Play에 쓰지 않습니다.

## 7. 글 자리 (writing #1201)
* 장면마다 글 하나, 최대 두 줄. 줄바꿈은 writing이 원고에 직접 넣고(자동 줄바꿈에 맡기지 않음) 한 줄씩 상한을 지킵니다.
* 한 줄 상한(두 크기에서 같음, `tools/store.py` 실측):

| 언어 | 한 줄 | 두 줄 |
| --- | --- | --- |
| ko | 14 | 28 |
| ja | 11 | 22 |
| en | 24 | 48 |

* 재는 법은 `lengths.py`와 같습니다: ko는 띄어쓰기 없는 한글로 칸을 채운 수, ja는 전각 1em에서 금칙 여유 한 글자를 뺀 수, en은 글자 빈도 가중 평균 폭에서 줄바꿈 손실을 뺀 수.
* 슬롯 이름과 키는 writing이 정합니다(제안: `store.screenshot.caption`, 키는 장면 순서대로 `today`, `evidence`, `calendar`, `daySheet`, `mySaju`, `share`).
* 이 상한은 `lengths.md` `## 상한` 절에 넣지 않습니다. writing 검사(`test_slots.design_lengths`)가 그 절의 슬롯을 writing 슬롯에서 바로 찾으므로, 슬롯이 생기기 전에 넣으면 writing 검사가 깨집니다. writing이 슬롯을 만든 뒤 옮길지는 그때 writing과 정합니다.

## 8. Play 그래픽 이미지 (G1)
* 1024×500, 바탕 `gradient.today` 라이트 160°.
* 가로 조합 `logo/lockup.png`(1047×288)를 폭 472(그림 폭의 46%, 높이는 비율대로 약 130)로 가로 세로 가운데에 둡니다.
* 글은 넣지 않습니다. 세 언어에 같은 한 장을 씁니다(워드마크는 한글, 언어별 앱 이름은 스토어가 글로 보여 줌).

## 9. 검사 (`tools/store.py`)
* 장면의 IA 화면 id가 `docs/ia/screens.json`에 있음.
* (화면, 상태, 시나리오) 조합이 app 렌더 사례 `app/test/screenshots/screens_test.dart`의 `_Shot`에 있음. 상태 이름(`default`, `unlocked`)은 IA 상태 목록이 아니라 이 사례의 이름입니다.
* fixture 시나리오가 `app/fixtures/<시나리오>/`에 있음.
* 장면 순서 번호가 1부터 빈틈없고 6장(Play 2~8, App Store 10 이하).
* 크기: App Store 1320×2868, Play 긴 변 ≤ 짧은 변의 2배, 짧은 변 ≥ 1080, 그래픽 이미지 1024×500.
* 틀: 글 자리와 화면 판이 그림 폭 안, 화면 판 위가 글 두 줄 아래(글 위 + 2 × 크기 × 줄 높이 ≤ 화면 판 위).
* 글꼴이 있으면 상한을 재어 `store/README.md` 표와 대조.

## 10. 함께 고치는 것
* 결정 V133(이 명세), `artifacts/index.json`에 관문 질문 페이지 셋 등록.
* design `CLAUDE.md`: "현재 상태"의 병합된 #1180 항목을 지우고 #1202로, "기준 문서와 도구"에 `store/`.
