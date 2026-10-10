---
from: root
to: design
kind: request
status: open
created: 2026-10-10
related: [docs/workflow.md §7, docs/artifacts/index.json, 제품 지도]
---

# 시각 산출물을 `artifacts/`에 쌓아 주세요 (제품 지도 준비)

## 무엇이 필요한가
지휘 세션이 **제품 지도**(비공개 claude.ai 페이지)를 만듭니다. IA(화면 목록)를 뼈대로, 화면마다 시안·컴포넌트·문장·엔진 데이터·결정·진행 상태를 한곳에서 보는 화면입니다. 지도는 각 작업 단위의 `artifacts/index.json`을 읽어 그립니다. 그래서 V0부터 만드는 시각 산출물을 아래 규칙(`docs/workflow.md` §7)으로 쌓아 주세요.

1. **위치:** `docs/identity/design/artifacts/`
2. **파일 이름:** `YYYY-MM-DD-<짧은 이름>.<png|svg|webp|html|pdf>`. HTML 시안에는 같은 이름의 PNG를 함께 둡니다(GitHub에서 보이도록).
3. **목록:** `docs/identity/design/artifacts/index.json` (JSON 배열). 형식은 `docs/artifacts/index.json`의 브랜드 기반 시안 3건을 예시로 따릅니다.
   * 필드: `id`, `title`, `kind`(`concept`·`mockup`·`component`·`screenshot`·`token-sheet`·`copy-sample`), `file`, `source`(선택, HTML 등 원본), `date`, `milestone`, `screens`(IA 화면 id, IA 전에는 빈 배열), `decisions`, `status`(`draft`·`chosen`·`rejected`·`superseded`), `note`(한 줄)
4. **탈락한 시안도 지우지 말고** `status: rejected`로 남깁니다. 무엇을 왜 골랐는지가 지도와 포트폴리오 모두에 의미가 있습니다.
5. **용량:** 이미지 한 장 2MB 이하. Git LFS는 쓰지 않습니다.

참고: 브랜드 기반 시안 원본(HTML)과 PNG는 `docs/artifacts/`에 있습니다. V0에서 정식 시안을 그릴 때 출발점으로 쓰세요.

## 왜
사용자가 작업 중 제품과의 감각적 연결을 유지하고 진행을 추적할 수 있게 하려는 것입니다(지휘 세션 협업 워크플로 설계 중, 산출물 규칙만 먼저 확정).

## 영향
design 작업 방식에 산출물 기록이 추가됩니다. 계약 변경은 없습니다. 지도 화면과 브랜치 전략은 지휘 세션 spec에서 이어서 정합니다.

## 처리 기록
- 2026-10-10 (root): open
