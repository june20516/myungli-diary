import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/device_registrar.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/pending_destination.dart';
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
  bool notifyAskPending,
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
      notifyAskPending: await container
          .read(deviceFlagsStoreProvider)
          .readBool(notifyAskPendingKey),
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
    // 알림 허락을 아직 거치지 않은 새 계정처럼 알림 허락 대기 플래그도 켭니다(A17).
    await tester.runAsync(() async {
      await _seedLocalData(container.read(appDatabaseProvider));
      await container
          .read(deviceFlagsStoreProvider)
          .writeBool(notifyAskPendingKey, value: true);
    });

    // AuthInterceptor가 refresh 거부(401·재사용) 때 부르는 것과 같은 경로입니다.
    await tester.runAsync(container.read(tokenStoreProvider).signOut);
    await _settle(tester);

    final remaining = await _remaining(tester, container);
    _expectCleaned(remaining);
    expect(remaining.adConsentDone, isTrue, reason: '기기 플래그는 남습니다');
    expect(
      remaining.notifyAskPending,
      isFalse,
      reason: '알림 허락 대기는 그 계정의 온보딩 단계라 끕니다(A17)',
    );
    expect(purchases.loggedInAccountId, isNull);
    expect(crash.userId, isNull);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });

  testWidgets('refresh·로그아웃으로 다시 계산하는 동안 진입 갈래가 null이 되지 않아 목적지를 기억하지 않습니다', (
    tester,
  ) async {
    // 진입 뒤 목적지 복귀(A17)는 entry가 null일 때만 경로를 기억합니다. 다시 계산하는
    // 동안 이전 값이 남는다는 전제가 깨지면 로그아웃한 계정의 경로가 다음 진입에 새므로
    // 그 전제를 고정합니다.
    final (container, _) = await launchWithLeftovers(
      tester,
      scenario: 'member',
    );
    final entries = <EntryState?>[];
    container.listen(entryProvider, (_, next) => entries.add(next));
    final router = container.read(routerProvider)..go('/calendar');
    // 달력은 대역 서버(실제 I/O)에서 달을 받으므로 I/O와 함께 정착합니다.
    await settleWithIo(tester);

    await tester.runAsync(container.read(entryStateProvider.notifier).refresh);
    await _settle(tester);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/calendar');

    await tester.runAsync(container.read(tokenStoreProvider).signOut);
    await _settle(tester);

    expect(entries, isNot(contains(null)));
    expect(entries.last, EntryState.signedOut);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/welcome');
    expect(container.read(pendingDestinationProvider), isNull);
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
        releaseDevice: container
            .read(deviceRegistrarProvider)
            .releaseForSignOut,
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

  testWidgets('로그아웃 뒤 진입 계산이 실패해도 이전 계정의 갈래를 들고 있지 않고, 다시 시도하면 welcome', (
    tester,
  ) async {
    var configDown = false;
    final (container, _) = await launchWithLeftovers(
      tester,
      scenario: 'member',
    );
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(
      interceptors.length - 1,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (configDown && options.path == '/v1/app-config') {
            handler.reject(
              DioException.badResponse(
                statusCode: 503,
                requestOptions: options,
                response: _problem(options, 503, 'service.unavailable'),
              ),
              true,
            );
          } else {
            handler.next(options);
          }
        },
      ),
    );
    expect(container.read(entryProvider), EntryState.ready);

    configDown = true;
    await tester.runAsync(container.read(tokenStoreProvider).signOut);
    await _settle(tester);

    expect(container.read(entryStateProvider).hasError, isTrue);
    expect(container.read(entryProvider), EntryState.signedOut);
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsNothing);

    configDown = false;
    await tester.runAsync(container.read(entryStateProvider.notifier).refresh);
    await _settle(tester);
    expect(container.read(entryProvider), EntryState.signedOut);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
  });
}
