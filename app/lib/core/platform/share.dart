import 'dart:typed_data';

/// OS 공유 시트.
abstract interface class ShareSheet {
  /// PNG 이미지를 [text]와 함께 공유합니다.
  Future<void> sharePng(Uint8List png, {required String text});
}
