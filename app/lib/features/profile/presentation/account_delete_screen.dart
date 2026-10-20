import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/profile/application/account_delete_controller.dart';

/// IA `account-delete`의 출구 대상. 삭제가 끝나면 진입이 다시 계산돼 라우터 redirect가 보냅니다.
const Set<String> accountDeleteExits = {ScreenIds.welcome};

/// IA `account-delete`에서 이 화면이 처리하는 상태.
const Set<String> accountDeleteHandledStates = {'error'};

/// 계정 삭제(`account-delete`, 결정 A63).
///
/// 제목과 지워지는 데이터 안내, 삭제 버튼(`primary-button` `destructive`)입니다. 버튼은 확인 창
/// (`dialog` `destructive`, 첫 초점은 취소) 뒤 `deleteMe` → 로그아웃 정리이고, 끝나면 진입이
/// `welcome`으로 갑니다. 지우는 중에는 버튼이 처리 중 표시이고 뒤로 가기를 막습니다. 실패하면
/// 오류 toast(`account-delete:error`)이고 버튼을 다시 누를 수 있습니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)라 제목·안내는 같은 글자 역할의 [Text]로 그립니다.
class AccountDeleteScreen extends ConsumerStatefulWidget {
  /// account-delete 화면을 만듭니다.
  const new({super.key});

  /// 삭제 버튼.
  static const Key deleteKey = ValueKey(SlotIds.accountDeleteCtaDelete);

  @override
  ConsumerState<AccountDeleteScreen> createState() =>
      _AccountDeleteScreenState();
}

class _AccountDeleteScreenState extends ConsumerState<AccountDeleteScreen>
    with SingleOpenGuard<AccountDeleteScreen> {
  /// 확인 창 뒤 지웁니다. 확인 창이 열려 있거나 지우는 중이면 같은 프레임의 두 번째 누름도
  /// 받지 않습니다([guardOpen]).
  Future<void> _delete() async {
    try {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showMyungliDialog(
        context,
        variant: DialogVariant.destructive,
        title: l10n.accountDeleteDeleteConfirm,
        confirm: l10n.accountDeleteDeleteConfirmDelete,
        cancel: l10n.accountDeleteDeleteConfirmCancel,
        identifier: SlotIds.accountDeleteDeleteConfirm,
      );
      if (!confirmed || !mounted) return;
      // 성공하면 진입이 다시 계산돼 라우터가 welcome으로 보냅니다(이 화면은 사라집니다).
      await ref.read(accountDeleteControllerProvider.notifier).delete();
    } on AppError catch (error) {
      if (mounted) {
        showMyungliToast(
          context,
          errorMessage(AppLocalizations.of(context), error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    // 지우는 중에도 controller가 버려지지 않게 화면이 붙들어 둡니다.
    final deleting = ref.watch(accountDeleteControllerProvider);
    return PopScope(
      // 지우는 중에 화면을 떠나면 결과(오류 안내)를 보일 곳이 없어 막습니다.
      canPop: !deleting,
      child: Semantics(
        identifier: ScreenIds.accountDelete,
        child: Scaffold(
          key: const ValueKey(ScreenIds.accountDelete),
          body: SafeArea(
            child: Column(
              children: [
                MyungliAppBar.inner(
                  title: l10n.accountDeleteBarTitle,
                  titleIdentifier: SlotIds.accountDeleteBarTitle,
                  // 스택 바닥(딥링크·복원)이거나 지우는 중이면 숨깁니다.
                  showBack: !deleting && MyungliAppBar.canGoBack(context),
                ),
                Expanded(
                  child: OnboardingPageLayout(
                    body: [
                      Semantics(
                        identifier: SlotIds.accountDeleteTitleHead,
                        header: true,
                        child: Text(
                          l10n.accountDeleteTitleHead,
                          key: const ValueKey(SlotIds.accountDeleteTitleHead),
                          style: tokens.typography.title.copyWith(
                            color: tokens.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.s12),
                      Semantics(
                        identifier: SlotIds.accountDeleteDataBody,
                        child: Text(
                          l10n.accountDeleteDataBody,
                          key: const ValueKey(SlotIds.accountDeleteDataBody),
                          style: tokens.typography.bodyUi.copyWith(
                            color: tokens.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                    actions: [
                      PrimaryButton(
                        key: AccountDeleteScreen.deleteKey,
                        identifier: SlotIds.accountDeleteCtaDelete,
                        variant: PrimaryButtonVariant.destructive,
                        label: l10n.accountDeleteCtaDelete,
                        loading: deleting,
                        onPressed: () => guardOpen(_delete),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
