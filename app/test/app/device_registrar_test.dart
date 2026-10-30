import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/device_registrar.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/entry/sign_out_cleaner.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/device.dart';
import 'package:myungli_diary/core/api/gen/model/device_input.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/notification_setting.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

import '../support/app_harness.dart';

/// 기기 등록·해제를 흉내 냅니다. 기기 id는 `device-<토큰>`입니다.
final class _DeviceApi implements DefaultApi {
  final registered = <String>[];
  final deleted = <String>[];

  /// `deleteDevice`를 실패시키는 함수(던짐).
  Never Function()? failDelete;

  @override
  Future<Response<Device>> registerDevice({
    required DeviceInput deviceInput,
    String? idempotencyKey,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    registered.add(deviceInput.fcmToken);
    return Response(
      requestOptions: RequestOptions(),
      statusCode: 201,
      data: Device(
        id: 'device-${deviceInput.fcmToken}',
        platform: deviceInput.platform,
      ),
    );
  }

  @override
  Future<Response<void>> deleteDevice({
    required String id,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    deleted.add(id);
    failDelete?.call();
    return Response(requestOptions: RequestOptions(), statusCode: 204);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 토큰을 바꿀 수 있는 푸시 대역.
final class _Push implements PushMessaging {
  new(this.current);

  String? current;
  final _refreshes = StreamController<String>.broadcast();

  /// 토큰을 바꾸고 변경 사건을 냅니다.
  void refresh(String token) {
    current = token;
    _refreshes.add(token);
  }

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<PushOpen> get opens => const Stream.empty();

  @override
  Future<PushOpen?> initialOpen() async => null;

  @override
  Future<bool> requestPermission() async => true;
}

/// 진입 상태를 테스트가 바꿉니다.
final class _EntryHolder extends Notifier<EntryState?> {
  @override
  EntryState? build() => EntryState.signedOut;

  // ignore: use_setters_to_change_properties, 테스트가 호출하는 설정 함수
  void set(EntryState? value) => state = value;
}

final _entryHolderProvider = NotifierProvider<_EntryHolder, EntryState?>(
  _EntryHolder.new,
);

Profile _profile(NotificationSettingStatusEnum status) => Profile(
  honorific: '하늘',
  language: Language.ko,
  currentTimezone: 'Asia/Seoul',
  birth: Birth(
    calendar: CalendarType.solar,
    date: LunarOrSolarDate(year: 1990, month: 1, day: 1),
    isLeapMonth: false,
    time: BirthTime(status: BirthTimeStatusEnum.unknown),
    gender: BirthGenderEnum.female,
    timezone: 'Asia/Seoul',
    place: BirthPlace(status: BirthPlaceStatusEnum.notAsked),
  ),
  notification: NotificationSetting(status: status, time: '08:00'),
);

final class _Harness {
  new({
    String? token = 't1',
    NotificationSettingStatusEnum notification =
        NotificationSettingStatusEnum.enabled,
  }) : push = _Push(token) {
    container = ProviderContainer(
      overrides: [
        ...testOverrides(),
        entryProvider.overrideWith((ref) => ref.watch(_entryHolderProvider)),
        cachedProfileProvider.overrideWith(
          (ref) async => _profile(notification),
        ),
        pushMessagingProvider.overrideWithValue(push),
        restClientProvider.overrideWithValue(api),
        crashReporterProvider.overrideWithValue(reporter),
        targetPlatformProvider.overrideWithValue(TargetPlatform.android),
      ],
    );
  }

  final api = _DeviceApi();
  final _Push push;
  final reporter = FakeCrashReporter();
  late final ProviderContainer container;

  DeviceRegistrar get registrar => container.read(deviceRegistrarProvider);

  /// registrar를 붙들어 진입·토큰 변경을 듣게 합니다(앱 루트처럼).
  void start() => container.read(deviceRegistrarProvider);

  DeviceFlagsStore get flags => container.read(deviceFlagsStoreProvider);

  Future<String?> storedId() => flags.readString(registeredDeviceIdKey);

  /// 진입을 [entry]로 바꾸고 그 뒤의 동기화가 끝날 때까지 기다립니다.
  Future<void> enter(EntryState entry) async {
    container.read(_entryHolderProvider.notifier).set(entry);
    await settle();
  }

  /// 걸려 있는 동기화가 모두 끝날 때까지 기다립니다.
  Future<void> settle() async {
    await pumpEventQueue();
    await registrar.idle;
    await pumpEventQueue();
  }

  void dispose() => container.dispose();
}

DioException _offline() => DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

DioException _notFound() => DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(),
    statusCode: 404,
    headers: Headers.fromMap({
      Headers.contentTypeHeader: ['application/problem+json'],
    }),
    data: {
      'type': 'about:blank',
      'title': 'Not found',
      'status': 404,
      'code': 'device.not_found',
    },
  ),
);

void main() {
  late _Harness h;

  tearDown(() => h.dispose());

  test('알림이 꺼져 있으면 실행 때 등록하지 않음', () async {
    h = _Harness(notification: NotificationSettingStatusEnum.disabled)..start();
    await h.enter(EntryState.ready);
    expect(h.api.registered, isEmpty);
  });

  test('로그인·동의·알림 켬이면 실행 때 등록', () async {
    h = _Harness()..start();
    await h.enter(EntryState.ready);
    expect(h.api.registered, ['t1']);
    expect(await h.storedId(), 'device-t1');
  });

  test('같은 실행에서 같은 토큰을 이미 등록했으면 다시 등록하지 않음', () async {
    h = _Harness()..start();
    await h.enter(EntryState.ready);
    await h.enter(EntryState.adConsentRequired);
    await h.enter(EntryState.ready);
    expect(h.api.registered, ['t1']);
  });

  test('로그아웃 뒤 다시 로그인하면 다시 등록', () async {
    h = _Harness()..start();
    await h.enter(EntryState.ready);
    await h.registrar.releaseForSignOut();
    await h.enter(EntryState.signedOut);
    await h.enter(EntryState.ready);
    expect(h.api.registered, ['t1', 't1']);
    expect(h.api.deleted, ['device-t1']);
  });

  test('로그아웃·동의 전이면 토큰이 바뀌어도 등록하지 않음', () async {
    h = _Harness()..start();
    await h.enter(EntryState.consentRequired);
    h.push.refresh('t2');
    await h.settle();
    expect(h.api.registered, isEmpty);
  });

  test('토큰이 바뀌면 새 토큰 등록 뒤 이전 id 해제, 저장된 id는 새 id', () async {
    h = _Harness()..start();
    await h.enter(EntryState.ready);
    h.push.refresh('t2');
    await h.settle();
    expect(h.api.registered, ['t1', 't2']);
    expect(h.api.deleted, ['device-t1']);
    expect(await h.storedId(), 'device-t2');
  });

  test('앱이 꺼진 사이 토큰이 바뀌었으면 실행 때 새 id를 받고 이전 id 해제', () async {
    h = _Harness(token: 't2');
    await h.flags.writeString(registeredDeviceIdKey, value: 'device-t1');
    h.start();
    await h.enter(EntryState.ready);
    expect(h.api.registered, ['t2']);
    expect(h.api.deleted, ['device-t1']);
    expect(await h.storedId(), 'device-t2');
  });

  test('실행 등록과 토큰 변경이 겹쳐도 차례로 한 번씩', () async {
    h = _Harness()..start();
    h.container.read(_entryHolderProvider.notifier).set(EntryState.ready);
    h.push.refresh('t1');
    await h.settle();
    expect(h.api.registered, ['t1']);
  });

  test('토큰이 없으면 등록하지 않음', () async {
    h = _Harness(token: null)..start();
    await h.enter(EntryState.ready);
    expect(h.api.registered, isEmpty);
  });

  group('releaseForSignOut', () {
    test('저장된 id를 해제하고 지움', () async {
      h = _Harness();
      await h.flags.writeString(registeredDeviceIdKey, value: 'device-t1');
      await h.registrar.releaseForSignOut();
      expect(h.api.deleted, ['device-t1']);
      expect(await h.storedId(), isNull);
    });

    test('해제가 오프라인으로 실패해도 id는 지우고 보고하지 않음', () async {
      h = _Harness()..api.failDelete = () => throw _offline();
      await h.flags.writeString(registeredDeviceIdKey, value: 'device-t1');
      await h.registrar.releaseForSignOut();
      expect(await h.storedId(), isNull);
      expect(h.reporter.errors, isEmpty);
    });

    test('예상 밖 오류는 요약만 보고하고 던지지 않음', () async {
      h = _Harness()..api.failDelete = () => throw StateError('플러그인 오류');
      await h.flags.writeString(registeredDeviceIdKey, value: 'device-t1');
      await h.registrar.releaseForSignOut();
      expect(await h.storedId(), isNull);
      expect(h.reporter.errors.single.errorType, 'StateError');
    });

    test('404 device.not_found는 성공으로 보고 보고하지 않음', () async {
      h = _Harness()..api.failDelete = () => throw _notFound();
      await h.flags.writeString(registeredDeviceIdKey, value: 'device-t1');
      await h.registrar.releaseForSignOut();
      expect(await h.storedId(), isNull);
      expect(h.reporter.errors, isEmpty);
    });

    test('저장된 id가 없으면 부르지 않음', () async {
      h = _Harness();
      await h.registrar.releaseForSignOut();
      expect(h.api.deleted, isEmpty);
    });
  });

  test('강제 로그아웃·계정 삭제(signedOut 이벤트)는 deleteDevice 없이 저장 키만 지움', () async {
    h = _Harness();
    final tokens = h.container.read(tokenStoreProvider);
    await tokens.save(
      TokenPair(
        accessToken: 'a',
        accessTokenExpiresAt: DateTime.utc(2030),
        refreshToken: 'r',
        refreshTokenExpiresAt: DateTime.utc(2031),
      ),
    );
    await h.flags.writeString(registeredDeviceIdKey, value: 'device-t1');
    h.container.read(signOutCleanerProvider);
    await tokens.signOut();
    await pumpEventQueue();
    expect(h.api.deleted, isEmpty);
    expect(await h.storedId(), isNull);
  });
}
