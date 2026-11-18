# Play 비공개 테스트 일일 확인

Google Play 새 개인 계정의 production 신청 요건(테스터 12명 이상이 14일 연속, T1)을 지키는지 지휘 세션이 하루 한 번 확인하는 루틴입니다. 세션이 계속 떠 있지 않아도 되게, 세션을 열거나 다시 이을 때마다 이 문서를 따라 **오늘 확인이 안 됐을 때만** 돌립니다(멱등).

## 값과 상태 (로컬 값, D98, 대장 K19)
`$MYUNGLI_LOCAL_DIR/root/shared/play-closed-test/` (`MYUNGLI_LOCAL_DIR` 기본 `~/.config/myungli`)

| 파일 | 내용 |
| --- | --- |
| `config.json` | Chrome 브라우저 deviceId, Play Console 개발자 id, 앱 id, 통계와 대시보드 주소, 업체 공지 주소, 시작일, 기준 설치 수 |
| `state.json` | `active`(루틴을 계속 돌릴지), `last_checked`(마지막 확인 날짜, 로컬 날짜 `YYYY-MM-DD`), `history`(날짜별 기록) |
| `shots/YYYY-MM-DD.png` | 그날 통계 그래프 캡처 |

공개 저장소라 계정 id와 주소는 이 문서에 적지 않고 `config.json`에서 읽습니다.

## 언제 돌리나
1. **세션을 열거나 다시 이을 때:** `state.json`을 읽습니다. `active`가 `true`이고 `last_checked`가 오늘이 아니면 아래 "확인 절차"를 돌립니다. 오늘 이미 했으면 건너뜁니다.
2. **세션이 길게 이어질 때:** `CronList`에 이 루틴 예약이 없으면 `CronCreate`로 매일 한 번(예: `13 10 * * *`) 예약합니다. 예약 prompt는 "`tools/play-closed-test/README.md`의 확인 절차를 따름"입니다. 예약도 실행 전에 `last_checked`를 보고 오늘 했으면 건너뜁니다. 예약은 세션이 끝나면 사라지므로 1번이 기본입니다.
3. `active`가 `false`면 아무것도 하지 않고, 남은 예약이 있으면 지웁니다.

## 확인 절차
읽기만 합니다. Play Console 설정을 바꾸거나 무엇을 제출하지 않습니다.

1. Claude in Chrome에서 `config.json`의 `browser_device_id` 브라우저를 `select_browser`로 고르고 새 탭을 엽니다. 연결이 안 되거나 Play Console 로그인이 풀려 있으면 다시 시도하지 않고 사용자에게 알린 뒤 끝냅니다(`last_checked`를 고치지 않음).
2. `statistics_url`을 열고 몇 초 기다린 뒤 시계열 그래프를 화면에 맞추고 `save_to_disk` 스크린샷을 찍습니다. 그래프 위에 마우스를 올려 최근 날짜의 설치한 사용자 수를 읽습니다. 처음 약 3일은 "데이터 없음"이 정상입니다(업체 공지).
3. 스크린샷을 `shots/<오늘>.png`로 복사합니다.
4. `dashboard_url`에서 비공개 테스트와 프로덕션 신청 진행 표시(테스터 수, 일수, 신청 버튼)를 읽습니다.
5. 연 탭을 닫습니다.
6. `state.json`의 `last_checked`를 오늘로, `history`에 `{date, installs_latest, installs_min_since_data, dashboard, note}`를 더합니다.
7. 사용자에게 한두 줄로 알립니다. 아래는 휴대폰 알림(PushNotification)도 보냅니다.
   * 집계가 시작된 뒤 어느 날이든 설치 수가 `min_installs`(12) 미만: "비공개 테스트 설치 수 12 미만, 업체에 알려 주세요". 업체 공지가 2~3일 주기 추적을 요청합니다.
   * 프로덕션 신청 버튼이 켜짐: 신청은 사용자가 하고, Google 설문은 업체 예시를 따릅니다.

## 끝내기
Google이 production 접근을 승인하면 `state.json`의 `active`를 `false`로 바꾸고 예약을 지웁니다. 사용자는 승인 사실을 업체에 알립니다.

## 관련
* Play 요건: https://support.google.com/googleplay/android-developer/answer/14151465
* 업체 공지 주소와 업체 이름: `config.json`
* 업체 권장: 테스트 중 앱 업데이트 1회 이상(올리면 업체에 알림). app의 다음 빌드를 비공개 테스트 트랙에도 올릴 때 지휘가 상기합니다.
