import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/refresh_request.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

/// logout을 흉내 냅니다. [onLogout]으로 interceptor의 동작(예: refresh 거부 뒤
/// 로그아웃)을 재현합니다.
final class _LogoutApi implements DefaultApi {
  new(this.onLogout);

  final Future<void> Function() onLogout;
  int calls = 0;

  @override
  Future<Response<void>> logout({
    required RefreshRequest refreshRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls++;
    await onLogout();
    return Response(requestOptions: RequestOptions(), statusCode: 204);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _pair = TokenPair(
  accessToken: 'access',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshToken: 'refresh',
  refreshTokenExpiresAt: DateTime.utc(2031),
);

void main() {
  late TokenStore tokens;
  late List<AuthEvent> events;

  setUp(() async {
    tokens = TokenStore(MemorySecureStore());
    await tokens.save(_pair);
    events = [];
    tokens.events.listen(events.add);
  });

  tearDown(() => tokens.dispose());

  test('logout 중에 interceptor가 이미 로그아웃했으면 signedOut을 한 번만 냅니다', () async {
    // access token 만료 → refresh 거부 → interceptor가 signOut한 경우입니다.
    final api = _LogoutApi(() async {
      await tokens.signOut();
      throw DioException(requestOptions: RequestOptions());
    });

    await revokeAndSignOut(
      api: api,
      tokens: tokens,
      releaseDevice: () async {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(api.calls, 1);
    expect(events, [AuthEvent.signedOut]);
  });

  test('기기 해제를 server 로그아웃보다 먼저 부릅니다(#347 ②)', () async {
    final order = <String>[];
    final api = _LogoutApi(() async => order.add('logout'));

    await revokeAndSignOut(
      api: api,
      tokens: tokens,
      releaseDevice: () async => order.add('releaseDevice'),
    );

    expect(order, ['releaseDevice', 'logout']);
  });

  test('logout이 성공하면 토큰을 지우고 signedOut을 한 번 냅니다', () async {
    final api = _LogoutApi(() async {});

    await revokeAndSignOut(
      api: api,
      tokens: tokens,
      releaseDevice: () async {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, [AuthEvent.signedOut]);
    expect(tokens.accessToken, isNull);
    expect(await tokens.refreshToken(), isNull);
  });
}
