import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/entry/sign_out.dart';
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
/// 설치 확인 → `getAppConfig` → 토큰 확인 → `getMe` 순서입니다. 설치 표시
/// ([installedKey])가 없으면 다시 설치한 것이라 이전 설치의 토큰을 버립니다. 통신이 실패하면 오류 상태가
/// 되고(launch 화면이 다시 시도를 보임), `getMe`가 401이면 남은 토큰을 지우고
/// (`TokenStore.signOut`) 로그아웃으로 봅니다. 삭제 대기 계정이면 server에 토큰 폐기를
/// 시도한 뒤 로그아웃합니다([revokeAndSignOut]). 어느 쪽이든 `signedOut` 이벤트가 나가
/// 로컬 정리가 돕니다. 토큰 이벤트(로그아웃, 약관 동의 필요)를 받으면 다시 계산합니다.
///
/// 이 계산이 내는 [meProvider]가 세션 복원과 로그인 뒤 계정 연결의 유일한 출처입니다
/// (`AccountLinker`).
class EntryController extends AsyncNotifier<EntrySnapshot> {
  @override
  Future<EntrySnapshot> build() {
    final tokens = ref.watch(tokenStoreProvider);
    final subscription = tokens.events.listen((_) => ref.invalidateSelf());
    ref.onDispose(subscription.cancel);
    return _compute();
  }

  /// 다시 계산하고 끝나면 돌아옵니다. 로그인·온보딩·약관 동의가 끝나면 부릅니다.
  ///
  /// build를 다시 돌리므로 겹친 계산은 Riverpod이 오래된 결과를 버립니다.
  /// 계산 중에도 이전 값이 남아 라우터는 launch로 되돌아가지 않습니다.
  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // 실패는 state(AsyncError)로 드러납니다.
    }
  }

  Future<EntrySnapshot> _compute() async {
    final api = ref.read(restClientProvider);
    final tokens = ref.read(tokenStoreProvider);
    final flags = ref.read(deviceFlagsStoreProvider);
    final appVersion = await ref.read(appVersionProvider.future);

    if (!await flags.readBool(installedKey)) {
      // 다시 설치: 이전 설치의 Keychain 토큰은 버립니다. DB가 비어 있어 정리할
      // 로컬 데이터가 없으므로 로그아웃 이벤트는 내지 않습니다.
      await tokens.discardWithoutEvent();
      await flags.writeBool(installedKey, value: true);
    }

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
      } on AppError catch (e) {
        if (!_isUnauthorized(e)) {
          rethrow;
        }
        // refresh 거부로 interceptor가 이미 로그아웃했다면 이벤트를 두 번 내지 않습니다.
        if (tokens.accessToken != null || await tokens.refreshToken() != null) {
          await tokens.signOut();
        }
        return const EntrySnapshot(EntryState.signedOut, null);
      }
    }

    if (me != null && isPendingDeletion(me)) {
      // signOut 이벤트로 다시 계산되며, 그때는 세션이 없어 getMe를 부르지 않습니다.
      await revokeAndSignOut(api: api, tokens: tokens);
      return const EntrySnapshot(EntryState.signedOut, null);
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

  bool _isUnauthorized(AppError error) => switch (error) {
    ProblemError(:final status) => status == 401,
    UnexpectedError(:final cause) =>
      cause is DioException && cause.response?.statusCode == 401,
    _ => false,
  };

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

/// 이 기기에서 광고 동의를 거쳤는지. 진입 계산이 끝날 때마다 다시 읽습니다.
final adConsentGivenProvider = FutureProvider<bool>((ref) {
  ref.watch(entryStateProvider);
  return ref.watch(deviceFlagsStoreProvider).readBool(adConsentDoneKey);
});

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
