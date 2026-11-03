// design 로고 원본(docs/identity/design/logo/, 결정 V7)에서
// 앱 아이콘 PNG를 만듭니다(결정 A102).
// 실행(app/에서): dart run tool/gen_app_icons.dart
// 필요: resvg(SVG 렌더링, `brew install resvg`),
//       ImageMagick `magick`(알파 제거, 메타데이터 정리)
//
// * iOS: ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json의 자리마다 그립니다.
//   픽셀 60 이상은 큰 원형, 그보다 작으면 작은 원형입니다(V7). App Store가 알파 채널을
//   거부하므로 모두 알파 없이 씁니다.
// * Android: 이전 기기용 mipmap-*/ic_launcher.png(48dp, 같은 크기 규칙)와 Android 8 이상
//   adaptive 아이콘(전경, 배경 108dp PNG와 mipmap-anydpi-v26/ic_launcher.xml).
// 같은 원본과 도구 버전이면 결과 파일이 같습니다(PNG 시각 정보를 넣지 않음).

import 'dart:convert';
import 'dart:io';

const _logoDir = '../docs/identity/design/logo';
const _largeIcon = '$_logoDir/icon-large.svg';
const _smallIcon = '$_logoDir/icon-small.svg';
const _androidForeground = '$_logoDir/icon-android-foreground.svg';
const _androidBackground = '$_logoDir/icon-android-background.svg';

/// 이 픽셀 크기 이상은 큰 원형을 씁니다(V7: 큰 원형은 60px 이상).
const _largeIconMinPx = 60;

const _iosIconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _androidRes = 'android/app/src/main/res';

/// Android 밀도별 배율(mdpi = 1).
const _androidDensities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

const _legacyIconDp = 48;
const _adaptiveLayerDp = 108;

const _adaptiveIconXml =
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- tool/gen_app_icons.dart가 만듭니다. '
    'Android 8 이상 adaptive 아이콘(결정 A102). -->\n'
    '<adaptive-icon '
    'xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n';

void main() {
  _requireTool('resvg', ['--version']);
  _requireTool('magick', ['-version']);

  _writeIosIcons();
  _writeAndroidIcons();
  stdout.writeln('앱 아이콘을 만들었습니다.');
}

void _writeIosIcons() {
  final contents = jsonDecode(
    File('$_iosIconSet/Contents.json').readAsStringSync(),
  ) as Map<String, Object?>;
  for (final image
      in (contents['images']! as List<Object?>).cast<Map<String, Object?>>()) {
    final points = double.parse((image['size']! as String).split('x').first);
    final scale = double.parse((image['scale']! as String).replaceAll('x', ''));
    final px = (points * scale).round();
    _render(
      svg: px >= _largeIconMinPx ? _largeIcon : _smallIcon,
      px: px,
      output: '$_iosIconSet/${image['filename']}',
      keepAlpha: false,
    );
  }
}

void _writeAndroidIcons() {
  for (final MapEntry(key: density, value: scale)
      in _androidDensities.entries) {
    final dir = '$_androidRes/mipmap-$density';
    final legacyPx = (_legacyIconDp * scale).round();
    final layerPx = (_adaptiveLayerDp * scale).round();
    _render(
      svg: legacyPx >= _largeIconMinPx ? _largeIcon : _smallIcon,
      px: legacyPx,
      output: '$dir/ic_launcher.png',
      keepAlpha: false,
    );
    _render(
      svg: _androidForeground,
      px: layerPx,
      output: '$dir/ic_launcher_foreground.png',
      keepAlpha: true,
    );
    _render(
      svg: _androidBackground,
      px: layerPx,
      output: '$dir/ic_launcher_background.png',
      keepAlpha: false,
    );
  }
  File('$_androidRes/mipmap-anydpi-v26/ic_launcher.xml')
    ..createSync(recursive: true)
    ..writeAsStringSync(_adaptiveIconXml);
}

/// [svg]를 [px] 정사각으로 그려 [output]에 씁니다. [keepAlpha]가 아니면 알파 채널을 뺍니다.
void _render({
  required String svg,
  required int px,
  required String output,
  required bool keepAlpha,
}) {
  final rendered = '${Directory.systemTemp.path}/myungli_icon_$px.png';
  _run('resvg', ['-w', '$px', '-h', '$px', svg, rendered]);
  File(output).parent.createSync(recursive: true);
  _run('magick', [
    rendered,
    if (!keepAlpha) ...[
      '-background',
      'white',
      '-alpha',
      'remove',
      '-alpha',
      'off',
    ],
    '-strip',
    '-define',
    'png:exclude-chunks=date,time',
    output,
  ]);
  File(rendered).deleteSync();
}

void _requireTool(String executable, List<String> versionArgs) {
  try {
    Process.runSync(executable, versionArgs);
  } on ProcessException {
    stderr.writeln('$executable이 없습니다. app/README.md "앱 아이콘"을 보세요.');
    exit(3);
  }
}

void _run(String executable, List<String> args) {
  final result = Process.runSync(executable, args);
  if (result.exitCode != 0) {
    stderr.writeln('$executable ${args.join(' ')} 실패:\n${result.stderr}');
    exit(1);
  }
}
