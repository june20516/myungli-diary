---
from: design
to: root
kind: report
status: done
created: 2026-10-10
related: [V0, 브랜드 기반(docs/identity/README.md), docs/background/06-design-system.md, docs/workflow.md §4·§7, 2026-10-10-root-to-design-artifacts]
---

# V0 시각 정체성 완료

## 무엇을 했는가
* 브랜치 `design/visual-identity`에서 V0을 마쳤습니다. spec → plan → 실행 순서입니다.
* **기준 문서:** [`docs/identity/design/visual-identity.md`](../../identity/design/visual-identity.md). 시각(색·그라데이션·타이포·로고)에 관해서는 이 문서가 `docs/background/06-design-system.md`를 대체합니다.
* **결정:** design 결정 V1~V7 ([`decisions.md`](../../identity/design/decisions.md)). 요약:
  * 색은 OKLCH 규칙으로 만들고 화면은 의미 역할만 씁니다.
  * 브랜드 팔레트(UI)와 오행 팔레트(데이터)를 분리합니다.
  * 글자 조합은 대비 4.5:1 이상입니다.
  * 다크 모드를 MVP에 포함합니다.
  * 그라데이션은 `gradient.today` 토큰 하나로, 대표 화면 세 곳(데일리 카드·온보딩·공유 이미지)에만 씁니다.
  * 타이포는 문장 고운돋움/Zen Maru Gothic, UI는 Pretendard/Pretendard JP입니다.
  * 로고는 세이지 공책과 낙관 아이콘, 고운돋움 아웃라인 워드마크입니다.
* **산출물:** `tools/palette.py`(생성기·대비 검사기, 32/32 통과), `logo/`(앱 아이콘 큰·작은 원형, Android 적응형, 워드마크, 가로 조합), `specimen/index.html`(견본).
* **시각 산출물 요청(`2026-10-10-root-to-design-artifacts`) 반영:** `docs/identity/design/artifacts/`에 7건을 등록했습니다(chosen 5, superseded 2). 탈락한 안도 note에 남겼습니다. 요청 문서 상태는 지휘 세션의 accepted를 기다립니다.

## 지휘 세션이 알아야 할 것
1. **브랜드 기반 README "시각 방향"의 시안 값과 달라진 점:** README가 "참고용, 확정은 design"이라고 둔 값입니다.
   * 좋은 날 배지: `#f4b6ae` + 흰 글자(대비 1.73:1) → coral-600 `#a75c53` + 흰 글자(4.89:1)
   * 용어 토큰: `#e3efe6` + `#4f7f5e`, 굵게(3.92:1) → sage-100 `#e8f2e9` + sage-700 `#47634c`, 굵게 하지 않음(5.80:1)
   * README의 시안 값 표를 `visual-identity.md`로 가리키게 바꿀지 판단해 주세요.
2. **결정 번호와 마일스톤 이름이 겹칩니다.** workflow §4의 design 결정 번호 `V<n>`과 로드맵 마일스톤 V0~V2가 같은 글자를 씁니다. design 문서에서는 "결정 V1"과 마일스톤 "V1"을 구분해 적고 있습니다. 번호 체계를 바꿀지는 지휘 세션이 정해 주세요. 예를 들어 결정을 `VD<n>`으로 쓰는 방법이 있습니다.
3. **06 대체:** `docs/background/06-design-system.md`는 원문 그대로 두었습니다. 정체성 README의 문서 체계에 `visual-identity.md`를 연결해 주세요.

## 영향
* **app:** 아직 계약 변경은 없습니다. 디자인 토큰 계약은 V1에서 동결합니다. `visual-identity.md`와 `palette.py` JSON 출력이 V1 토큰의 출발점입니다. 아이콘 PNG 크기별 내보내기는 app 몫입니다.
* **writing:** 견본의 예문은 자리표시자입니다. 용어 토큰은 굵기 대신 색으로 표시합니다.
* 하위 호환이 깨지는 변경은 없습니다.

## 다음
* V1 착수 예정입니다. 토큰 형식과 Dart 코드 생성 방식을 app에 요청함으로 제안합니다. 날의 성격 배지 3종, 캘린더 길흉 점, 일본어 줄 간격도 V1에서 정합니다.
* V2는 MVP 화면 목록(IA)을 기다립니다.

## 처리 기록
- 2026-10-10 (design): done — 브랜치 `design/visual-identity`
