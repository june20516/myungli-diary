import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/reaction_input.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/reaction_controller.dart';

import '../../support/app_harness.dart';
import '../../support/daily_fixture.dart';

final _today = CalendarDate(2026, 10, 13);

/// 반응 요청(PUT·DELETE)을 `METHOD path`로 남기고, [hold]가 있으면 끝날 때까지 붙잡습니다.
final class _ReactionTap extends Interceptor {
  final requests = <String>[];

  /// 설정되어 있으면 이 Future가 끝날 때까지 다음 반응 요청에 응답하지 않습니다.
  Completer<void>? hold;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains('/reaction')) {
      requests.add('${options.method} ${options.path}');
      final pending = hold;
      if (pending != null) {
        await pending.future;
      }
    }
    handler.next(options);
  }
}

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// [scenario]로 부팅하고 오늘 응답이 올 때까지 기다립니다.
Future<(ProviderContainer, _ReactionTap)> _boot(
  WidgetTester tester, {
  String scenario = 'member',
  List<Override> overrides = const [],
}) async {
  final container = (await tester.runAsync(
    () => bootstrapForTest(scenario, overrides: overrides),
  ))!;
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(entryStateProvider.future));
  expect(container.read(entryProvider), EntryState.ready);
  final tap = _ReactionTap();
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, tap);
  await tester.runAsync(
    () => container.read(timezoneSyncProvider).syncIfChanged(),
  );
  final subscription = container.listen(dailyControllerProvider, (_, _) {});
  addTearDown(subscription.close);
  await _until(
    tester,
    () => container.read(dailyControllerProvider).value != null,
  );
  return (container, tap);
}

/// `putReaction`이 API 밖의 예외(`StateError`)로 끝나는 클라이언트. server에 닿지 않습니다.
final class _ThrowingApi extends DefaultApi {
  // 생성 클라이언트의 매개변수 이름(`_dio`)은 숨겨져 있어 이름을 맞출 수 없습니다.
  // ignore: matching_super_parameters
  const new(super.dio);

  @override
  Future<Response<void>> putReaction({
    required String date,
    required String slot,
    required ReactionInput reactionInput,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => throw StateError('server에 닿기 전 실패');
}

/// 캐시 키 조회가 던지는 provider 대체.
final _throwingKeyLookup = <Override>[
  reactionCacheKeyProvider.overrideWithValue(
    (_) => throw StateError('캐시 키 실패'),
  ),
];

/// 손으로 바꾸는 "오늘". 화면이 열린 채 자정을 넘기는 것을 흉내 냅니다.
final class _TestToday extends Notifier<CalendarDate> {
  @override
  CalendarDate build() => CalendarDate(2026, 10, 13);

  CalendarDate get date => state;

  set date(CalendarDate value) => state = value;
}

final _testTodayProvider = NotifierProvider<_TestToday, CalendarDate>(
  _TestToday.new,
);

FakeCrashReporter _reporter(ProviderContainer container) =>
    container.read(crashReporterProvider) as FakeCrashReporter;

/// getDaily만 대신 답하는 대역을 대역 서버 앞에 끼웁니다. 본문은 member와 같은 응답에서 시작합니다.
ScriptedDailyServer _scriptDaily(ProviderContainer container) {
  final server = ScriptedDailyServer();
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, server);
  return server;
}

/// [server]의 총운 첫 문장 반응을 [liked]에 맞춥니다.
void _setScriptedReaction(ScriptedDailyServer server, {required bool liked}) {
  final fortune = server.body['fortune']! as Map<String, dynamic>;
  final head = fortune['head']! as Map<String, dynamic>;
  if (liked) {
    head['reaction'] = 'like';
  } else {
    head.remove('reaction');
  }
}

/// 오늘 응답을 다시 받고 값이 돌아올 때까지 기다립니다.
Future<void> _reload(WidgetTester tester, ProviderContainer container) async {
  unawaited(container.read(dailyControllerProvider.notifier).reload());
  await _spin(tester);
  await _until(
    tester,
    () => !container.read(dailyControllerProvider).isLoading,
  );
}

/// 실제 I/O와 가짜 시계의 microtask를 한 번씩 풀어 줍니다.
Future<void> _spin(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 300; i++) {
    if (done()) {
      return;
    }
    await _spin(tester);
  }
  fail('조건이 채워지지 않음');
}

/// 오늘 총운 첫 문장.
SlotText _head(ProviderContainer container) =>
    container.read(dailyControllerProvider).value!.daily.fortune.head;

/// `toggle`을 부르고, 끝났는지와 던진 오류를 담는 상자를 돌려줍니다.
({bool Function() finished, List<Object> errors}) _press(
  ProviderContainer container,
) {
  final errors = <Object>[];
  var finished = false;
  unawaited(
    container
        .read(reactionControllerProvider.notifier)
        .toggle(_head(container), date: _today)
        .catchError(errors.add)
        .whenComplete(() => finished = true),
  );
  return (finished: () => finished, errors: errors);
}

bool _liked(ProviderContainer container) => ReactionController.isLiked(
  container.read(reactionControllerProvider),
  _today,
  _head(container),
);

/// 그날 캐시에 저장된 총운 첫 문장의 반응.
Future<SlotTextReactionEnum?> _cachedReaction(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final key = container.read(dailyControllerProvider.notifier).cacheKey!;
  final cached = await tester.runAsync<Daily?>(
    () => container.read(dailyRepositoryProvider).cached(key),
  );
  return cached!.fortune.head.reaction;
}

/// 그날 캐시의 총운 첫 문장 반응이 [expected]가 될 때까지 기다립니다.
Future<void> _untilCachedReaction(
  WidgetTester tester,
  ProviderContainer container,
  SlotTextReactionEnum? expected,
) async {
  for (var i = 0; i < 100; i++) {
    if (await _cachedReaction(tester, container) == expected) {
      return;
    }
    await _spin(tester);
  }
  fail('캐시의 반응이 $expected가 되지 않음');
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('누르면 바로 켜지고 PUT 한 번, 성공하면 캐시도 like', (tester) async {
    final (container, tap) = await _boot(tester);
    expect(_liked(container), isFalse);
    expect(await _cachedReaction(tester, container), isNull);

    final press = _press(container);
    // 응답을 기다리기 전에 이미 켜져 있습니다(낙관적).
    expect(_liked(container), isTrue);
    await _until(
      tester,
      () => press.errors.isNotEmpty || tap.requests.isNotEmpty,
    );
    await _until(tester, press.finished);

    expect(tap.requests, [
      'PUT /v1/daily/2026-10-13/slots/daily.fortune.head/reaction',
    ]);
    expect(
      _fake(container)
          .requestBodiesOf('putReaction')
          .map((body) => jsonDecode(body! as String)),
      [
        {'reaction': 'like'},
      ],
    );
    expect(press.errors, isEmpty);
    expect(_liked(container), isTrue);
    expect(await _cachedReaction(tester, container), SlotTextReactionEnum.like);
  });

  testWidgets('켜진 것을 누르면 DELETE, 캐시의 반응도 지워집니다', (tester) async {
    final (container, tap) = await _boot(tester);
    final first = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);
    await _until(tester, first.finished);

    final second = _press(container);
    expect(_liked(container), isFalse);
    await _until(tester, () => tap.requests.length == 2);
    await _until(tester, second.finished);

    expect(tap.requests.last, startsWith('DELETE '));
    expect(_fake(container).callCountOf('deleteReaction'), 1);
    expect(_liked(container), isFalse);
    expect(await _cachedReaction(tester, container), isNull);
  });

  testWidgets('실패하면 되돌리고 오류를 알립니다', (tester) async {
    final (container, tap) = await _boot(tester, scenario: 'reaction-failed');
    final press = _press(container);
    expect(_liked(container), isTrue);
    await _until(tester, () => press.errors.isNotEmpty);

    expect(press.errors.single, isA<AppError>());
    expect(_liked(container), isFalse);
    expect(tap.requests, hasLength(1));
    // 캐시는 그대로입니다.
    expect(await _cachedReaction(tester, container), isNull);
  });

  testWidgets('요청 중 두 번 더 누르면(켬 끔 켬) 끝난 뒤 추가 요청이 없습니다', (tester) async {
    final (container, tap) = await _boot(tester);
    tap.hold = Completer<void>();
    final first = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);
    _press(container);
    expect(_liked(container), isFalse);
    _press(container);
    expect(_liked(container), isTrue);

    tap.hold!.complete();
    await _until(
      tester,
      () => _fake(container).callCountOf('putReaction') == 1,
    );
    await _until(tester, first.finished);
    // 한 번 더 보낼 일이 있었다면 보낼 시간을 줍니다.
    for (var i = 0; i < 5; i++) {
      await _spin(tester);
    }

    expect(tap.requests, hasLength(1));
    expect(_liked(container), isTrue);
    expect(await _cachedReaction(tester, container), SlotTextReactionEnum.like);
  });

  testWidgets('요청 중 한 번 더 누르면 끝난 뒤 DELETE 한 번입니다', (tester) async {
    final (container, tap) = await _boot(tester);
    tap.hold = Completer<void>();
    final first = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);
    _press(container);
    expect(_liked(container), isFalse);

    tap.hold!.complete();
    tap.hold = null;
    await _until(tester, () => tap.requests.length == 2);
    await _until(tester, first.finished);

    expect(tap.requests.map((r) => r.split(' ').first), ['PUT', 'DELETE']);
    expect(_liked(container), isFalse);
    expect(await _cachedReaction(tester, container), isNull);
  });

  testWidgets('요청 중 더 눌러도 실패하면 누르기 전 상태로 돌아갑니다', (tester) async {
    final (container, tap) = await _boot(tester, scenario: 'reaction-failed');
    tap.hold = Completer<void>();
    final first = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);
    _press(container);
    _press(container);
    expect(_liked(container), isTrue);

    tap.hold!.complete();
    await _until(tester, () => first.errors.isNotEmpty);

    expect(_liked(container), isFalse);
    expect(tap.requests, hasLength(1));
    expect(await _cachedReaction(tester, container), isNull);
  });

  testWidgets('자정을 넘겨 새 날짜 응답이 오면 요청 중이 아닌 어제 항목을 지웁니다', (tester) async {
    final (container, tap) = await _boot(
      tester,
      overrides: [
        todayProvider.overrideWith((ref) => ref.watch(_testTodayProvider)),
      ],
    );
    final press = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);
    await _until(tester, press.finished);
    final yesterdayKey = ReactionController.keyOf(
      CalendarDate(2026, 10, 13),
      'daily.fortune.head',
    );
    expect(container.read(reactionControllerProvider).keys, [yesterdayKey]);

    container.read(_testTodayProvider.notifier).date = CalendarDate(
      2026,
      10,
      14,
    );
    await _until(
      tester,
      () =>
          container.read(dailyControllerProvider).value?.date ==
          CalendarDate(2026, 10, 14),
    );

    expect(container.read(reactionControllerProvider), isEmpty);
  });

  testWidgets('반응 확인 뒤 시작한 응답이 reaction 없이 오면 응답을 따릅니다', (tester) async {
    final (container, tap) = await _boot(tester);
    final press = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);
    await _until(tester, press.finished);
    expect(container.read(reactionControllerProvider), isNotEmpty);

    // 확인 뒤에 시작한 fetch가 reaction 없이 오면 다른 기기에서 지운 것이므로 응답을 따릅니다.
    unawaited(container.read(dailyControllerProvider.notifier).reload());
    await _until(
      tester,
      () => container.read(reactionControllerProvider).isEmpty,
    );
    expect(_liked(container), isFalse);
  });

  testWidgets('반응 확인 전에 시작한 응답이 확인 뒤 도착해도 켜진 채로 두고 캐시를 다시 고칩니다', (
    tester,
  ) async {
    final (container, tap) = await _boot(tester);
    final server = _scriptDaily(container)..hold = Completer<void>();
    unawaited(container.read(dailyControllerProvider.notifier).reload());
    await _until(tester, () => server.paths.isNotEmpty);

    final press = _press(container);
    await _until(tester, press.finished);
    expect(tap.requests, hasLength(1));
    expect(_liked(container), isTrue);

    // 반응 확인 전에 시작한 fetch가 reaction 없이 이제 도착합니다.
    server.hold!.complete();
    await _until(
      tester,
      () => !container.read(dailyControllerProvider).isLoading,
    );
    for (var i = 0; i < 5; i++) {
      await _spin(tester);
    }

    expect(_liked(container), isTrue);
    await _untilCachedReaction(tester, container, SlotTextReactionEnum.like);
  });

  testWidgets('요청 중에 새 응답이 와도 그 슬롯의 값은 유지됩니다', (tester) async {
    final (container, tap) = await _boot(tester);
    tap.hold = Completer<void>();
    final press = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);

    unawaited(container.read(dailyControllerProvider.notifier).reload());
    for (var i = 0; i < 10; i++) {
      await _spin(tester);
    }
    expect(_liked(container), isTrue);

    tap.hold!.complete();
    await _until(tester, press.finished);
    expect(_liked(container), isTrue);
  });

  testWidgets('끄기(DELETE)가 실패하면 다시 켜지고 오류를 알립니다', (tester) async {
    final (container, tap) = await _boot(
      tester,
      scenario: 'reaction-delete-failed',
    );
    final server = _scriptDaily(container);
    _setScriptedReaction(server, liked: true);
    await _reload(tester, container);
    expect(_liked(container), isTrue);

    final press = _press(container);
    expect(_liked(container), isFalse);
    await _until(tester, press.finished);

    expect(press.errors.single, isA<AppError>());
    expect(tap.requests.single, startsWith('DELETE '));
    expect(_liked(container), isTrue);
  });

  testWidgets('요청 중 새 응답이 온 뒤 실패하면 처음 값이 아니라 새 응답 값으로 돌아갑니다', (tester) async {
    final (container, tap) = await _boot(
      tester,
      scenario: 'reaction-delete-failed',
    );
    final server = _scriptDaily(container);
    _setScriptedReaction(server, liked: true);
    await _reload(tester, container);
    expect(_liked(container), isTrue);

    tap.hold = Completer<void>();
    final press = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);

    // 다른 기기에서 이미 지워서, 요청 중에 온 응답에는 reaction이 없습니다.
    _setScriptedReaction(server, liked: false);
    await _reload(tester, container);
    expect(_liked(container), isFalse);

    tap.hold!.complete();
    await _until(tester, press.finished);

    expect(press.errors.single, isA<AppError>());
    expect(_liked(container), isFalse);
  });

  testWidgets('server에 닿기 전 API 밖의 예외는 낙관 상태를 되돌리고 UnexpectedError로 알립니다', (
    tester,
  ) async {
    final (container, _) = await _boot(
      tester,
      overrides: [
        restClientProvider.overrideWith(
          (ref) => _ThrowingApi(ref.watch(dioProvider)),
        ),
      ],
    );
    final press = _press(container);
    expect(_liked(container), isTrue);
    await _until(tester, press.finished);

    expect(press.errors.single, isA<UnexpectedError>());
    expect(_liked(container), isFalse);
    expect(_reporter(container).errors, hasLength(1));
  });

  testWidgets('캐시 키 조회가 던져도 반응은 확인된 값을 유지하고 보고만 합니다', (tester) async {
    final (container, _) = await _boot(tester, overrides: _throwingKeyLookup);
    final press = _press(container);
    await _until(tester, press.finished);

    expect(press.errors, isEmpty);
    expect(_liked(container), isTrue);
    expect(_reporter(container).errors, hasLength(1));
  });

  testWidgets('응답이 덮은 캐시를 다시 고칠 때 키 조회가 던져도 잡히지 않은 오류가 없습니다', (tester) async {
    final (container, _) = await _boot(tester, overrides: _throwingKeyLookup);
    final server = _scriptDaily(container)..hold = Completer<void>();
    unawaited(container.read(dailyControllerProvider.notifier).reload());
    await _until(tester, () => server.paths.isNotEmpty);
    final press = _press(container);
    await _until(tester, press.finished);
    // 반응을 확인할 때 한 번 보고했습니다.
    expect(_reporter(container).errors, hasLength(1));

    server.hold!.complete();
    await _until(
      tester,
      () => !container.read(dailyControllerProvider).isLoading,
    );
    for (var i = 0; i < 5; i++) {
      await _spin(tester);
    }

    // 응답이 확인보다 앞서 시작해 캐시를 다시 고치려다 한 번 더 보고하고, 잡히지 않은 오류는 없습니다.
    expect(_reporter(container).errors, hasLength(2));
    expect(_liked(container), isTrue);
  });

  testWidgets('요청 중 캐시 값이 내보내져도 추가 요청이 없고 실패하면 캐시가 아닌 처음 값으로 돌아갑니다', (
    tester,
  ) async {
    final (container, tap) = await _boot(tester, scenario: 'reaction-failed');
    // 캐시에는 옛 반응(like)이 남아 있습니다.
    final cacheKey = container.read(dailyControllerProvider.notifier).cacheKey!;
    await tester.runAsync(
      () => container
          .read(dailyRepositoryProvider)
          .patchCachedReaction(
            cacheKey,
            slot: _head(container).slot,
            liked: true,
          ),
    );
    final server = _scriptDaily(container)..hold = Completer<void>();
    tap.hold = Completer<void>();
    final press = _press(container);
    await _until(tester, () => tap.requests.isNotEmpty);

    // 다시 열어 캐시를 먼저 내보냅니다(server 응답은 붙잡혀 아직 옵니다).
    container.invalidate(dailyControllerProvider);
    await _until(
      tester,
      () => container.read(dailyControllerProvider).value?.fromCache ?? false,
    );

    tap.hold!.complete();
    await _until(tester, press.finished);

    expect(press.errors.single, isA<AppError>());
    expect(tap.requests, hasLength(1));
    // 캐시의 like가 아니라 server가 확인한 처음 값(없음)으로 돌아갑니다.
    expect(
      container.read(reactionControllerProvider)[ReactionController.keyOf(
        _today,
        _head(container).slot,
      )],
      isFalse,
    );
    // 붙잡았던 server 응답을 풀어 끝냅니다(캐시 값이 server 값으로 바뀝니다).
    server.hold!.complete();
    await _until(
      tester,
      () => !(container.read(dailyControllerProvider).value?.fromCache ?? true),
    );
  });

  testWidgets('다른 날짜의 같은 슬롯을 눌러도 오늘 상태는 그대로입니다', (tester) async {
    final (container, tap) = await _boot(tester);
    final head = _head(container);
    final yesterday = CalendarDate(2026, 10, 12);

    final done = container
        .read(reactionControllerProvider.notifier)
        .toggle(head, date: yesterday);
    var finished = false;
    unawaited(done.whenComplete(() => finished = true));
    await _until(tester, () => finished);

    final state = container.read(reactionControllerProvider);
    expect(ReactionController.isLiked(state, yesterday, head), isTrue);
    expect(_liked(container), isFalse);
    expect(tap.requests, [
      'PUT /v1/daily/2026-10-12/slots/daily.fortune.head/reaction',
    ]);
  });
}
