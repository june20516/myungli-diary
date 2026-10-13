# 저장소 감시 (지휘 세션)

지휘 세션이 열려 있는 동안 PR·Issue·main `ci-gate`의 변화를 1분마다 비교해, 바뀐 것만 한 줄씩 알립니다. GitHub webhook 없이 `gh` 조회로 동작합니다.

## 띄우기
지휘 세션은 **세션을 열면 사용자가 말하지 않아도** Claude Code의 Monitor로 띄웁니다.

* command: `tools/repo-watch/watch.sh <세션 scratchpad>/repo-watch-state`
* timeout: 최대(30분). 만료 알림이 오면 같은 명령으로 바로 다시 띄웁니다. 직전 상태는 상태 디렉터리의 `prev`에 남아 있어 그사이 변화도 다음 비교에서 알립니다.

## 알림을 받으면
1. 전체 현황을 다시 봅니다: 병합·열린 PR, 열린·최근 닫힌 Issue, main `ci-gate`, 원격 브랜치.
2. 정기 일과(루트 `CLAUDE.md`)에서 해당하는 일을 처리합니다. PR 병합은 사용자가 합니다.

## 출력
`변화: PR #<번호> <OPEN|MERGED|CLOSED> <제목>`, `변화: Issue #<번호> <OPEN|CLOSED> <제목>`, `변화: main-ci <sha> <status> <conclusion>`. 조회가 하나라도 실패한 회차는 건너뜁니다.
