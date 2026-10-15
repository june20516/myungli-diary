import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 스토어를 엽니다. 열지 못하면 빠져나갈 수 없는 화면이라 toast로 알려 다시 누르게 합니다.
Future<void> _openStore(BuildContext context, WidgetRef ref) async {
  final crashReporter = ref.read(crashReporterProvider);
  try {
    await ref.read(storeLauncherProvider).openStore();
  } on Object catch (error, stack) {
    // 진단을 위해 요약(오류 타입)만 보고합니다(D64 ②).
    crashReporter.record(CrashSummary.from(error), stack);
    if (!context.mounted) return;
    showMyungliToast(context, AppLocalizations.of(context).errorUnexpected);
  }
}

/// 앱 버전이 최소 버전보다 낮을 때의 안내 화면. 스토어 열기 버튼 하나뿐이고 출구가 없습니다.
///
/// 뒤로 가기로 벗어날 수 없어야 하므로 [PopScope]로 막습니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)라 서버 조각 배열용 `SentenceBlock` 대신 같은 글자
/// 역할의 [Text]로 그립니다. ui 슬롯 화면은 모두 같은 방식입니다.
class ForceUpdateScreen extends ConsumerWidget {
  /// force-update 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    return PopScope(
      canPop: false,
      child: Semantics(
        identifier: ScreenIds.forceUpdate,
        child: Scaffold(
          key: const ValueKey(ScreenIds.forceUpdate),
          body: SafeArea(
            child: OnboardingPageLayout(
              body: [
                Semantics(
                  identifier: SlotIds.forceUpdateNoticeHead,
                  header: true,
                  child: Text(
                    l10n.forceUpdateNoticeHead,
                    key: const ValueKey(SlotIds.forceUpdateNoticeHead),
                    style: tokens.typography.title.copyWith(
                      color: tokens.colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: Space.s12),
                Semantics(
                  identifier: SlotIds.forceUpdateNoticeBody,
                  child: Text(
                    l10n.forceUpdateNoticeBody,
                    key: const ValueKey(SlotIds.forceUpdateNoticeBody),
                    style: tokens.typography.bodyUi.copyWith(
                      color: tokens.colors.textSecondary,
                    ),
                  ),
                ),
              ],
              actions: [
                PrimaryButton(
                  key: const ValueKey(SlotIds.forceUpdateCtaStore),
                  identifier: SlotIds.forceUpdateCtaStore,
                  label: l10n.forceUpdateCtaStore,
                  onPressed: () => _openStore(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
