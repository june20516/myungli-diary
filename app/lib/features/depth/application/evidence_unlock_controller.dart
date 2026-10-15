import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show NotifierProviderFamily, ProviderListenable;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/monetization/application/entitlements_providers.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

/// 보상형 광고를 끝까지 본 뒤 근거 열람 권한을 다시 묻는 간격(A26, spec §7).
const rewardPollInterval = Duration(seconds: 2);

/// 권한을 묻는 최대 시간. 지나면 잠금 해제 실패 toast입니다(A26).
const rewardPollTimeout = Duration(seconds: 30);

/// 권한 확인 간격과 최대 시간. 실측(A2) 뒤 조정하고, 테스트는 짧게 바꿉니다.
final rewardPollTimingProvider =
    Provider<({Duration interval, Duration timeout})>(
      (ref) => (interval: rewardPollInterval, timeout: rewardPollTimeout),
    );

/// 근거를 담은 응답 하나(오늘의 `Daily`, 계획 6의 `Chart`).
///
/// 근거 시트와 잠금 해제 흐름은 화면에 묶이지 않고 이 인터페이스만 봅니다. 잠금이 풀린 뒤
/// 무엇을 다시 받을지는 응답마다 [reload]가 정합니다. 잠금 해제 흐름의 family 키이므로 값으로
/// 비교되어야 합니다.
@immutable
abstract interface class EvidenceSubject {
  /// 응답의 근거 열람 상태. 받는 중·실패도 그대로 전합니다.
  ProviderListenable<AsyncValue<EvidenceAccess>> get access;

  /// 캐시를 건너뛰고 응답을 다시 받습니다. 실패는 던지지 않고 [access]의 오류로 남깁니다.
  Future<void> reload(Ref ref);
}

/// 오늘 응답(`getDaily`)의 근거. 잠금이 풀리면 [DailyController.reload]로 다시 받습니다.
@immutable
final class DailyEvidenceSubject implements EvidenceSubject {
  /// 오늘 응답의 근거.
  const new();

  @override
  ProviderListenable<AsyncValue<EvidenceAccess>> get access =>
      dailyControllerProvider.select(
        (value) => value.whenData((view) => view.daily.evidenceAccess),
      );

  @override
  Future<void> reload(Ref ref) =>
      ref.read(dailyControllerProvider.notifier).reload();

  @override
  bool operator ==(Object other) => other is DailyEvidenceSubject;

  @override
  int get hashCode => (DailyEvidenceSubject).hashCode;
}

/// [slotId] 슬롯의 근거를 담은 응답. 계획 6이 사주 표 계열 슬롯을 여기서 가릅니다.
EvidenceSubject evidenceSubjectFor(String slotId) =>
    const DailyEvidenceSubject();

/// 잠금 해제 흐름에서 화면이 알려야 하는 일(toast).
sealed class UnlockEvent {
  /// 하위 타입이 상속하는 기본 생성자입니다.
  const new();
}

/// 광고를 끝까지 봤지만 권한 확인이 오지 않았습니다(최대 시간이 지났거나, 권한이 생겼다는데
/// 다시 받은 응답이 여전히 잠김). `evidence-sheet.unlock.failed` toast입니다.
final class UnlockTimedOut extends UnlockEvent {
  /// 확인 시간 초과.
  const new();
}

/// 광고를 표시하지 못했습니다. 오류 toast입니다.
final class UnlockFailed extends UnlockEvent {
  /// 실패 원인을 담습니다.
  const new(this.error);

  /// 실패 원인.
  final AppError error;
}

/// 근거 시트의 열람 상태.
final class EvidenceUnlockState {
  /// 상태를 만듭니다.
  const new({
    required this.link,
    this.adReady = false,
    this.refreshing = false,
    this.refreshError,
  });

  /// 잠김 4상태(`depth-link.evidenceSheet`).
  final DepthLinkState link;

  /// 광고를 불러 둬 버튼을 켤 수 있는지. 불러오는 중이거나 광고를 보는 중이면 false입니다.
  final bool adReady;

  /// 권한이 생겨 응답을 다시 받는 중인지(세 구역 skeleton, IA `loading`).
  final bool refreshing;

  /// 권한이 생긴 뒤 응답을 다시 받지 못한 원인(IA `error`). 다시 시도하면 지워집니다.
  final AppError? refreshError;
}

/// 근거 시트의 잠금 해제 흐름(A26, D60, spec §7).
///
/// 상태 기계:
/// * 처음: 응답이 `unlocked`면 [DepthLinkState.unlocked]이고 아무것도 하지 않습니다. 아니면
///   [DepthLinkState.locked]에서 광고를 미리 불러 두고(`adReady`, 없으면
///   [DepthLinkState.lockedNoAd]), 이용권을 한 번 물어 이미 권한이 있으면(확인 중에 시트를
///   닫았던 경우, 광고 제거권을 산 경우) 바로 다시 받습니다.
/// * [watchAd]: 끝까지 보면 [DepthLinkState.unlocking]에서 이용권을
///   [rewardPollTimingProvider] 간격으로 최대 시간까지 묻습니다. 권한이 생기면
///   `refreshing`(skeleton)으로 응답을 다시 받아 [DepthLinkState.unlocked]이고,
///   시간이 지나면 [UnlockTimedOut]과 `locked`입니다.
///   닫으면 그대로 `locked`, 표시 실패는 [UnlockFailed]와 `locked`이며 광고를 다시 불러 둡니다.
/// * 다시 받기가 실패하면 `refreshError`이고 [retry]로 다시 받습니다.
///
/// 시트가 닫혀 버려지면(autoDispose) 묻기와 기다림을 멈추고 이벤트를 내지 않습니다.
/// 권한은 server만 부여합니다. 열림은 응답의 `evidenceAccess`로만 정합니다.
class EvidenceUnlockController extends Notifier<EvidenceUnlockState> {
  /// [subject] 응답의 근거를 엽니다.
  new(this.subject);

  /// 근거를 담은 응답.
  final EvidenceSubject subject;

  final _events = StreamController<UnlockEvent>.broadcast();

  /// 미리 불러 둔 광고. 한 번 보이면 버립니다.
  RewardedAdHandle? _ad;

  /// 확인 간격 기다림. 버려지면 취소해 남은 묻기가 일어나지 않게 합니다.
  Timer? _wait;

  /// 화면이 toast로 알릴 일. 시트가 닫히면 닫힙니다.
  Stream<UnlockEvent> get events => _events.stream;

  @override
  EvidenceUnlockState build() {
    ref
      ..onDispose(() {
        _wait?.cancel();
        _ad = null;
        unawaited(_events.close());
      })
      ..listen(subject.access, _onAccess);
    if (ref.read(subject.access).value == EvidenceAccess.unlocked) {
      return const EvidenceUnlockState(link: DepthLinkState.unlocked);
    }
    // build 안에서는 상태를 바꿀 수 없으므로 준비는 다음 차례에 합니다.
    unawaited(Future.microtask(_prepare));
    return const EvidenceUnlockState(link: DepthLinkState.locked);
  }

  /// 광고를 보입니다. 광고가 준비된 `locked`에서만 동작합니다.
  Future<void> watchAd() async {
    final ad = _ad;
    if (ad == null || state.link != DepthLinkState.locked) {
      return;
    }
    _ad = null;
    // 광고를 보는 동안 버튼을 꺼 두 번 누르지 않게 합니다.
    state = const EvidenceUnlockState(link: DepthLinkState.locked);
    RewardedResult result;
    try {
      result = await ad.show();
    } on AppError catch (error) {
      result = RewardFailed(error);
    }
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case RewardEarned():
        await _awaitGrant();
      case RewardDismissed():
        await _loadAd();
      case RewardFailed(:final error):
        _emit(UnlockFailed(error));
        await _loadAd();
    }
  }

  /// 오류 화면의 다시 시도. 응답을 다시 받습니다.
  Future<void> retry() async {
    if (state.refreshError != null) {
      await _refresh();
    } else {
      await subject.reload(ref);
    }
  }

  /// 광고를 불러 두고, 이미 권한이 있는지 한 번 묻습니다.
  Future<void> _prepare() async {
    if (!ref.mounted) {
      return;
    }
    await Future.wait([_loadAd(), _refreshIfGranted()]);
  }

  Future<void> _refreshIfGranted() async {
    if (await _insightActive() && ref.mounted && _canRefresh) {
      await _refresh();
    }
  }

  /// 아직 잠겨 있고 다시 받는 중이 아니면 다시 받을 수 있습니다.
  bool get _canRefresh =>
      state.link != DepthLinkState.unlocked && !state.refreshing;

  /// 보상형 광고를 불러 둡니다. 없거나 실패하면 [DepthLinkState.lockedNoAd]입니다.
  Future<void> _loadAd() async {
    RewardedAdHandle? ad;
    try {
      ad = await ref
          .read(adsProvider)
          .loadRewarded(userId: ref.read(currentAccountIdProvider));
    } on Object {
      // 광고 SDK 오류와 계정 id 없음(로그아웃 직후)은 볼 수 있는 광고가 없는 것과 같습니다.
      ad = null;
    }
    // 그사이 확인 중·다시 받는 중·열림으로 넘어갔으면 버튼을 다시 켜지 않습니다.
    if (!ref.mounted || state.link != DepthLinkState.locked) {
      return;
    }
    _ad = ad;
    state = ad == null
        ? const EvidenceUnlockState(link: DepthLinkState.lockedNoAd)
        : const EvidenceUnlockState(link: DepthLinkState.locked, adReady: true);
  }

  /// 끝까지 본 뒤 권한이 생길 때까지 묻습니다.
  Future<void> _awaitGrant() async {
    state = const EvidenceUnlockState(link: DepthLinkState.unlocking);
    final timing = ref.read(rewardPollTimingProvider);
    final attempts = math.max(
      1,
      (timing.timeout.inMicroseconds / timing.interval.inMicroseconds).floor(),
    );
    for (var i = 0; i < attempts; i++) {
      await _delay(timing.interval);
      if (!ref.mounted || !_canRefresh) {
        return;
      }
      final granted = await _insightActive();
      if (!ref.mounted || !_canRefresh) {
        return;
      }
      if (granted) {
        await _refresh();
        return;
      }
    }
    state = const EvidenceUnlockState(link: DepthLinkState.locked);
    _emit(const UnlockTimedOut());
    await _loadAd();
  }

  /// 권한이 생겼으니 응답을 다시 받습니다. 열림은 다시 받은 응답의 `evidenceAccess`로 정합니다.
  Future<void> _refresh() async {
    state = const EvidenceUnlockState(
      link: DepthLinkState.unlocking,
      refreshing: true,
    );
    await subject.reload(ref);
    if (!ref.mounted) {
      return;
    }
    final access = ref.read(subject.access);
    final error = access.error;
    if (error != null) {
      state = EvidenceUnlockState(
        link: DepthLinkState.unlocking,
        refreshError: error is AppError ? error : UnexpectedError(error),
      );
    } else if (access.value == EvidenceAccess.unlocked) {
      state = const EvidenceUnlockState(link: DepthLinkState.unlocked);
    } else {
      // 권한이 생겼다는데 응답이 아직 잠김: server 반영을 기다리지 않고 실패로 알립니다.
      state = const EvidenceUnlockState(link: DepthLinkState.locked);
      _emit(const UnlockTimedOut());
      await _loadAd();
    }
  }

  /// 응답이 다른 길(오늘 화면의 다시 받기, 자정 넘김)로 바뀌면 따라갑니다.
  /// 다시 받는 중이면 그 결과는 [_refresh]가 정합니다.
  void _onAccess(
    AsyncValue<EvidenceAccess>? previous,
    AsyncValue<EvidenceAccess> next,
  ) {
    if (state.refreshing) {
      return;
    }
    final access = next.value;
    if (access == EvidenceAccess.unlocked &&
        state.link != DepthLinkState.unlocked) {
      _wait?.cancel();
      state = const EvidenceUnlockState(link: DepthLinkState.unlocked);
    } else if (access == EvidenceAccess.locked &&
        state.link == DepthLinkState.unlocked) {
      // 새 날짜의 응답처럼 다시 잠기면 처음처럼 준비합니다.
      state = const EvidenceUnlockState(link: DepthLinkState.locked);
      unawaited(_prepare());
    }
  }

  /// 근거 열람 권한이 있는지. 묻기 실패는 "아직 없음"으로 보고 다음 차례에 다시 묻습니다.
  Future<bool> _insightActive() async {
    try {
      final entitlements = await ref
          .read(entitlementsRepositoryProvider)
          .fetch();
      return entitlements.insight.active;
    } on AppError {
      return false;
    }
  }

  /// [duration]만큼 기다립니다. 버려지면 끝나지 않습니다(남은 일이 이어지지 않음).
  Future<void> _delay(Duration duration) {
    final done = Completer<void>();
    _wait = Timer(duration, done.complete);
    return done.future;
  }

  void _emit(UnlockEvent event) {
    if (ref.mounted && !_events.isClosed) {
      _events.add(event);
    }
  }
}

/// 근거 시트 하나의 잠금 해제 흐름. 시트가 닫히면 버려집니다.
final NotifierProviderFamily<
  EvidenceUnlockController,
  EvidenceUnlockState,
  EvidenceSubject
>
evidenceUnlockControllerProvider = NotifierProvider.autoDispose
    .family<EvidenceUnlockController, EvidenceUnlockState, EvidenceSubject>(
      EvidenceUnlockController.new,
    );
