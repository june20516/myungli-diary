# 제품 지도 (D45)

저장소를 원본으로 만드는 비공개 claude.ai 페이지입니다: **https://claude.ai/artifact/GFLHjAufPE6F4qPyssdfsC**

* 탭: 노선도(기본) · 화면 · 정체성 · 로직 · 산출물 · 아이디어 · 결정. 역이나 화면, 아이디어를 누르면 시트로 상세가 열립니다.
* 크게 보기: 산출물 이미지를 누르거나 노선도·로직의 "크게 보기"를 누르면 확대 창이 열립니다(축소·맞춤·확대, Ctrl+휠, +/- 키).
* 설계: `docs/specs/2026-10-10-collab-workflow-design.md` §7
* 레이아웃 선택 기록: `docs/artifacts/index.json`의 `product-map-layout`

로직 탭의 흐름도는 데이터가 아니라 페이지 틀에 있습니다. 엔진 판정 흐름(D19 등)이 바뀌면 `page/index.html`의 mermaid 블록을 고칩니다.

## 무엇을 읽나
`build_map_data.py`가 아래를 읽어 `data.json`을 만들고, 산출물 이미지를 `images/<저장소 경로>`로 복사합니다.

| 원본 | 지도 영역 |
| --- | --- |
| `docs/roadmap.md` 마일스톤 표, "현재 진행 순서" | 노선도, 진행 순서 |
| 모든 결정 로그(D·C·S·A·W·V) | 결정 |
| 모든 `artifacts/index.json`과 이미지 | 산출물, 역·화면 상세 |
| `docs/identity/README.md` | 정체성, 머리글 컨셉 문장 |
| `docs/ia/screens.json` (IA, 없으면 MVP 임시 화면 목록) | 화면(탭별 묶음, 슬롯·컴포넌트·상태·경로 상세) |
| `docs/ideas.md`, 그 `검토` 상태가 가리키는 문서의 첫 제목·`상태:` 줄 | 아이디어(흐름 보드: 대기 → 검토 중 → 채택 → 보류·기각) |
| `gh issue list` (실패하면 빈 목록) | 열린 Issue, 역 상세 |

## 갱신 (지휘 세션 정기 일과)
1. 지휘 worktree를 `main` 최신으로 맞춥니다: `git fetch origin && git merge origin/main`
2. 데이터를 만들고 페이지를 함께 둡니다. 출력 디렉터리는 세션 scratchpad를 씁니다.
   ```
   OUT=<scratchpad>/product-map
   rm -rf "$OUT" && python3 -I tools/product-map/build_map_data.py . "$OUT"
   cp tools/product-map/page/index.html "$OUT/"
   ```
3. Artifact를 **같은 URL로** 다시 publish합니다: `url`에 위 주소, `file_path`에 `$OUT/index.html`, `root`에 `$OUT`, `files`에 `data.json`과 `images/` 아래 모든 파일. `icon`은 넘기지 않습니다.
4. 페이지 틀(`page/index.html`)을 바꿨다면 PR로 합칩니다. 데이터만 바뀐 갱신은 commit할 것이 없습니다.

## 테스트
`cd tools/product-map && python3 -I -m unittest -q`
