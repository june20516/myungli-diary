import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

/// [failWrites]를 켜면 쓰기가 실패하는 저장소.
class _FailingWriteStore implements SecureStore {
  bool failWrites = true;
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('저장 실패');
    }
    _values[key] = value;
  }
}

TokenPair _pair(String access) => TokenPair(
  accessToken: access,
  accessTokenExpiresAt: DateTime.utc(2026, 10, 14),
  refreshToken: 'refresh-$access',
  refreshTokenExpiresAt: DateTime.utc(2026, 11),
);

void main() {
  test('refresh token 저장이 실패하면 메모리 access token도 바뀌지 않는다', () async {
    final tokens = TokenStore(_FailingWriteStore());

    await expectLater(tokens.save(_pair('new')), throwsStateError);

    expect(tokens.accessToken, isNull);
  });

  test('저장이 실패하면 기존 access·refresh token이 그대로 남는다', () async {
    final store = _FailingWriteStore()..failWrites = false;
    final tokens = TokenStore(store);
    await tokens.save(_pair('old'));

    store.failWrites = true;
    await expectLater(tokens.save(_pair('new')), throwsStateError);

    expect(tokens.accessToken, 'old');
    expect(await tokens.refreshToken(), 'refresh-old');
  });
}
