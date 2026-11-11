# 근거 자료 (References)

엔진 연산과 앱 문구(Easy 텍스트·Pro 설명)에 인용할 원전 근거를 모아둔 곳입니다.

## 사용 원칙
* **엔진**은 용신이나 추천을 정할 때 근거 위치(파일 + 키)를 `evidence` 깊이용 근거(`Evidence.source_ref`)에 함께 반환합니다.
* **문구**는 원문 인용을 그대로 쓰거나 풀어 쓰되, 근거가 어디서 왔는지 추적할 수 있게 합니다.
* 원문이 없는 내용(통설·현대 해석)은 근거 자료에 넣지 않거나, `note`로 "원문 근거 아님"을 밝힙니다.

## 『궁통보감(窮通寶鑑)』 — `gungtong-bogam/`

`johu_evidence.json`, `five_elements.json`, `corrections.json`은 엔진이 `source_ref`로 읽으므로 패키지 데이터 디렉터리로 옮겼습니다(경로는 아래 표). 나머지는 이 디렉터리에 둡니다.
출처: [위키문헌 『窮通寶鑑』](https://zh.wikisource.org/wiki/%E7%AA%AE%E9%80%9A%E5%AF%B6%E9%91%91) 원문(raw wikitext, 2026-10-10 수집). 고전 원문은 저작권 보호 기간이 지났습니다. 위키문헌 편집본은 CC BY-SA 라이선스이므로 출처를 표기합니다.

| 파일 | 내용 | 문구 활용 예 |
| --- | --- | --- |
| `source.wikitext` | 원문 전체 (수집 원본, 수정 금지) | - |
| `entries.json` | 일간 → 계절(三春~三冬) → 월 항목 구조. 문단, 계절 총론, 예시 명조 70개 표 | 사주 예시, 테스트 사례 |
| `core/src/myungli_engine/references/data/gungtong_bogam/johu_evidence.json` | 일간 × 월지 120칸: 조후용신, 오행, 근거 수준, 원문 첫 문장(`key_sentence`), 전체 문단, 정정 이력 | Pro 바텀시트의 "왜 이 기운이 필요한가" 근거 문장 |
| `core/src/myungli_engine/references/data/gungtong_bogam/five_elements.json` | 「五行總論」의 오행별 방위·색·수·성정, 억부 원리 | 행운의 컬러·숫자·방향 근거, 감성 코멘트 |
| `core/src/myungli_engine/references/data/gungtong_bogam/corrections.json` | 통용 정리표를 원문 기준으로 정정한 11칸과 근거 문장 | - |
| `verification-report.md` | 조후표 ↔ 원문 120칸 대조 결과 (자동 생성) | - |
| `tools/parse_source.py` | 원문 파서 | - |
| `tools/build_evidence.py` | 위 JSON과 리포트 생성기 | - |

다시 생성하려면 저장소 루트에서 다음을 실행합니다.
```bash
python3 -I core/docs/references/gungtong-bogam/tools/build_evidence.py
```

### 주의 사항
* **색 근거:** 이 수집본 「五行總論」의 正色은 水黑·火赤·木青·土黃 네 가지로 金이 빠져 있습니다. 같은 문장을 실은 『三命通會』 四庫全書本 卷一(`sammyeong-tonghoe/skqs-vol01.wikitext`), 『五行精紀』(송, 출처 표시 『燭神經』), 『古今圖書集成』 藝術典 595권은 모두 "水黑、火赤、木青、金白、土黃"이라, 수집본 누락으로 보고 `five_elements.json`의 색 대응에 金=白을 넣었습니다(#937). 인용(`quote`)은 이 수집본 글자 그대로라 金白이 없고, `note`가 이를 밝힙니다. 같은 문장 뒤의 "及其變易…"(12운성에 따라 색이 바뀜)은 『三命通會』 四庫全書本에 단계마다 작은 주가 있습니다.
* **숫자 근거:** 「五行總論」의 수는 水1·火2·木3·金4·土5입니다(生數). 행운의 숫자를 이 체계로 정할지는 아직 결정하지 않았습니다.
* **근거 수준:** `evidence_level: "season"`인 11칸은 원문에 해당 월 항목이 없어 계절 총론을 근거로 썼습니다. 문구에서는 "○월"이 아니라 "○○(계절)에 태어난"으로 표현합니다.
* **언어:** 원문은 위키문헌 수집본의 간체 전사이고, `於`처럼 번체 글자가 일부 섞여 있습니다. 수집본 머리(`{{header}}`)에 판본(底本) 정보가 없고, core가 대조할 번체 판본도 없습니다. 간체를 번체로 기계 변환하지 않습니다(后/後·余/餘처럼 대응이 갈려 근거와 어긋남). 앱에 원문을 낼 때는 `quote`·`passage`를 글자 그대로 씁니다(#258). 번체 판본을 들이려면 판본을 정하고 120칸 대조(`verification-report.md`)를 다시 해야 하므로 별도 작업으로 합니다. 한국어 번역·해설은 따로 필요합니다(미작성).

## 태그 판정 원전: 『三命通會』 `sammyeong-tonghoe/`, 『滴天髓』 `jeokcheonsu/` (#804)

태그(합, 충, 일지 충, 월지 충, 신살 5종)의 근거입니다. 위키문헌 원문을 글자 그대로 저장했고, 출처와 revision은 각 디렉터리의 `PROVENANCE.md`에 있습니다. 태그별 대조 결과와 쓰지 않은 후보는 [`tag-sources-survey.md`](tag-sources-survey.md)에 있습니다.

| 파일 | 내용 |
| --- | --- |
| `sammyeong-tonghoe/vol2.wikitext`, `vol3.wikitext` | 『三命通會』 卷二, 卷三 원문 (수집 원본, 수정 금지, 간체) |
| `sammyeong-tonghoe/skqs-vol01.wikitext` | 『三命通會』 四庫全書本 卷一 원문 (수집 원본, 수정 금지, 번체, 구두점 없음). 오행 색 金=白 대조와 색 변역 원전(#937) |
| `jeokcheonsu/ch03.wikitext`, `ch17.wikitext` | 『滴天髓』 「地支論」, 「月令論」 원문 (수집 원본, 수정 금지, 번체) |
| `sammyeong-tonghoe/skqs-vol01.wikitext` → `core/src/myungli_engine/references/data/sammyeong_tonghoe/five_elements.json` | 행운 색 변역(變易) 원전 `color_change`: 「論五行」 본문(`quote`, 작은 주 뺌)과 작은 주를 괄호에 넣은 문단(`passage`), 명리일기 해석 `note`(#937, core C33). 생성기 `tools/build_color_source.py` |
| `tools/build_tag_sources.py` | 조목 문단을 뽑아 `core/src/myungli_engine/references/data/<자료>/tags.json`을 만드는 생성기. 인용이 원문 문단에 없으면 멈춤 |

다시 생성하려면 저장소 루트에서 다음을 실행합니다.
```bash
python3 -I core/docs/references/tools/build_tag_sources.py
```

* **문단:** 『三命通會』 수집본은 문장 중간에서 줄을 바꿔 두었으므로 빈 줄로 나뉜 덩어리를 한 문단으로 보고 줄을 구분자 없이 잇습니다. 『滴天髓』은 본문 줄과 주석 줄이 각각 한 문단입니다. 글자는 바꾸지 않습니다(수집본의 已·化盖 같은 표기도 그대로, `note`에 밝힘).
* **원전 없음:** 십성 쏠림 태그는 명리일기가 정한 규칙이라 원전이 없습니다. 근거의 `source_ref`가 빈 문자열입니다(core C28).

## 개인 해석과 십성 묶음 원전 (#998)

원국 개인 해석(일간, 십성, 12운성, 양인, 대운과 세운)과 총운 본문, 십성 묶음 가이드 질문의 근거입니다. 위키문헌 원문을 글자 그대로 저장했고 출처는 각 디렉터리의 `PROVENANCE.md`에 있습니다(core C35).

| 파일 | 내용 |
| --- | --- |
| `sammyeong-tonghoe/skqs-vol02.wikitext` | 『三命通會』 四庫全書本 卷二: 「論五行旺相休囚死並寄生十二宫」(12운성), 「論年月日時」(궁위), 「論大運」 |
| `sammyeong-tonghoe/skqs-vol05.wikitext` | 같은 책 卷五: 「論古人立印食官財名義」, 십성별 조목(論正官 ~ 論建禄) |
| `sammyeong-tonghoe/skqs-vol03.wikitext` | 같은 책 卷三: 「論羊刃」(양인), 截路空亡 |
| `jeokcheonsu/ch12.wikitext` | 『滴天髓』 「衰旺論」(일간 강약과 덜고 더하기) |
| `tools/build_personal_sources.py` → `core/src/myungli_engine/references/data/sammyeong_tonghoe/personal.json`, `.../jeokcheonsu/personal.json` | 조목의 대표 문장을 원문에서 뽑아 근거 JSON을 만드는 생성기. 인용이나 조목 이름이 원문에 없으면 멈춤 |

다시 생성하려면 저장소 루트에서 다음을 실행합니다.
```bash
python3 -I core/docs/references/tools/build_personal_sources.py
```

* 자리(궁위)와 역할(용신, 희신, 기신)의 원문(『三命通會』 「論年月日時」, 『淵海子平』 「六親總篇」, 『滴天髓』 「閒神論」 등)은 근거에 붙이지 않고 규칙 지도에 적습니다.
* 『子平眞詮』은 위키문헌에 없어 쓰지 않았습니다. 『淵海子平』은 위키문헌 수집본에 底本 표시가 없어 근거로 쓰지 않았습니다.

## 시진 고르기 원전: 『協紀辨方書』 `xieji-bianfang/` (#980)

집중 시간(시진 고르기)의 원전 후보입니다. 위키문헌 四庫全書本 원문을 글자 그대로 저장했고 출처와 revision은 `xieji-bianfang/PROVENANCE.md`에 있습니다. 조목별 대조, 지금 규칙과의 대조, 원전만으로 짠 안의 측정은 [`hour-sources-survey.md`](hour-sources-survey.md)에 있습니다. 엔진은 아직 이 원문을 쓰지 않습니다(규칙은 사용자 결정 뒤).

| 파일 | 내용 |
| --- | --- |
| `xieji-bianfang/skqs-vol07.wikitext` ~ `skqs-vol36.wikitext` (8권) | 『欽定協紀辨方書』 卷七, 九, 十, 三十二~三十六 원문 (수집 원본, 수정 금지, 번체, 구두점 없음) |
| `sammyeong-tonghoe/skqs-vol03.wikitext` | 『三命通會』 四庫全書本 卷三 원문 (截路空亡 조목) |

