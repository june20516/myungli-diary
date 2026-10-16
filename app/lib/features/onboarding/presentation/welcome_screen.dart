import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// IA `welcome`의 출구 대상. 둘 다 진입 상태가 바뀌지 않는 이동이라 화면이 직접 이동합니다.
const Set<String> welcomeExits = {ScreenIds.onboardCall, ScreenIds.login};

/// 로그아웃 상태의 첫 화면. 서비스 소개와 시작하기·이미 계정이 있어요 버튼입니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)라 서버 조각 배열용 `SentenceBlock` 대신 같은 글자
/// 역할의 [Text]로 그립니다. ui 슬롯 화면은 모두 같은 방식입니다.
class WelcomeScreen extends StatelessWidget {
  /// welcome 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    return Semantics(
      identifier: ScreenIds.welcome,
      child: Scaffold(
        key: const ValueKey(ScreenIds.welcome),
        body: SafeArea(
          child: OnboardingPageLayout(
            body: [
              Semantics(
                identifier: SlotIds.welcomeConceptHead,
                header: true,
                child: Text(
                  l10n.welcomeConceptHead,
                  key: const ValueKey(SlotIds.welcomeConceptHead),
                  style: tokens.typography.display.copyWith(
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: Space.s12),
              Semantics(
                identifier: SlotIds.welcomeConceptBody,
                child: Text(
                  l10n.welcomeConceptBody,
                  key: const ValueKey(SlotIds.welcomeConceptBody),
                  style: tokens.typography.bodyUi.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
              ),
            ],
            actions: [
              PrimaryButton(
                key: const ValueKey(SlotIds.welcomeCtaStart),
                identifier: SlotIds.welcomeCtaStart,
                label: l10n.welcomeCtaStart,
                onPressed: () => context.push(pathOf(ScreenIds.onboardCall)),
              ),
              const SizedBox(height: Space.s8),
              PrimaryButton(
                key: const ValueKey(SlotIds.welcomeCtaSignin),
                identifier: SlotIds.welcomeCtaSignin,
                variant: PrimaryButtonVariant.quiet,
                label: l10n.welcomeCtaSignin,
                onPressed: () => context.push(pathOf(ScreenIds.login)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
