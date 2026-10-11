---
from: writing
to: server
kind: request
status: done
created: 2026-10-11
related: [W5, W9, W0 spec §4.2, §7, 호칭·조사 처리 규칙 v1]
---

# 호칭·조사 규칙 v1 사용법과 원고 → 시드 변환 안내

## 무엇이 필요한가
server 콘텐츠 모듈이 아래를 따라 주세요.

1. **계약 문서:** `docs/identity/writing/guide/honorific-josa.md` v1을 따릅니다. 내용은 아래와 같습니다.
   * 문자열은 NFC로 정규화합니다.
   * 렌더 순서
   * 병기형 조사 표기
   * 영문 판정의 한계
2. **테스트 자료:** `docs/identity/writing/rules/josa.yaml`의 `examples`(표기된 원고 → 렌더 결과)와 `name_rules.examples`(호칭 입력 → 저장값·코드)를 Go 테스트가 그대로 읽어 씁니다. 호칭에는 `{ } [ ] ( )`를 받지 않습니다(`name.invalid_char`). 매개변수 값은 슬롯 명세 `params`의 값 종류대로 렌더합니다(`honorific-josa.md` "값 종류별 렌더"). 판정이 다르면 기준 구현(`tools/src/mlw/josa.py`, `placeholders.py`)과 `examples`를 따릅니다.
3. **원고 → 시드 변환 전 검사:** 시드 CI에서 변환 전에 아래 명령을 저장소 루트에서 실행합니다. 종료 코드가 0이 아니면 변환하지 않습니다.
   ```
   uv run --project docs/identity/writing/tools mlw check <원고 경로>
   ```
   원고는 `content/<lang>/*.yaml`입니다.
4. **용어 토큰:** 원고의 `[[...]]`는 응답에서 토큰 표시 형식으로 바꿔 보냅니다. 표시 형식은 app·design과 정합니다.
5. **순환 상태는 server가 관리합니다(W0 spec §4.2).**
   * 문장 유형 순환: 사용자별·키별로 `advice → state → care`. 총운 슬롯에만 적용합니다. 새 사용자의 첫 출현은 `advice`부터입니다(spec §4.2).
   * 가이드 변주 순환: 변주 1 → 2.
   * 돌봄 상한: 같은 사용자에게 돌봄(`care`) 유형 문장이 하루 2개, 연속 7일 7개를 넘지 않게 순환을 운용합니다(W14). 유형은 원고가 아니라 순환이 정하므로 검사기(`mlw check`)는 이 상한을 보지 않습니다.

## 왜
호칭("님", 「さん」)과 조사는 렌더 시점에 정해지므로 server 몫입니다(W5). 규칙을 한 곳(`josa.yaml`)에 두어야 검사기와 server 렌더러가 같은 결과를 냅니다.

## 영향
* **server:** 조사 렌더러 구현과 시드 CI 단계 추가. 둘 다 server 소유이며 writing은 구현하지 않습니다.
* 순환 규칙의 적용 슬롯은 D40 범위 확인(`2026-10-10-writing-to-root-d40-scope`) 결과에 따라 넓어질 수 있습니다.
* 계약 등록은 `2026-10-11-writing-to-root-contracts`로 요청했습니다.

## 처리 기록
- 2026-10-11 (writing): open
- 2026-10-11 (writing): done — 요청함이 GitHub Issues로 옮겨져(D44) Issue #55로 다시 열었습니다(D57·D59 반영). 이후 처리는 Issue에서 합니다
