# W1-3 용어·근거 원고 계획

**Goal:** spec `specs/2026-10-16-w1-content-design.md` §2·§5.3의 W1-3 묶음(용어 뜻, glossary 값 이름, 근거 basis, 원전 source)을 3개 언어로 채우고 `mlw check`에서 `--partial`을 뺍니다.

**범위(2026-10-28 `mlw check` 기준 빈 원고):**

| 묶음 | 슬롯 | ko | en | ja |
| --- | --- | --- | --- | --- |
| W1-3a | `term.meaning` | 62 | 62 | 62 |
| W1-3a | `glossary.value_name` (천간 10, 십성 10, 십성 묶음 5, 신살 6, 합충형 4) | 35 | 35 | 3 (W24로 비워 둔 閑神·極身弱·極身強) |
| W1-3b | `evidence.basis` | 24 | 24 | 24 |
| W1-3b | `evidence.source` | 124 | 124 | 124 |

**나누는 이유:** ko 245건을 한 라운드에 담으면 문항이 너무 많습니다. 묶음마다 spec §6.1 흐름(ko 초안 → `mlw judge` → 라운드 → en·ja)을 한 번씩 돌리고, PR은 W1-3b 끝에 `--partial`을 빼면서 하나로 냅니다.

## W1-3a 용어 뜻과 값 이름
- [ ] ko 초안: 용어 뜻은 뜻을 먼저, 사람이나 하루에서 드러나는 모습을 다음에 씁니다. 천간은 일간 비유(R10-1), 신살은 W1-1 태그 뜻(`term.tag.*`), 역할은 R10-8 이름과 맞춥니다. 원리 설명과 괄호 풀이는 쓰지 않습니다.
- [ ] `mlw check --partial` error 0
- [ ] `mlw judge --lang ko --slot term.meaning` (호출 수와 토큰을 먼저 알림)
- [ ] 라운드 R23: 천간 이름 표기(한 글자 또는 오행 붙임), 합충형 이름, 용어 뜻 표본, judge 의심 문장
- [ ] en·ja: 굳은 ko를 subagent에 맡기고 `mlw check`, `mlw judge --lang en/ja`로 확인

## W1-3b 근거 문장과 원전
- [ ] spec §4대로 basis 매개변수 종류를 바꿉니다(enum은 glossary 범주, 한자는 `text`, 정수는 `number`, 나머지 `none`).
- [ ] basis 24개 ko, source 124개 ko(`원전 「대목」` + core `quote` 글자 그대로 + 뜻 한 문장, core `note`를 따름, 조후 120칸은 같은 틀)
- [ ] `mlw judge`, 라운드 R24, en·ja
- [ ] glossary ja 빈 3개를 빠짐 허용으로 둘 방식을 W 결정으로 정합니다(spec §5.3).
- [ ] `writing.yml`의 `--partial` 삭제, 스토어 태그라인 확정(R8-6에서 출발)

## 확인할 요청
- spec §8 server: enum 대문자 `detail` 값을 glossary 키로 바꿔 렌더하는지(W1-3b 전)
- core #258: 원전 `quote` 번체 원문 여부(기다리지 않고 core 글자 그대로 씀)
