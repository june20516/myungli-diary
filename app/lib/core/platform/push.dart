import 'package:myungli_diary/core/ia/ia_ids.dart';

/// 알림을 눌러 앱이 열린 사건.
final class PushOpen {
  const new _({required this.screenId});

  /// 열려야 할 화면 id(IA)로 만듭니다. IA 화면 id가 아니면 null입니다.
  ///
  /// 모르는 값을 `today` 같은 화면으로 바꾸지 않고 사건을 무시합니다.
  static PushOpen? tryCreate(String screenId) {
    final sanitized = sanitizeScreenId(screenId);
    return sanitized == null ? null : PushOpen._(screenId: sanitized);
  }

  /// 열려야 할 화면 id(IA).
  final String screenId;
}

/// 푸시 알림(FCM).
abstract interface class PushMessaging {
  /// 알림 권한을 요청합니다. 허용하면 true.
  Future<bool> requestPermission();

  /// 묻지 않고, 지금 OS 알림 권한이 허락돼 있는지. 묻기 전이거나 거절했으면 false.
  Future<bool> hasPermission();

  /// 지금의 기기 토큰. 없으면 null.
  Future<String?> token();

  /// 기기 토큰이 바뀔 때마다 새 토큰.
  Stream<String> get tokenRefreshes;

  /// 앱이 실행 중일 때 알림을 눌러 열릴 때마다.
  Stream<PushOpen> get opens;

  /// 앱이 꺼진 상태에서 알림을 눌러 시작됐으면 그 사건. 아니면 null.
  Future<PushOpen?> initialOpen();
}
