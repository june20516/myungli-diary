import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';

/// 온보딩 입력 화면(`onboard-*`·`birthplace`)을 여는 방식.
///
/// 결정 A19: 같은 화면을 `profile-edit`(계획 6)가 수정 모드로 엽니다.
enum OnboardingStepMode {
  /// 온보딩 단계. 입력을 초안에 저장하고 다음 단계로 `push`합니다.
  onboarding,

  /// 정보 수정. 서버에도 초안에도 저장하지 않고 `context.pop(값)`으로 돌려줍니다.
  /// 시작 값은 `push`의 `extra`로 받습니다(없으면 기본값).
  edit,
}

/// 수정 모드를 알리는 query 이름과 값(`?mode=edit`).
const String onboardingModeQuery = 'mode';

/// [onboardingModeQuery]의 수정 모드 값.
const String onboardingModeEdit = 'edit';

/// [state]의 query로 입력 화면 모드를 읽습니다. 없거나 모르는 값이면 온보딩입니다.
OnboardingStepMode onboardingStepModeOf(GoRouterState state) =>
    state.uri.queryParameters[onboardingModeQuery] == onboardingModeEdit
    ? OnboardingStepMode.edit
    : OnboardingStepMode.onboarding;

/// 온보딩 진행 막대의 전체 단계 수. 한국 기기는 호칭·생일·시간·성별 4단계, 한국 밖은
/// 출생지가 더해져 5단계입니다(D29).
final onboardingStepCountProvider = Provider<int>(
  (ref) => ref.watch(deviceRegionIsKoreaProvider) ? 4 : 5,
);
