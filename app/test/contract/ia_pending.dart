/// 아직 IA `states`를 처리하지 않은 화면 id.
///
/// 계획 2~7이 화면을 만들어 `ScreenSpec.handledStates`를 채울 때마다 해당 id를
/// 지웁니다. 끝난 화면이 남아 있으면 IA 계약 테스트가 실패하고(ratchet),
/// 빈 집합이 목표입니다. IA `exits`가 빈 화면은 넣지 않습니다(넣으면 ratchet
/// 테스트가 즉시 실패합니다). 시트 화면은 registry에 없으므로 시트를 만드는 계획이
/// registry에 등록하면서 지웁니다.
const Set<String> pendingStateScreens = {'ad-free'};

/// 아직 IA `exits`를 구현하지 않은 page 화면 id(출구가 없는 화면은 제외).
///
/// 화면 task가 `ScreenSpec.exits`를 IA exits의 대상과 같게 채울 때마다 해당 id를
/// 지웁니다. 끝난 화면이 남아 있으면 IA 계약 테스트가 실패하고(ratchet),
/// 빈 집합이 목표입니다. IA `exits`가 빈 화면은 넣지 않습니다(넣으면 ratchet
/// 테스트가 즉시 실패합니다).
const Set<String> pendingExitScreens = {'ad-free'};
