import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/refresh_request.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/profile/application/account_delete_controller.dart';

/// `deleteMe`가 [deleteStatus]로 끝나는 대역. 204가 아니면 그 상태의 DioException을 던집니다.
final class _Api implements DefaultApi {
  new({this.deleteStatus = 204});

  final int deleteStatus;
  int deleteCalls = 0;
  int logoutCalls = 0;

  @override
  Future<Response<void>> deleteMe({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    deleteCalls++;
    final options = RequestOptions();
    if (deleteStatus != 204) {
      throw DioException.badResponse(
        statusCode: deleteStatus,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: deleteStatus),
      );
    }
    return Response(requestOptions: options, statusCode: 204);
  }

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
    logoutCalls++;
    return Response(requestOptions: RequestOptions(), statusCode: 204);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 지우기(로컬 로그아웃)만 실패하는 보안 저장소(키체인 오류 등).
final class _DeleteFailingStore implements SecureStore {
  final _inner = MemorySecureStore();

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) => _inner.write(key, value);

  @override
  Future<void> delete(String key) async => throw StateError('키체인을 지우지 못했습니다');
}

Future<TokenStore> _signedIn(SecureStore store) async {
  final tokens = TokenStore(store);
  addTearDown(tokens.dispose);
  await tokens.save(
    TokenPair(
      accessToken: 'access',
      accessTokenExpiresAt: DateTime.utc(2030),
      refreshToken: 'refresh',
      refreshTokenExpiresAt: DateTime.utc(2031),
    ),
  );
  return tokens;
}

ProviderContainer _containerOf(_Api api, TokenStore tokens) {
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(api),
      tokenStoreProvider.overrideWithValue(tokens),
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(accountDeleteControllerProvider, (_, _) {});
  addTearDown(sub.close);
  return container;
}

void main() {
  test('204면 server logout 없이 로컬 로그아웃한다', () async {
    final api = _Api();
    final tokens = await _signedIn(MemorySecureStore());
    final events = <AuthEvent>[];
    tokens.events.listen(events.add);
    final container = _containerOf(api, tokens);

    await container.read(accountDeleteControllerProvider.notifier).delete();
    await pumpEventQueue();

    expect(api.deleteCalls, 1);
    expect(api.logoutCalls, 0);
    expect(await tokens.hasSession(), isFalse);
    expect(events, [AuthEvent.signedOut]);
  });

  test('401이면 이미 지워진 것으로 보고 로컬 로그아웃한다', () async {
    final api = _Api(deleteStatus: 401);
    final tokens = await _signedIn(MemorySecureStore());
    final container = _containerOf(api, tokens);

    await container.read(accountDeleteControllerProvider.notifier).delete();

    expect(api.logoutCalls, 0);
    expect(await tokens.hasSession(), isFalse);
  });

  test('503이면 로그인 상태 그대로 AppError를 던진다', () async {
    final api = _Api(deleteStatus: 503);
    final tokens = await _signedIn(MemorySecureStore());
    final container = _containerOf(api, tokens);

    await expectLater(
      container.read(accountDeleteControllerProvider.notifier).delete(),
      throwsA(isA<AppError>()),
    );

    expect(await tokens.hasSession(), isTrue);
    expect(container.read(accountDeleteControllerProvider), isFalse);
  });

  test(
    'deleteMe 뒤 로컬 로그아웃이 예상 밖 오류면 요약만 기록하고 UnexpectedError로 던집니다(D64)',
    () async {
      final api = _Api();
      final tokens = TokenStore(_DeleteFailingStore());
      addTearDown(tokens.dispose);
      await tokens.save(
        TokenPair(
          accessToken: 'access',
          accessTokenExpiresAt: DateTime.utc(2030),
          refreshToken: 'refresh',
          refreshTokenExpiresAt: DateTime.utc(2031),
        ),
      );
      final crash = FakeCrashReporter();
      final container = ProviderContainer(
        overrides: [
          restClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(tokens),
          crashReporterProvider.overrideWithValue(crash),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(accountDeleteControllerProvider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(accountDeleteControllerProvider.notifier).delete(),
        throwsA(isA<UnexpectedError>()),
      );
      expect(api.deleteCalls, 1);
      expect(crash.errors.single.errorType, 'StateError');
      // 끝나면 다시 누를 수 있습니다.
      expect(container.read(accountDeleteControllerProvider), isFalse);
    },
  );
}
