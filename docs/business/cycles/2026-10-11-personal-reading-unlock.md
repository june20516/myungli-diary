# 원국 개인 해석을 잠그고 광고로 여는가

* 작성: 지휘 세션, 2026-10-11
* 상태: 반영 완료
* 관련 결정: D11·D12·D53·D54·D57·D59, 결론 D60
* 절차: [수익화 결정 체계](../README.md)

## 1. 질문

풀이 시트의 "내 사주에서는"(원국 용어별 개인 해석)을 MVP에 **처음부터 잠긴 기능**으로 넣고, 보상형 광고(rewarded ad)를 보면 열리게 하는가. 나중에는 구독으로도 열리게 한다.

출발점:
* design V2가 풀이 시트를 "일반 뜻 + '내 사주에서는' 상자"로 그리고 잠김 변형을 준비했습니다(Issue #32, `sentence.md`).
* 그런데 IA의 `explain-sheet` 슬롯은 `term.meaning`(일반 뜻)·`today.reason`(오늘 그런 이유)뿐입니다. 원국 용어별 개인 해석은 엔진 메시지 키·writing 슬롯·IA 어디에도 없습니다. 지금 계약대로면 사주 표에서 연 상자는 비어 있습니다.
* 사용자 결정: 무료로 주다가 잠그지 않습니다. 개인 해석은 새 기능으로 넣고, 처음 해제 수단은 광고 시청입니다(광고 도입에 편승).

바뀔 수 있는 범위:
* IA: 풀이 시트 개인 해석 슬롯, 잠김 표시, 광고 보기 흐름(시스템 화면), 잠금 안내 슬롯
* core: 원국 용어별 개인 해석 메시지 키(용어 × 자리)
* writing: 개인 해석 원고(3개 언어), 잠금·보상 고지 문구
* design: 잠김 변형을 MVP에서 씀, 보상 고지 모양
* S1: entitlement 종류 추가, 보상형 광고 서버 확인(SSV)
* A1: 보상형 광고 로드·표시, 잠김 상태 그리기

함께 다룰 아이디어: I7.

## 2. 조사

subagent 하나가 웹에서 조사했습니다(확인일 2026-10-11). 원문을 연 것은 사실, 해석은 "추정", 찾지 못한 것은 "미확인"으로 적었습니다.

### 2.1 정책

| 항목 | 내용 | 구분 | 출처 |
| --- | --- | --- | --- |
| AdMob opt-in | 보상형 광고는 사용자가 분명히 고른 뒤에만 보입니다. 거절해도 앱 사용을 막으면 안 됩니다 | 사실 | [AdMob 보상 정책](https://support.google.com/admob/answer/7313578?hl=en) |
| AdMob 보상 고지 | 매번 광고 전에 필요한 행동과 보상을 분명히 알립니다. 유도 문구 금지 | 사실 | 같은 문서 |
| 금지 보상 | 현금·암호화폐·기프트카드. 앱 안에서만 쓰는 비금전 보상은 허용 | 사실 | 같은 문서 |
| 콘텐츠 해제 | AdMob 정책에 따로 문장이 없음. Google Play 광고 정책은 "unlocking a specific game feature"를 예로 듦. 앱 안 콘텐츠 열람은 허용될 가능성이 높음 | 사실 / 추정 | [Play 광고 정책](https://support.google.com/googleplay/android-developer/answer/9857753?hl=en) |
| 건너뛰기·한도 | 보상은 건너뛰기 시점(최대 30초)에 지급. 광고 단위에 frequency cap 설정 가능 | 사실 | [AdMob 보상형 광고 단위](https://support.google.com/admob/answer/7311747?hl=en) |
| 민감 카테고리 | "Astrology & esoteric"은 deprecated, 영어·포르투갈어만 적용, 2026-10-23 제거 예정. 운세 앱이라 생기는 제약은 찾지 못함 | 사실 | [AdMob 민감 카테고리](https://support.google.com/admob/answer/3150953?hl=en) |
| Apple 3.2.2(x) | "Apps may otherwise incentivize users to take specific actions within apps (e.g. … watching an ad)" | 사실 | [App Store 심사 가이드라인](https://developer.apple.com/app-store/review/guidelines/) |
| Apple 3.1.1 | 콘텐츠를 **판매**해 열면 IAP 필수. 광고 시청은 판매가 아니므로 충돌하지 않음. 유료 해제를 더하면 그 부분은 IAP | 사실 / 추정 | 같은 문서 |

### 2.2 서버 확인(SSV)

* 보상이 지급되면 Google이 서명된 GET을 콜백 URL로 보냅니다. 파라미터는 `transaction_id`, `user_id`, `custom_data`, `reward_amount`, `signature`, `key_id` 등입니다. 서명은 ECDSA, 공개키는 `gstatic.com/admob/reward/verifier-keys.json`(24시간 넘게 캐시하지 않음). 200이 아니면 1초 간격 최대 5번 다시 보냅니다. [AdMob SSV](https://developers.google.com/admob/android/ssv) (사실)
* 권장 흐름은 클라이언트 콜백으로 바로 보상하고 서버 콜백으로 확인하는 것입니다. 보상이 중요하면 서버 콜백만 기다려도 됩니다. (사실, 같은 문서)
* `transaction_id`로 멱등 처리해야 합니다. (추정)
* RevenueCat도 SSV를 대신 받아 기간 entitlement를 줍니다. 단 **beta**, 최소 30분, Flutter는 수동 연동만. [RevenueCat Ad Rewards](https://www.revenuecat.com/docs/ad-monetization/rewards) (사실)
* Flutter `ServerSideVerificationOptions(userId, customData)`. `RewardedAd`는 한 번만 보이고 다 쓰면 dispose. [AdMob Flutter Rewarded](https://developers.google.com/admob/flutter/rewarded) (사실)

### 2.3 국내 사례

| 앱 | 구조 | 해제 단위 | 유료와의 관계 | 출처 |
| --- | --- | --- | --- | --- |
| 포스텔러 만세력 | 2025-07 v1.0.5 "각 명식의 맞춤형 풀이가 추가되었습니다. (광고 시청 후 확인 가능)" | 풀이 볼 때마다 광고(리뷰, 추정) | 2026-05 재화 '복채' IAP 추가, 복채로 더 빠르게 확인 | [App Store](https://apps.apple.com/kr/app/id6480584804) |
| 점신 | 광고 1회 → 약 2시간 행운패스(리뷰 진술) | 시간 | 1개월 광고 제거 ₩2,900 | [Google Play](https://play.google.com/store/apps/details?id=handasoft.mobile.divination&hl=ko&gl=KR), [App Store](https://apps.apple.com/kr/app/id960571015) |
| 우주고양이 보라 | 광고 → 재화(젤리) 적립 | 재화 | 젤리 IAP | [App Store](https://apps.apple.com/kr/app/id6469338831) |

* 국내 유형은 건별·시간 패스·재화 셋입니다. 하루 한도를 공개한 곳은 찾지 못했습니다. 리뷰 불만은 광고 길이와 빈도에 몰려 있습니다. (추정)

### 2.4 설계 관행

* 광고 제거 상품이 있어도 보상형은 opt-in이라 남겨 두는 곳이 흔합니다(CodyCross: "you still have the opportunity to watch ads to earn rewards"). 구독자에게는 잠금 자체가 없게 같은 entitlement에 묶으라고 권합니다. [RevenueCat Blog](https://www.revenuecat.com/blog/engineering/monetizing-without-a-paywall-using-ads), [CodyCross](https://codycross-en-2-0.helpscoutdocs.com/article/2524-how-does-the-ad-free-version-work) (사실)
* no fill: 광고가 준비됐을 때만 버튼을 켜는 방식이 정책(거절·실패가 사용을 막지 않음)에 맞습니다. [Unity Blog](https://unity.com/blog/3-ways-to-optimize-the-ad-experience-for-your-users) (사실 / 적용은 추정)
* 한국 보상형 eCPM: iOS $20.94·Android $22.01(2024 2분기, 주로 게임), 평균 $12.00(Appodeal 2024 4분기 인용). 운세 앱 값은 다를 수 있음. [GameDevReports](https://gamedevreports.substack.com/p/tenjin-ad-monetization-in-mobile-00b), [Mistplay](https://business.mistplay.com/resources/mobile-ads-ecpm/) (사실, 2차 자료)

### 2.5 기존 결정과의 관계

* **D12** "멤버십·구독은 해설 콘텐츠가 아니라 기능 단위의 접근 제한이나 횟수 제한으로 차등"과 부딪힙니다. 개인 해석은 해설 콘텐츠입니다. 판단 기준 3이 D12를 지키라고 하므로 D12를 고치는 결정이 필요합니다.
* **D11**(정보 깊이는 유료 등급이 아님)은 지킬 수 있습니다. 풀이 시트(explain)와 근거 시트(evidence)는 그대로 열고, "원국 개인 해석"을 별도 기능으로 잠그면 깊이가 잠기지 않습니다.
* **D53** ①은 배너만 정했습니다. 보상형 광고는 사용자가 눌러야 뜨는 전면 광고라 형식 추가가 필요합니다.
* **판단 기준 1**(핵심 경험인 오늘 풀이·일기·달력은 막지 않음): 개인 해석은 나의 사주 표에서 여는 심화 내용이라 핵심 경험 밖입니다. 오늘 화면의 "오늘 그런 이유"는 열어 둡니다.

## 3. 선택지

정할 것이 넷입니다. 각 줄의 평가는 판단 기준 1(사용자·재방문)·2(실제 지불 검증)·3(기존 결정)에 비춘 것입니다.

### 3.1 무엇을 잠그나

* **(가) 원국 개인 해석만 (권장).** 나의 사주(`saju-chart`·`manse-table`·`daeun-table`)에서 연 용어의 "내 사주에서는". 일반 뜻·오늘 그런 이유·근거 시트는 무료. 기준 1 지킴, 3은 D12 개정 한 건, D11 유지.
* (나) 개인 해석 + 근거 시트. 기준 3에서 D11과 부딪힘(evidence 깊이를 잠금).

### 3.2 광고 한 번에 무엇이 열리나

* **(가) 그날 하루 모든 개인 해석 (권장).** 계정에 그날 끝(사용자 시간대 자정)까지 만료일이 있는 entitlement를 줍니다. D53의 entitlement 모델을 그대로 씁니다. 광고 피로가 적고(기준 1), 매일 다시 볼 이유가 생깁니다.
* (나) 용어 하나 영구. 포스텔러 만세력과 비슷합니다. 다 열고 나면 광고 수익이 끊기고, 나중 구독의 가치도 줄어듭니다. 용어별 해제 기록이 따로 필요합니다.
* (다) 몇 시간(점신식 2시간). 사주 표는 하루 안에 다시 볼 일이 많지 않아 체감이 (가)와 비슷하고, 규칙만 복잡해집니다.

### 3.3 광고 제거권(D53·D54)을 산 사람은

* **(가) 기간 동안 개인 해석도 열림 (권장).** "광고 제거"를 산 사람에게 광고를 보라고 하지 않습니다. ₩2,500 상품의 가치가 커져 기준 2(실제 지불 검증)에 유리합니다. 나중 구독도 같은 entitlement를 줍니다.
* (나) 배너만 없애고 개인 해석은 계속 광고로. 업계에 흔하지만, 광고를 없애려고 산 사람에게 광고를 권하게 됩니다.

### 3.4 서버 확인을 어디서 받나

* **(가) server가 SSV를 직접 받음 (권장).** Go에서 서명 검증·`transaction_id` 멱등 처리 후 entitlement를 줍니다. 하루 단위·광고 제거권 통합을 자유롭게 정할 수 있습니다.
* (나) RevenueCat Ad Rewards. beta이고 Flutter는 수동 연동, 최소 단위가 30분 기간이라 "그날 끝까지"를 표현하기 어렵습니다.

### 범위 영향 (선택지와 무관하게 생기는 것)

* MVP에 새 원고가 생깁니다: 원국 용어 × 자리별 개인 해석(십성 10 × 천간·지지 자리, 12운성 12, 신살, 3개 언어). writing W1과 core 메시지 키가 늘어납니다.
* app은 보상형 광고 단위를 추가하고, 광고가 준비됐을 때만 "광고 보고 열기"를 켭니다. 광고 동의(D53 ④) 전이거나 광고가 없으면 버튼을 끄고 안내합니다.

## 4. 결정 (D60)

사용자가 고른 것:
* **3.1 무엇을 잠그나:** 제시한 (가)·(나)가 아니라 사용자 안입니다. "해설 콘텐츠가 빠지면 돈되는 게 별로 없다. 깊이 3단계 중 마지막 단계를 유료로." 이어서 evidence 깊이에는 원국표(사주 표·만세력·대운 표)도 들어 있어, **해석만 잠그고 표 데이터는 무료**로 좁혔습니다. 잠기는 것은 판정 근거·원전 인용·원국 개인 해석입니다. "내 사주에서는"은 explain이 아니라 evidence 깊이로 옮깁니다.
* **3.2 해제 단위:** (가) 그날 하루 전부.
* **3.3 광고 제거권:** (가) 기간 동안 열림.
* **3.4 서버 확인:** (가) server가 SSV를 직접 받음.

이유:
* 기준 1: 핵심 경험(오늘 풀이 surface·explain, 일기, 달력)과 자기 사주 표는 열려 있습니다. 광고는 사용자가 고를 때만 뜨고 하루 한 번이면 됩니다.
* 기준 2: 광고 제거권(₩2,500)에 근거·해석 열람이 더해져, 실제로 돈을 내는 사람이 있는지 보기에 유리합니다. 보상형 광고 시청 수는 잠긴 해석에 대한 수요를 보여 줍니다.
* 기준 3: D11·D12를 사용자 결정으로 고쳤습니다(D60). D53의 광고 형식에 보상형을 더했고, 전면·네이티브는 여전히 없습니다.

## 5. 반영

* `docs/decisions.md`: D60
* `docs/ia/screens.json`: 화면 `system-rewarded-ad` 추가, `evidence-sheet` 슬롯 6개(`personal.body`, `lock.head`, `lock.reward`, `lock.cta`, `lock.pass`, `lock.unavailable`)·`primary-button`·출구 2개, `saju-chart` 출구 1개, `ad-free.offer.head` 역할. 추가만이라 v1 유지(화면 35·컴포넌트 41·슬롯 109)
* `docs/specs/2026-10-11-ia-design.md`: 화면 표·슬롯 표·개정 기록, §11 범위 밖의 지난 항목 정리
* `docs/identity/README.md`: 깊이 표에 잠금 범위
* `docs/business/README.md`: 판단 기준 3
* `docs/background/04-mvp-spec.md` §4.5
* `docs/contracts/README.md`: IA 행
* `docs/roadmap.md`: 외부 준비물(보상형 광고 단위·SSV 콜백 URL)
* `server/CLAUDE.md`, `app/CLAUDE.md`
* 아이디어 I7: `채택 D60`
* 요청: core(원국 개인 해석 메시지 키), writing(원고·잠금 문구), design(풀이 시트 상자 제거, 근거 시트 잠김 변형, 보상 고지), server·app 착수 Issue 코멘트
