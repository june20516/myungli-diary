import 'package:flutter/widgets.dart';
import 'package:myungli_diary/app/router/placeholder_screen.dart';
import 'package:myungli_diary/app/screens/launch_screen.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/features/auth/presentation/consent_screen.dart';
import 'package:myungli_diary/features/auth/presentation/login_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/birthplace_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/force_update_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_birth_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_call_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_gender_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_time_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/preview_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/welcome_screen.dart';

/// 화면 하나의 등록 정보.
final class ScreenSpec {
  /// [id] 화면을 [builder]로 만듭니다.
  const new(
    this.id,
    this.builder, {
    this.handledStates = const {},
    this.exits = const {},
  });

  /// IA 화면 id.
  final String id;

  /// 화면 본체를 만듭니다.
  final WidgetBuilder builder;

  /// 이 화면이 직접 처리하는 IA 상태 id. 기반 단계에서는 비어 있습니다.
  final Set<String> handledStates;

  /// 이 화면이 실제로 이동시키는 대상 화면 id. IA exits의 대상 집합과 같아야 하고,
  /// 출구를 구현하기 전에는 비어 있습니다(`pendingExitScreens`).
  final Set<String> exits;
}

/// 본체를 만든 화면. 화면 task가 여기에 하나씩 더합니다.
final Map<String, ScreenSpec> _implementedScreens = {
  ScreenIds.launch: const ScreenSpec(
    ScreenIds.launch,
    _buildLaunch,
    handledStates: launchHandledStates,
    exits: {
      ScreenIds.today,
      ScreenIds.adConsent,
      ScreenIds.welcome,
      ScreenIds.forceUpdate,
    },
  ),
  ScreenIds.forceUpdate: const ScreenSpec(
    ScreenIds.forceUpdate,
    _buildForceUpdate,
  ),
  ScreenIds.welcome: const ScreenSpec(
    ScreenIds.welcome,
    _buildWelcome,
    exits: welcomeExits,
  ),
  ScreenIds.onboardCall: const ScreenSpec(
    ScreenIds.onboardCall,
    _buildOnboardCall,
    exits: onboardCallExits,
  ),
  ScreenIds.onboardBirth: const ScreenSpec(
    ScreenIds.onboardBirth,
    _buildOnboardBirth,
    handledStates: onboardBirthHandledStates,
    exits: onboardBirthExits,
  ),
  ScreenIds.onboardTime: const ScreenSpec(
    ScreenIds.onboardTime,
    _buildOnboardTime,
    handledStates: onboardTimeHandledStates,
    exits: onboardTimeExits,
  ),
  ScreenIds.onboardGender: const ScreenSpec(
    ScreenIds.onboardGender,
    _buildOnboardGender,
    exits: onboardGenderExits,
  ),
  ScreenIds.birthplace: const ScreenSpec(
    ScreenIds.birthplace,
    _buildBirthplace,
    handledStates: birthplaceHandledStates,
    exits: birthplaceExits,
  ),
  ScreenIds.preview: const ScreenSpec(
    ScreenIds.preview,
    _buildPreview,
    handledStates: previewHandledStates,
    exits: previewExits,
  ),
  ScreenIds.login: const ScreenSpec(
    ScreenIds.login,
    _buildLogin,
    handledStates: loginHandledStates,
    exits: loginExits,
  ),
  ScreenIds.consent: const ScreenSpec(
    ScreenIds.consent,
    _buildConsent,
    handledStates: consentHandledStates,
    exits: consentExits,
  ),
};

/// page 화면 registry. 시트·system 화면은 route가 없어 넣지 않습니다.
/// 본체가 아직 없는 page 화면은 [PlaceholderScreen]으로 채웁니다.
final Map<String, ScreenSpec> screenRegistry = {
  ..._implementedScreens,
  for (final screen in iaScreens)
    if (screen.presentation == IaPresentation.page &&
        !_implementedScreens.containsKey(screen.id))
      screen.id: ScreenSpec(
        screen.id,
        (context) => PlaceholderScreen(screen.id),
      ),
};

Widget _buildLaunch(BuildContext context) => const LaunchScreen();

Widget _buildForceUpdate(BuildContext context) => const ForceUpdateScreen();

Widget _buildWelcome(BuildContext context) => const WelcomeScreen();

Widget _buildOnboardCall(BuildContext context) => const OnboardCallScreen();

Widget _buildOnboardBirth(BuildContext context) => const OnboardBirthScreen();

Widget _buildOnboardTime(BuildContext context) => const OnboardTimeScreen();

Widget _buildOnboardGender(BuildContext context) => const OnboardGenderScreen();

Widget _buildBirthplace(BuildContext context) => const BirthplaceScreen();

Widget _buildPreview(BuildContext context) => const PreviewScreen();

Widget _buildLogin(BuildContext context) => const LoginScreen();

Widget _buildConsent(BuildContext context) => const ConsentScreen();
