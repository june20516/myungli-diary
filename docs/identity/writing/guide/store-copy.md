# 스토어 문구

App Store와 Google Play 등록정보에 쓰는 writing 원고입니다. 사용자에게 보이는 글이라 D93(긴 대시, 범위 대시, 가운뎃점 금지)과 보이스·톤 가이드를 따릅니다.

## 원고와 업로드 (W80)
* 원고: `content/<lang>/store.yaml`, 슬롯 명세: `slots/store/listing.yaml`(칸마다 슬롯 하나, 상한은 스토어 콘솔 값)
* 업로드용: `generated/store/listing.json`(언어 → 슬롯 → 키 → 글, `mlw gen-docs`가 만듦). 지휘가 이 파일로 두 스토어 콘솔에 올립니다.
* 스크린샷 위 글(`store.screenshot.caption`)의 키는 design 스토어 명세(`docs/identity/design/store/store.json`)의 장면 id이고, app 생성 명령이 장면에 맞춰 넣습니다. 줄바꿈은 원고의 줄바꿈 그대로이고, 한 줄 상한(ko 14, en 23, ja 11)과 두 줄은 `mlw check`가 봅니다. 상한은 추정이라 app 생성 명령의 실제 폭 검사가 최종 기준입니다.
* App Store 키워드는 UTF-8 100바이트(`length_unit: utf8_bytes`)이고, 쉼표 뒤에 띄어쓰지 않습니다.

## 쓰는 법 (W80, 라운드 R49)
* 기능을 나열하지 않습니다. 사용자가 앱을 찾는 순간("중요한 일정이 있다면")과 얻는 것("중요한 약속은 길일에 잡아 보세요")을 사람 말로 씁니다.
* 스크린샷 한 장에는 한 가지만 짚습니다. 화면의 기능 셋을 한 문장에 몰지 않습니다.
* 첫 줄은 개인화 약속입니다: "같은 날이라도 각자의 오늘은 다릅니다."
* 의무가 아닌 결제, 광고, 언어, 주의 문구는 넣지 않습니다. 순위, "최고", "무료", 경쟁 앱 이름, 가격(D74)도 넣지 않고 운세 효과를 단정하지 않습니다.
* 주체가 애매한 피동("보여요")보다 주체가 분명한 문장을 씁니다. 느낌표는 쓰지 않습니다(`slop.P8`).
* 설명은 합니다체, 홍보 문구와 짧은 설명, 스크린샷 위 글은 해요체나 명사로 맺습니다.

## 태그라인 (W49, 라운드 R9-11·R25-1)
App Store 부제(`store.subtitle`)와 공유 이미지 태그라인(`share-preview.image.tagline`, `sharePreviewImageTagline`)이 같은 문장입니다. 바꿀 때는 두 곳을 함께 바꿉니다. en은 부제 상한(30자) 때문에 부제만 짧은 판("Daily Readings for Your Chart")입니다.

| 언어 | 문장 |
| --- | --- |
| ko | 오늘 일진을 내 사주에 맞춰 풀어 주는 일기 |
| en | A diary that reads today for your own chart |
| ja | 今日の干支を、あなたの命式に合わせて読み解く日記 |

* en, ja는 원어민 검수 전 초안입니다(D70, E18).
* 앱 이름(ko 명리일기, en Myungli Diary, ja 命理日記, W17)은 스토어가 따로 보여 주므로 태그라인에 넣지 않습니다.
