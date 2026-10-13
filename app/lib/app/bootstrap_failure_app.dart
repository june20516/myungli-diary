import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

/// `bootstrap`이 실패했을 때 `runApp`으로 띄우는 최소 화면. 라우터·provider 없이 안내만 보입니다.
class BootstrapFailureApp extends StatelessWidget {
  /// 안내 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return MaterialApp(
      theme: buildTheme(brightness: Brightness.light, locale: locale),
      darkTheme: buildTheme(brightness: Brightness.dark, locale: locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                AppLocalizations.of(context).bootstrapFailed,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
