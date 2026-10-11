# 통합 로드맵

지휘 세션이 관리합니다. 제품 단계(Phase 1~3)는 `docs/background/05-roadmap.md`를 따르고, 이 문서는 **Phase 1(MVP) 안에서 서브 프로젝트들이 어떤 순서로 맞물리는지**를 다룹니다.

**제품 지도:** https://claude.ai/artifact/GFLHjAufPE6F4qPyssdfsC (노선도로 진행 상태를 봅니다. 지휘 세션이 정기 일과에서 갱신합니다.)

## 마일스톤

| ID | 마일스톤 | 담당 | 선행 조건 | 끝나면 열리는 것 | 상태 |
| --- | --- | --- | --- | --- | --- |
| R0 | 제품 결정·엔진 설계 | 지휘 | - | C1 | **완료** (D1~D34) |
| C1 | 엔진 기반: 시각 변환·원국·판정 규칙 (계획 Task 1~13) | core | R0 | C2 | **완료** (main 병합 완료, PR #1 `ec4fc90`) |
| C2 | **엔진 gRPC 계약 v1 freeze** (Task 14) | core | C1 | S2, I1 | **완료** (main 병합 완료, PR #1 `ec4fc90`) |
| C3 | 엔진 완성: 서버·골든 테스트·CI (Task 15~20) | core | C2 | I1 | **완료** (main 병합 완료, PR #1 `ec4fc90`, CI check·proto·slow 통과) |
| S1 | server 설계 (spec·계획) | server | R0, M0 | S2 | 시작 전 (착수 가능) |
| S2 | server 구현: 인증·프로필·일기·콘텐츠 모듈·엔진 클라이언트 | server | S1, C2 | S3, I1 | 시작 전 |
| S3 | **REST API v1 freeze** | server | S2 | A2, I2 | 시작 전 |
| A1 | app 설계 (spec·계획), 대역 데이터로 화면 구현 | app | R0, IA, M0, V2 | A2 | 시작 전 (착수 가능, UI 구현 포함. S1과 병행 가능) |
| A2 | app의 실제 API 연동 | app | A1, S3 | I2 | 시작 전 |
| B0 | 브랜드 기반 확정 (`docs/identity/README.md`) | 지휘 | 브랜드 기반 spec 승인 | W0, V0, IA | **완료** |
| IA | MVP 화면 목록: 화면, 목적, 화면마다 들어갈 문장 슬롯과 컴포넌트 (계약, D39) | 지휘 | B0 | W0 슬롯 목록, V2, A1 | **완료** (D47~D51, `docs/ia/screens.json` v1) |
| M0 | 수익화 결정 체계 수립과 첫 사이클, MVP 범위 재검증 | 지휘 | IA | S1·A1 착수 | **완료** (D53, `docs/business/`) |
| W0 | 라이팅 시스템 기반: 보이스·톤 가이드, 슬롯 명세, slop 패턴, 검수 절차, 검사기 | writing | B0 (슬롯 목록은 IA) | W1 | **완료** (PR #36 `7698f52`, 결정 W1~W15, 계약: 슬롯 명세·호칭 조사·검사기) |
| V0 | 시각 정체성 | design | B0 | V1 | **완료** (PR #10 `77b7e4f`, 결정 V1~V7) |
| V1 | **디자인 토큰 freeze** | design | V0 | V2, A1 | **완료** (PR #18 `d049e08`, 계약 1.0.0, 결정 V8~V12) |
| V2 | 컴포넌트 명세 | design | V1, IA | A1 UI 구현 | **완료** (PR #43 `47a1867`, 컴포넌트 계약 1.0.0, 토큰 1.1.0, 결정 V13~V24) |
| W1 | 콘텐츠: 메시지 키별 문장 3개 언어 초안 → 원어민 검수 (D28) | writing → server 시드 | W0, C2(`message_keys.json`) | I3 | 시작 전 (착수 가능) |
| I1 | 통합 1: server ↔ core 실제 gRPC 호출 | 지휘 판단 | C3, S2 | I3 | - |
| I2 | 통합 2: app ↔ server | 지휘 판단 | A2, S3 | I3 | - |
| I3 | 통합 3: 데일리·나의 사주·캘린더·일기 전 과정 E2E | 지휘 판단 | I1, I2, W1 | I4 | - |
| I4 | 스토어 심사·출시 (iOS / Android) | 지휘 + app | I3 | Phase 2 | - |

**병행 가능 구간:** S1 · A1은 M0 뒤에 서로 기다리지 않고 진행합니다. 동시에 진행하면 `git worktree`로 작업 디렉터리를 나눕니다(`docs/workflow.md` §6). B0 이후 W0와 V0도 서로 기다리지 않으며, core·server 흐름과도 따로 진행합니다. 정체성 쪽 순서는 B0 → (W0 ∥ V0) → IA → V1 → V2 → A1 UI 구현입니다. 수익화 사이클 M0는 IA 뒤, S1·A1 착수 전에 돌려 MVP 범위를 다시 확인합니다(D52).

## 현재 진행 순서 (2026-10-11 기준)
지휘 세션이 상태가 바뀔 때마다 고칩니다. 위 표의 선행 조건을 지금 상태에 대입한 결과입니다.

* **M0가 끝났습니다(D53).** MVP에 광고와 1개월 광고 제거권이 들어갔고, server·app 착수가 열렸습니다. 소셜 로그인(카카오·Apple, D55)과 배포 플랫폼(GCP Cloud Run + Cloud SQL, D56)도 정해져 S1 범위를 막는 것이 없습니다.
* **W0(PR #36)와 V2(PR #43)가 끝났습니다.** A1은 UI 구현까지, W1은 콘텐츠 작성까지 착수할 수 있습니다. 콘텐츠의 저장·선택·렌더는 server입니다(D59).
* **가장 긴 경로:** A1 UI 구현 → A2 → I2·I3. 콘텐츠 쪽은 W1(3개 언어 초안 → 원어민 검수) → I3.

| 순서 | 담당 | 할 일 | 막는 것 |
| --- | --- | --- | --- |
| 1 | server·app | S1·A1 착수 (IA spec §10의 범위, D53~D59 포함). app은 컴포넌트 명세 1.0.0·토큰 1.1.0(Issue #44) | S2, A2 |
| 병행 | writing | W1 착수. V2 문구 자리(Issue #42), 매개변수 대조는 core #38 뒤 | I3 |
| 여유 | design | 다음 마일스톤 없음. app의 A1 중 질문 응대 | 없음 |
| S1 구현 전 | core | 엔진 컨테이너(#34), 매개변수 파일(#38), 시진 RPC(#41). 그 밖의 후속(#4·#5·#9) | S2 배포, W1 검사 |

## 외부 준비물
| 항목 | 필요한 시점 | 담당 |
| --- | --- | --- |
| 한국천문연구원 API 키 (data.go.kr: 24절기·음양력) | core Task 18 | 사용자 |
| `buf` 설치 | core Task 14 | core 세션 |
| Apple Developer / Google Play 개발자 계정 | I4 (빌드 배포는 A1부터 필요할 수 있음) | 사용자 |
| 영어·일본어 원어민 검수 | W1 | 사용자 (writing W1) |
| ~~배포 플랫폼 선정 (서버·엔진)~~ | S1 | **결정 완료** (D56: GCP Cloud Run + Cloud SQL) |
| GCP 프로젝트 준비: 결제 계정, Artifact Registry·Cloud Run·Cloud SQL·Secret Manager API 사용 설정, GitHub Actions용 Workload Identity Federation (D56) | S1 배포 단계 | 사용자 (설정 절차는 server가 안내) |
| Kakao Developers 앱 등록, Apple Sign in with Apple 설정(Services ID, 키) (D55) | S1·A1 로그인 연동 | 사용자 |
| 사업자등록, 통신판매업 신고, 스토어 세금·정산 계좌 (D53) | 출시 전 (I4) | 사용자 |
| AdMob 계정, RevenueCat 계정 (D53) | A1 연동 시점 | 사용자 |
| AdMob 보상형 광고 단위 생성, SSV 콜백 URL 설정(server가 주소 안내) (D60) | S2·A1 연동 시점 | 사용자 |
| ~~KASI 자료(테스트 fixture 약 520KB)의 저장소 재배포 허용 범위 확인~~ | 저장소 공개 전 | **확인 완료** (2026-10-10): 공공데이터포털 음양력 정보(15012679)·특일 정보(15012690) 모두 "이용허락범위 제한 없음", 무료. 출처 표기는 core에 요청 |

## 지휘 세션 미결 (서브 프로젝트 설계 전에 정할 것)
| 항목 | 걸린 곳 | 근거 |
| --- | --- | --- |
| (없음) | | |

* 결정됨: 소셜 로그인 제공자는 D55(카카오·Apple), 서버·엔진 배포 플랫폼은 D56(GCP)입니다(2026-10-11).
* 이관 후 결정됨: "캘린더 길흉 점의 색 규칙"은 design V1에서 정했습니다. 점이 아니라 날짜 칸을 옅게 채웁니다(2026-10-11, design 결정 V10, PR #18).
