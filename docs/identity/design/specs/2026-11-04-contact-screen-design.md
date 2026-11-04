# 문의 화면 배치와 슬롯 상한 (D102, #763·#758)

* 날짜: 2026-11-04, design 세션
* 요청: writing #763(문의 화면 `contact` 슬롯 상한), drift #758(IA `contact`가 쓰는 컴포넌트의 "쓰는 화면", PR #753·#751)
* 결과: 컴포넌트 계약 3.4.0(추가만), 결정 V55, `lengths.md` 3.4.0

## 1. 확인한 사실

| 사실 | 출처 |
| --- | --- |
| `contact`의 컴포넌트는 `app-bar`, `text-field`, `primary-button`, `toast`. 상태는 `error`(보내기 실패) 하나 | `docs/ia/screens.json` |
| 사용자는 문의 내용과 답장 메일(필수)만 쓰고, 함께 보내는 정보를 화면에 알리고, 주소를 글자로 보임 | D102 ①④ |
| 칸마다 이름 키와 칸 안 안내 키가 따로 있음(`contactMessageFieldLabel`·`Hint`, `contactEmailFieldLabel`·`Hint`). 메일 형식 오류 `contactEmailInvalid`, 보내기 실패 `contactSendFailed` | writing `slots/ui/contact.yaml`, R29 |
| `text-field`에는 칸 이름과 칸 오류 줄 부품이 없었음. 오류 줄은 `input-step`이 그림 | `components/input.json` 3.3.0 |
| writing 길이 검사는 값이 정해지지 않은 `text` 매개변수(`{email}`)가 든 문구를 세지 않음 | writing `src/mlw/sentence.py` `_rendered_length` |

## 2. 판단

* 칸이 둘이라 질문 하나가 칸 이름을 대신하는 `input-step`을 쓸 수 없습니다. 칸 안 안내는 글을 쓰면 사라지므로 이름을 칸 위에 늘 보입니다(`text-field` `label`).
* 메일 형식 오류는 그 칸에 붙어야 어디를 고칠지 알 수 있어 칸 아래 오류 줄(`errorLine`)로 보입니다. 모양은 `input-step` 오류 줄과 같게 해 앱 안 오류 표시를 하나로 둡니다.
* 보내기 실패는 화면을 `error-state`로 바꾸면 쓴 글이 가려지므로 toast로 알립니다. 429와 503도 같은 문구입니다. 주소 안내가 늘 보여 다른 길이 화면에 있습니다.
* 주소는 D102 ④ "글자로"를 따라 링크로 만들지 않고, 길게 눌러 복사할 수 있게 합니다.
* 뒤로 가기는 확인 창 없이 쓴 글을 버립니다. 확인 창을 두려면 writing 슬롯이 새로 필요하고, 문의 글은 짧은 편입니다. 사용 중 불편이 보이면 다시 정합니다.

## 3. 글자 수

`lengths.md` 3.4.0 설명을 봅니다. ja `contactEmailFieldHint`는 라틴 주소 예시라 실측 키별 상한 16(`KEY_MEASURED_LIMITS`). R29 원고는 모두 상한 안입니다.
