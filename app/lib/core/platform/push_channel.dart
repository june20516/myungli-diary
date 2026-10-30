import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 아침 알림 Android 채널 id. server가 보내는 `android.notification.channel_id`와
/// 같습니다(#603).
const String morningChannelId = 'morning';

/// 알림 채널. 이름은 기기 설정 > 알림에 보이는 글이라 앱 언어를 따릅니다(W46).
abstract interface class NotificationChannels {
  /// 아침 알림 채널을 [name]으로 만듭니다. 이미 있으면 이름만 바뀝니다.
  Future<void> ensureMorning(String name);
}

/// Android 채널을 만드는 경계.
typedef CreateAndroidChannel = Future<void> Function(
  AndroidNotificationChannel channel,
);

Future<void> _createWithPlugin(AndroidNotificationChannel channel) async {
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

/// `flutter_local_notifications`로 채널을 만드는 실제 구현. iOS는 채널이 없어 아무것도
/// 하지 않고, 실패는 삼킵니다(채널이 없으면 Android가 기본 채널로 보임).
final class LocalNotificationChannels implements NotificationChannels {
  /// [isAndroid]가 false면 아무것도 하지 않습니다.
  const new({
    required this.isAndroid,
    this.createAndroidChannel = _createWithPlugin,
  });

  /// Android에서 실행 중인지.
  final bool isAndroid;

  /// 채널 만들기 경계.
  final CreateAndroidChannel createAndroidChannel;

  @override
  Future<void> ensureMorning(String name) async {
    if (!isAndroid) return;
    try {
      await createAndroidChannel(
        AndroidNotificationChannel(morningChannelId, name),
      );
    } on Object {
      // 채널 이름을 못 바꿔도 알림은 기본 채널로 보입니다.
    }
  }
}
