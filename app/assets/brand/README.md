# 제공자 로고 (소셜 로그인)

`social-login-button`이 쓰는 제공자 공식 자산입니다. 색·모양·비율은 바꾸지 않습니다(컴포넌트 명세: "색·로고·문구는 각 제공자의 공식 가이드와 공식 자산"). 카카오·Apple의 받은 날짜는 2026-10-14입니다.

## 카카오 — `kakao/kakao_symbol.svg`

* 출처: Kakao Developers 디자인 리소스 다운로드 `https://developers.kakao.com/tool/resource/login`의 "전체 다운로드"(`https://developers.kakao.com/tool/download/Kakao%20Login.zip`). 디자인 가이드: `https://developers.kakao.com/docs/ko/kakaologin/design-guide`
* 내용: zip의 `SVG/kakao_login_kr_medium.svg`(버튼 전체)에서 **말풍선 심볼 path를 그대로** 옮기고 `viewBox`만 20x20 칸 가운데에 심볼(약 15)이 놓이도록 잡았습니다. path 좌표와 색(`#191919`, 파일에 든 값)은 원본 그대로입니다. 컨테이너(`#FEE500`)와 레이블(`#000000` 85%)은 가이드 값을 코드에서 씁니다.
* 버튼 문구(ARB `loginKakaoLabel`): 디자인 가이드 "Best practices > Label"의 완성형을 씁니다. 한국어 "카카오 로그인"(`https://developers.kakao.com/docs/ko/kakaologin/design-guide`), 영어 "Login with Kakao"(`https://developers.kakao.com/docs/en/kakaologin/design-guide`, 2026-10-14 확인). **일본어는 출처 미확인입니다.** 가이드에는 한국어·영어 레이블만 있고 일본어판 가이드나 일본어 버튼 리소스를 찾지 못해 "カカオログイン"은 임의로 옮긴 임시 문구입니다(ARB 설명에 "출처 미확인"). writing 원고나 출시 전에 확인합니다.
* 이용 조건(가이드 요약): 말풍선 심볼을 기본으로 쓰고 심볼의 형태·비율·색상은 바꿀 수 없다. 카카오 CI나 기능 아이콘을 심볼로 쓸 수 없고, 심볼 없이 버튼을 구성할 수 없다. 레이블은 "카카오 로그인"(완성형) 또는 "로그인"(축약형). 자산 사용 약관의 전문은 확인하지 못했습니다.

## Apple — `apple/apple_logo_black.svg`, `apple/apple_logo_white.svg`

* 출처: Apple Design Resources의 Sign in with Apple 로고 `https://devimages-cdn.apple.com/design/resources/download/Logo-Sign-in-with-Apple.dmg`(`https://developer.apple.com/design/resources/`), 가이드: Human Interface Guidelines "Sign in with Apple"
* 내용: dmg의 `Sign in with Apple - Logo Only/SVG/Logo - SIWA - Logo-only - {Black,White}.svg`에서 **로고 path를 그대로** 옮기고 정사각 바탕 사각형만 뺐습니다(`viewBox`는 로고 범위). 라이트 모드는 검정 바탕에 흰 로고, 다크 모드는 흰 바탕에 검정 로고를 씁니다(명세 `lightMode: black`, `darkMode: white`).
* **이용 조건 주의:** dmg에 든 "Apple Design Resources License"는 자산을 macOS·iOS 등 UI의 목업(mock-up) 제작에만 쓰도록 허용하고 "소프트웨어 프로그램에 내장하지 않는다"고 적습니다(§2). 반면 HIG는 Sign in with Apple 버튼에 공식 로고 자산을 쓰도록 안내합니다. 출시 전에 이 해석(앱 안 사용 허용 여부, Android 웹 흐름의 로고 사용)을 사용자가 확인해야 합니다.

## LINE — `line/line_icon.png`, Google — `google/g_logo_{light,dark}.png`

출처·받은 날짜·변환은 각 디렉터리의 `SOURCE.md`에 있습니다(받은 날짜 2026-10-22). `SOURCE.md`가 번들에 들어가지 않도록 `pubspec.yaml`에는 이미지 파일만 적습니다.

## 명리일기 로고 — `myungli/lockup.svg`

* 출처: `docs/identity/design/logo/lockup.svg`(`share-image` `logo`). 라이트 고정이라 `lockup-dark.svg`는 싣지 않습니다.
* 변환: flutter_svg가 중첩 `<svg>`를 그리지 않아, 원본의 중첩 `<svg>` 두 개를 같은 좌표 변환의 `<g transform>`으로 바꿨습니다. path·색·크기는 원본 그대로입니다. 원본이 바뀌면 같은 규칙으로 다시 만듭니다.
  * 아이콘: `<svg x=0 y=0 width=150 height=150 viewBox="0 0 100 100">` -> `<g transform="scale(1.5)">`(150/100).
  * 글자: `<svg x=187.5 y=25 width=357.4 height=100 viewBox="84.5 -840 3305.5 925">` -> `<g transform="translate(187.5 25) scale(S) translate(-84.5 840)">`. `S = min(357.4/3305.5, 100/925) = 0.108108108`(preserveAspectRatio meet 배율), 마지막 translate는 `-(viewBox x, y)`입니다.
  * 닫는 `</svg>`는 `</g>`로 바꿉니다. 원본의 `<defs>`·`<title>`은 그대로 둡니다.
