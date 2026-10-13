/// 알림을 눌러 앱이 열린 사건.
final class PushOpen {
  /// 열려야 할 화면 id(IA)를 담습니다.
  const new({required this.screenId});

  /// 열려야 할 화면 id.
  final String screenId;
}

/// 푸시 알림(FCM).
abstract interface class PushMessaging {
  /// 알림 권한을 요청합니다. 허용하면 true.
  Future<bool> requestPermission();

  /// 지금의 기기 토큰. 없으면 null.
  Future<String?> token();

  /// 기기 토큰이 바뀔 때마다 새 토큰.
  Stream<String> get tokenRefreshes;

  /// 알림을 눌러 앱이 열릴 때마다.
  Stream<PushOpen> get opens;
}
