import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/push_channel.dart';

void main() {
  test('ensureMorning은 id morning과 받은 이름으로 Android 채널을 만듭니다', () async {
    final created = <AndroidNotificationChannel>[];
    await LocalNotificationChannels(
      isAndroid: true,
      createAndroidChannel: (channel) async => created.add(channel),
    ).ensureMorning('아침 운세');
    expect(created, hasLength(1));
    expect(created.single.id, morningChannelId);
    expect(created.single.name, '아침 운세');
    expect(created.single.importance, Importance.defaultImportance);
  });

  test('iOS에서는 아무것도 하지 않습니다', () async {
    final created = <AndroidNotificationChannel>[];
    await LocalNotificationChannels(
      isAndroid: false,
      createAndroidChannel: (channel) async => created.add(channel),
    ).ensureMorning('아침 운세');
    expect(created, isEmpty);
  });

  test('만들기가 실패해도 던지지 않습니다', () async {
    await expectLater(
      LocalNotificationChannels(
        isAndroid: true,
        createAndroidChannel: (_) => throw StateError('플러그인 없음'),
      ).ensureMorning('아침 운세'),
      completes,
    );
  });
}
