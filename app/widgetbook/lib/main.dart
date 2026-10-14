import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary_widgetbook/action_directory.dart';
import 'package:myungli_diary_widgetbook/elements_directory.dart';
import 'package:myungli_diary_widgetbook/feedback_directory.dart';
import 'package:myungli_diary_widgetbook/frame_directory.dart';
import 'package:myungli_diary_widgetbook/input_directory.dart';
import 'package:myungli_diary_widgetbook/sentence_directory.dart';
import 'package:myungli_diary_widgetbook/today_directory.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const MyungliWidgetbook());

/// 컴포넌트 카탈로그. 테마(라이트·다크), 로케일(ko·en·ja), 글자 크기를 add-on으로 바꿉니다.
class MyungliWidgetbook extends StatelessWidget {
  /// 카탈로그 앱을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    const koreanLocale = Locale('ko');
    return Widgetbook.material(
      directories: [
        elementsDirectory,
        actionDirectory,
        frameDirectory,
        feedbackDirectory,
        sentenceDirectory,
        inputDirectory,
        todayDirectory,
      ],
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(
              name: '라이트',
              data: buildTheme(
                brightness: Brightness.light,
                locale: koreanLocale,
              ),
            ),
            WidgetbookTheme(
              name: '다크',
              data: buildTheme(
                brightness: Brightness.dark,
                locale: koreanLocale,
              ),
            ),
          ],
        ),
        LocalizationAddon(
          locales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialLocale: koreanLocale,
        ),
        TextScaleAddon(min: 1, divisions: 10),
      ],
    );
  }
}
