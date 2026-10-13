import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/app_config.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/minimum_version.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:pub_semver/pub_semver.dart';

Me meWith({
  bool consentRequired = false,
  bool hasProfile = true,
  String accountId = 'acc-1',
}) => Me.fromJson({
  'accountId': accountId,
  'status': 'active',
  'consentRequired': consentRequired,
  'requiredConsents': <String>[],
  'hasProfile': hasProfile,
  'adFree': {'active': false},
  'insight': {'active': false},
});

EntryState compute({
  String app = '1.0.0',
  String minimum = '1.0.0',
  bool hasSession = true,
  Me? me,
  bool adConsentDone = true,
}) => computeEntry(
  appVersion: Version.parse(app),
  minimumVersion: Version.parse(minimum),
  hasSession: hasSession,
  me: me,
  adConsentDone: adConsentDone,
);

void main() {
  group('computeEntry', () {
    test('최소 버전과 같은 버전은 통과합니다', () {
      expect(compute(me: meWith()), EntryState.ready);
    });

    test('최소 버전보다 낮으면 forceUpdate이고 다른 조건보다 먼저입니다', () {
      expect(
        compute(minimum: '1.0.1', hasSession: false),
        EntryState.forceUpdate,
      );
      expect(
        compute(
          minimum: '1.0.1',
          me: meWith(consentRequired: true, hasProfile: false),
          adConsentDone: false,
        ),
        EntryState.forceUpdate,
      );
    });

    test('세션이 없으면 signedOut', () {
      expect(compute(hasSession: false), EntryState.signedOut);
    });

    test('세션은 있어도 me가 없으면 signedOut', () {
      expect(compute(), EntryState.signedOut);
    });

    test('약관 미동의는 프로필 없음보다 먼저입니다', () {
      expect(
        compute(me: meWith(consentRequired: true, hasProfile: false)),
        EntryState.consentRequired,
      );
    });

    test('프로필이 없으면 profileRequired', () {
      expect(
        compute(me: meWith(hasProfile: false), adConsentDone: false),
        EntryState.profileRequired,
      );
    });

    test('프로필이 있고 이 기기 광고 동의 전이면 adConsentRequired', () {
      expect(
        compute(me: meWith(), adConsentDone: false),
        EntryState.adConsentRequired,
      );
    });

    test('모두 갖추면 ready', () {
      expect(compute(me: meWith()), EntryState.ready);
    });
  });

  group('entryStateProvider', () {
    late AppDatabase database;
    late _Api api;
    late TokenStore tokens;
    late FakeAdConsentCounter consent;

    setUp(() {
      database = AppDatabase.forExecutor(NativeDatabase.memory());
      api = _Api();
      tokens = TokenStore(_MemorySecureStore());
      consent = FakeAdConsentCounter();
    });

    tearDown(() async {
      await tokens.dispose();
      await database.close();
    });

    ProviderContainer container({String version = '1.0.0'}) {
      final c = ProviderContainer(
        overrides: [
          restClientProvider.overrideWithValue(api),
          tokenStoreProvider.overrideWithValue(tokens),
          appDatabaseProvider.overrideWithValue(database),
          adConsentProvider.overrideWithValue(consent),
          appVersionProvider.overrideWith((ref) => Version.parse(version)),
          ...entryOverrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> signIn() async {
      await tokens.save(_pair);
    }

    test('세션이 없으면 getMe를 부르지 않고 signedOut', () async {
      final c = container();
      expect(await c.read(entryStateProvider.future), EntryState.signedOut);
      expect(api.meCalls, 0);
    });

    test('getAppConfig가 실패하면 AsyncError', () async {
      api.configError = DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'offline',
      );
      final c = container();
      await expectLater(
        c.read(entryStateProvider.future),
        throwsA(isA<OfflineError>()),
      );
      expect(c.read(entryStateProvider), isA<AsyncError<EntryState>>());
    });

    test('getMe가 401이면 signedOut', () async {
      await signIn();
      api.meError = _status(401);
      final c = container();
      expect(await c.read(entryStateProvider.future), EntryState.signedOut);
    });

    test('getMe가 그 밖의 오류면 AsyncError', () async {
      await signIn();
      api.meError = _status(500);
      final c = container();
      await expectLater(
        c.read(entryStateProvider.future),
        throwsA(isA<AppError>()),
      );
    });

    test('낮은 앱 버전이면 forceUpdate', () async {
      await signIn();
      final c = container(version: '0.9.0');
      expect(await c.read(entryStateProvider.future), EntryState.forceUpdate);
    });

    test('광고 동의 전이면 gather를 한 번 부르고 플래그를 쓴 뒤 ready', () async {
      await signIn();
      consent.result = AdConsentResult.nonPersonalized;
      final c = container();
      expect(await c.read(entryStateProvider.future), EntryState.ready);
      expect(consent.calls, 1);
      expect(
        await c.read(deviceFlagsStoreProvider).readBool(adConsentDoneKey),
        isTrue,
      );

      await c.read(entryStateProvider.notifier).refresh();
      expect(consent.calls, 1);
    });

    test('me 계정 id가 currentAccountIdProvider로 이어집니다', () async {
      await signIn();
      api.me = meWith(accountId: 'acc-9');
      final c = container();
      await c.read(entryStateProvider.future);
      expect(c.read(currentAccountIdProvider), 'acc-9');
    });

    test('로그아웃 상태에서 currentAccountIdProvider는 StateError', () async {
      final c = container();
      await c.read(entryStateProvider.future);
      expect(
        () => c.read(currentAccountIdProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<StateError>(),
          ),
        ),
      );
    });

    test('signedOut 이벤트를 받으면 다시 계산합니다', () async {
      await signIn();
      final c = container();
      expect(await c.read(entryStateProvider.future), EntryState.ready);
      await tokens.signOut();
      await Future<void>.delayed(Duration.zero);
      await c.read(entryStateProvider.future);
      expect(c.read(entryStateProvider).value, EntryState.signedOut);
    });
  });
}

final _pair = TokenPair(
  accessToken: 'access',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshToken: 'refresh',
  refreshTokenExpiresAt: DateTime.utc(2031),
);

class FakeAdConsentCounter implements AdConsent {
  int calls = 0;
  AdConsentResult result = AdConsentResult.personalized;

  @override
  Future<AdConsentResult> gather() async {
    calls++;
    return result;
  }
}

DioException _status(int status) => DioException.badResponse(
  statusCode: status,
  requestOptions: RequestOptions(),
  response: Response<Object?>(
    requestOptions: RequestOptions(),
    statusCode: status,
  ),
);

class _MemorySecureStore implements SecureStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _Api implements DefaultApi {
  int meCalls = 0;
  DioException? configError;
  DioException? meError;
  Me? me;

  @override
  Future<Response<AppConfig>> getAppConfig({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (configError != null) {
      throw configError!;
    }
    return Response(
      requestOptions: RequestOptions(),
      data: AppConfig(
        minimumVersion: MinimumVersion(ios: '1.0.0', android: '1.0.0'),
      ),
    );
  }

  @override
  Future<Response<Me>> getMe({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    meCalls++;
    if (meError != null) {
      throw meError!;
    }
    return Response(requestOptions: RequestOptions(), data: me ?? meWith());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
