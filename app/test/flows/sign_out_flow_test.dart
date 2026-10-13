import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

import '../support/app_harness.dart';

/// member fixture의 계정 id.
const _memberAccountId = '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10';

/// 정한 요청만 대신 답하고 나머지는 대역 서버로 넘기는 interceptor.
///
/// 대역 서버 바로 앞에 끼웁니다. 키는 `<METHOD> <path>`입니다.
final class _StubServer extends Interceptor {
  new(this.stubs);

  final Map<String, Response<Object?> Function(RequestOptions)> stubs;
  final calls = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final stub = stubs['${options.method} ${options.path}'];
    if (stub == null) {
      handler.next(options);
      return;
    }
    calls.add(options);
    final response = stub(options);
    final status = response.statusCode ?? 200;
    if (status >= 400) {
      handler.reject(
        DioException.badResponse(
          statusCode: status,
          requestOptions: options,
          response: response,
        ),
        true,
      );
    } else {
      handler.resolve(response, true);
    }
  }
}

Response<Object?> _problem(RequestOptions options, int status, String code) =>
    Response<Object?>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: ['application/problem+json'],
      }),
      data: {'status': status, 'code': code, 'title': code, 'traceId': 't'},
    );

Response<Object?> _pendingDeletionMe(RequestOptions options) =>
    Response<Object?>(
      requestOptions: options,
      statusCode: 200,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: ['application/json'],
      }),
      data: {
        'accountId': _memberAccountId,
        'status': 'pending_deletion',
        'deletionScheduledAt': '2026-11-12T00:00:00Z',
        'consentRequired': false,
        'requiredConsents': <Object?>[],
        'hasProfile': true,
        'adFree': {'active': false},
        'insight': {'active': false},
      },
    );

/// 이전 실행이 남긴 것처럼 로컬 데이터를 심습니다.
Future<void> _seedLocalData(AppDatabase database) async {
  await database
      .into(database.cachedResponses)
      .insertOnConflictUpdate(
        CachedResponsesCompanion.insert(
          accountId: _memberAccountId,
          kind: 'calendar',
          cacheKey: 'k',
          json: '{}',
          evidenceAccess: 'unlocked',
          fetchedAt: DateTime.utc(2026, 10, 12),
        ),
      );
  await database
      .into(database.diaryDrafts)
      .insertOnConflictUpdate(
        DiaryDraftsCompanion.insert(
          accountId: _memberAccountId,
          date: '2026-10-12',
          body: '초안',
          updatedAt: DateTime.utc(2026, 10, 12),
        ),
      );
  await database
      .into(database.onboardingInputs)
      .insertOnConflictUpdate(
        OnboardingInputsCompanion.insert(
          id: const Value(1),
          json: '{"honorific":"하늘"}',
          updatedAt: DateTime.utc(2026, 10, 12),
        ),
      );
}

typedef _Remaining = ({
  int cached,
  int drafts,
  int onboarding,
  bool adConsentDone,
  String? refreshToken,
});

Future<_Remaining> _remaining(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final database = container.read(appDatabaseProvider);
  return (await tester.runAsync(() async {
    return (
      cached: (await database.select(database.cachedResponses).get()).length,
      drafts: (await database.select(database.diaryDrafts).get()).length,
      onboarding:
          (await database.select(database.onboardingInputs).get()).length,
      adConsentDone: await container
          .read(deviceFlagsStoreProvider)
          .readBool(adConsentDoneKey),
      refreshToken: await container.read(tokenStoreProvider).refreshToken(),
    );
  }))!;
}

void _expectCleaned(_Remaining remaining) {
  expect(remaining.cached, 0, reason: '캐시');
  expect(remaining.drafts, 0, reason: '일기 초안');
  expect(remaining.onboarding, 0, reason: '온보딩 입력');
  expect(remaining.refreshToken, isNull, reason: 'refresh token');
}

/// 비동기 정리(DB 실제 I/O)가 끝나도록 시계를 풀어 줍니다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

void main() {
  late FakePurchases purchases;
  late FakeCrashReporter crash;

  setUp(() {
    purchases = FakePurchases();
    crash = FakeCrashReporter();
  });

  List<Override> fakes() => [
    purchasesProvider.overrideWithValue(purchases),
    crashReporterProvider.overrideWithValue(crash),
  ];

  /// 이전 실행의 데이터와 SDK 연결이 남은 상태로 [scenario]를 띄웁니다.
  /// [stubs]는 진입 계산 전에 대역 서버 앞에 끼웁니다.
  Future<(ProviderContainer, _StubServer)> launchWithLeftovers(
    WidgetTester tester, {
    required String scenario,
    Map<String, Response<Object?> Function(RequestOptions)> stubs = const {},
  }) async {
    final container = (await tester.runAsync(
      () => bootstrapForTest(scenario, overrides: fakes()),
    ))!;
    addTearDown(container.dispose);
    final stub = _StubServer(stubs);
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, stub);
    await tester.runAsync(() async {
      await _seedLocalData(container.read(appDatabaseProvider));
      await container
          .read(deviceFlagsStoreProvider)
          .writeBool(adConsentDoneKey, value: true);
      // RevenueCat SDK는 이전 실행의 계정을 기억합니다.
      await purchases.logIn('previous-run');
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyungliApp(),
      ),
    );
    await settleEntry(tester, container);
    await _settle(tester);
    return (container, stub);
  }

  testWidgets('로그인한 뒤 강제 로그아웃되면 로컬 데이터를 비우고 SDK 연결을 끊습니다', (tester) async {
    final (container, _) = await launchWithLeftovers(
      tester,
      scenario: 'member',
    );
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    expect(container.read(meProvider)?.accountId, _memberAccountId);
    // 다른 실행에서 남은 데이터를 다시 심습니다(로그인 상태에서 쌓인 것).
    await tester.runAsync(
      () => _seedLocalData(container.read(appDatabaseProvider)),
    );

    // AuthInterceptor가 refresh 거부(401·재사용) 때 부르는 것과 같은 경로입니다.
    await tester.runAsync(container.read(tokenStoreProvider).signOut);
    await _settle(tester);

    final remaining = await _remaining(tester, container);
    _expectCleaned(remaining);
    expect(remaining.adConsentDone, isTrue, reason: '기기 플래그는 남습니다');
    expect(purchases.loggedInAccountId, isNull);
    expect(crash.userId, isNull);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });

  testWidgets('시작 직후 refresh가 거부되면 내 정보를 받기 전이어도 로컬 데이터를 비웁니다', (tester) async {
    final (container, stub) = await launchWithLeftovers(
      tester,
      scenario: 'member',
      stubs: {
        'POST /v1/auth/refresh': (o) => _problem(o, 401, 'auth.refresh_reused'),
      },
    );

    expect(stub.calls, hasLength(1));
    expect(container.read(meProvider), isNull);
    final remaining = await _remaining(tester, container);
    _expectCleaned(remaining);
    expect(remaining.adConsentDone, isTrue, reason: '기기 플래그는 남습니다');
    expect(purchases.loggedInAccountId, isNull, reason: '이전 실행의 구매 계정 해제');
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });

  testWidgets('시작 때 삭제 대기 계정이면 server logout을 시도하고 로컬 데이터를 비웁니다', (
    tester,
  ) async {
    final (container, stub) = await launchWithLeftovers(
      tester,
      scenario: 'member',
      stubs: {
        'GET /v1/me': _pendingDeletionMe,
        // 폐기가 실패해도 로컬 로그아웃은 합니다.
        'POST /v1/auth/logout': (o) => _problem(o, 503, 'service.unavailable'),
      },
    );

    final logout = stub.calls.where((o) => o.path == '/v1/auth/logout');
    expect(logout, hasLength(1));
    expect(logout.single.data, contains('fake-refresh-token'));
    _expectCleaned(await _remaining(tester, container));
    expect(container.read(meProvider), isNull);
    expect(purchases.loggedInAccountId, isNull);
    expect(crash.userId, isNull, reason: '삭제 대기 계정은 연결하지 않습니다');
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });

  testWidgets('getMe가 401이면 refresh token을 지우고 로컬 데이터를 비웁니다', (tester) async {
    final (container, _) = await launchWithLeftovers(
      tester,
      scenario: 'member',
      stubs: {'GET /v1/me': (o) => _problem(o, 401, 'auth.token_invalid')},
    );

    _expectCleaned(await _remaining(tester, container));
    expect(purchases.loggedInAccountId, isNull);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });

  testWidgets('자발적 로그아웃은 server에 폐기를 보내고 같은 정리를 거칩니다', (tester) async {
    final (container, stub) = await launchWithLeftovers(
      tester,
      scenario: 'member',
      stubs: {
        'POST /v1/auth/logout': (o) =>
            Response<Object?>(requestOptions: o, statusCode: 204),
      },
    );
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    await tester.runAsync(
      () => _seedLocalData(container.read(appDatabaseProvider)),
    );

    await tester.runAsync(
      () => revokeAndSignOut(
        api: container.read(restClientProvider),
        tokens: container.read(tokenStoreProvider),
      ),
    );
    await _settle(tester);

    final logout = stub.calls.where((o) => o.path == '/v1/auth/logout');
    expect(logout, hasLength(1));
    expect(
      logout.single.headers['Authorization'],
      isNotNull,
      reason: 'logout은 bearer가 필요합니다',
    );
    _expectCleaned(await _remaining(tester, container));
    expect(purchases.loggedInAccountId, isNull);
    expect(crash.userId, isNull);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });

  testWidgets('세션 복원 뒤 구매·비정상 종료 보고에 계정 id를 잇고 화면 id를 남깁니다', (tester) async {
    await pumpApp(tester, scenario: 'member', overrides: fakes());

    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    await _settle(tester);
    expect(purchases.loggedInAccountId, _memberAccountId);
    expect(crash.userId, _memberAccountId);
    expect(crash.breadcrumbs, [ScreenIds.launch, ScreenIds.today]);
  });
}
