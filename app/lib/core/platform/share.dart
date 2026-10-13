import 'dart:typed_data';

/// OS 공유 시트.
abstract interface class ShareSheet {
  /// PNG 이미지를 [text]와 함께 공유합니다.
  ///
  /// PNG는 라이트 테마로 그린 것을 넘깁니다(렌더는 호출자 몫).
  Future<void> sharePng(Uint8List png, {required String text});
}
