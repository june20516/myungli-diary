import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/deletion_scheduled.dart';
import 'package:myungli_diary/core/api/gen/model/refresh_request.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/profile/application/account_delete_controller.dart';

/// `deleteMe`·`logout`이 늘 성공하는 대역.
final class _Api implements DefaultApi {
  int deleteCalls = 0;

  @override
  Future<Response<DeletionScheduled>> deleteMe({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    deleteCalls++;
    return Response(
      requestOptions: RequestOptions(),
      statusCode: 202,
      data: DeletionScheduled(
        deletionScheduledAt: DateTime.utc(2026, 11, 12, 15),
      ),
    );
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
  }) async => Response(requestOptions: RequestOptions(), statusCode: 204);

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

void main() {
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
