# Google "G" 로고 출처

* 받은 날짜: 2026-10-22
* 가이드: Google Sign-In branding guidelines `https://developers.google.com/identity/branding-guidelines`
* 배포 자산: 같은 페이지의 "Download" 묶음 `https://developers.google.com/static/identity/images/signin-assets.zip` (sha256 `ba884069e12093b06bcfd776915081254a7c95094b80d50be2c5dc6bac1c1da1`)

## 파일

| 파일 | 원본 | 쓰는 곳 |
| --- | --- | --- |
| `g_logo_light.png` | `Android + Web/PNG @4x/Light/Theme=Light, Show text=No, Shape=Square, Platform=Android+Web@4x.png` | light 테마 버튼(라이트 화면), `connected` 흰 원 배지 |
| `g_logo_dark.png` | `Android + Web/PNG @4x/Dark/Theme=Dark, Show text=No, Shape=Square, Platform=Android+Web@4x.png` | dark 테마 버튼(다크 화면) |

* 변환: 아이콘만 있는 40dp 정사각 버튼(@4x, 160px)에서 G 칸(SVG 원본의 G mask 범위 10~30dp, @4x 40~120px)만 80x80px로 잘라 냈습니다. 픽셀·색·비율은 원본 그대로이고, G 둘레의 바탕은 그 테마 버튼의 바탕색(light `#FFFFFF`, dark `#131314`)입니다.
* SVG가 아니라 PNG를 쓰는 이유: 묶음의 SVG는 표준 컬러 그라데이션 G를 `foreignObject`(CSS conic-gradient)와 가우스 흐림 `filter`로 그려 `flutter_svg`가 그리지 못합니다.
* 이용 조건(가이드 요약): G의 크기·색을 바꾸지 않고 표준 컬러 G를 쓰며, light·dark·neutral 테마 바탕 위에만 놓습니다. "Google" 한 낱말만 라벨로 쓰지 않습니다. 직접 크기를 만들 때는 묶음의 로고에서 시작합니다.
