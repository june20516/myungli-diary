import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/os_share.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('OsShareSheet는 PNG 파일 하나와 문구를 넘김', () async {
    final shared = <({List<XFile> files, String? text})>[];
    final png = Uint8List.fromList([137, 80, 78, 71]);
    await OsShareSheet(
      shareFiles: (files, {text}) async =>
          shared.add((files: files, text: text)),
    ).sharePng(png, text: '오늘의 문장');

    expect(shared, hasLength(1));
    final file = shared.single.files.single;
    expect(file.mimeType, 'image/png');
    expect(await file.readAsBytes(), png);
    expect(shared.single.text, '오늘의 문장');
  });
}
