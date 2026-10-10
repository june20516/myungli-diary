# 명리일기 (Myungri Diary)

사주 명리학을 바탕으로 사람마다 다른 하루(일진 × 원국)를 추천하고, 일기로 기록·회고하는 앱입니다.

## 저장소 구조 (모노레포)
| 디렉터리 | 내용 | 기술 |
| --- | --- | --- |
| `app/` | 모바일 앱 | Flutter |
| `server/` | 메인 API 서버, 콘텐츠 모듈, 배치 | Go |
| `core/` | 명리 엔진 (gRPC 서버) | Python |
| `proto/` | Go ↔ 엔진 gRPC 계약 (`.proto`, buf) | Protocol Buffers |
| `docs/` | 배경 문서, 결정 로그, 설계 spec, 근거 자료 | - |

* 각 디렉터리는 자기 언어의 기본 도구를 그대로 씁니다. 저장소 전체를 묶는 빌드 도구는 쓰지 않습니다.
* CI와 배포는 디렉터리 경로 필터로 나눕니다.
* 각 서비스는 자기 디렉터리만으로 빌드되어야 합니다. 그래서 proto 생성 코드는 서비스마다 commit하고, 엔진이 쓰는 데이터는 `core/` 안에 둡니다.
* 릴리스 태그에는 접두어를 붙입니다. 예: `core/v1.0.0`, `app/v1.0.0`.

## 작업 방식
* 각 서브 프로젝트는 자기 디렉터리에서 별도 세션으로 설계 → 계획 → 구현 → 마무리를 진행합니다. 저장소 루트의 세션은 조율·계약·통합 로드맵을 맡습니다.
* 규약: [`docs/workflow.md`](docs/workflow.md), 세션 지시: 각 디렉터리의 `CLAUDE.md`

## 문서
* 제품 배경: [`docs/background/`](docs/background/README.md)
* 제품·아키텍처 결정: [`docs/decisions.md`](docs/decisions.md)
* 통합 로드맵: [`docs/roadmap.md`](docs/roadmap.md)
* 계약 목록: [`docs/contracts/README.md`](docs/contracts/README.md)
* 요청함: GitHub Issues (규칙 `docs/workflow.md` §5.2, 이관 전 문서 보관 [`docs/coordination/`](docs/coordination/README.md))
* 엔진 위키·spec·계획·원전 근거: [`core/docs/`](core/docs/)
