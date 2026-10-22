# LINE 아이콘 출처

* 받은 날짜: 2026-10-22
* 가이드: LINE Login button design guidelines `https://developers.line.biz/en/docs/line-login/login-button/`
* 배포 자산: 같은 페이지의 "Download the LINE Login button template" `https://vos.line-scdn.net/line-developers/docs/media/line-login/login-button/LINE_Login_Button_Image.zip` (sha256 `2357d4643557b3eca7c7d83bdd66c5fee7712fedd4f3c1abb75a2ffb30eb9111`). 가이드는 받기 전에 "Usage Guidelines for the LINE Login Button"에 동의한 것으로 봅니다.

## 파일

| 파일 | 원본 | 쓰는 곳 |
| --- | --- | --- |
| `line_icon.png` | `Line_Login_Button_Image/images/Android/xxdpi/line_120.png` (120x120, 바꾸지 않은 사본) | 버튼 로고(흰색), `connected` 초록 배지 안 심볼 |

* 흰 말풍선 아이콘이고 바탕은 투명입니다. 버튼 바탕 `#06C755`는 코드가 칠합니다. 꺼짐 로고색(`#1E1E1E` 20%)은 코드가 이 아이콘을 그 색으로 칠해 그립니다(가이드 색 표).
* 로고와 글자 사이 세로 구분선: 묶음의 `btn_login_base.png`는 버튼 높이만 한 정사각 칸 가운데에 아이콘을 두고 그 칸 오른쪽 끝에 1dp 구분선(검정 8%)을 긋습니다. 코드는 같은 자리(높이 52 칸의 끝)에 같은 색으로 긋습니다.
* 이용 조건(가이드 요약): 정해진 색만 쓰고, 아이콘 비율을 바꾸지 않으며 잘 보여야 하고, 옛 아이콘이나 바꾼 아이콘을 쓰지 않습니다. 글자는 줄바꿈 없이 LINE으로 로그인함이 드러나야 합니다.
