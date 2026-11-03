# W51 슬롯 상한과 집중 시간 칩 (#710·#546)

* 입력: Issue #710(writing W51, IA 밖 새 `ui.*` 슬롯 7개 상한), #546의 design 몫(`lucky-card` 시간 칸의 범위 대시와 가운뎃점, D93)
* 결과: 결정 V52~V54, 컴포넌트 계약 3.3.0, `lengths.md` 3.3.0
* 시안 없음. app 구현(`app/lib/design/components/saju/`, `depth/evidence_sheet_body.dart`)과 writing R26 원고를 기준으로 정함

## 확인한 사실

| 사실 | 출처 |
| --- | --- |
| 집중 시간 구간은 1~2개 | `server/api/openapi.yaml` `FocusTimeCard.picks` minItems 1, maxItems 2 |
| 범위 표기는 ko `~`, ja `〜`, en " to ", 여러 값은 레이아웃으로 나눔 | writing W44 |
| app은 꼬리표를 기둥 폭 `SizedBox` 안 한 줄로 그림, '나'는 `PositionedDirectional(top: -8, end: -6)`, 좌우 6 | `daeun_table.dart`, `saju_pillars.dart`, `tag_me.dart` |
| app은 표 칸 근거 시트의 빈 해석에 제목 + `bodyUi` 보조색 문장을 그림 | `evidence_sheet_body.dart` `_section(emptyText)` |
| 만세력 행 머리 52px, 대운 기둥 52px 간격 4, 세운 5칸 | `saju.json` |

## 1. 집중 시간 칩 (V52)

사용자가 세 안(구간마다 칩, 칩 하나에 두 줄, 쉼표 한 줄) 중 "구간마다 칩 하나"를 골랐습니다. 범위 표기는 처음에 세 언어 모두 `~`로 제안했다가, en에서 `~`가 "약"이라는 지적을 받고 W44의 언어별 표기로 고쳤습니다.

* `time` 변형에 `repeat`(`FocusTimeCard.picks`, 최대 2), `value.format`은 언어별 객체, `join` 삭제.
* 칩 줄 최대 7개. 두 칩은 같은 설명을 열고 테두리는 누른 칩에만.
* 공유 이미지는 첫 구간 칩 하나(칩 수 표 그대로).

## 2. W51 슬롯 상한

| 슬롯 | 잰 자리 | 폭 | 줄 | ko | ja | en |
| --- | --- | --- | --- | --- | --- | --- |
| `ui.settings.row`, `ui.profile-edit.birthplace` | settings-row 이름과 값이 나눔(사이 `space.8`, 새로 명세에 적음) | 132 | 1 | 11 | 8 | 19 |
| `ui.legal.row` | settings-row 이름 | 272 | 1 | 23 | 18 | 42 |
| `ui.saju-chart.tab` | segmented 두 칸 | 156 | 1 | 13 | 10 | 22 |
| `ui.saju.header` | 만세력 행 머리 term-token label | 44 | 2 | 8 | 4 | 10 |
| `ui.saju.tag` | 대운 꼬리표(기둥 둘과 간격, V53) | 92 | 1 | 8 | 6 | 13 |
| `ui.evidence.personal-empty` | 근거 시트 빈 해석 안내(V54) | 320 | 2 | 60 | 42 | 100 |

* 키별: `sajuTagMe`는 `tag.me`(10px 굵게, 기둥 75.5 − 12)로 7, 5, 10. en `manseRowHiddenStems`는 실측 상한 12(낱말마다 44px 안).
* 상한 없음: `ui.saju.a11y`, `ui.lucky-card.a11y`, `ui.share.a11y`(스크린리더 전용), `ui.system.tracking`(iOS 시스템 창).
* R26 원고 중 넘는 것: en `sajuChartTabLuck` "Calendar and luck cycles" 24자(상한 22, 실측 155.1px / 156px). writing에 줄이기 요청.

### 고른 것과 버린 것

* 꼬리표: 기둥 폭에 가두고 원고를 줄이는 안은 ja "わたし"가 전각 상한 1자가 되어 버렸습니다. 꼬리표는 줄에 하나라 이웃 위로 넘쳐도 겹칠 것이 없습니다.
* 행 머리: 52px를 넓히면 네 열이 좁아져 지장간 두 줄 묶음이 빠듯해집니다. 대운 라벨과 같은 두 줄 규칙을 택했습니다.
