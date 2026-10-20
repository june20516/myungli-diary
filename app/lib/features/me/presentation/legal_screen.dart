import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/legal_links_provider.dart';
import 'package:myungli_diary/core/api/gen/model/legal_links.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/load_feedback.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 약관·정책(`legal`, 결정 A61·D80).
///
/// `settings-row` 묶음 하나에 줄 셋입니다.
/// * "이용약관"·"개인정보 처리방침"은 `AppConfig.legal` 주소([legalLinksProvider])에 화면 언어
///   (`?lang=`)를 붙여 외부 브라우저로 엽니다. 주소를 받는 동안 두 줄은 비활성이고, 받지 못하면
///   오류 toast를 보이고 두 줄 중 하나를 누르면 다시 받습니다(settings의 프로필 받기와 같음).
///   브라우저를 열지 못하면 오류 toast입니다.
/// * "오픈소스 라이선스"는 Flutter 라이선스 페이지입니다(`showLicensePage`가 여는 [LicensePage]
///   route를 직접 push해 닫힐 때까지 기다림). 글꼴과 GeoNames 고지는 앱 시작 때 더합니다
///   (`registerAppLicenses`, #312).
/// * 브라우저·라이선스 페이지를 여는 동안 다시 눌러도 또 열지 않습니다.
class LegalScreen extends ConsumerStatefulWidget {
  /// legal 화면을 만듭니다.
  const new({super.key});

  /// 이용약관 줄.
  static const Key termsRowKey = ValueKey('legal.row.terms');

  /// 개인정보 처리방침 줄.
  static const Key privacyRowKey = ValueKey('legal.row.privacy');

  /// 오픈소스 라이선스 줄.
  static const Key licensesRowKey = ValueKey('legal.row.licenses');

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen>
    with SingleOpenGuard<LegalScreen> {
  @override
  void initState() {
    super.initState();
    // 주소를 받지 못하면 이유를 알립니다(다시 받을 때마다 새 오류면 다시 알림).
    listenLoadErrorToast(ref, context, legalLinksProvider);
  }

  Future<void> _openDocument(String address) async {
    final l10n = AppLocalizations.of(context);
    final uri = legalDocumentUri(
      address,
      Localizations.localeOf(context).languageCode,
    );
    try {
      await ref.read(externalBrowserProvider).open(uri);
    } on Object catch (error, stack) {
      // 진단을 위해 요약(오류 타입)만 보고합니다(D64 ②).
      ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
      if (!mounted) return;
      showMyungliToast(context, l10n.errorUnexpected);
    }
  }

  Future<void> _openLicenses() async {
    final l10n = AppLocalizations.of(context);
    // 라이선스 페이지가 닫힐 때까지 기다려 두 번 열지 않습니다.
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => LicensePage(applicationName: l10n.appTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final linksState = ref.watch(legalLinksProvider);
    final links = linksState.value;
    final failed = linksState.failedWithoutValue;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    /// 문서 줄: 주소가 있으면 열기, 받지 못했으면 다시 받기, 받는 중이면 비활성(A61).
    VoidCallback? documentRow(String Function(LegalLinks links) address) {
      if (links != null) {
        return () => guardOpen(() => _openDocument(address(links)));
      }
      return failed ? () => ref.invalidate(legalLinksProvider) : null;
    }

    return Semantics(
      identifier: ScreenIds.legal,
      child: Scaffold(
        key: const ValueKey(ScreenIds.legal),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.legalBarTitle,
                titleIdentifier: SlotIds.legalBarTitle,
                // 스택 바닥(딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    Space.s20,
                    Space.s8,
                    Space.s20,
                    Space.s24 + bottom,
                  ),
                  children: [
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: LegalScreen.termsRowKey,
                          variant: SettingsRowVariant.navigate,
                          label: l10n.legalTermsLabel,
                          onTap: documentRow((links) => links.terms),
                        ),
                        SettingsRow(
                          key: LegalScreen.privacyRowKey,
                          variant: SettingsRowVariant.navigate,
                          label: l10n.legalPrivacyLabel,
                          onTap: documentRow((links) => links.privacy),
                        ),
                        SettingsRow(
                          key: LegalScreen.licensesRowKey,
                          variant: SettingsRowVariant.navigate,
                          label: l10n.legalLicensesLabel,
                          onTap: () => guardOpen(_openLicenses),
                        ),
                      ],
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
