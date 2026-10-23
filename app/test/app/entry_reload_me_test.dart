import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../support/app_harness.dart';

/// `getMe`의 응답을 바꾸거나 실패시키는 REST 클라이언트.
class _SwitchableApi extends DefaultApi {
  // super 매개변수는 부모의 비공개 이름(_dio)과 달라 matching_super_parameters가 걸립니다.
  // ignore: use_super_parameters
  new(Dio dio) : super(dio);

  Me? meOverride;
  Exception? failWith;
  int getMeCalls = 0;

  /// 있으면 열릴 때까지 `getMe`를 붙잡습니다.
  Completer<void>? gate;

  @override
  Future<Response<Me>> getMe({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    getMeCalls++;
    await gate?.future;
    final override = meOverride;
    final failure = failWith;
    if (failure != null) {
      throw failure;
    }
    final response = await super.getMe(
      cancelToken: cancelToken,
      headers: headers,
      extra: extra,
      validateStatus: validateStatus,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    if (override == null) {
      return response;
    }
    return Response<Me>(
      requestOptions: response.requestOptions,
      statusCode: 200,
      data: override,
    );
  }
}

Future<(ProviderContainer, _SwitchableApi)> _start({
  String scenario = 'member',
}) async {
  late _SwitchableApi api;
  final container = await bootstrapForTest(
    scenario,
    overrides: [
      restClientProvider.overrideWith(
        (ref) => api = _SwitchableApi(ref.watch(dioProvider)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(entryStateProvider.future);
  return (container, api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getMe 결과로 me만 바뀌고 entry는 그대로', () async {
    final (container, api) = await _start();
    final before = container.read(entryStateProvider).value!;
    expect(before.entry, EntryState.ready);
    api.meOverride = before.me!.copyWith(hasProfile: true, accountId: 'new-id');

    await container.read(entryStateProvider.notifier).reloadMe();

    final after = container.read(entryStateProvider).value!;
    expect(after.me!.accountId, 'new-id');
    expect(after.entry, before.entry);
    expect(after.config, same(before.config));
  });

  DioException offline() => DioException.connectionError(
    requestOptions: RequestOptions(path: '/v1/me'),
    reason: '테스트 실패',
  );

  FakeCrashReporter crashOf(ProviderContainer container) =>
      container.read(crashReporterProvider) as FakeCrashReporter;

  test('getMe 실패면 이전 me가 남는다', () async {
    final (container, api) = await _start();
    final before = container.read(entryStateProvider).value!;
    api.failWith = offline();

    await container.read(entryStateProvider.notifier).reloadMe();

    expect(container.read(entryStateProvider).value!.me, before.me);
  });

  test('AppError(오프라인)는 기록하지 않는다', () async {
    final (container, api) = await _start();
    api.failWith = offline();

    await container.read(entryStateProvider.notifier).reloadMe();

    expect(crashOf(container).errors, isEmpty);
  });

  test('예상 밖 오류는 crashReporter에 한 번 기록한다', () async {
    final (container, api) = await _start();
    final before = container.read(entryStateProvider).value!;
    api.failWith = Exception('예상 밖');

    await container.read(entryStateProvider.notifier).reloadMe();

    expect(crashOf(container).errors, hasLength(1));
    expect(container.read(entryStateProvider).value!.me, before.me);
  });

  test('로그아웃 상태(me == null)면 getMe를 부르지 않는다', () async {
    final (container, api) = await _start(scenario: 'new-user');
    expect(container.read(entryStateProvider).value!.me, isNull);
    final callsBefore = api.getMeCalls;

    await container.read(entryStateProvider.notifier).reloadMe();

    expect(api.getMeCalls, callsBefore);
  });

  test('getMe를 기다리는 사이 진입 계산이 시작되면 결과를 쓰지 않는다', () async {
    final (container, api) = await _start();
    final before = container.read(entryStateProvider).value!;
    final gate = Completer<void>();
    api
      ..gate = gate
      ..meOverride = before.me!.copyWith(accountId: 'reloaded');
    final notifier = container.read(entryStateProvider.notifier);
    final reloading = notifier.reloadMe();
    await Future<void>.delayed(Duration.zero);

    // 진입 계산 중 끼어든 값(계산 중이 아닌 data)이 나오는지 지켜봅니다.
    final settled = <AsyncValue<Object?>>[];
    final subscription = container.listen(entryStateProvider, (_, next) {
      if (!next.isLoading) settled.add(next);
    });
    addTearDown(subscription.close);
    final refreshing = notifier.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(entryStateProvider).isLoading, isTrue);

    gate.complete();
    await reloading;
    expect(settled, isEmpty, reason: '계산 중에는 reloadMe가 state를 바꾸지 않음');
    expect(await refreshing, isNull);
    expect(settled, hasLength(1));
  });
}
