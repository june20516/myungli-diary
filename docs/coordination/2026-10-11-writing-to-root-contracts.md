---
from: writing
to: root
kind: request
status: open
created: 2026-10-11
related: [W0 spec §9, W9, 계약 목록, core/message_keys.json, D40]
---

# 제공 계약 3개 등록과 메시지 키별 매개변수 목록 요청

## 무엇이 필요한가
1. **제공 계약 3개를 `docs/contracts/README.md`에 등록해 주세요.**

   | 계약 | 원본 위치 | 버전 | 사용 |
   | --- | --- | --- | --- |
   | 슬롯 명세 | `docs/identity/writing/slots/` (`_schema.yaml`, `content/`, `ui/`) | v1 | server, app |
   | 라이팅 검사기 | `docs/identity/writing/tools/` (`mlw` CLI, 패키지 `myungli-writing`) | v0.1.0 | server 시드 CI, app CI |
   | 호칭·조사 처리 규칙 | `docs/identity/writing/guide/honorific-josa.md`, `rules/josa.yaml` | v1 | server 콘텐츠 모듈 |

   * 슬롯 명세 계약에는 **원고 표기**가 포함됩니다.
     * 자리표시자 `{param}`
     * `{param:category}`: glossary 범주로 값 이름을 렌더합니다(예: `{element:color}`는 오행을 색 이름으로).
     * 조사 표기 6쌍
     * 용어 토큰 `[[...]]` (W9)
   * 렌더 순서는 `guide/honorific-josa.md` v1이 정합니다.
   * 검사기 실행: 저장소 루트에서 `uv run --project docs/identity/writing/tools mlw <명령>`.
2. **`core/message_keys.json`에 키별 매개변수 목록이 없습니다.** core가 키별 매개변수를 함께 내보내는 방안을 지휘 세션이 판단해 주세요.
3. **app 쪽 ARB 메시지 이름 규약을 확인해 주세요.** writing은 `slots/ui/*.yaml`의 메시지 이름을 lowerCamelCase Dart 식별자로 가정했습니다. app 착수 시 맞는지 확인이 필요합니다.
4. **D40 범위 확인이 아직 열려 있습니다.** `2026-10-10-writing-to-root-d40-scope`를 다시 알려 드립니다.

## 왜
* 계약 파일이 생겼습니다(W0 spec §9). server·app이 읽고 쓰려면 목록에 있어야 합니다.
* 슬롯 YAML의 키별 매개변수는 엔진 코드에서 옮겨 적었습니다. 계약에 목록이 없어서, 엔진 코드와 plan 표가 달랐던 사례가 실제로 2건 있었습니다.
  * `calendar.*`: 매개변수는 `score`입니다.
  * `yongsin.method.*`: 매개변수는 `yongsin, huisin, gisin, tonggwan`입니다.
* 매개변수가 바뀌어도 writing이 알 방법은 엔진 코드를 다시 읽는 것뿐입니다.

## 영향
* **core:** 승낙하면 `message_keys.json`의 형식이 바뀝니다(키마다 매개변수 목록 추가). 기존 소비자가 있으면 하위 호환을 확인해야 합니다.
* **writing:** 매개변수 목록이 계약에 생기면 슬롯 YAML의 `params`를 계약과 대조하는 검사를 추가합니다.
* **server, app:** 계약 등록으로 의존 관계가 문서에 남습니다. 하위 호환이 깨지는 변경은 없습니다.

## 처리 기록
- 2026-10-11 (writing): open
