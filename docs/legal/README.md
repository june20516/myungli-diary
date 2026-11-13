# 법적 문서 (이용약관·개인정보 처리방침)

앱이 여는 이용약관과 개인정보 처리방침의 원문입니다(D80). 원문은 이 디렉터리에 두고, server가 서비스 도메인의 정적 페이지로 내줍니다.

* **고치는 쪽:** 초안은 지휘 세션, 확정은 사용자입니다. 공개 저장소이므로 원문도 공개 문서로 씁니다(D74).
* **파일:** `<언어>/terms.md`, `<언어>/privacy.md` (언어: `ko`, `en`, `ja`). 머리에 시행일을 적습니다.
* **주소:** server가 `/legal/terms`·`/legal/privacy`(`?lang=ko|en|ja`)로 내주고, `getAppConfig`가 그 주소를 알려 줍니다. app은 주소를 상수로 두지 않습니다.
* **검토 기준(D126 ①):** 개인정보보호위원회 처리방침 작성지침, 공정거래위원회 표준약관, 법령 원문. 유료 법률 검토는 받지 않습니다.
* **사업자 정보(D126 ②):** 상호, 대표자, 주소, 사업자등록번호, 통신판매업 신고번호는 원문에 빈자리만 두고 server가 페이지를 내줄 때 로컬 값으로 채웁니다. 원문과 `server/legal/data/`에 값을 적지 않습니다. 빈자리 표기는 server가 정합니다.
* **원문 상태:** ko, en, ja 처리방침과 이용약관 초안이 있습니다(시행일은 확정 때). 빈자리 표기는 server S157(`{{business.name}}`, `{{business.representative}}`, `{{business.address}}`, `{{business.registrationNumber}}`, `{{business.mailOrderNumber}}`)입니다. 스토어 양식 답안은 [`store-disclosures.md`](store-disclosures.md)입니다.
