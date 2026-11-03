// ARB 원고에서 OS가 직접 보여 주는 문구(홈 화면 앱 이름, iOS 권한 창)를 만드는 순수 함수입니다.
// 도구(tool/gen_native_strings.dart)와 테스트가 함께 씁니다(결정 A101).
//
// * iOS: ios/Runner/<언어>.lproj/InfoPlist.strings와 Info.plist의 기본값
// * Android: android/app/src/main/res/values(-<언어>)/strings.xml
// 기본값은 en입니다. 앱 화면이 지원하지 않는 언어를 en으로 보이므로(resolveAppLanguage)
// OS 문구도 같게 맞춥니다. iOS 개발 지역(DEVELOPMENT_LANGUAGE)도 en입니다.

import 'dart:convert';
import 'dart:io';

/// 앱이 지원하는 언어. ARB 파일, `*.lproj`, `values-*` 이름이 같습니다.
const nativeLocales = ['en', 'ko', 'ja'];

/// OS가 언어를 고르지 못할 때 쓰는 기본 언어.
const nativeBaseLocale = 'en';

/// iOS Info.plist 키와 그 문구의 ARB 키.
const iosInfoPlistKeys = {
  // 홈 화면 앱 이름(writing W17).
  'CFBundleDisplayName': 'appTitle',
  // ATT 권한 창 문구(writing 슬롯 ui.system.tracking, #697).
  'NSUserTrackingUsageDescription': 'iosTrackingUsageDescription',
};

/// Android 문자열 리소스 이름과 그 문구의 ARB 키.
const androidStringKeys = {
  // 홈 화면 앱 이름(AndroidManifest `android:label="@string/app_name"`).
  'app_name': 'appTitle',
};

/// Info.plist(app 기준 경로).
const infoPlistPath = 'ios/Runner/Info.plist';

/// 언어별 InfoPlist.strings(app 기준 경로).
String infoPlistStringsPath(String locale) =>
    'ios/Runner/$locale.lproj/InfoPlist.strings';

/// 언어별 Android strings.xml(app 기준 경로). 기본 언어는 `values`입니다.
String androidStringsPath(String locale) => locale == nativeBaseLocale
    ? 'android/app/src/main/res/values/strings.xml'
    : 'android/app/src/main/res/values-$locale/strings.xml';

/// ARB(app 기준 경로).
String arbPath(String locale) => 'lib/core/l10n/arb/app_$locale.arb';

/// [locale] ARB에서 [keys](생성 키 → ARB 키)마다 문구를 읽습니다. 없으면 던집니다.
Map<String, String> readNativeStrings(String locale, Map<String, String> keys) {
  final arb = jsonDecode(
    File(arbPath(locale)).readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final MapEntry(key: nativeKey, value: arbKey) in keys.entries)
      nativeKey: switch (arb[arbKey]) {
        final String text when text.isNotEmpty => text,
        _ => throw StateError('${arbPath(locale)}에 $arbKey가 없습니다'),
      },
  };
}

/// `InfoPlist.strings` 내용. 키 순서는 [iosInfoPlistKeys] 순서입니다.
String renderInfoPlistStrings(Map<String, String> strings) {
  final buffer = StringBuffer(
    '/* tool/gen_native_strings.dart가 ARB에서 생성합니다. 손대지 않습니다. */\n',
  );
  for (final key in iosInfoPlistKeys.keys) {
    buffer.writeln('"$key" = "${escapeStringsValue(strings[key]!)}";');
  }
  return buffer.toString();
}

/// Android `strings.xml` 내용. 이름 순서는 [androidStringKeys] 순서입니다.
String renderAndroidStrings(Map<String, String> strings) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- tool/gen_native_strings.dart가 ARB에서 생성합니다. 손대지 않습니다. -->')
    ..writeln('<resources>');
  for (final name in androidStringKeys.keys) {
    buffer.writeln(
      '    <string name="$name">${escapeAndroidValue(strings[name]!)}</string>',
    );
  }
  buffer.writeln('</resources>');
  return buffer.toString();
}

/// `.strings` 따옴표 안에 넣을 수 있게 역슬래시, 따옴표, 줄바꿈을 escape합니다.
String escapeStringsValue(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n');

/// plist `<string>` 안에 넣을 수 있게 XML 특수 문자를 escape합니다.
String escapePlistValue(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Android 문자열 리소스 규칙대로 XML 특수 문자, 역슬래시, 따옴표, 줄바꿈을 escape합니다.
String escapeAndroidValue(String value) => escapePlistValue(
  value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n'),
);

/// Info.plist [plist]의 [iosInfoPlistKeys] 값을 [strings]로 바꾼 내용. 키가 없으면 던집니다.
String applyInfoPlistStrings(String plist, Map<String, String> strings) {
  var result = plist;
  for (final key in iosInfoPlistKeys.keys) {
    final pattern = RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)');
    if (!pattern.hasMatch(result)) {
      throw StateError('$infoPlistPath에 $key가 없습니다');
    }
    result = result.replaceFirstMapped(
      pattern,
      (match) => '${match[1]}${escapePlistValue(strings[key]!)}${match[2]}',
    );
  }
  return result;
}

/// 생성할 파일 경로와 내용 전체.
Map<String, String> renderNativeStrings() => {
  for (final locale in nativeLocales) ...{
    infoPlistStringsPath(locale): renderInfoPlistStrings(
      readNativeStrings(locale, iosInfoPlistKeys),
    ),
    androidStringsPath(locale): renderAndroidStrings(
      readNativeStrings(locale, androidStringKeys),
    ),
  },
  infoPlistPath: applyInfoPlistStrings(
    File(infoPlistPath).readAsStringSync(),
    readNativeStrings(nativeBaseLocale, iosInfoPlistKeys),
  ),
};
