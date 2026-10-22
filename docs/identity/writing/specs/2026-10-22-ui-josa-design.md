# ui 원고의 조사 렌더 설계

* 날짜: 2026-10-22
* 다루는 요청: 사용자 요청(writing 세션 2026-10-22, "언제까지 회피할 수는 없어"). 지휘 D 기록과 app 구현은 요청함으로 보냅니다(§9).
* 근거: 호칭·조사 처리 규칙 v1.1(`guide/honorific-josa.md`, `rules/josa.yaml`), server 판정표 `server/internal/content/render/josa.go`와 그 테스트(`josa.yaml`의 `examples`를 읽음), app `RenderedTextView`(V28, app은 조사를 붙이지 않음), app gen-l10n 설정(`app/l10n.yaml`, template `app_ko.arb`), IA 슬롯 spec §4의 `ui.markup`

## 1. 목표

1. ko ui 원고의 매개변수 뒤에 조사 표기(`(이)가` 등 6쌍)를 쓸 수 있게 합니다. 지금은 `ui.markup`이 막아서 매개변수 뒤에 조사가 오지 않는 문장 틀로만 씁니다.
2. app이 조사를 빠뜨리면 컴파일 오류가 나게 합니다. 화면에 조사 표기가 그대로 보이는 일이 없어야 합니다.
3. 조사 판정 규칙의 원본은 `rules/josa.yaml` 하나입니다. 기준 구현(Python), server(Go), app(Dart)이 같은 `examples`로 결과를 맞춥니다.

바꾸지 않는 것: 콘텐츠 슬롯의 조사 렌더(server, 렌더 순서 v1.1), en·ja 원고, ui에서 `{name}`과 용어 토큰 `[[...]]` 금지, 이미 있는 ui 키의 문구와 ARB 시그니처.

## 2. 접근 방식

ARB 생성 때 조사 표기를 ICU `select`로 펼치고, app은 값의 받침 종류만 구해 넘깁니다(접근 A, 사용자 선택).

버린 방식:
* **문자열 후처리(B):** app이 `l10n.foo(...)` 결과에서 조사 표지를 찾아 바꿉니다. 부르는 것을 빠뜨려도 컴파일되고 표지가 화면에 보입니다. 검사기로도 막기 어렵습니다.
* **server가 ui 문구를 렌더(C):** 오프라인 화면과 로그인 전 화면에서 쓸 수 없습니다.

## 3. 원고 표기 (ko ui)

* `content/ko/ui.yaml`에 콘텐츠와 같은 조사 표기를 씁니다. 예: `"{title}(이)가 내일이에요"`. 사람이 읽고 고치는 원본은 이 표기 그대로입니다.
* 조사 표기는 매개변수 바로 뒤에만 옵니다. 그 매개변수의 값 종류는 `text`나 `number`입니다.
* ICU plural 가지 안의 매개변수 뒤에도 쓸 수 있습니다. 예: `{count, plural, other{{count}(이)에요}}`.
* en·ja 원고에는 조사 표기를 쓰지 않습니다(지금 규칙 그대로).

## 4. ARB 생성 (`mlw gen-docs`, `arb_export.py`)

* ko ARB에서 `{p}` 바로 뒤의 조사 표기를 다음으로 바꿉니다. 가지 값은 `josa.yaml`의 `pairs`에서 옵니다.

  ```
  {p}{pJosa, select, final{<with_batchim>} rieul{<rieul 또는 with_batchim>} none{<without_batchim>} other{<fallback>}}
  ```

  예: `{title}(으)로` → `{title}{titleJosa, select, final{으로} rieul{로} none{로} other{(으)로}}`

* 가지 이름:

  | 가지 | 뜻 | 기준 구현 |
  | --- | --- | --- |
  | `final` | 받침 있음(ㄹ 아님) | `Batchim.OTHER` |
  | `rieul` | ㄹ 받침 | `Batchim.RIEUL` |
  | `none` | 받침 없음 | `Batchim.NONE` |
  | `other` | 판정할 수 없음(ICU 필수 기본 가지) | `None` → 병기형 `fallback` |

* 매개변수 이름은 `<원래 이름>Josa`입니다. ko ARB의 `placeholders`에 `{"type": "String"}`으로 더하고, `description`을 "app이 josaClass(<원래 이름>)로 채움"으로 둡니다.
* 한 문장에 같은 매개변수 뒤 조사가 여러 번 나와도 `pJosa`는 하나입니다.
* en·ja ARB에는 `pJosa`가 없습니다. template이 ko라서 생성 메서드 시그니처에는 들어가고, en·ja에서는 쓰이지 않습니다.
* 생성 결과는 같은 입력이면 항상 같습니다(지금 `render_arb`와 같음).

## 5. 검사기 (v0.8.0)

| 규칙 | 바뀌는 것 | 수준 |
| --- | --- | --- |
| `ui.markup` | ko 원고에서 조사 표기를 허용합니다. `{name}`·용어 토큰 금지와 en·ja의 조사 표기 금지는 그대로입니다 | error |
| `ui.josa_position` (새) | ui 조사 표기가 매개변수 바로 뒤에 있는지, 그 매개변수가 `text`·`number`인지 봅니다 | error |
| `ui.josa_literal` (새) | ko ui 원고에서 `text`·`number` 매개변수 바로 뒤에 바뀌는 조사를 글자로 붙이면 막습니다. 대상 글자는 `pairs`의 받침 있음·없음 값(이·가·은·는·을·를·과·와·으로·로·이에요·예요)입니다. 조사 표기를 쓰라고 알립니다 | error |
| `ui.josa_name_clash` (새) | 원고 매개변수 이름과 생성할 `pJosa` 이름이 겹치면 막습니다 | error |
| `check-arb` | ko ARB의 `pJosa` 자리표시자를 슬롯 `params` 밖이어도 받습니다. select마다 원래 매개변수가 바로 앞에 있어야 합니다(`arb.josa_orphan`). 문장 규칙은 `final`·`rieul`·`none` 가지를 펼쳐 보고, 병기형(`other`)은 괄호가 `style.S1`에 걸려 뺍니다(자리표시자가 있는 ARB 메시지는 길이를 재지 않으므로 놓치는 길이도 없음) | error |

* `ui.josa_literal`은 매개변수(또는 그 뒤 닫는 따옴표) 바로 뒤에 붙은 조사 글자이고, 그 뒤(흔한 보조사 `는·도·만·요·의` 하나는 건너뜀)에 한글이 이어지지 않을 때 잡습니다. 그래서 `{date}이후`·`{date}이나`는 잡지 않고 `{provider}로는`·`{title}와의`·`{title}이)`는 잡습니다. 따옴표 뒤 조사 표기(`'{title}'(이)가`)는 펼치지 않으므로 `ui.josa_position` error이고, 문장을 따옴표 없이 쓰거나 조사가 오지 않게 씁니다. 받침과 상관없는 말(`{date}까지`, `{count}개`, `{tag} 태그`)과 조사(`{end}에`)도 막지 않습니다.
* 새 규칙은 `ui.markup`처럼 `tools/src/mlw/markup.py`의 코드 규칙이고, 걸리는 예와 통과하는 예는 `tools/tests/test_markup.py`의 parametrize 사례로 둡니다.

## 6. app 계약 (app이 구현)

* 판정 함수: `josaClass(String shown)` → `'final' | 'rieul' | 'none' | 'other'`.
  * 순서는 기준 구현 `final_batchim`과 같습니다. NFC 정규화 → 마지막 글자가 한글 음절이면 받침 → 숫자·영문·천간지지 한자로 끝나면 `readings`의 읽는 소리 → 그 밖은 `'other'`.
  * 판정표는 Dart 코드에 둡니다(server와 같은 방식). app 테스트가 `docs/identity/writing/rules/josa.yaml`의 `examples`를 읽어 결과를 맞춥니다.
* 부르는 쪽은 **화면에 보이는 문자열 그대로** 넘깁니다. 숫자는 서식을 적용한 뒤(`1,000`), 날짜·시각도 서식을 적용한 뒤입니다.

  ```dart
  l10n.eventDueNotice(title, josaClass(title))
  ```

* 생성 메서드는 positional 인자이고 `pJosa`는 원래 매개변수들 뒤에 붙습니다(`app/l10n.yaml`에 `use-named-parameters` 없음).
* app은 조사 표기를 문자열에서 찾아 바꾸지 않습니다. 사용자가 입력한 값에 `(이)가`가 들어 있어도 그대로 보입니다.
* 반복을 줄이는 감싸는 함수는 app이 정합니다.

## 7. 테스트

* `arb_export`: 6쌍 전부, `(으)로`의 `rieul` 가지, `(이)에요`, 한 문장에 같은 매개변수 두 번, plural 가지 안, 조사 없는 메시지는 그대로(시그니처 불변).
* 펼친 ko ARB 문장을 `icu.plural` 파서로 다시 읽어 문법이 맞는지 봅니다.
* `check-arb`가 `pJosa`를 받고, 원래 매개변수가 없는 `pJosa`는 막는지 봅니다.
* 새 검사 규칙 셋의 걸리는 예·통과하는 예(`test_markup.py`).
* `rules/josa.yaml`의 `examples`에 이미 있는 판정할 수 없는 예(`★`, 병기형)로 Python·Go·Dart가 `other` 가지까지 같은 표로 확인합니다.
* 저장소 원고 전체: 지금 원고에 조사 표기가 없으므로 생성 ARB가 바뀌지 않아야 합니다(`gen-docs --check`).

## 8. 계약 버전과 결정

* 호칭·조사 처리 규칙 v1.1 → **v1.2**: 받는 쪽에 app(ui ARB 조사). `guide/honorific-josa.md`에 "ui ARB의 조사" 절(§4 형태, 가지 이름, §6 계약).
* 슬롯 명세 → 다음 버전(추가만): ko ui 원고에 조사 표기 허용. 어떤 키에 조사를 처음 쓰면 그 키의 ARB 매개변수가 늘어 하위 호환이 깨지므로, 그때마다 app에 알립니다.
* 검사기 v0.7.0 → **v0.8.0**: §5.
* writing 결정 **W38**(W37은 PR #436).
* 지휘 D 기록 요청: ui 문구의 조사를 app이 `select`로 고르고, 판정 규칙 원본은 `rules/josa.yaml` 하나라는 것.

## 9. 이행 순서

1. **writing PR:** §4·§5·§7·§8. 이 PR에서는 ui 원고에 조사 표기를 쓰지 않아 ARB 키 시그니처가 바뀌지 않습니다. 함께 지휘 Issue(D 기록)와 app Issue(`josaClass` 구현)를 올립니다.
2. **app:** `josaClass`와 테스트. 완료 보고 Issue.
3. **writing:** 조사가 필요한 문구에 처음 씁니다. 키마다 app에 알립니다. 이미 있는 회피 문구 8곳은 자연스러우면 그대로 두고, 회피 때문에 어색해진 곳만 고칩니다.

## 10. 바뀌는 파일 (writing)

* `tools/src/mlw/arb_export.py`(펼치기), `markup.py`(`ui.markup` 완화, 새 규칙), `arb.py`(`check-arb`), 새 규칙 등록과 테스트
* `tests/test_josa_select.py`·`test_markup.py`·`test_arb_export.py`·`test_arb.py`·`test_icu.py`
* `guide/honorific-josa.md`, `decisions.md`(W38), `docs/contracts/README.md` writing 행, writing `CLAUDE.md`
