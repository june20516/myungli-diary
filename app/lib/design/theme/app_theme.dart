import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 밝기와 언어에 맞는 앱 테마를 만듭니다. 일본어면 [jaType], 그 밖은 [koType]입니다.
///
/// 명세에 없는 Material 효과(물결, 그림자, 표면 색조, 상태 겹침 색)는 끕니다.
ThemeData buildTheme({required Brightness brightness, required Locale locale}) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? darkColors : lightColors;
  final type = locale.languageCode == 'ja' ? jaType : koType;
  final gradients = isDark ? darkGradients : lightGradients;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.actionPrimary,
    onPrimary: colors.actionOnPrimary,
    secondary: colors.actionPrimary,
    onSecondary: colors.actionOnPrimary,
    error: colors.tagBadFg,
    onError: colors.tagBadBg,
    surface: colors.bgBase,
    onSurface: colors.textPrimary,
    surfaceTint: Colors.transparent,
    outline: colors.line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.bgBase,
    canvasColor: colors.bgBase,
    textTheme: Typography.material2021().black.apply(
      fontFamily: type.bodyUi.fontFamily,
      fontFamilyFallback: type.bodyUi.fontFamilyFallback,
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    cardTheme: const CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      backgroundColor: colors.bgSheet,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      backgroundColor: colors.bgSheet,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [
      MyungliTokens(colors: colors, typography: type, gradients: gradients),
    ],
  );
}
