# T1 전 보안 점검(Q1) — 준비 메모

* 작성: 지휘 세션, 2026-10-30
* 상태: 초안(준비 메모). 착수 때 사용자와 범위와 방식을 확정하고 승인받습니다
* 착수 시점: 로드맵 Q1 행(검수 피드백 회차와 H1 기준 문서 정리가 끝난 뒤, T1 전)

## 1. 목적

T1부터는 테스터의 실제 계정, 생년월일, 일기 본문이 staging에 쌓입니다. 그 전에 인프라, 배포 경로, server, 엔진, app, 로컬 값 전반을 한 번에 점검합니다. 막아야 할 것을 T1 전에 막고, 나머지는 출시(I4) 전 일로 정리합니다.

## 2. 공개 저장소에서 다루는 법(D74)

* 이 저장소는 공개입니다. **발견 사항의 상세(재현 방법, 취약 지점)는 공개 저장소에 적지 않습니다.**
* 발견 대장은 비공개 내부 저장소 `security/`에 둡니다. 공개 쪽 Issue에는 "비공개 기록 `security/<파일>` #<n>"과 고칠 방향만 적습니다.
* 고친 PR이 병합된 뒤에도 상세는 비공개 쪽에만 남깁니다.

## 3. 점검 범위(착수 때 확정)

| 영역 | 점검 항목 |
| --- | --- |
| GCP IAM | 서비스 계정마다 역할 최소화, 사람 계정의 소유자 권한, 서비스 계정 키 0개, 키 생성 금지 정책(관리형 `iam.managed.disableServiceAccountKeyCreation`이 조직에서 Enforced인지, 2026-10-30 미확인) |
| 배포 경로 | WIF 조건(저장소, environment 하나, PR #671), prod environment 승인자, Actions `permissions` 최소화, 외부 action을 SHA로 고정, `pull_request_target` 사용 여부 |
| GitHub 저장소 | 브랜치 보호, 공개 이력 전체의 비밀 스캔(gitleaks 등), Dependabot과 secret scanning 설정 |
| 네트워크와 데이터 | Cloud Run ingress와 인증(엔진은 내부 전용), Cloud SQL 공개 IP와 TLS, bucket 공개 여부(tfstate 포함), 감사 로그, 예산 알림 |
| 비밀 값 | Secret Manager 접근 주체, Terraform 관리 범위, 로컬 값 대장(D98, `docs/local-values.md`)과 실물 대조, 미룬 교체(staging App Check debug token) |
| server 인증 | JWT 서명, 만료, 폐기, 소셜 id_token 검증(aud, iss, nonce, azp), Apple 웹 복귀, staging 테스트 로그인이 prod에서 꺼지는지, App Check 검증 |
| server 인가와 입력 | 다른 사용자 자원 접근(IDOR), 입력 검증, rate limit, 로그의 개인 정보, 토큰 암호화(`TOKEN_ENCRYPTION_KEY`), 계정 삭제가 남기는 것 |
| 외부 콜백 | RevenueCat webhook 인증과 sandbox 분리(D99), AdMob SSV 서명 검증 |
| 엔진(core) | 외부에서 닿지 않는지, 입력 범위 |
| app | 저장소와 빌드 산출물에 비밀 없음, 토큰 저장 위치, release에서 debug provider와 Test Store 키가 쓰일 수 없는지, App Link 검증, 로그, TLS |
| 의존성 | Go(`govulncheck`), Dart와 Flutter 패키지, Python 도구, 컨테이너 기반 이미지 |
| 개인 정보 | `docs/legal/data-inventory.md`와 실제 수집, 보관, 삭제 대조 |

## 4. 방식(착수 때 확정)

1. **단위별 자기 점검:** 각 단위에 `kind:request`로 위 표 중 자기 몫을 보냅니다. 결과는 비공개 대장으로 모읍니다.
2. **독립 점검:** 단위 세션의 결론을 넘겨주지 않은 새 리뷰어가 코드와 설정을 직접 봅니다(보안 감사 agent, 사용자가 실행하는 `/code-review ultra` 등). 인프라는 콘솔과 `gcloud` 출력으로 확인합니다.
3. **심각도:** Critical, High, Medium, Low. 판정은 "T1 테스터 데이터에 실제로 닿는가"를 기준으로 합니다.
4. **조치:** 고치는 Issue는 공개 저장소에 상세 없이 올리고, 고친 뒤 독립 점검자가 다시 확인합니다.

## 5. 끝난 조건(T1 관문)

* Critical과 High가 0입니다(고침, 또는 사용자가 위험을 받아들인다는 결정 행).
* Medium 이하는 I4 전 일로 대장에 남습니다.
* 결과 요약(건수와 상태만)을 로드맵 Q1 행에 적습니다.
