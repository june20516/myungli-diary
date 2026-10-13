import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/dev/scenario_picker.dart';
import 'package:myungli_diary/app/entry/account_linker.dart';
import 'package:myungli_diary/app/entry/sign_out_cleaner.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

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
  late Duration _deviceUtcOffset;

  @override
  void initState() {
    super.initState();
    _deviceUtcOffset = DateTime.now().timeZoneOffset;
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
    final offset = DateTime.now().timeZoneOffset;
    if (offset != _deviceUtcOffset) {
      _deviceUtcOffset = offset;
      _onDeviceTimeZoneChanged();
    }
  }

  /// 기기 시간대가 바뀌었을 때의 자리입니다.
  ///
  /// 프로필 시간대 갱신(PATCH)은 계획 2에서 붙입니다. "오늘"은 프로필 시간대를
  /// 따르므로 지금은 아무것도 바꾸지 않습니다.
  void _onDeviceTimeZoneChanged() {}

  @override
  Widget build(BuildContext context) => widget.child;
}
