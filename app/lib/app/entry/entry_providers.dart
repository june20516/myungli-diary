import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

/// 설치된 앱 버전.
final appVersionProvider = FutureProvider<Version>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return parseAppVersion(info.version);
}, retry: (_, _) => null);

/// 실행 중인 플랫폼. 최소 버전 선택에 쓰며 테스트가 바꿉니다.
final targetPlatformProvider = Provider<TargetPlatform>(
  (ref) => defaultTargetPlatform,
);

/// 진입 갈래를 계산합니다.
///
/// `getAppConfig` → 토큰 확인 → `getMe` 순서입니다. 통신이 실패하면 오류 상태가
/// 되고(launch 화면이 다시 시도를 보임), `getMe`가 401이면 로그아웃으로 봅니다.
class EntryController extends AsyncNotifier<EntrySnapshot> {
  int _generation = 0;

  @override
  Future<EntrySnapshot> build() {
    _generation++;
    final tokens = ref.watch(tokenStoreProvider);
    final subscription = tokens.events.listen((_) => unawaited(refresh()));
    ref.onDispose(subscription.cancel);
    return _compute();
  }

  /// 로딩 화면을 거치지 않고 다시 계산합니다. 로그인·온보딩·약관 동의가 끝나면 부릅니다.
  ///
  /// 계산이 겹치면 마지막에 요청한 결과만 반영하고, dispose 뒤에는 쓰지 않습니다.
  Future<void> refresh() async {
    final generation = ++_generation;
    final result = await AsyncValue.guard(_compute);
    if (!ref.mounted || generation != _generation) {
      return;
    }
    state = result;
  }

  Future<EntrySnapshot> _compute() async {
    final api = ref.read(restClientProvider);
    final tokens = ref.read(tokenStoreProvider);
    final flags = ref.read(deviceFlagsStoreProvider);
    final appVersion = await ref.read(appVersionProvider.future);

    final config = await _call(api.getAppConfig);
    final minimum = parseAppVersion(
      minimumVersionFor(config, ref.read(targetPlatformProvider)),
    );

    final hasSession =
        tokens.accessToken != null || await tokens.refreshToken() != null;
    Me? me;
    if (hasSession && appVersion >= minimum) {
      try {
        me = await _call(api.getMe);
      } on ProblemError catch (e) {
        if (e.status != 401) {
          rethrow;
        }
      } on UnexpectedError catch (e) {
        final cause = e.cause;
        if (cause is! DioException || cause.response?.statusCode != 401) {
          rethrow;
        }
      }
    }

    EntryState compute({required bool adConsentDone}) => computeEntry(
      appVersion: appVersion,
      minimumVersion: minimum,
      hasSession: hasSession,
      me: me,
      adConsentDone: adConsentDone,
    );

    final adConsentDone = await flags.readBool(adConsentDoneKey);
    final entry = compute(adConsentDone: adConsentDone);
    if (entry != EntryState.adConsentRequired) {
      return EntrySnapshot(entry, me);
    }
    // 결과(맞춤·비맞춤)와 상관없이 이 기기에서 한 번 거친 것으로 칩니다.
    await ref.read(adConsentProvider).gather();
    await flags.writeBool(adConsentDoneKey, value: true);
    return EntrySnapshot(compute(adConsentDone: true), me);
  }

  Future<T> _call<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
      return data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}

/// 진입 갈래. 자동 재시도 없이 launch 화면의 다시 시도 버튼으로만 다시 합니다.
final entryStateProvider =
    AsyncNotifierProvider<EntryController, EntrySnapshot>(
      EntryController.new,
      retry: (_, _) => null,
    );

/// 계산된 진입 갈래. 계산 전이거나 실패했으면 null입니다.
final entryProvider = Provider<EntryState?>(
  (ref) => ref.watch(entryStateProvider).value?.entry,
);

/// 로그인한 사용자의 내 정보. 로그아웃이거나 아직 계산 전이면 null입니다.
final meProvider = Provider<Me?>(
  (ref) => ref.watch(entryStateProvider).value?.me,
);

/// 앱 루트 `ProviderScope`에 넣는 override. 계정 id를 [meProvider]에서 채웁니다.
final List<Override> entryOverrides = [
  currentAccountIdProvider.overrideWith((ref) {
    final me = ref.watch(meProvider);
    if (me == null) {
      throw StateError('로그아웃 상태에서는 계정 id가 없습니다.');
    }
    return me.accountId;
  }),
];
