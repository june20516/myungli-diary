/// 컴포넌트 계약(5.0.0)에 있으나 아직 구현하지 않아 `implementedComponents`에 없는
/// 컴포넌트 id → 이유와 담당 task(DS1 화면 따라잡기 계획).
///
/// 컴포넌트를 만드는 task가 `implementedComponents`에 올리면서 여기서 지웁니다. 등록한 id가
/// 여기 남아 있거나, 여기에도 등록부에도 없는 계약 id가 있으면 계약 대조 테스트가 실패합니다
/// (ratchet). 단계 7(Task 23~24)이 끝나면 비어야 하고, Task 27이 빈 맵을 확인합니다.
const Map<String, String> knownPendingComponents = {
  'luck-pillar': '대운, 세운 기둥(compact, column) 새 컴포넌트 (Task 12)',
  'diary-summary': '나 탭 회고 집계 새 컴포넌트 (Task 13)',
  'date-header': '오늘, 그날 시트 날짜 머리 새 컴포넌트 (Task 15)',
  'tag-sentence-list': '오늘 사주 기운 태그 문장 목록 새 컴포넌트 (Task 15)',
  'date-block': '일기 쓰기 날짜 블록 새 컴포넌트 (Task 19)',
  'fortune-verdict': '그날 시트 길흉판정 새 컴포넌트 (Task 21)',
  'score-row': '길흉판정 내역 줄 새 컴포넌트 (Task 21)',
  'birth-info-row': '사주 표 머리 출생 정보 줄 새 컴포넌트 (Task 23)',
  'band-table': '만세력 띠 표 새 컴포넌트 (Task 23)',
  'stage-strip': '12운성 띠 새 컴포넌트 (Task 23)',
};

/// 구현은 있으나 5.0.0 계약을 아직 따라잡지 않은 대조 → 이유와 담당 task.
///
/// 키는 대조 이름(`<컴포넌트 id> <대조>`)입니다. 대기 중인 대조는 5.0.0 값으로 써 두고
/// 아직 실패해야 합니다. 담당 task가 구현을 고쳐 대조가 통과하면 테스트가 "대기 목록에서
/// 지우세요"로 실패하므로(ratchet) 그때 여기서 지웁니다. Task 27이 빈 맵을 확인합니다.
const Map<String, String> knownPendingChecks = {
  'lucky-card spec':
      '변형 tag 삭제(대표 태그는 hanja-tag, V78). 오늘 화면이 쓰는 칩이라 '
      '오늘 재구성과 함께 (Task 15)',
  'diary-row day group':
      '묶음 카드 맨 위 배지를 날의 성격 dayKind hanja-tag로, order와 dayKind '
      'marginBottom (V81, Task 18)',
  'diary-editor spec':
      '본문 초점 중 키보드 내리기 버튼(focused, keyboard.dismiss, F-013) '
      '(V68, Task 19)',
  'diary-row entries head':
      '그날 시트 일기 머리를 section-header가 맡고 entries head는 그리지 않음 '
      '(V85, Task 22 그날 시트 재구성)',
  'manse-table spec':
      'loading 뼈가 기준 줄 + band-table 뼈라 band-table이 있어야 함 '
      '(V89, Task 23)',
  'daeun-table spec':
      'states.current, thisYear 삭제와 luck-pillar 뼈 loading '
      '(V90, Task 24 대운과 세운 줄 재구성)',
};
