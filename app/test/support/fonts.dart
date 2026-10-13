import 'dart:io';

import 'package:flutter/services.dart';
import 'package:myungli_diary/app/licenses.dart';

/// 테스트에서 `assets/fonts`의 글꼴을 family 이름으로 올립니다.
///
/// 골든 테스트가 Ahem 대신 실제 글꼴로 그리게 하려고 씁니다.
Future<void> loadBundledFonts() async {
  for (final font in bundledFonts) {
    final loader = FontLoader(font.family);
    final files =
        Directory('assets/fonts/${font.folder}')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.ttf') || f.path.endsWith('.otf'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }
}
