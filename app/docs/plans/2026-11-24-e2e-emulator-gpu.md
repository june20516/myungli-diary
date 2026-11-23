# CI e2e 에뮬레이터 GPU 모드 변경과 밤 실행 판단 (A155)

2026-11-24 작성. 2026-11-11부터 `app.yml` `e2e-android`가 멈추거나 실패한 문제의 조치와, 그 조치가 통했는지 밤 실행으로
판단하는 계획입니다. 실험을 더 하지 않고 밤 실행 결과로만 판단합니다(사용자 결정 2026-11-24).

## 확인한 사실

| 사실 | 근거 |
| --- | --- |
| 실패 형태: 테스트 중 에뮬레이터 프로세스가 통째로 사라지고, patrol과 adb가 기기를 기다리며 멈춤 | 실행 45120537531 이후 job 로그, `e2e-freeze.log` |
| 사라지기 직전 약 1분 동안 기기가 응답하지 않음. 이 동안 에뮬레이터 스레드는 모두 종료 처리 중(`do_exit`) | `e2e-diag/qemu-kstacks.txt`(실행 45176426286, 45176443979) |
| 원인 자리: 에뮬레이터 호스트 렌더 스레드(`RenderThread`)가 SwiftShader가 실행 중 만든 코드 안에서 SIGSEGV. 다른 렌더 스레드는 `gles_swiftshader/libGLESv2.so` 안 | gdb를 미리 붙여 받은 `e2e-diag/qemu-crash-bt.txt`(실행 45181178973) |
| CI GPU 모드였던 `swiftshader_indirect`(액션 기본값)와 시험한 `swangle_indirect`는 에뮬레이터 36.4.9부터 deprecated. 공식 소프트웨어 모드는 `software`, `lavapipe` | [에뮬레이터 하드웨어 가속 문서](https://developer.android.com/studio/run/emulator-acceleration), [릴리스 노트 36.4.9](https://developer.android.com/studio/releases/emulator) |
| 로컬(Mac, 호스트 GPU)에서는 같은 흐름이 통과 | `tool/patrol_local.sh`, 2026-11-23 |
| 37.3.10의 `-gpu software`도 GLES는 `swangle`(ANGLE 2.1.17841 위 SwiftShader Vulkan)로 골라져 같은 사라짐이 남. `-gpu lavapipe`도 GLES는 `swangle`(Vulkan만 lavapipe) | 실행 45215247009 job 로그 `gles_mode_selected`, solidDoWant/vault-sync#1085 리뷰 |
| 같은 ANGLE 빌드(2.1.17841)가 Flutter 앱 첫 화면에서 에뮬레이터 호스트를 통째로 죽인 사례가 에뮬레이터 36.1.9(빌드 13823996) 고정으로 전체 통과 | bdero/flutter_scene#314 |
| 11-11 첫 실패와 11-10 마지막 통과는 같은 에뮬레이터 37.2.13. 버전이 아니라 앱 화면 변화가 계기 | 실행 42916495762, 42945275408 |
| 재현은 확률적. 실제 흐름(사주 표 → 용어 → 열린 풀이 시트)은 14번 중 14번 재현, 다른 화면 조합은 섞여 나옴 | 진단 matrix 실행들 |

## 원인이 아니었던 것 (다시 쫓지 않음)

* `unlock.glint`(반짝임): 반짝임만 띄우면 통과하고, CI 기본(기기 애니메이션 끔)에서는 동작 줄이기로 반짝임이 아예 돌지 않는데도 재현됨.
* `SeepOnChange`: 3번 반복에서 있는 쪽 1/3, 없는 쪽 3/3 재현. 한 번씩 본 결과는 우연이었음.
* 메모리(OOM 없음), 누적(시간순 지표가 쌓이지 않음), CPU 코어 수, Vulkan 끄기, 기기 애니메이션 설정, 시스템 이미지 API 33~36, 클립·투명도·물리 모양·그림자 층.

## 조치

1차(PR #1302): 에뮬레이터 옵션을 `-gpu software`로. 병합 뒤 첫 실행에서 안 통함.

2차(브랜치 `app/e2e-emulator-pin`): 에뮬레이터를 36.1.9(빌드 13823996, 액션 입력 `emulator-build`)로 고정하고 `-gpu swangle_indirect`를 씁니다. 36.1.9에는 `software`, `lavapipe` 모드가 없습니다. E2E 테스트와 앱 코드는 그대로입니다(A155).
진단 장치는 남깁니다: patrol 30분 timeout, 에뮬레이터 사라짐 즉시 감지(`tool/e2e_ci.sh`), 시간순 지표와 얼음 때 스택
(`tool/e2e_ci_monitor.sh`), 수동 진단 matrix(`e2e_diag_matrix`, `patrol_test/diag/glint_diag_test.dart`).

## 판단 계획

**시작:** 2차 조치가 든 PR이 `staging`에 병합된 뒤 첫 밤 실행(매일 03:00 KST, `schedule`, 브랜치 `staging`)부터 셉니다.
병합 뒤 `staging` push로 도는 `e2e-android`도 같이 셉니다.

**판정:**
* **고쳐짐:** 조치 뒤 `e2e-android`가 연속 3번 성공. 조치 전에는 11-11 이후 모든 실행이 실패해, 3번 연속 성공이면 우연으로 보기 어렵습니다.
* **안 고쳐짐:** 조치 뒤 한 번이라도 "테스트 중 에뮬레이터 프로세스가 사라졌습니다" 오류로 실패.
* **판정에서 빼고 따로 처리:** 에뮬레이터가 살아 있는 채 테스트가 실패한 경우(`❌ Failed`가 있고 사라짐 오류가 없음). 테스트 자체의 문제라 원래대로 고칩니다. 연속 횟수는 이어서 셉니다.

**확인 명령:** (GitHub API 한도 때문에 세션을 열 때 한 번씩만 봅니다)

```sh
gh run list -R june20516/myungli-diary -w app.yml --branch staging --limit 6 \
  --json databaseId,event,createdAt,conclusion,headSha \
  -q '.[]|"\(.databaseId) \(.event) \(.createdAt) \(.conclusion)"'
# 실패한 실행은 e2e-android job 로그에서 사라짐 오류가 있는지 봅니다.
jid=$(gh run view <run> -R june20516/myungli-diary --json jobs -q '.jobs[]|select(.name=="e2e-android")|.databaseId')
gh api repos/june20516/myungli-diary/actions/jobs/$jid/logs | grep -cE "에뮬레이터 프로세스가 사라졌|gles_mode_selected"
# 사라짐 문구는 tool/e2e_ci.sh의 ::error 문구다. gles_mode_selected 줄로 그린 백엔드도 같이 본다.
```

**기록:** 아래 표에 실행마다 한 줄씩 적습니다.

| 날짜(KST) | 실행 | 이벤트 | 결과 | 사라짐 | 비고 |
| --- | --- | --- | --- | --- | --- |
| 11-24 01:19 | 45215247009 | push | failure | 있음 | 1차 `software`(37.3.10, gles swangle). 안 고쳐짐 → 2차 조치 |

## 판정 뒤

* **고쳐짐:**
  1. A155 행에 결과를 적습니다.
  2. app `CLAUDE.md` 현재 상태에서 이 항목을 지웁니다.
  3. #1282 ①(자동 E2E 다시 돌리기, 커버리지 보고서 갱신)을 진행합니다.
  4. 진단 장치를 남길지 정합니다. timeout과 사라짐 감지는 남기고, `patrol_test/diag/`와 gdb 감시는 걷어 낼지 사용자에게 묻습니다.
* **안 고쳐짐:** 실험을 늘리기 전에 사용자에게 보고하고 다음 중 하나를 고릅니다.
  1. 그 실행의 `e2e-diag/qemu-kstacks.txt`로, 죽은 곳이 여전히 SwiftShader인지 다른 렌더러(Mesa)인지 봅니다.
  2. `-gpu host`에 runner의 Mesa llvmpipe(Xvfb)를 써서 SwiftShader를 아예 거치지 않게 합니다(사례 확인 못 함, 동작부터 실험 필요).
  3. CI E2E를 GitHub 기본 runner 밖으로 옮깁니다(Firebase Test Lab 실기기, self-hosted Mac, GPU runner). 비용이나 운영 부담이 있어 사용자 결정이 필요합니다.
