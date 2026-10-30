import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/push.dart';

/// 알림 `data`에서 열 화면. `kind`가 `morning`이면 오늘 화면이고, 모르는 종류(열린 값)나
/// 빈 `data`는 앱만 열도록 null입니다(#603).
PushOpen? pushOpenFromData(Map<String, Object?> data) =>
    data['kind'] == 'morning' ? PushOpen.tryCreate(ScreenIds.today) : null;

/// Firebase Messaging SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는
/// [FirebasePushMessaging]에 둡니다.
abstract interface class MessagingApi {
  /// 알림 권한을 요청합니다. 허용(임시 허용 포함)하면 true.
  Future<bool> requestPermission();

  /// 묻지 않고 지금 알림 권한이 허락(임시 허용 포함)돼 있는지.
  Future<bool> hasPermission();

  /// 지금의 FCM 토큰.
  Future<String?> getToken();

  /// FCM 토큰이 바뀔 때마다.
  Stream<String> get onTokenRefresh;

  /// 실행 중 알림을 눌러 열릴 때마다 그 메시지의 `data`.
  Stream<Map<String, Object?>> get onMessageOpenedApp;

  /// 꺼진 상태에서 알림으로 시작했으면 그 메시지의 `data`.
  Future<Map<String, Object?>?> getInitialMessageData();
}

/// 실제 Firebase Messaging SDK를 부르는 경계(기본값).
final class SdkMessagingApi implements MessagingApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<bool> requestPermission() async =>
      _allowed(await FirebaseMessaging.instance.requestPermission());

  @override
  Future<bool> hasPermission() async =>
      _allowed(await FirebaseMessaging.instance.getNotificationSettings());

  static bool _allowed(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => true,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently ||
        AuthorizationStatus.notDetermined => false,
      };

  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<Map<String, Object?>> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async =>
      (await FirebaseMessaging.instance.getInitialMessage())?.data;
}

/// 푸시 알림의 실제 구현(FCM).
///
/// Firebase 초기화가 실패했으면(A93) SDK가 동기로 던질 수 있어 모든 호출을 감쌉니다.
/// 토큰과 처음 사건은 null, 스트림은 빈 스트림, 권한은 false로 끝납니다.
final class FirebasePushMessaging implements PushMessaging {
  /// adapter를 만듭니다.
  const new({this.api = const SdkMessagingApi()});

  /// SDK 경계.
  final MessagingApi api;

  @override
  Future<bool> requestPermission() async {
    try {
      return await api.requestPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await api.hasPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    try {
      return await api.getToken();
    } on Object {
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes => _guard(() => api.onTokenRefresh);

  @override
  Stream<PushOpen> get opens =>
      _guard(() => api.onMessageOpenedApp)
          .map(pushOpenFromData)
          .where((open) => open != null)
          .cast<PushOpen>();

  @override
  Future<PushOpen?> initialOpen() async {
    try {
      final data = await api.getInitialMessageData();
      return data == null ? null : pushOpenFromData(data);
    } on Object {
      return null;
    }
  }

  static Stream<T> _guard<T>(Stream<T> Function() stream) {
    try {
      return stream().handleError((Object _) {});
    } on Object {
      return const Stream.empty();
    }
  }
}
