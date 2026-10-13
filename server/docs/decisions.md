# server 결정 로그

server 안에서 정한 사항을 모읍니다. 제품 결정(D#)과 부딪히면 구현을 멈추고 요청함으로 올립니다. 상세 근거는 "문서" 열을 따릅니다.

| # | 날짜 | 영역 | 결정 | 근거 / 문서 |
| --- | --- | --- | --- | --- |
| S1 | 2026-10-11 | 실행 구조 | Go 바이너리 하나를 하위 명령으로 실행합니다. `serve`는 Cloud Run service, 배치(`precompute`·`notify`·`retention`)와 `migrate`·`seed`는 Cloud Run Jobs이며 Cloud Scheduler가 실행합니다. Scheduler가 service 엔드포인트를 부르는 방식은 쓰지 않습니다 | 사용자 결정 (업계 표준 우선), spec §2 |
| S2 | 2026-10-11 | API | REST API v1은 OpenAPI 3.1 contract-first(`server/api/openapi.yaml`, oapi-codegen)입니다. `/v1` 경로, camelCase, RFC 3339, cursor 목록, `Idempotency-Key` | spec §5 |
| S3 | 2026-10-11 | 기술 | `net/http`, PostgreSQL + `pgx`·`sqlc`·`goose`, UUIDv7, `grpc-go`(buf managed mode), `slog`·OpenTelemetry, expand/contract migration | spec §2.3·§13 |
| S4 | 2026-10-11 | 캐시 | 엔진 결과 캐시는 PostgreSQL 테이블에 두고 `ResultCache` 인터페이스 뒤에 숨깁니다. Redis(Memorystore)는 spec §7.3의 기준을 넘을 때 도입합니다 | 사용자 결정, spec §7.3 |
| S5 | 2026-10-11 | 데이터 | null은 "값 없음"만 뜻합니다. "모름"·"건너뜀"·"묻지 않음" 같은 사용자 선택은 상태 열로 명시하고 CHECK 제약으로 값 열과 짝을 맞춥니다. API도 상태 필드로 보냅니다 | 사용자 결정, spec §3.2 |
| S6 | 2026-10-11 | 데이터 | 사용자가 지우는 일기·일정은 soft delete(`deleted_at`)합니다. 30일 동안 복구할 수 있고, 그 뒤 내용만 비우고 행은 남깁니다. FK는 `ON DELETE RESTRICT` | 사용자 결정, spec §3.1·§8.3 |
| S7 | 2026-10-11 | 계정 | 계정 삭제는 30일 유예 뒤 행을 지우지 않고 익명화합니다. 민감 정보는 더미 값으로 바꾸거나 비우고, 제공자 연결을 끊어 로그인을 막습니다. Apple revoke·카카오 unlink는 삭제 요청 시점에 합니다 | 사용자 결정, spec §4.4·§9 |
| S8 | 2026-10-11 | 인증 | 카카오·Apple 모두 OIDC `id_token`을 JWKS로 검증합니다. access token은 ES256 JWT 15분, refresh token은 30일·쓸 때마다 교체·재사용 감지 시 family 폐기(첫 사용 뒤 30초 안이고 다음 token이 미사용이면 응답 유실 재시도로 보고 새 token 발급, S20). 이메일로 계정을 자동 연결하지 않습니다 | spec §4 |
| S9 | 2026-10-11 | 콘텐츠 | 렌더된 문장은 위치 숫자 대신 조각 배열(`segments`, 용어 조각에 `term`)로 보냅니다. 데일리는 세 깊이를 한 응답에 담습니다 | spec §6.4 (표시 방식은 app·design과 확정) |
| S10 | 2026-10-11 | 오류 | RFC 9457 problem+json에 기계용 `code`와 `traceId`를 붙입니다. 사용자 문구는 app이 `code`로 만듭니다. 엔진 `UNAVAILABLE`→503, deadline→504, `INTERNAL`→502 | spec §11 |
| S11 | 2026-10-11 | 결제 | RevenueCat webhook은 신호로만 쓰고, 받을 때마다 RevenueCat REST로 구매 내역을 다시 조회해 entitlement를 맞춥니다. 복원도 같은 함수입니다 | spec §10 |
| S12 | 2026-10-11 | 배포 | staging·prod 두 GCP 프로젝트. main 병합 → staging 자동, prod는 GitHub environment 승인. 콘텐츠 시드는 원고를 변환한 파일을 `server/`에 commit해 이미지에 포함합니다 | spec §6.1·§13 |
| S13 | 2026-10-11 | 알림 | 알림 시각은 5분 단위입니다. `job notify`가 5분마다 최근 60분 안의 미발송 대상에게 FCM HTTP v1로 보내고, `notification_log`로 하루 한 번을 지킵니다. 알림 문장은 개인화하되 호칭을 쓰지 않습니다. 큐(Cloud Tasks)는 spec §8.2 기준을 넘을 때 도입합니다 | 사용자 결정 (호칭 없음), spec §8.2 |
| S14 | 2026-10-11 | 권한 | 근거 열람 권한(D60)은 `entitlement_grants`에 부여 건마다 한 행으로 출처(`ad_free_pass`·`rewarded_ad`·`subscription`)와 함께 기록합니다. AdMob SSV는 server가 직접 받아 ECDSA 검증·`transaction_id` 멱등 처리 후 계정 현재 시간대의 다음 자정까지 부여합니다. 권한이 없으면 잠긴 내용을 빼고, 응답마다 `evidenceAccess`(`unlocked`·`locked`)로 잠김을 명시합니다(S5 원칙) | D60, spec §6.4·§10.1 |
| S15 | 2026-10-13 | 인증 | 로그인 nonce는 카카오·Apple이 같습니다. app은 제공자에게 SHA-256(원문)의 hex를 보내고 server에는 원문을 보냅니다. server는 원문을 해시해 `id_token`의 nonce와 대조합니다 | P2 계획 Task 1 |
| S16 | 2026-10-13 | 계정 | 삭제 대기(`pending_deletion`) 계정이 가진 access token으로는 `getMe`·`deleteMe`·`logout`만 됩니다. refresh는 거부하고, 같은 제공자로 다시 로그인해야 계정이 돌아옵니다. 복구 로그인은 같은 트랜잭션에서 그 계정의 이전 세션(refresh token)을 모두 폐기하고 새 세션만 발급합니다. 제공자 연결 해제는 외부 호출 직전에 계정이 아직 삭제 대기인지 확인합니다 | P2 계획 Task 8·10, 최종 review |
| S17 | 2026-10-13 | 데이터 접근 | sqlc 생성 패키지를 도메인마다 둡니다(`internal/<domain>/<domain>db`). 업무 시각은 `Clock`에서 받아 쿼리에 넘기고 SQL의 `now()`를 쓰지 않습니다 | P2 계획 |
| S18 | 2026-10-13 | 약관 | 동의 문서 버전은 `account.CurrentDocuments` 코드 상수입니다. 버전을 올리면 모든 계정이 다시 동의합니다. 현재 버전이 아닌 버전으로 동의하면 422 `consent.version_mismatch`입니다 | P2 계획 |
| S19 | 2026-10-13 | 인증 | Apple 로그인 트랜잭션이 실패하면 교환한 Apple refresh token은 저장하지 않고 revoke도 하지 않은 채 버립니다. Apple revoke는 사용자의 앱 승인 전체를 끊어, 이미 저장된(또는 동시 로그인이 먼저 commit한) 연결까지 무효로 만들기 때문입니다. code 교환 응답의 `id_token` sub가 로그인 `id_token`의 sub와 다르면 로그인을 거절합니다 | P2 계획 Task 8, 최종 review |
| S20 | 2026-10-13 | 인증 | 이미 쓴 refresh token이 첫 사용 뒤 30초 안(경계 포함)에 다시 오고 그 다음 token이 아직 미사용·미폐기이면, 탈취가 아니라 응답 유실 재시도로 봅니다. 다음 token을 폐기하고 같은 family로 새 token을 발급하며, 첫 사용 시각은 바꾸지 않아 유예 창이 늘어나지 않습니다. 근거: server가 갱신을 commit한 뒤 응답이 유실되면(지하철, 와이파이·LTE 전환) 앱이 예전 token으로 재시도할 수밖에 없어 로그아웃되는 것을 막습니다(Auth0 reuse interval·Okta grace period와 같은 방식). 보안 비용: 첫 사용 뒤 30초 안의 탈취 token 사용은 감지하지 못합니다 | 사용자 결정 |
