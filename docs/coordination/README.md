# 요청함 (보관소)

**2026-10-10부터 요청함은 GitHub Issues입니다(D44).** 이 디렉터리는 이관 전 문서의 보관소입니다. 규칙은 `docs/workflow.md` §5.2에 있습니다.

## Issue로 요청·보고하기
* 양식으로 엽니다: `gh issue create --template request.yml` (`report.yml`, `notice.yml`, `task.yml`)
* 내 앞으로 온 것 보기: `gh issue list --label to:<단위>` (단위: `root`, `core`, `server`, `app`, `writing`, `design`)
* 라벨
  | 라벨 | 뜻 |
  | --- | --- |
  | `from:<단위>`, `to:<단위>` | 보내는 쪽, 받는 쪽 |
  | `kind:request`·`kind:report`·`kind:notice`·`kind:task` | 요청, 보고, 공지, 코드가 아닌 지속 작업 |
  | `blocking` | 다른 작업을 막고 있음 |
  | `accepted`, `rejected` | 지휘 세션이 수락, 거절 |
* 마일스톤은 로드맵 ID(`docs/roadmap.md`)입니다.
* Issue에서 정한 결정은 결정 로그(D·C·S·A·W·V)에 적고, 그 번호를 Issue에 남깁니다.

## 이 디렉터리
* 이관 당시 열려 있던 문서는 맨 위에 "이관됨: GitHub Issue #N" 표시를 달고 그대로 둡니다. 진행 중인 세션이 이 경로를 안내받았기 때문입니다. Issue가 닫히면 지휘 세션이 `archive/`로 옮깁니다.
* 끝난 문서는 `archive/`에 있습니다.
* `TEMPLATE.md`는 이관 전 형식이며, 새 문서는 만들지 않습니다.
