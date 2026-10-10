# 요청함 (Coordination)

서브 프로젝트 사이의 요청과 보고를 문서로 주고받는 곳입니다. 규칙은 `docs/workflow.md` §5.2에 있습니다.

* 파일 이름: `YYYY-MM-DD-<보내는 쪽>-to-<받는 쪽>-<짧은 주제>.md`
  * `<보내는 쪽>`/`<받는 쪽>`: `root`, `core`, `server`, `app`
* 형식: [`TEMPLATE.md`](TEMPLATE.md)
* 상태: `open` → `accepted` / `rejected` (지휘 세션) → `done` (받는 쪽)
* 완료 보고(`<서브 프로젝트>-to-root`)는 `done`으로 바로 써도 됩니다.
* 끝난 문서는 지휘 세션이 `archive/`로 옮깁니다.

## 열린 문서
(지휘 세션이 세션을 시작할 때 이 디렉터리의 `open`·`accepted` 문서를 확인합니다.)
