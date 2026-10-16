import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/platform/device_timezone.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/profile/data/profile_repository.dart';

import 'app_harness.dart';

/// 값을 바꿀 수 있는 기기 시간대 대역.
final class MutableDeviceTimezone implements DeviceTimezone {
  new(this.value);

  /// 지금 돌려줄 IANA 이름.
  String value;

  @override
  Future<String> current() async => value;
}

/// 프로필 수정 요청을 기록하고, 정한 횟수만큼 연결 오류([offlineFailures])·503([failures])으로
/// 답한 뒤 본문의 시간대를 되돌려 줍니다.
final class ProfileServer extends Interceptor {
  new({this.failures = 0, this.offlineFailures = 0});

  int failures;
  int offlineFailures;
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
    if (offlineFailures > 0) {
      offlineFailures--;
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        true,
      );
      return;
    }
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
            ...seoulProfile,
            'currentTimezone': body['currentTimezone'],
          },
          'warnings': <Object?>[],
        },
      ),
      true,
    );
  }
}

const seoulProfile = <String, Object?>{
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

/// member 시나리오에 사본(Asia/Seoul)을 심습니다.
///
/// 기기 시간대와 [overrides]는 자식 컨테이너에서 덮어씁니다(부팅이 이미 기기 시간대를
/// override하므로 같은 컨테이너에서는 두 번 덮을 수 없습니다). 돌려주는 컨테이너가 자식입니다.
Future<(ProviderContainer, ProfileServer, FakeCrashReporter)> setUpSync(
  WidgetTester tester, {
  required String device,
  MutableDeviceTimezone? deviceSource,
  int failures = 0,
  int offlineFailures = 0,
  bool seed = true,
  List<Override> overrides = const [],
}) async {
  final reporter = FakeCrashReporter();
  final root = (await tester.runAsync(() => bootstrapForTest('member')))!;
  addTearDown(root.dispose);
  await tester.runAsync(() => root.read(entryStateProvider.future));
  final server = ProfileServer(
    failures: failures,
    offlineFailures: offlineFailures,
  );
  final interceptors = root.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, server);
  if (seed) {
    await tester.runAsync(
      () => root
          .read(cacheStoreProvider)
          .write(
            CacheKind.profile,
            profileCacheKey,
            jsonEncode(Profile.fromJson(seoulProfile).toJson()),
            access: EvidenceAccess.unlocked,
          ),
    );
  }
  final container = ProviderContainer(
    parent: root,
    overrides: [
      deviceTimezoneProvider.overrideWithValue(
        deviceSource ?? MutableDeviceTimezone(device),
      ),
      crashReporterProvider.overrideWithValue(reporter),
      timezoneSyncProvider.overrideWith(TimezoneSync.new),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return (container, server, reporter);
}
