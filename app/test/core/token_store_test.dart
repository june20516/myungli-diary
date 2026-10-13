import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

class _FailingWriteStore implements SecureStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> write(String key, String value) async {
    throw StateError('저장 실패');
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
}
