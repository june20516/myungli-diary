# 친숙도 검수 절차

명리일기 문장이 사람에게 자연스럽게 읽히는지 사용자가 직접 고르는 절차입니다. 검사기(`mlw check`)는 기계로 판정할 수 있는 것만 막습니다. 의미와 어감은 이 절차로 판단합니다.

## 언제 쓰나
* **W0:** 보이스 규칙과 슬롯 예시를 세울 때. 라운드 R1~R7(spec §8.3).
* **W1:** 슬롯별 표본, 그리고 LLM 판정이 의심 표시한 문장을 볼 때.

## LLM 판정 (1차 거르기)
사람이 보기 전에 `mlw judge`로 의심 문장을 추립니다(결정 W1·W27). 막지 않는 로컬 명령이고 CI에서는 돌리지 않습니다.

```
uv run --project docs/identity/writing/tools mlw judge docs/identity/writing/content --lang ko
uv run --project docs/identity/writing/tools mlw judge docs/identity/writing/content --lang ko --slot daily.color
```

* `rules/slop.yaml`에서 `judge: llm`인 패턴의 `rubric`과 예를 루브릭으로 넘깁니다. 슬롯 목적 예외·`allowed`는 빼고 `forbidden`은 넣습니다(`check`와 같음).
* 모델은 로컬 `claude` CLI(`claude -p`)로 부릅니다. 기본 `sonnet`이고 `--model`로 바꿉니다. 한 번에 묻는 문장 수는 `--batch-size`(기본 40)입니다.
* `--shadow jev --shadow-out <파일>`을 주면 같은 문장을 TypeSafe jev에도 물어 판정 쌍을 JSONL로 남깁니다(W30, W1 첫 라운드용). 키는 `TYPESAFE_API_KEY="$(cat "${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/writing/shared/typesafe.key")"`(D98 대장 K7)로 넘기고, 본 판정 결과는 바뀌지 않습니다.
* 판정은 실행마다 조금씩 다를 수 있습니다. 고친 슬롯을 다시 돌리면 새 의심이 나올 수 있습니다.
* 출력은 `check`와 같은 `파일:줄 규칙 warn 메시지` 형식이고, 종료 코드는 늘 0입니다. 호출이 실패하거나 응답이 잘못되면 `judge.call_failed`·`judge.bad_response` 경고를 남기고 다음 묶음을 계속합니다.
* 의심 표시는 판정이 아닙니다. 표시된 문장은 아래 라운드에서 고쳐 쓴 선택지와 함께 내고, 같은 성격이 반복되면 규칙이나 `rubric`을 고칩니다.

## 라운드 진행
1. writing 세션이 터미널에 문항을 냅니다. 문항 하나에 선택지는 4~5개입니다.
2. 선택지에는 항상 **"다 별로"**를 둡니다.
3. 라운드마다 **숨긴 slop 대조군**을 1개 섞습니다. 대조군은 `rules/slop.yaml`의 패턴 하나를 일부러 담은 문장입니다. 어떤 것이 대조군인지는 고른 뒤 공개합니다.
4. 앞 라운드의 문항 1개를 **선택지 순서를 바꿔 다시** 냅니다. 같은 것을 고르면 일관된 선택으로 봅니다.
5. 일부 선택지는 **실제 커뮤니티·리뷰 표현**에서 가져옵니다.
   * 표현 단위로 검색해 실제 쓰임을 확인합니다. 크롤링(대량 수집)은 하지 않습니다.
   * 한국어 출처: 브런치, 블라인드, 다음카페, 네이트판, 더쿠, 인스티즈 같은 온건한 커뮤니티와 커머스 리뷰.
   * 출처는 고른 뒤 공개합니다. 출처를 미리 알면 판단이 흔들리기 때문입니다.
6. 판정자는 사용자 한 명입니다. 고른 이유를 한 줄 덧붙이면 규칙으로 옮기기 쉬워집니다.

## 규칙으로 굳히기
* **같은 성격의 선택이 2회** 나오면 규칙으로 굳힙니다. 재출제 문항에서 같은 답이 나온 경우도 포함합니다.
* 굳힌 규칙은 세 곳에 남깁니다.
  * `decisions.md`에 W# 결정으로 기록합니다.
  * 기계로 판정할 수 있으면 `rules/*.yaml`에 `examples`(걸리는 예, 통과하는 예)와 함께 넣습니다.
  * 판정할 수 없으면 슬롯 명세의 `examples`(좋은 예·나쁜 예, 이유)에 넣습니다.
* 대조군이 걸러지지 않거나 사용자가 새 slop을 지적하면 `rules/slop.yaml`에 패턴을 추가합니다.
* "다 별로"가 나오면 그 문항의 방향을 바꿔 다시 냅니다. 같은 방향으로 선택지만 바꾸지 않습니다.

## 기록
* 라운드마다 `artifacts/YYYY-MM-DD-round-<번호>.md`를 남깁니다. 담는 것:
  * 문항과 선택지(순서 그대로)
  * 대조군 표시와 그 패턴 ID
  * 고른 것과 이유
  * 선택지 출처
  * 굳힌 규칙과 그 W# 번호
* `artifacts/index.json`에 항목을 추가합니다(`kind: copy-sample`, `milestone`, `screens`, `decisions`, `status`). 형식은 `docs/workflow.md` §7을 따릅니다.

## 영어·일본어
같은 절차로 레퍼런스를 고를 수 있지만 원어민 검수(D28, W1)를 대신하지 않습니다. W0에서는 구두점, 경칭, 한국어 대비 길이 비율 같은 언어별 대응만 정합니다.

## 원어민 검수 (E18)
en, ja 원고는 원어민 감수자가 앱 없이 시트로 봅니다(D140, W84). 시트는 xlsx이고 감수는 Google Sheets에서 합니다.

1. **내보내기(writing):** 차수나 묶음 단위로 빈 시트를 만들어 저장소에 넣습니다.
   ```
   uv run --project docs/identity/writing/tools mlw review-export --lang en --tier 1
   uv run --project docs/identity/writing/tools mlw review-export --lang ja --bundle store,ui
   ```
   * 출력은 `review/<언어>/tier<n>.xlsx` 또는 `<묶음>-<묶음>.xlsx`입니다. 차수 표는 W84 ③, 감수자 안내 원문은 `review/guide-<언어>.md`입니다.
   * 원고 파일이 새로 생겨 차수 표에 없으면 내보내기가 멈춥니다. `mlw.review.sheet.TIERS`에 넣습니다.
2. **올리기(사용자):** Google Drive에 xlsx를 올리면 Sheets 문서로 바뀝니다(설정 "업로드한 파일 변환"이 꺼져 있으면 열 때 "Google Sheets로 열기"). 감수자에게 편집 권한으로 공유합니다.
3. **받기(사용자):** 감수가 끝나면 "파일 > 다운로드 > Microsoft Excel(.xlsx)"로 받아 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/writing/review/`에 둡니다. 저장소에는 넣지 않습니다(감수자 정보).
4. **writing 판정:** 수정안을 그대로 받지 않고 한 줄씩 한국어 원문, 슬롯 설명, 같은 말을 쓰는 다른 줄과 대조합니다(W85 ③).
   * 감수자가 적은 글자 수는 믿지 않고 다시 잽니다. 상한 판정은 검사기가 합니다.
   * 고쳐서 받을 줄은 수정안 칸을 고치고, 받지 않을 줄은 `writing 판정` 칸에 이유를 적습니다. 같은 말을 쓰는 다른 줄도 함께 맞춥니다.
   * 묶음 탭의 첫 줄(칸 머리)이 망가져 있으면 다시 읽기가 멈춥니다. 원래 머리로 고친 사본으로 읽습니다.
5. **다시 읽기(writing):** 먼저 `--dry-run`으로 결과만 보고, 이어 실제로 반영합니다.
   ```
   uv run --project docs/identity/writing/tools mlw review-import docs/identity/writing/content <받은 시트.xlsx> --dry-run
   uv run --project docs/identity/writing/tools mlw review-import docs/identity/writing/content <받은 시트.xlsx>
   ```
   * 결과는 받은 시트 옆 `<이름>-result.xlsx`의 `반영 결과` 칸과, 출력의 이유별 수입니다.
   * `용어 표기가 바뀜`과 `용어 분류` 행은 같은 용어가 다른 곳에도 있을 수 있어 writing이 `glossary`와 맞춰 직접 고칩니다.
   * `검사:` 이유는 상한, slop, 금지 문자 같은 검사에 걸린 것입니다. 감수자와 다른 표현을 정하거나 상한을 design에 요청합니다.
   * 반영한 뒤 생성 문서(ARB, 스토어, 웹 JSON)가 다시 만들어지므로 함께 commit하고, 받는 쪽(app, server, web)에 알립니다.
