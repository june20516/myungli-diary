# 운영 명령 runbook (S170, #1321, D145)

사용자 지원, 장애, 정책 위반, 법령 요청에 대응할 때 prod DB에 SQL로 직접 붙지 않고 `server ops` 명령으로만 데이터를 보고 고칩니다. 모든 명령은 감사 기록(`ops_audit`)을 남깁니다. 설계는 [`server/docs/specs/2026-11-26-ops-commands-design.md`](../specs/2026-11-26-ops-commands-design.md)입니다.

이 문서에는 목적별로 언제 열어도 되는지(운영 기준)를 적지 않습니다(D145 ⑤⑥, 비공개 내부 관리계획).

## 1. 준비

명령은 운영자 컴퓨터에서 저장소의 배포된 커밋으로 실행합니다. 결과는 stdout으로만 나가고 Cloud Logging에 남지 않습니다.

1. 운영자 본인의 Google 계정으로 로그인합니다.

   ```sh
   gcloud auth login
   gcloud auth application-default login
   ```

2. 연결 값 파일 `ops.env`를 만듭니다. 위치는 `$MYUNGLI_LOCAL_DIR/server/<환경>/ops.env`(`docs/local-values.md` K20)입니다. 운영자 메일이 DB 사용자 이름이라 저장소에 두지 않습니다. 비밀번호는 없습니다.

   ```sh
   APP_ENV=prod
   CLOUD_SQL_INSTANCE=myungli-diary:asia-northeast3:myungli-pg
   DATABASE_URL="user=operator@example.com dbname=myungli sslmode=disable"
   ```

   * `APP_ENV`: `staging` 또는 `prod`.
   * `CLOUD_SQL_INSTANCE`: `<프로젝트>:<리전>:<인스턴스>`. 프로젝트는 `server/deploy/terraform/env/<환경>.tfvars`의 `project_id`, 리전은 `variables.tf`의 `region`(기본 `asia-northeast3`), 인스턴스 이름은 `sql.tf`의 `myungli-pg`입니다. 환경의 Terraform 출력이나 콘솔에서 연결 이름을 복사해도 됩니다.
   * `DATABASE_URL`의 `user=`는 운영자 본인의 Google 메일이고, `dbname`은 `myungli`입니다.

3. `server/` 디렉터리에서 값을 읽어 들이고 실행합니다.

   ```sh
   cd server
   set -a; source "${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/server/prod/ops.env"; set +a
   go run ./cmd/server ops account show --account 00000000-0000-0000-0000-000000000000 --reason "문의 확인"
   ```

## 2. 운영자 등록과 빼기

운영자 메일은 개인정보라 공개 저장소의 tfvars나 CI에 두지 않습니다. 프로젝트 관리자가 환경마다 아래를 합니다.

1. Cloud SQL IAM 사용자를 추가합니다.

   ```sh
   gcloud sql users create operator@example.com --instance=myungli-pg --type=cloud_iam_user --project <프로젝트>
   ```

2. 운영자가 프로젝트 소유자가 아니면 IAM 역할 두 개를 줍니다. 연결(connector)에 `roles/cloudsql.client`, IAM 로그인에 `roles/cloudsql.instanceUser`가 필요합니다.

   ```sh
   gcloud projects add-iam-policy-binding <프로젝트> --member=user:operator@example.com --role=roles/cloudsql.client
   gcloud projects add-iam-policy-binding <프로젝트> --member=user:operator@example.com --role=roles/cloudsql.instanceUser
   ```

3. `migrate up`이 사람 IAM 사용자를 `myungli_ops` 구성원으로 넣도록 `server-migrate` Job을 한 번 실행합니다. 배포마다 돌기도 하므로 다음 배포를 기다려도 됩니다.

   ```sh
   gcloud run jobs execute server-migrate --region asia-northeast3 --project <프로젝트> --wait
   ```

   사람 IAM 사용자의 판별 규칙: 로그인할 수 있고, 이름에 `@`가 있고, `.iam`으로 끝나지 않는 역할입니다(서비스 계정 사용자는 `<이름>@<프로젝트>.iam`). 런타임과 migrator 서비스 계정은 들어가지 않습니다. 이 규칙에 걸리는 역할은 모두 운영자가 되므로 인스턴스에 아래 둘을 하지 않습니다.

   * IAM 그룹 인증(`--type=cloud_iam_group`)을 붙이지 않습니다. 그룹 구성원이 로그인하면 메일 이름의 역할이 생겨 운영자로 들어갑니다.
   * 이름에 `@`가 있는 BUILT_IN 사용자(비밀번호 사용자)를 만들지 않습니다.

4. 확인: 위 준비로 `ops audit list --since <오늘 날짜> --reason "등록 확인"`을 실행해 오류 없이 표가 나오면 됩니다. 이 확인 조회도 감사 행을 하나 남깁니다. `DB 사용자 ...에 운영자 역할이 없습니다`가 나오면 3번이 아직입니다.

**프로젝트 소유자가 아닌 운영자를 등록하기 전 조건:** `myungli_ops` 구성원은 `diaries`, `schedules`, `profiles`를 `psql` 같은 직접 SQL로 읽을 수 있고, 이 열람은 감사 행을 남기지 않습니다. 소유자가 아닌 사람을 등록하기 전에 콘텐츠 열람을 `SECURITY DEFINER` 함수로 옮기고 `myungli_ops`에는 그 함수의 EXECUTE만 주는 작업을 먼저 합니다(S170 ⑪).

**운영자 빼기:** DB 사용자를 지우면 역할 구성원도 함께 사라집니다. 필요하면 IAM 역할 두 개도 거둡니다.

```sh
gcloud sql users delete operator@example.com --instance=myungli-pg --project <프로젝트>
```

## 3. 명령

모든 명령에 `--reason "<사유>"`가 필수입니다. 앞뒤 공백을 뗀 뒤 1~500자이고, 줄바꿈(`\n`, `\r`, U+0085, U+2028, U+2029), NUL, 잘못된 UTF-8은 안 됩니다. 사유가 없거나 인자가 틀리면 종료 코드 2로 끝나고 데이터를 바꾸거나 보이지 않습니다. `--json`은 기계가 읽는 출력입니다. 아래는 `go run ./cmd/server`를 `server`로 줄여 씁니다.

### 계정 조회

문의 메일의 계정 id, 또는 스토어 영수증 번호로 찾습니다. 둘 중 하나만 줍니다.

```sh
server ops account show --account 00000000-0000-0000-0000-000000000000 --reason "문의 확인"
server ops account show --store-transaction <스토어 거래 id> --reason "영수증 번호로 문의"
```

보이는 것: 계정(상태 `active`/`deleted`, 가입, 삭제 시각, 최근 활동), 로그인 수단(제공자 종류와 연결 시각), 기기(플랫폼, 활성, 마지막 접속), 권한, 구매 장부. 제공자 subject, 토큰, 알림 token, 호칭, 출생 정보, 본문은 보이지 않습니다. 같은 스토어 거래 id가 여러 계정에 있으면 후보 계정 id를 알려 주고 끝납니다. `--account`로 다시 조회합니다.

### 권한 부여

```sh
server ops grant --account 00000000-0000-0000-0000-000000000000 --entitlement ad_free --days 30 --reason "결제 반영 누락 보상"
server ops grant --account 00000000-0000-0000-0000-000000000000 --entitlement insight --until 2026-12-31T00:00:00Z --reason "오류 보상"
```

* `--entitlement`: `ad_free`(광고 제거와 근거 열람 두 행) 또는 `insight`(근거 열람 한 행).
* 기간은 `--days <1~366>` 또는 `--until <RFC 3339>` 중 하나입니다. 만료는 지금보다 뒤이고 지금부터 366일 이내여야 합니다. "지금"과 `--days`의 기준, 부여 시작 시각은 운영자 컴퓨터 시계가 아니라 DB 시각입니다.
* 지운 계정에는 주지 않습니다.

### 권한 회수

```sh
server ops revoke --account 00000000-0000-0000-0000-000000000000 --grant 123 --reason "잘못 부여"
```

`--grant`는 `account show`에 나온 부여 행 id입니다. 거둘 수 있는 출처는 `operator`, `rewarded_ad`뿐이며, `ad_free` 묶음으로 준 두 행은 한 번에 거둡니다. 구매에서 생긴 구간(`ad_free_pass`)은 거절합니다. 환불은 스토어에서 처리하면 webhook과 동기화가 장부를 고칩니다. 이미 취소됐거나 만료된 행은 바꾸지 않고 알립니다.

### 콘텐츠 열람

`--purpose`는 정확히 `inquiry`, `incident`, `policy`, `legal` 중 하나입니다. 대상은 좁혀서만 엽니다. 본문은 실행한 사람의 터미널(stdout)로만 갑니다.

```sh
server ops content diary --account 00000000-0000-0000-0000-000000000000 --date 2026-11-01 --purpose inquiry --reason "오류 문의 확인"
server ops content diary --account 00000000-0000-0000-0000-000000000000 --id 00000000-0000-0000-0000-000000000001 --purpose inquiry --reason "오류 문의 확인"
server ops content schedule --account 00000000-0000-0000-0000-000000000000 --date 2026-11-01 --purpose inquiry --reason "오류 문의 확인"
server ops content profile --account 00000000-0000-0000-0000-000000000000 --purpose inquiry --reason "계산 오류 문의 확인"
```

`diary`와 `schedule`은 `--date YYYY-MM-DD` 또는 `--id <uuid>` 중 하나입니다. 계정 전체를 내보내거나 날짜 범위를 주는 인자는 없습니다. 화면에 나온 본문은 터미널 기록, 클립보드 등 다른 곳에 남기지 않습니다.

### 감사 기록 보기

```sh
server ops audit list --account 00000000-0000-0000-0000-000000000000 --reason "처리 이력 확인"
server ops audit list --since 2026-11-01 --limit 200 --reason "기간 점검"
```

`--account`와 `--since`(UTC 날짜) 중 하나 이상이 필요하고, 둘 다 주면 AND입니다. `--limit`은 1~1000(기본 100)입니다. 이 조회도 감사 기록에 남습니다. 표의 "대상" 칸은 `target` JSON 그대로이고, 부여와 회수의 전후 값(`before`, `after`)은 `--json`으로 봅니다.

## 4. 종료 코드

| 코드 | 뜻 |
| --- | --- |
| 0 | 성공 |
| 1 | 실행 오류: 계정 없음, 프로필 없음, 모호한 거래 조회, DB 연결 실패, 운영자 역할 없음, 회수 거절 등. 오류 한 줄이 stderr로 나갑니다 |
| 2 | 사용법 오류: 사유 없음, 목적 값 틀림, 대상 둘 다 또는 하나도 없음, 기간 범위 밖. 데이터를 바꾸거나 보이지 않고 감사 행도 남기지 않습니다 |

## 5. 감사 기록

* 표 `ops_audit`에 언제(`at`, DB 시각), 누가(`actor`, DB가 인증한 `session_user`), 어떤 경로로(`channel` `cli`), 무엇을(`action` `account_show`, `grant`, `revoke`, `content_view`, `audit_list`와 `target`), 왜(`reason`, 열람은 `purpose`) 했는지, 부여와 회수는 전후 값(`before`, `after`)이 남습니다.
* 열람 기록에는 본문이 아니라 계정 id와 연 항목 id, 개수만 남습니다.
* 조회와 열람도 기록합니다. 기록에 실패하면 결과가 보이지 않습니다. 권한 부여와 회수가 거절되면 감사 행은 남지 않습니다.
* `at`과 `cli` 경로의 `actor`는 trigger가 DB `now()`와 `session_user`로 정하므로 명령 인자나 컴퓨터 시계로 바꿀 수 없습니다.
* 행은 고칠 수 없고, 2년이 지난 행만 지울 수 있습니다(trigger). `job retention`이 2년 지난 감사 행과 끝난 지 2년 지난 운영자 부여 행을 지웁니다.
* 보려면 위 "감사 기록 보기"를 씁니다.

## 6. 범위 밖

요청 로그는 계정 id를 남기지 않고 앱 버전은 저장하지 않으므로, 계정별 접속 기록은 `last_active_at`과 기기의 `last_seen_at`까지만 보입니다.
