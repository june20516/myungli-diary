/// 아직 IA `states`를 처리하지 않은 화면 id.
///
/// 계획 2~7이 화면을 만들어 `ScreenSpec.handledStates`를 채울 때마다 해당 id를
/// 지웁니다. 끝난 화면이 남아 있으면 IA 계약 테스트가 실패하고(ratchet),
/// 빈 집합이 목표입니다. 시트 화면은 registry에 없으므로 시트를 만드는 계획이
/// registry에 등록하면서 지웁니다.
const Set<String> pendingStateScreens = {
  'launch',
  'onboard-birth',
  'onboard-time',
  'birthplace',
  'preview',
  'login',
  'consent',
  'today',
  'explain-sheet',
  'evidence-sheet',
  'calendar',
  'day-sheet',
  'event-edit',
  'diary-list',
  'diary-edit',
  'diary-view',
  'tag-diary',
  'my-saju',
  'saju-chart',
  'ad-free',
  'profile-edit',
  'account-delete',
};
