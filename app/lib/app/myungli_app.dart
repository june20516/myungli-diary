import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/dev/scenario_picker.dart';
import 'package:myungli_diary/app/entry/account_linker.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/entry/sign_out_cleaner.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';

/// 앱 루트: 라우터, 라이트·다크 테마(기기 설정), 로케일(ko·en·ja)을 엮습니다.
class MyungliApp extends ConsumerWidget {
  /// 앱 루트를 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 계정 연결·로그아웃 정리 담당을 앱이 떠 있는 동안 붙들어 둡니다.
    ref
      ..watch(accountLinkerProvider)
      ..watch(signOutCleanerProvider);
    // 진입이 ready가 될 때도 한 번 기기 시간대를 맞춰 봅니다.
    ref.listen(entryProvider, (previous, next) {
      if (next == EntryState.ready && previous != EntryState.ready) {
        unawaited(ref.read(timezoneSyncProvider).syncIfChanged());
      }
    });
    final locale = ref.watch(localeProvider);
    final showDevMenu =
        kDebugMode && ref.watch(apiModeProvider) == ApiMode.fake;
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(brightness: Brightness.light, locale: locale),
      darkTheme: buildTheme(brightness: Brightness.dark, locale: locale),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (device, supported) =>
          Locale(resolveAppLanguage(device ?? locale).value),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return AppLifecycleHooks(
          child: showDevMenu ? DevMenuTrigger(child: content) : content,
        );
      },
    );
  }
}

/// 앱이 다시 앞으로 올 때 하는 일을 모읍니다.
class AppLifecycleHooks extends ConsumerStatefulWidget {
  /// [child]를 감싸 생명주기를 듣습니다.
  const new({required this.child, super.key});

  /// 앱 내용.
  final Widget child;

  @override
  ConsumerState<AppLifecycleHooks> createState() => _AppLifecycleHooksState();
}

class _AppLifecycleHooksState extends ConsumerState<AppLifecycleHooks>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // 백그라운드에서 자정이 지났을 수 있어 타이머를 기다리지 않고 바로 다시 확인합니다.
    ref.invalidate(todayProvider);
    // 구매·보고 계정 연결이 실패했으면 다시 시도합니다(이미 연결됐으면 거름).
    ref.read(accountLinkerProvider).linkFromEntry(ref.read(entryStateProvider));
    // 기기 시간대가 프로필 사본과 다르면 server에 알립니다.
    unawaited(ref.read(timezoneSyncProvider).syncIfChanged());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
