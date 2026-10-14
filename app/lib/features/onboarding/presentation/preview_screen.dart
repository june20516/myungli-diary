import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/preview.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/onboarding/application/preview_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_navigation.dart';

/// IA `preview`의 출구 대상. 둘 다 진입 상태가 바뀌지 않는 이동이라 화면이 직접 이동합니다.
const Set<String> previewExits = {ScreenIds.login, ScreenIds.onboardCall};

/// IA `preview`가 직접 처리하는 상태. 오프라인은 오류 상태의 offline 변형으로 그립니다.
const Set<String> previewHandledStates = {
  'loading',
  'error',
  'offline',
  'time-unknown',
};

/// 첫 풀이(D50): 로그인 없이 온보딩 입력으로 오늘 풀이 일부를 한 번 보여 주고 저장(로그인)으로 잇습니다.
///
/// 날의 성격 배지와 총운 문장(`fortune.head`), 대표 태그가 있는 날은 이어지는 문장(`fortune.tag`)만
/// 보입니다. 이 화면은 `term-token`이 없는 화면이라 용어 조각도 일반 글자입니다(V28). 요청이 실패해도
/// (설치당 1회 한도 포함) 아래 버튼은 그대로라 저장하고 계속하기와 다시 입력을 막지 않습니다.
class PreviewScreen extends ConsumerWidget {
  /// preview 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 입력이 덜 찬 채 열렸으면(딥링크·복원) 다시 시도 대신 첫 단계에서 입력을 마저 받습니다.
    ref.listen(previewProvider, (_, next) {
      // 로그인 화면이 위에 있는 동안(기존 계정 로그인이 초안을 비우는 중)에는 끼어들지 않습니다.
      if (next.error is OnboardingInputIncomplete &&
          ModalRoute.of(context)?.isCurrent == true) {
        goBackToOnboardCall(context);
      }
    });
    return Semantics(
      identifier: ScreenIds.preview,
      child: Scaffold(
        key: const ValueKey(ScreenIds.preview),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                // 스택 바닥(갈래의 첫 화면, 딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                title: '',
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ScreenStateView<Preview>(
                  value: ref.watch(previewProvider),
                  onRetry: _retriable(ref.watch(previewProvider).error)
                      ? () => ref.invalidate(previewProvider)
                      : null,
                  dataWithNotice: (preview, offlineNotice) => _PreviewBody(
                    preview: preview,
                    offlineNotice: offlineNotice,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s20,
                  Space.s12,
                  Space.s20,
                  Space.s24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      key: const ValueKey(SlotIds.previewCtaSave),
                      identifier: SlotIds.previewCtaSave,
                      label: l10n.previewCtaSave,
                      onPressed: () =>
                          context.push<void>(pathOf(ScreenIds.login)),
                    ),
                    const SizedBox(height: Space.s8),
                    PrimaryButton(
                      key: const ValueKey(SlotIds.previewCtaRestart),
                      identifier: SlotIds.previewCtaRestart,
                      variant: PrimaryButtonVariant.quiet,
                      label: l10n.previewCtaRestart,
                      // 입력은 초안에 남아 있어 onboard-call이 채워진 채로 열립니다.
                      onPressed: () => goBackToOnboardCall(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 같은 입력으로 다시 요청해도 소용없는 오류(이미 쓴 미리보기, 입력 검증 실패, 입력 미완)가
/// 아니면 true.
bool _retriable(Object? error) {
  if (error is OnboardingInputIncomplete) return false;
  if (error is! ProblemError) return true;
  final code = error.code;
  return code != 'preview.used' &&
      code != 'request.inconsistent' &&
      !code.startsWith('birth.') &&
      !code.startsWith('date.') &&
      !code.startsWith('name.');
}

class _PreviewBody extends StatelessWidget {
  const new({required this.preview, required this.offlineNotice});

  final Preview preview;
  final Widget offlineNotice;

  /// 시간 모름 notice의 서버 문장. 없으면 null입니다.
  String? get _timeUnknownMessage {
    for (final notice in preview.notices) {
      if (notice.code == NoticeCode.timeUnknown) {
        return notice.text.segments.map((s) => s.text).join();
      }
    }
    return null;
  }

  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final login = await showMyungliDialog(
      context,
      variant: DialogVariant.confirm,
      title: l10n.previewShareLoginNotice,
      identifier: SlotIds.previewShareLoginNotice,
      confirm: l10n.previewShareLoginNoticeConfirm,
      cancel: l10n.previewShareLoginNoticeCancel,
    );
    if (login && context.mounted) {
      await context.push<void>(pathOf(ScreenIds.login));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeUnknown = _timeUnknownMessage;
    final tag = preview.fortune.tag;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          offlineNotice,
          if (timeUnknown != null)
            NoticeBanner(
              key: const ValueKey('preview.time-unknown'),
              variant: NoticeBannerVariant.timeUnknown,
              message: timeUnknown,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Space.s24),
                Semantics(
                  identifier: SlotIds.previewCharacterLabel,
                  container: true,
                  child: KeyedSubtree(
                    key: const ValueKey(SlotIds.previewCharacterLabel),
                    child: DayCharacter(
                      variant: dayCharacterVariantOf(preview.dayKind),
                      label: dayKindName(l10n, preview.dayKind),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),
                SentenceBlock(
                  variant: SentenceBlockVariant.card,
                  text: preview.fortune.head.text,
                  slotId: SlotIds.previewFortuneHead,
                ),
                if (tag != null) ...[
                  const SizedBox(height: Space.s12),
                  SentenceBlock(
                    variant: SentenceBlockVariant.body,
                    text: tag.text,
                    slotId: SlotIds.previewFortuneBody,
                  ),
                ],
                const SizedBox(height: Space.s24),
                ShareButton(
                  variant: ShareButtonVariant.soft,
                  label: l10n.shareLabel,
                  onPressed: () => _share(context),
                ),
                const SizedBox(height: Space.s16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
