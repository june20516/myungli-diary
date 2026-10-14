import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/profile/data/profile_repository.dart';

import '../../support/app_harness.dart';

/// 프로필 수정 요청을 기록하고, 정한 횟수만큼 503으로 답한 뒤 본문의 시간대를 되돌려 줍니다.
final class _ProfileServer extends Interceptor {
  new({this.failures = 0});

  int failures;
  final bodies = <Map<String, Object?>>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method != 'PATCH' || options.path != '/v1/me/profile') {
      handler.next(options);
      return;
    }
    final raw = options.data;
    final body =
        (raw is String ? jsonDecode(raw) : raw)! as Map<String, Object?>;
    bodies.add(body);
    if (failures > 0) {
      failures--;
      handler.reject(
        DioException.badResponse(
          statusCode: 503,
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            headers: Headers.fromMap({
              Headers.contentTypeHeader: ['application/problem+json'],
            }),
            data: {
              'status': 503,
              'code': 'server.unavailable',
              'title': 'x',
              'traceId': 't',
            },
          ),
        ),
        true,
      );
      return;
    }
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/json'],
        }),
        data: {
          'profile': {
            ..._seoulProfile,
            'currentTimezone': body['currentTimezone'],
          },
          'warnings': <Object?>[],
        },
      ),
      true,
    );
  }
}

const _seoulProfile = <String, Object?>{
  'honorific': '하늘',
  'language': 'ko',
  'currentTimezone': 'Asia/Seoul',
  'birth': {
    'calendar': 'solar',
    'date': {'year': 1990, 'month': 5, 'day': 15},
    'isLeapMonth': false,
    'time': {'status': 'known', 'value': '14:30'},
    'gender': 'female',
    'timezone': 'Asia/Seoul',
    'place': {'status': 'not_asked'},
  },
  'notification': {'status': 'not_asked'},
};

void main() {
  /// member 시나리오에 사본(Asia/Seoul)을 심습니다.
  ///
  /// 기기 시간대와 [overrides]는 자식 컨테이너에서 덮어씁니다(부팅이 이미 기기 시간대를
  /// override하므로 같은 컨테이너에서는 두 번 덮을 수 없습니다). 돌려주는 컨테이너가 자식입니다.
  Future<(ProviderContainer, _ProfileServer, FakeCrashReporter)> setUpSync(
    WidgetTester tester, {
    required String device,
    int failures = 0,
    bool seed = true,
    List<Override> overrides = const [],
  }) async {
    final reporter = FakeCrashReporter();
    final root = (await tester.runAsync(() => bootstrapForTest('member')))!;
    addTearDown(root.dispose);
    await tester.runAsync(() => root.read(entryStateProvider.future));
    final server = _ProfileServer(failures: failures);
    final interceptors = root.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, server);
    if (seed) {
      await tester.runAsync(
        () => root
            .read(cacheStoreProvider)
            .write(
              CacheKind.profile,
              profileCacheKey,
              jsonEncode(Profile.fromJson(_seoulProfile).toJson()),
              access: EvidenceAccess.unlocked,
            ),
      );
    }
    final container = ProviderContainer(
      parent: root,
      overrides: [
        deviceTimezoneProvider.overrideWithValue(FakeDeviceTimezone(device)),
        crashReporterProvider.overrideWithValue(reporter),
        timezoneSyncProvider.overrideWith(TimezoneSync.new),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return (container, server, reporter);
  }

  testWidgets('사본과 기기 시간대가 다르면 PATCH 본문에 currentTimezone만 보낸다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'America/Los_Angeles',
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, [
      {'currentTimezone': 'America/Los_Angeles'},
    ]);
    // 응답이 사본이 되어 다시 부르면 보내지 않습니다.
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, hasLength(1));
  });

  testWidgets('같으면 보내지 않는다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Seoul',
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, isEmpty);
  });

  testWidgets('UTC offset이 같아도 IANA 이름이 다르면 보낸다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, [
      {'currentTimezone': 'Asia/Tokyo'},
    ]);
  });

  testWidgets('503이어도 예외가 나오지 않고 다음에 다시 보낸다', (tester) async {
    final (container, server, reporter) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      failures: 1,
    );
    final sync = container.read(timezoneSyncProvider);
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, hasLength(1));
    expect(reporter.errors.single.status, 503);
    await tester.runAsync(sync.syncIfChanged);
    expect(server.bodies, hasLength(2));
    expect(reporter.errors, hasLength(1));
  });

  testWidgets('사본이 없으면 보내지 않는다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      seed: false,
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, isEmpty);
  });

  testWidgets('진입이 ready가 아니면 보내지 않는다', (tester) async {
    final (container, server, _) = await setUpSync(
      tester,
      device: 'Asia/Tokyo',
      overrides: [entryProvider.overrideWithValue(EntryState.signedOut)],
    );
    await tester.runAsync(container.read(timezoneSyncProvider).syncIfChanged);
    expect(server.bodies, isEmpty);
  });
}
