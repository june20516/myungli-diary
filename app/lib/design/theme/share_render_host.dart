import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

/// 화면 밖 트리에 방향·기본 `MediaQuery`·라이트 테마·언어(글꼴 묶음·문구)를 줍니다.
///
/// 화면 트리의 값은 이어지지 않으므로 [locale]을 직접 넘깁니다. 기기 글자 배율과 다크 모드는
/// 받지 않습니다(결정 V5). 공유 이미지를 그리는 곳이 `OffscreenRenderer`에 넘기기 전에 감쌉니다.
class ShareRenderHost extends StatelessWidget {
  /// [child]를 [locale]·라이트 테마로 감쌉니다.
  const new({required this.locale, required this.child, super.key});

  /// 화면과 같은 언어.
  final Locale locale;

  /// 그릴 위젯.
  final Widget child;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Localizations(
        locale: locale,
        delegates: AppLocalizations.localizationsDelegates,
        child: Theme(
          data: buildTheme(brightness: Brightness.light, locale: locale),
          child: child,
        ),
      ),
    ),
  );
}
