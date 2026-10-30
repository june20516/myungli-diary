import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/firebase_push.dart';

final class _FakeMessagingApi implements MessagingApi {
  new({this.initialData});

  final Map<String, Object?>? initialData;
  final refreshes = StreamController<String>.broadcast();
  final openedData = StreamController<Map<String, Object?>>.broadcast();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> getToken() async => 'fcm-token';

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Stream<Map<String, Object?>> get onMessageOpenedApp => openedData.stream;

  @override
  Future<Map<String, Object?>?> getInitialMessageData() async => initialData;
}

/// 모든 호출이 실패합니다. getter는 Firebase 초기화 전처럼 동기로 던집니다.
final class _ThrowingMessagingApi implements MessagingApi {
  @override
  Future<bool> requestPermission() => Future.error(StateError('실패'));

  @override
  Future<String?> getToken() => Future.error(StateError('실패'));

  @override
  Stream<String> get onTokenRefresh => throw StateError('초기화 전');

  @override
  Stream<Map<String, Object?>> get onMessageOpenedApp =>
      throw StateError('초기화 전');

  @override
  Future<Map<String, Object?>?> getInitialMessageData() =>
      throw StateError('초기화 전');
}

void main() {
  group('pushOpenFromData', () {
    test('kind morning이면 today', () {
      expect(
        pushOpenFromData({'kind': 'morning', 'date': '2026-10-28'})?.screenId,
        ScreenIds.today,
      );
    });

    test('모르는 kind와 빈 data는 null', () {
      expect(pushOpenFromData({'kind': 'evening'}), isNull);
      expect(pushOpenFromData({}), isNull);
    });
  });

  group('FirebasePushMessaging', () {
    test('토큰을 그대로 돌려줍니다', () async {
      expect(
        await FirebasePushMessaging(api: _FakeMessagingApi()).token(),
        'fcm-token',
      );
    });

    test('getToken이 던지면 null', () async {
      expect(
        await FirebasePushMessaging(api: _ThrowingMessagingApi()).token(),
        isNull,
      );
    });

    test('requestPermission이 실패하면 false', () async {
      expect(
        await FirebasePushMessaging(api: _ThrowingMessagingApi())
            .requestPermission(),
        isFalse,
      );
    });

    test('opens는 morning만 흘립니다', () async {
      final api = _FakeMessagingApi();
      final opens = <String>[];
      final subscription = FirebasePushMessaging(api: api).opens
          .listen((open) => opens.add(open.screenId));
      api.openedData
        ..add({'kind': 'evening'})
        ..add({'kind': 'morning'});
      await pumpEventQueue();
      await subscription.cancel();
      expect(opens, [ScreenIds.today]);
    });

    test('tokenRefreshes는 새 토큰을 흘립니다', () async {
      final api = _FakeMessagingApi();
      final tokens = <String>[];
      final subscription = FirebasePushMessaging(api: api).tokenRefreshes
          .listen(tokens.add);
      api.refreshes.add('next-token');
      await pumpEventQueue();
      await subscription.cancel();
      expect(tokens, ['next-token']);
    });

    test('initialOpen은 처음 메시지의 data로', () async {
      final push = FirebasePushMessaging(
        api: _FakeMessagingApi(initialData: {'kind': 'morning'}),
      );
      expect((await push.initialOpen())?.screenId, ScreenIds.today);
      expect(
        await FirebasePushMessaging(api: _FakeMessagingApi()).initialOpen(),
        isNull,
      );
    });

    test('SDK getter가 동기로 던져도 opens·tokenRefreshes는 빈 스트림, '
        'initialOpen은 null', () async {
      final push = FirebasePushMessaging(api: _ThrowingMessagingApi());
      expect(await push.opens.toList(), isEmpty);
      expect(await push.tokenRefreshes.toList(), isEmpty);
      expect(await push.initialOpen(), isNull);
    });
  });
}
