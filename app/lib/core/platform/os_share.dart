import 'dart:typed_data';

import 'package:myungli_diary/core/platform/share.dart';
import 'package:share_plus/share_plus.dart';

/// 파일과 문구를 OS 공유 시트로 넘기는 경계.
typedef ShareFiles = Future<void> Function(List<XFile> files, {String? text});

Future<void> _shareWithPlugin(List<XFile> files, {String? text}) async {
  // iPad는 기준 위치가 없으면 화면 가운데에 띄웁니다(share_plus 13).
  await SharePlus.instance.share(ShareParams(files: files, text: text));
}

/// OS 공유 시트(`share_plus`)의 실제 구현.
final class OsShareSheet implements ShareSheet {
  /// 구현을 만듭니다.
  const new({this.shareFiles = _shareWithPlugin});

  /// 공유 경계.
  final ShareFiles shareFiles;

  /// 공유하는 이미지 파일 이름.
  static const String fileName = 'myungli.png';

  @override
  Future<void> sharePng(Uint8List png, {required String text}) => shareFiles([
    XFile.fromData(png, mimeType: 'image/png', name: fileName),
  ], text: text);
}
