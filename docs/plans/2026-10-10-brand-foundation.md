# 브랜드 기반 확정과 정체성 작업 단위 착수 Implementation Plan

> **agentic worker에게:** REQUIRED SUB-SKILL: 이 plan을 task 단위로 구현하려면 suberpower:subagent-driven-development(권장) 또는 suberpower:executing-plans를 사용하세요. Step은 추적을 위해 checkbox(`- [ ]`) 문법을 사용합니다.

**Goal:** 브랜드 기반 확정본(B0)을 `docs/identity/README.md`로 만들고, writing·design 작업 단위가 자기 세션에서 바로 시작할 수 있도록 규약·계약·로드맵·착수 안내를 갖춥니다.

**Architecture:** 코드가 없는 문서 작업입니다. 확정본은 spec §3~§7과 부록 B를 "기준" 문체로 옮긴 것이고, 나머지 task는 기존 지휘 세션 문서를 spec §10~§12대로 고칩니다. 각 task는 아래 "공통 검증"의 링크 검사와 task별 grep 검사로 끝납니다.

**Tech Stack:** Markdown, git, Python 3 표준 라이브러리(검증 스크립트)

**Spec:** `docs/specs/2026-10-10-brand-foundation-design.md` (D36~D40)

## Global Constraints

* 작업 위치: worktree `/Users/bran/personal/myungli-diary-root`, 브랜치 `root/brand-foundation`. 원래 checkout(`/Users/bran/personal/myungli-diary`)은 core 세션이 쓰고 있으므로 건드리지 않습니다.
* 고치는 파일은 지휘 세션 소유 경로(`docs/workflow.md` §2)와 새 `docs/identity/`뿐입니다. `core/`, `server/` 아래는 고치지 않습니다. `app/CLAUDE.md`는 지휘 세션이 쓰는 착수 안내라 고칠 수 있습니다.
* 문서는 한국어 경어체(합니다체)로 씁니다. 기존 문서의 표·목록 형식을 따릅니다.
* 새 이름은 spec 그대로 씁니다: 깊이 `surface`/`explain`/`evidence`, 기본 깊이, 호칭, 용어 토큰, 문장 유형 `advice`/`state`/`care`, 결정 접두어 W#·V#, 마일스톤 B0·IA·W0·V0·V1·V2.
* 문서 본문에 Easy/Pro를 새로 쓰지 않습니다(D37). 대응 관계를 설명하는 문장만 예외입니다.
* 작업 단위의 spec·plan 경로는 `docs/identity/<writing|design>/specs/`, `.../plans/`입니다(`docs/`를 한 번 더 두지 않음).
* 요청함 이름 규칙의 보내는 쪽·받는 쪽 값에 `writing`, `design`을 추가합니다.
* commit 메시지 범위는 `docs(root): …`이고, 끝에 세션 attribution 두 줄(Co-Authored-By, Claude-Session)을 붙입니다.
* push와 main 병합은 사용자가 요청할 때만 합니다.

## Review Focus

1. 다른 문서가 가리키던 06 디자인 시스템이나 "캘린더 점 색은 지휘 세션 미결" 같은 옛 안내가 남아 있는 경우 → 새 작업 단위 세션이 그 안내를 따라가서는 안 됩니다. Task 4·5의 grep 검사가 남은 곳을 0건으로 만듭니다.
2. writing·design 세션이 자기 CLAUDE.md만 읽고 시작해도 소유 경로와 첫 할 일을 알 수 있어야 합니다. 루트 CLAUDE.md는 cwd에서 위로 올라가며 읽히므로, 세션 판별 규칙이 `docs/identity/writing` 같은 깊은 경로도 잡아야 합니다(Task 4 검사).
3. 확정본 README 자체가 부록 B의 slop 패턴(느낌표, 정의형 소개, 자기 형용)을 어기면 기준 문서로서 신뢰를 잃습니다. Task 1의 검사가 이를 잡습니다.
4. 상대 경로 링크가 깊이가 다른 디렉터리(`docs/identity/writing/CLAUDE.md` → `../../workflow.md`)에서 깨질 수 있습니다. 모든 task가 공통 링크 검사로 끝납니다.
5. 결정 번호(D36~D40)와 마일스톤 ID가 문서마다 다르게 적히는 경우. Task 6의 교차 검사가 확인합니다.

## 공통 검증

모든 task의 마지막 검증 step에서 실행합니다. 저장소 안의 `.md` 파일에서 상대 경로 링크가 실제 파일을 가리키는지 확인합니다.

```bash
cd /Users/bran/personal/myungli-diary-root && python3 -I - <<'EOF'
import re, pathlib, sys
root = pathlib.Path('.')
bad = []
for md in root.rglob('*.md'):
    if '.suberpowers' in md.parts or '.git' in md.parts:
        continue
    for target in re.findall(r'\]\(([^)#\s]+)(?:#[^)]*)?\)', md.read_text(encoding='utf-8')):
        if re.match(r'[a-z]+://', target) or target.startswith('mailto:'):
            continue
        if not (md.parent / target).exists():
            bad.append(f'{md}: {target}')
print('\n'.join(bad) or 'OK: 깨진 링크 없음')
sys.exit(1 if bad else 0)
EOF
```

Expected: `OK: 깨진 링크 없음`

---

### Task 1: 브랜드 기반 확정본 (B0)

**Files:**
- Create: `docs/identity/README.md`

**Interfaces:**
- Consumes: spec §3~§7, 부록 B, 부록 C
- Produces: `docs/identity/README.md`의 절 제목(다른 문서가 `#` 없이 파일 단위로 링크합니다): `## 이 문서의 위상`, `## 컨셉과 포지셔닝`, `## 성격`, `## 원칙`, `## 공용 용어와 부품`, `## 시각 방향`, `## slop 패턴`, `## 작업 단위`

- [ ] **Step 1: README 작성**

절 구성과 내용:
* `# 명리일기 정체성 기준`
* `## 이 문서의 위상`: "지금 유효한 정체성 기준"이며 정체성에 관해서는 `docs/background/` 00·03·06을 대체한다(D38). 바꾸는 쪽은 지휘 세션이고, 근거는 spec 링크(`../specs/2026-10-10-brand-foundation-design.md`). writing·design 작업 단위는 이 문서를 계약("브랜드 기반")으로 사용한다.
* `## 컨셉과 포지셔닝`: spec §3 그대로. 컨셉 문장은 인용 블록으로 정확히 "오늘 일진을 내 사주에 맞춰 풀어주는 일기 앱".
* `## 성격`: spec §4의 표와 존재 비유, 문장 유형 세 가지.
* `## 원칙`: spec §5의 원칙 0~3(번호 0·1·2·3으로 다시 매김: 0 맥락과 빈도, 1 낮은 주의력, 2 강조는 UI, 3 번역투 금지).
* `## 공용 용어와 부품`: spec §6. 각 항목에 결정 번호(D36, D37, D40)를 붙임.
* `## 시각 방향`: spec §7과 부록 C의 색 값("시안 값, 확정은 design V1"이라고 명시).
* `## slop 패턴`: 부록 B의 8개 항목. "라이팅 시스템이 이 목록에서 출발해 넓힌다"는 문장 한 줄.
* `## 작업 단위`: `writing/CLAUDE.md`, `design/CLAUDE.md` 링크와 한 줄 설명(Task 2·3이 만듦).

spec의 근거 서술(라운드 번호, "사용자가 골랐다")은 옮기지 않습니다. 기준 문서는 규칙만 담고, 근거는 spec 링크로 대신합니다.

- [ ] **Step 2: README가 자기 slop 패턴을 어기지 않는지 검사**

Run:
```bash
cd /Users/bran/personal/myungli-diary-root && grep -nE '!|[😀-🙏✨🌊]|Easy|Pro\b' docs/identity/README.md | grep -v 'Easy는\|Pro는\|대체' ; echo "exit=$?"
```
Expected: 출력 줄 없이 `exit=1` (느낌표·이모지·새 Easy/Pro 사용 0건). 예문 인용 속 "완전 좋은 날" 같은 나쁜 예는 느낌표 없이 적습니다.

- [ ] **Step 3: 공통 검증 실행**

Task 2·3 전이므로 `writing/CLAUDE.md`, `design/CLAUDE.md` 두 링크만 깨진 것으로 나오면 정상입니다. 그 밖의 깨진 링크는 0건이어야 합니다.

- [ ] **Step 4: Commit**

```bash
git add docs/identity/README.md
git commit -m "docs(root): 브랜드 기반 확정본 docs/identity/README.md (B0)"
```

### Task 2: writing 작업 단위 착수 안내

**Files:**
- Create: `docs/identity/writing/CLAUDE.md`
- Create: `docs/identity/writing/decisions.md`

**Interfaces:**
- Consumes: Task 1의 `docs/identity/README.md`
- Produces: writing 세션의 시작 문서. 브랜치 이름 `writing/system-foundation`

- [ ] **Step 1: `CLAUDE.md` 작성**

`app/CLAUDE.md`와 같은 절 구성:
* `# writing — 라이팅 시스템`: "이 디렉터리에서 시작한 세션은 writing 세션"이며 루트 `CLAUDE.md`(`../../../CLAUDE.md`)와 `../../workflow.md`를 함께 따른다.
* `## 범위`: spec §8 산출물 표(W0·W1 구분 유지), 슬롯 명세 항목 목록, 참고 접근법, 친숙도 검수 절차를 요약하고 spec §8 링크.
* `## 고칠 수 있는 곳`: `docs/identity/writing/`, `docs/coordination/`(작성). 그 밖은 읽기만.
* `## 계약`: 브랜드 기반 **사용**(지휘), 슬롯 명세·검사기 **제공**(server, app), 호칭 접미사·조사 처리 규칙 **제공**(server, W0에서 계약 등록 요청), `core/message_keys.json` **사용**(W1, core C2 이후).
* `## 현재 상태 (2026-10-10, 지휘 세션 작성)`: 설계 시작 전. 슬롯 목록을 채우는 데 필요한 IA(D39)는 지휘 세션이 아직 만들지 않았으므로 W0은 틀·패턴·절차·검사기부터.
* `## 다음 할 일`: ① 읽을 것(`../README.md`, spec, `docs/decisions.md`의 D13·D19~D24·D27·D28·D36~D40, `docs/background/` 00·03) ② 브랜치 `git worktree add ../myungli-diary-writing -b writing/system-foundation --no-track main` 후 그 worktree의 `docs/identity/writing`에서 세션 시작 ③ brainstorming → `specs/` ④ 친숙도 검수 라운드는 사용자와 n지선다로 진행(spec §8).

- [ ] **Step 2: `decisions.md` 작성**

제목 `# writing 결정 로그 (W#)`, 한 줄 설명(루트 결정과 부딪히면 멈추고 요청함으로), `docs/decisions.md`와 같은 열(`| ID | 날짜 | 분류 | 결정 | 근거 |`)의 빈 표.

- [ ] **Step 3: 검사**

Run: `cd /Users/bran/personal/myungli-diary-root && grep -c 'writing/system-foundation\|--no-track' docs/identity/writing/CLAUDE.md`
Expected: `1` 이상. 이어서 공통 검증 → design 링크 하나만 깨진 것으로 나오면 정상.

- [ ] **Step 4: Commit**

```bash
git add docs/identity/writing
git commit -m "docs(root): writing 작업 단위 착수 안내"
```

### Task 3: design 작업 단위 착수 안내

**Files:**
- Create: `docs/identity/design/CLAUDE.md`
- Create: `docs/identity/design/decisions.md`

**Interfaces:**
- Consumes: Task 1의 README
- Produces: design 세션의 시작 문서. 브랜치 이름 `design/visual-identity`

- [ ] **Step 1: `CLAUDE.md` 작성**

Task 2와 같은 절 구성:
* `## 범위`: spec §9 표(V0·V1·V2), 06 원문은 V0의 입력이고 V0 결과가 06을 대체함, 그라데이션은 조건부 선택이라 토큰 하나로 묶어 교체 가능하게 둠, 컴포넌트 목록(데일리 카드 L1, 용어 토큰, 날의 성격 배지, 칩, 시트 단계), 캘린더 길흉 점 색 규칙(루트에서 이관, 엔진 spec §8 `LuckLevel` 3단계).
* `## 고칠 수 있는 곳`: `docs/identity/design/`, `docs/coordination/`.
* `## 계약`: 브랜드 기반 **사용**, 디자인 토큰 **제공**(app, `tokens/`, V1에서 동결), 컴포넌트 명세 **제공**(app), MVP 화면 목록 IA **사용**(지휘, D39, V2 선행 조건), 글자 수 상한 **주고받음**(writing, 요청함).
* `## 현재 상태`: 설계 시작 전. 시안은 지휘 세션 로컬 `.suberpowers/brainstorm/`에만 있으므로 V0에서 다시 그림. 시안 색 값은 README `## 시각 방향`.
* `## 다음 할 일`: 읽을 것(`../README.md`, spec §7·§9, `docs/background/06-design-system.md`, D16·D19·D20·D36·D37), worktree `../myungli-diary-design` + 브랜치 `design/visual-identity`(`--no-track main`), brainstorming → `specs/`. 토큰 파일 형식(JSON 등)과 Dart 코드 생성 방식은 app과 요청함으로 합의.

- [ ] **Step 2: `decisions.md` 작성**

Task 2 Step 2와 같은 형식, 제목 `# design 결정 로그 (V#)`.

- [ ] **Step 3: 검사**

Run: 공통 검증
Expected: `OK: 깨진 링크 없음`

- [ ] **Step 4: Commit**

```bash
git add docs/identity/design
git commit -m "docs(root): design 작업 단위 착수 안내"
```

### Task 4: 세션 규약 개정

**Files:**
- Modify: `CLAUDE.md` (루트) — "나는 어떤 세션인가", "공통 규칙"의 spec 경로 줄, "문서 위치" 표
- Modify: `docs/workflow.md` — §1 역할 표, §2 소유권 표, §3 spec·plan 경로 문단, §4 결정 로그, §5.2 이름 규칙, §6 브랜치 이름
- Modify: `docs/background/README.md`
- Modify: `app/CLAUDE.md` — "디자인" 줄, "다음 할 일"의 캘린더 점 색 줄

**Interfaces:**
- Consumes: Task 1~3이 만든 경로
- Produces: 세션 판별 규칙 "작업 디렉터리가 `docs/identity/writing/` 또는 `docs/identity/design/` 아래면 → 그 작업 단위 세션"

- [ ] **Step 1: 루트 `CLAUDE.md` 수정**

* 세션 판별에 위 규칙을 서브 프로젝트 줄 다음에 추가.
* spec 경로 줄에 "작업 단위는 `docs/identity/<writing|design>/specs/`, `plans/`" 추가.
* 문서 위치 표에 `| 정체성 기준 (브랜드·라이팅·디자인) | docs/identity/ |` 행 추가.

- [ ] **Step 2: `docs/workflow.md` 수정**

* §1 표에 writing 세션(시작 `docs/identity/writing/`, 라이팅 시스템과 콘텐츠의 설계 → 계획 → 실행 → 마무리)과 design 세션(시작 `docs/identity/design/`, 시각 정체성·토큰·컴포넌트 명세) 행 추가. 원칙 문단의 "서브 프로젝트"를 "서브 프로젝트와 작업 단위"로.
* §2 표에 `docs/identity/writing/` → writing, `docs/identity/design/` → design 행 추가. 지휘 소유 목록에 `docs/identity/README.md` 추가.
* §3 경로 문단에 작업 단위 경로 예외 한 문장.
* §4에 writing `W<n>`, design `V<n>` 추가. 파일은 `docs/identity/<단위>/decisions.md`.
* §5.2 값 목록에 `writing`, `design` 추가. `docs/coordination/README.md`의 같은 목록도 수정.
* §6 브랜치 이름에 `writing/<주제>`, `design/<주제>` 추가.

- [ ] **Step 3: `docs/background/README.md`와 `app/CLAUDE.md` 수정**

* background README: D37 안내 다음에 "정체성(컨셉·보이스·시각)에 관해서는 `docs/identity/`가 00·03·06을 대체합니다(D38)." 한 줄과 링크.
* app/CLAUDE.md "디자인" 줄 → "`docs/identity/README.md`(브랜드 기반), 디자인 토큰·컴포넌트 명세는 design 작업 단위가 제공(V1·V2). UI 구현은 V2 이후, 설계는 병행 가능". "캘린더 길흉 점의 색 규칙…지휘 세션에 확인" 줄 → "design V1 토큰에서 정합니다". 범위에 "온보딩: 호칭 필수 입력(D36)", "데일리: 콘텐츠 반응(좋아요) 수집(D40)" 추가. 화면 구성은 지휘 세션의 IA(D39)를 따른다는 줄 추가.

- [ ] **Step 4: 검사**

Run:
```bash
cd /Users/bran/personal/myungli-diary-root && grep -n 'docs/identity' CLAUDE.md docs/workflow.md docs/background/README.md app/CLAUDE.md | wc -l && grep -n '지휘 세션에 확인' app/CLAUDE.md; grep -n 'writing' docs/coordination/README.md | head -2
```
Expected: 첫 숫자 6 이상, `지휘 세션에 확인` 출력 없음, coordination README에 `writing` 한 줄 이상. 이어서 공통 검증 → OK.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/workflow.md docs/background/README.md app/CLAUDE.md docs/coordination/README.md
git commit -m "docs(root): writing·design 작업 단위를 세션 규약에 추가 (D38)"
```

### Task 5: 계약 목록과 로드맵 개정

**Files:**
- Modify: `docs/contracts/README.md`
- Modify: `docs/roadmap.md`

**Interfaces:**
- Consumes: spec §10·§11, D39·D40
- Produces: 계약 행 "브랜드 기반", "MVP 화면 목록 (IA)", "슬롯 명세", "호칭·조사 처리 규칙", 수정된 "디자인 토큰"

- [ ] **Step 1: 계약 목록 수정**

행 추가·수정 (열은 기존 표 그대로):
* 브랜드 기반 | `docs/identity/README.md` | 지휘 | writing, design | - | 확정 (B0) | spec, D38
* MVP 화면 목록 (IA) | (지휘 세션 작성 예정) | 지휘 | app, writing, design | - | 미작성 | D39
* 슬롯 명세 | `docs/identity/writing/` (W0에서 정함) | writing | server, app | - | 미설계 (W0) | spec §8
* 호칭·조사 처리 규칙 | (W0에서 정함) | writing | server (콘텐츠 모듈) | - | 미설계 (W0) | D36
* 디자인 토큰: 원본 위치 `docs/identity/design/tokens/`, 제공 design, 상태 "미설계 (V1에서 동결)", 근거 "spec §9, 06"

- [ ] **Step 2: 로드맵 수정**

* 마일스톤 표에 B0, IA, W0, V0, V1, V2 행 추가(spec §11 표 그대로: 담당·선행 조건·끝나면 열리는 것). W1의 담당을 "writing → server 시드", 선행 조건을 "W0, C2"로. A1 행에 "UI 구현은 V2 이후, 설계는 B0 이후 병행" 추가.
* 병행 가능 구간 문단에 "B0 이후 W0·V0는 서로 기다리지 않음, core·server 흐름과도 독립" 추가.
* 외부 준비물의 "영어·일본어 원어민 검수" 담당을 "사용자 (writing W1)"로.
* 지휘 세션 미결 표: "캘린더 길흉 점의 색 규칙" 행 삭제(→ design V1 이관, 행 대신 표 아래 한 줄로 이관 사실 기록). "MVP 화면 목록 작성 (D39)" 행 추가.

- [ ] **Step 3: 검사**

Run:
```bash
cd /Users/bran/personal/myungli-diary-root && grep -cE '^\| (B0|IA|W0|V0|V1|V2) \|' docs/roadmap.md && grep -c 'docs/identity/design/tokens' docs/contracts/README.md && grep -n '캘린더 길흉 점의 색 규칙 |' docs/roadmap.md
```
Expected: `6`, `1`, 마지막 grep 출력 없음. 이어서 공통 검증 → OK.

- [ ] **Step 4: Commit**

```bash
git add docs/contracts/README.md docs/roadmap.md
git commit -m "docs(root): 정체성 계약과 B0·IA·W0·V0~V2 마일스톤 추가 (D39·D40)"
```

### Task 6: 교차 검사와 넘겨주기

**Files:**
- Modify: 검사에서 어긋남이 나온 파일만

- [ ] **Step 1: 결정 번호·마일스톤 교차 검사**

Run:
```bash
cd /Users/bran/personal/myungli-diary-root && for id in D36 D37 D38 D39 D40; do printf '%s ' $id; grep -rl "$id" --include='*.md' . | grep -v .suberpowers | wc -l; done && grep -c '^| D3[6-9]\|^| D40' docs/decisions.md
```
Expected: 각 ID가 2개 이상 파일에 나오고(결정 로그 + 쓰는 곳), 마지막 숫자 `5`.

- [ ] **Step 2: Easy/Pro 잔존 검사**

Run: `cd /Users/bran/personal/myungli-diary-root && grep -rn 'Easy\|Pro 화면\|Pro 전용' --include='*.md' CLAUDE.md docs/identity docs/workflow.md docs/roadmap.md docs/contracts app/CLAUDE.md`
Expected: D37 대응 설명 문장 외 출력 없음.

- [ ] **Step 3: 공통 검증 실행** → `OK: 깨진 링크 없음`

- [ ] **Step 4: 사용자에게 넘겨주기**

commit 목록(`git log --oneline main..root/brand-foundation`)을 보여주고 다음을 사용자에게 확인합니다. 직접 실행하지 않습니다.
* main 병합과 push 여부. core 세션이 notice(`docs/coordination/2026-10-10-root-to-core-depth-terminology.md`)를 보려면 병합이 필요합니다.
* writing·design 세션 시작 방법: 각 `CLAUDE.md`의 "다음 할 일" ②의 worktree 명령.
* 다음 지휘 세션 작업: IA(D39).
