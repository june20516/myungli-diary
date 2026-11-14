# design — 디자인 시스템

이 디렉터리에서 시작한 세션은 **design 세션**입니다. 루트 [`CLAUDE.md`](../../../CLAUDE.md)와 [`docs/workflow.md`](../../workflow.md)의 공통 규약을 함께 따릅니다. 기준 문서는 [`docs/identity/README.md`](../README.md)(브랜드 기반)입니다.

## 범위
명리일기의 시각 정체성, 디자인 토큰, 컴포넌트 명세를 만듭니다. 구현(Flutter)은 app이 합니다. 상세는 [브랜드 기반 spec §7·§9](../../specs/2026-10-10-brand-foundation-design.md)에 있습니다.

| 산출물 | 받는 쪽 | 마일스톤 |
| --- | --- | --- |
| 시각 정체성: 로고 방향, 그라데이션 규칙, 오행 팔레트, 타이포 | 모두 | V0 |
| 디자인 토큰 (`tokens/`, 데이터 파일) | app (Dart 코드 생성) | V1 freeze |
| 캘린더 길흉 표시 규칙 (엔진 spec §8 `LuckLevel` 3단계, 루트 미결에서 이관). 점이 아니라 날짜 칸 채우기(결정 V10) | app | V1 |
| 컴포넌트 명세 (`components/`): IA 컴포넌트 + 상호작용 패턴·요소 | app | V2 |

* 비공개 기록 `background/06-design-system.md`(D74)는 V0의 입력이었습니다. V0 결과가 정체성 기준으로 06을 대체합니다.
* 그라데이션은 조건부 선택입니다(README "시각 방향"). 화면 바탕 그라데이션은 `gradient.today` 토큰 하나로 묶어, 리뉴얼할 때 그 토큰만 바꾸면 되게 합니다. 열린 근거 표시는 따로 `gradient.unlocked`(결정 V111, 2026-11-10)를 씁니다.

## 고칠 수 있는 곳
`docs/identity/design/`, GitHub Issues(요청·보고 작성, `gh issue list --label to:design`). 그 밖은 읽기만 합니다. 세션을 끝낼 때는 `docs/workflow.md` §3의 마무리 체크리스트를 따릅니다.

## 계약
| 계약 | 역할 | 상대 |
| --- | --- | --- |
| 브랜드 기반 (`docs/identity/README.md`) | **사용** | 지휘 |
| MVP 화면 목록 (IA, D39) | **사용** (V2의 선행 조건) | 지휘 |
| 디자인 토큰 (`tokens/`) | **제공** (V1 freeze, 그 뒤는 추가만) | app |
| 컴포넌트 명세 (`components/`) | **제공** | app |
| 글자 수 상한 | **주고받음** (요청함) | writing |

계약 버전과 상태는 [`docs/contracts/README.md`](../../contracts/README.md)를 봅니다. 이 파일에는 버전을 적지 않습니다.

## 현재 상태
진행 중인 일만 적고, 병합하면 지웁니다(`docs/workflow.md` §3 마무리 2번). 병합된 일의 경과는 PR 본문, 결정 행([`decisions.md`](decisions.md)), git에 있습니다.

* **H1 기준 문서 정리 #1168** (브랜치 `design/h1-doc-slimming-1168`, PR #1172, D131): 이 파일의 병합된 경과를 지우고, 통째로 대체된 결정 V35 원문을 [`decisions-history.md`](decisions-history.md)로 옮김. 이 파일이 크기 상한 아래로 내려와 docs-check가 면제를 지우라는 오류를 내며, 면제는 지휘가 지움.

## 기준 문서와 도구
* 시각 정체성: [`visual-identity.md`](visual-identity.md)(시각에 관해서는 비공개 기록 06을 대체). 색 값의 출처는 [`tools/palette.py`](tools/palette.py)(`--check`로 대비 검사).
* 토큰: [`tokens/`](tokens/README.md). 생성은 저장소 루트에서 `python3 docs/identity/design/tools/tokens.py`이고 손으로 고치지 않습니다. 추가만인지 대조하는 이전 버전 토큰은 `tools/fixtures/*-<버전>.tokens.json`에 둡니다(`test_tokens.py`).
* 컴포넌트 명세: [`components/`](components/README.md) JSON(사실) + MD(설명). 검사는 저장소 루트에서 `python3 docs/identity/design/tools/components.py`(IA, 토큰 참조, 요소, 패턴, 상태 대응표, 짝 MD). 판 기록(지움과 이름 바뀜)은 `components/README.md`에 있습니다.
* 글자 수 상한: [`lengths.md`](lengths.md), 도구 `tools/lengths.py`. 표는 도구 출력과 같아야 합니다.
* 시안 도구: `tools/token_css.py`(토큰을 CSS 변수로, `artifacts/ds1/tokens.css`), `tools/rules_audit.py`(간격 전수 점검), `tools/phosphor_names.txt`(Phosphor 이름 목록). 시안 기록은 [`artifacts/index.json`](artifacts/index.json).
* 로고: 원본 [`logo/`](logo/), 견본 [`specimen/index.html`](specimen/index.html). 옛 로고 모음(`artifacts/2026-10-10-v0-logo-final.*`)은 기록 고정본입니다.
* 한자 대체 글꼴: writing이 Pretendard JP에 없는 한자를 새로 쓰면 `tools/hanja_supplement.py`로 `Myungli Hanja Supplement`를 다시 만듭니다(V121).

## 검사 방법
* 테스트: 저장소 루트에서 `uv run --with pytest==8.3.5 --with fonttools==4.54.1 pytest docs/identity/design/tools -q`(1초 안쪽)
  * 반복 중 빠른 경로: 바꾼 도구의 테스트 파일만 돌립니다. 예: 명세는 `... pytest docs/identity/design/tools/test_components.py -q` + `python3 docs/identity/design/tools/components.py`, 글자 수는 `test_lengths.py`, 토큰은 `test_tokens.py test_dtcg.py`.
* CI `design.yml`의 `mode`: `own`은 빠른 검사 전체, `drift`와 `gate`는 계약(IA, writing 원고)을 읽는 검사만 돕니다(D81).
* 측정 글꼴(고운돋움, Zen Maru Gothic, Pretendard)은 저장소에 넣지 않습니다. 받기: `python3 docs/identity/design/tools/fonts.py --font-dir .suberpowers/fonts`(주소, sha256 고정).
  * 로컬에서 글꼴이 없으면 글자 수 표 비교와 워드마크 테스트 4개가 **skip**됩니다. CI는 글꼴을 받아 돌리고, 없으면 실패합니다(`DESIGN_FONTS_REQUIRED=1`).
* 앱 아이콘 래스터 원본(`logo/*.png`, V99)은 `logo/source/` 그림에서 만듭니다: `uv run --with pillow==11.0.0 --with numpy==2.1.3 --with scipy==1.14.1 python docs/identity/design/tools/app_icon.py`(resvg 필요). `logo/app-icon.json`을 함께 고칩니다. PNG는 바이너리라 이력이 커지므로 그림을 바꾸는 의도가 있는 PR에서만 다시 만들어 커밋합니다.
* 워드마크를 바꾸면 `uv run --with fonttools==4.54.1 python docs/identity/design/tools/wordmark.py --font .suberpowers/fonts/GowunDodum-Regular.ttf --out-dir docs/identity/design/logo` 뒤 위 `app_icon.py`로 가로 조합 PNG를 다시 만듭니다.

## 다음 할 일
1. **H1 #1168 마무리:** PR 병합 뒤 지휘가 docs-check 면제를 지우는지 봅니다.

그 밖에는 대기합니다. 아래 일이 생기면 엽니다.
2. **app 대응 지원:** app이 명세로 만들 수 없는 곳이나 저사양 Android 성능 결과를 `to:design` Issue로 보내면 컴포넌트 계약 버전 규칙대로 고칩니다.
3. W1 원어민 검수 문장이 나오면 일본어 줄 간격(1.75 / 1.7)을 다시 확인합니다.
4. app이 토큰 형식 변경을 요청하면 계약 버전 규칙(`tokens/README.md`)대로 대응합니다.
