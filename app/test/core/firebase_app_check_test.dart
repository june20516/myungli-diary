import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/firebase/firebase_env.dart';
import 'package:myungli_diary/core/platform/firebase_app_check.dart';

final class _FakeAppCheckApi implements AppCheckApi {
  new(this._getToken);

  final Future<String?> Function() _getToken;

  @override
  Future<void> activate({
    required AppCheckMode mode,
    String? debugToken,
  }) async {}

  @override
  Future<String?> getToken() => _getToken();
}

void main() {
  group('FirebaseAppCheckAdapter', () {
    test('토큰이 있으면 그 토큰', () async {
      final adapter = FirebaseAppCheckAdapter(
        api: _FakeAppCheckApi(() async => 'token-1'),
      );
      expect(await adapter.token(), 'token-1');
    });

    test('토큰이 null이면 null', () async {
      final adapter = FirebaseAppCheckAdapter(
        api: _FakeAppCheckApi(() async => null),
      );
      expect(await adapter.token(), isNull);
    });

    test('SDK가 던지면 null', () async {
      final adapter = FirebaseAppCheckAdapter(
        api: _FakeAppCheckApi(() async => throw StateError('초기화 전')),
      );
      expect(await adapter.token(), isNull);
    });

    test('timeout을 넘기면 null', () async {
      final never = Completer<String?>();
      final adapter = FirebaseAppCheckAdapter(
        api: _FakeAppCheckApi(() => never.future),
        timeout: const Duration(milliseconds: 10),
      );
      expect(await adapter.token(), isNull);
    });
  });

  group('appCheckModeFor', () {
    test('debug 빌드이고 staging일 때만 debug', () {
      expect(appCheckModeFor(env: FirebaseEnv.staging), AppCheckMode.debug);
    });

    test('release staging과 prod는 attest', () {
      expect(
        appCheckModeFor(env: FirebaseEnv.staging, isDebug: false),
        AppCheckMode.attest,
      );
      expect(
        appCheckModeFor(env: FirebaseEnv.prod, isDebug: false),
        AppCheckMode.attest,
      );
    });

    test('debug prod도 attest', () {
      expect(appCheckModeFor(env: FirebaseEnv.prod), AppCheckMode.attest);
    });
  });
}
