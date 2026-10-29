# 명리일기 모노레포

이 파일은 저장소의 **모든 세션**이 읽습니다. 서브 프로젝트 디렉터리에서 시작한 세션도 함께 읽습니다. 상세 규약은 [`docs/workflow.md`](docs/workflow.md)에 있으며, 작업을 시작하기 전에 반드시 읽습니다.

## 나는 어떤 세션인가
* 작업 디렉터리가 **본 저장소(`myungli-diary`) 루트**면 → **지휘 세션**입니다. 아래 "지휘 세션" 절을 따릅니다. 단위 worktree(`../myungli-diary-<단위>`)의 루트는 지휘 세션이 아닙니다.
* 작업 디렉터리가 `core/`, `server/`, `app/` 아래면 → 그 **서브 프로젝트 세션**입니다. 그 디렉터리의 `CLAUDE.md`를 따르고, 자기 소유 경로(`docs/workflow.md` §2) 밖은 고치지 않습니다.
* 작업 디렉터리가 `docs/identity/writing/` 또는 `docs/identity/design/` 아래면 → 그 **작업 단위 세션**(writing / design)입니다. 서브 프로젝트 세션과 같은 규칙을 따릅니다.

## 공통 규칙
* 서브 프로젝트끼리는 **계약 파일**(`docs/contracts/README.md`)과 **요청함**(GitHub Issues, `docs/workflow.md` §5.2)으로만 주고받습니다. 상대 서브 프로젝트의 코드를 직접 고치지 않습니다.
* 제품 결정의 기준은 [`docs/decisions.md`](docs/decisions.md)(D1~)입니다. 서브 프로젝트 결정이 이와 부딪히면 구현을 멈추고 요청함으로 올립니다.
* spec과 계획은 서브 프로젝트의 `docs/specs/`, `docs/plans/`에 둡니다. 작업 단위는 `docs/identity/<writing|design>/specs/`, `plans/`에 둡니다. suberpowers 기본 경로(`docs/suberpowers/…`)는 쓰지 않습니다.
* 같은 작업 디렉터리에서 세션 두 개를 동시에 돌리지 않습니다. 동시에 진행하려면 `git worktree`를 씁니다.
* **사용자에게 보이는 글에는 긴 대시(U+2014 —), 범위 대시(U+2013 –), 가운뎃점(U+00B7 ·)을 쓰지 않습니다(D93).** 화면 문구, ARB와 콘텐츠 원고, 공유 이미지, 알림, 스토어 문구, 법적 문서 원문, server가 내주는 페이지가 해당합니다. 나열은 쉼표나 "와/과", 범위는 `~`를 씁니다. commit, PR, Issue, spec, plan, 결정 로그처럼 작업에만 남는 글은 괜찮습니다.
* **로컬 값(D98):** 저장소에 넣지 않는 비밀, 설정 파일, 개발용 키의 원본은 저장소 밖 `${MYUNGLI_LOCAL_DIR:-$HOME/.config/myungli}/<단위>/<환경>/`에 두고, 단위 `.local/`에는 버려도 되는 산출물만 둡니다. 세션은 비밀 파일을 경로로만 다루고 내용을 출력하지 않습니다. 규칙과 대장은 [`docs/local-values.md`](docs/local-values.md)입니다.
* **공개 저장소(D74):** Issue·PR·커밋·문서·코드(fixture 포함)에 가격·수익 수치 같은 내부 정보를 적지 않습니다. 제품 배경 원문·수익화 기록·아이디어 함은 비공개 저장소에 있고, 링크하지 않고 "비공개 기록 `…`"으로 글로만 적습니다. 근거가 필요하면 지휘에게 Issue로 묻습니다.
* **세션을 열면:** `git fetch origin && git merge origin/main` 뒤 `gh issue list --label to:<단위>`를 봅니다. 그중 `drift` Issue(계약 변경 따라잡기)가 있으면 다른 일보다 먼저, 다음 PR에서 맞춥니다(`docs/workflow.md` §6.1).
* **사용자에게 답할 때 결정 번호(D·C·S·A·W·V)와 Issue·PR 번호(`#n`)에는 맥락에 맞는 짧은 요약을 붙입니다.** 예: "D90 ①(일기 보기의 그날 성격은 쓸 때 기록한 값)", "#564(구매 줄 구분자 삭제와 새 슬롯 상한)". 사용자가 번호를 따로 찾아보지 않아도 대화만으로 알 수 있게 합니다. 같은 답에서 다시 나오면 번호만 써도 됩니다. Issue, PR, commit, 문서처럼 링크로 따라갈 수 있는 글에는 붙이지 않아도 됩니다.
* **계약 버전과 상태의 기준은 `docs/contracts/README.md` 하나입니다.** 단위 `CLAUDE.md`에는 버전을 적지 않습니다. 주는 쪽은 계약을 바꾸는 PR에서 그 표의 자기 행을 직접 고칩니다.
* **병합:** 단위 PR은 사용자가 병합합니다. 지휘가 올린 `root/` PR은 `ci-gate` 통과 뒤 지휘가 병합합니다.

## 지휘 세션
* 맡는 일: 통합 로드맵([`docs/roadmap.md`](docs/roadmap.md)), 계약 목록 관리, 요청함(Issues) 분류(`accepted`/`rejected` 라벨), 둘 이상에 걸친 결정 기록, 서브 프로젝트 착수 안내(각 `CLAUDE.md`의 "현재 상태"와 "다음 할 일" 초안), 통합 시점 판단.
* 하지 않는 일: 서브 프로젝트 코드를 구현하지 않습니다.
* **저장소 감시**(세션을 열면 사용자가 말하지 않아도): `tools/repo-watch/watch.sh`를 Monitor로 띄우고, 만료되면 다시 띄웁니다. 변화 알림이 오면 전체 현황을 다시 보고 아래 일과에서 해당하는 일을 처리합니다(`tools/repo-watch/README.md`).
* **정기 일과**(세션을 열 때마다):
  1. 요청함 정리(`gh issue list`). 닫는 조건은 `docs/workflow.md` §5.2입니다.
     * 새 요청에 `accepted`/`rejected` 라벨을 붙입니다.
     * 완료 보고(`kind:report`)를 확인하고 닫습니다.
     * 처리했다는 코멘트가 달렸는데 열려 있는 Issue를 닫거나, 받는 쪽에 닫아 달라고 남깁니다(종류와 상관없이 지휘가 대신 닫을 수 있음, D78).
     * 일을 시키는 공지는 `kind:request`로 바꿉니다.
     * 닫힌 Issue의 `docs/coordination/` 원문을 `archive/`로 옮깁니다(예외는 `docs/coordination/README.md`).
     * 열린 `drift` Issue(`gh issue list --label drift`)를 확인하고, 받는 쪽 단위의 다음 할 일 맨 앞에 둡니다(`docs/workflow.md` §6.1).
     * 새로 병합된 단위 결정 행(C·S·A·W·V)의 `사용자 영향` 표시를 확인합니다. `#<n>`이면 루트 결정·IA·원고 요청·수집·보관 대장에 반영하고, `없음`이 맞는지도 봅니다(D87).
     * 외부 준비물 대장(`docs/external-prep.md`)을 봅니다. 때가 된 항목은 `to:user`·`kind:prep` Issue로 안내하고, 사용자에게 지금 준비할 것을 알립니다. 받은 값은 단위에 전달합니다(D91 ②, `docs/workflow.md` §5.3).
     * 열린 검수 피드백 항목(`docs/review/items.md`의 `보냄`)의 작업 Issue가 모두 닫혔으면 `끝남`으로 바꿉니다(`docs/review/README.md`).
  2. `docs/roadmap.md` "현재 진행 순서"를 갱신합니다.
  3. 제품 지도를 갱신합니다(`tools/product-map/README.md`).

## 문서 위치
| 문서 | 위치 |
| --- | --- |
| 제품 배경 원문 (00~06) | 비공개 내부 저장소 `../myungli-diary-internal`의 `background/` (D74) |
| 제품·아키텍처 결정 | `docs/decisions.md` |
| 통합 로드맵 | `docs/roadmap.md` |
| 외부 준비물 대장 | `docs/external-prep.md` |
| 로컬 값 보관 규칙과 대장 | `docs/local-values.md` |
| 제품 아이디어 함 | 내부 저장소 `ideas.md` |
| 수익화 결정 체계·시장 조사 | 내부 저장소 `business/` |
| 계약 목록 | `docs/contracts/README.md` |
| 제품 지도 (비공개 페이지) | https://claude.ai/artifact/GFLHjAufPE6F4qPyssdfsC (갱신: `tools/product-map/README.md`) |
| 요청함 | GitHub Issues (이관 전 문서 보관: `docs/coordination/`) |
| 엔진 위키·spec·계획·원전 근거 | `core/docs/` |
| 정체성 기준 (브랜드·라이팅·디자인) | `docs/identity/` |
