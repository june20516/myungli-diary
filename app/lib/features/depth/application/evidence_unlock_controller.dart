import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show NotifierProviderFamily, ProviderListenable;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/monetization/application/entitlements_providers.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 보상형 광고를 끝까지 본 뒤 근거 열람 권한을 다시 묻는 간격(A26, spec §7).
const rewardPollInterval = Duration(seconds: 2);

/// 권한을 묻는 최대 시간. 지나면 잠금 해제 실패 toast입니다(A26).
const rewardPollTimeout = Duration(seconds: 30);

/// 권한 확인 간격과 최대 시간. 실측(A2) 뒤 조정하고, 테스트는 짧게 바꿉니다.
final rewardPollTimingProvider =
    Provider<({Duration interval, Duration timeout})>(
      (ref) => (interval: rewardPollInterval, timeout: rewardPollTimeout),
    );

/// 근거와 슬롯 문장을 담은 응답 하나(오늘의 `Daily`, 계획 6의 `Chart`).
///
/// 근거 시트와 잠금 해제 흐름은 화면에 묶이지 않고 이 인터페이스만 봅니다. 잠금이 풀린 뒤
/// 무엇을 다시 받을지는 응답마다 [reload]가 정합니다. 잠금 해제 흐름의 family 키이므로 값으로
/// 비교되어야 합니다.
@immutable
abstract interface class EvidenceSubject {
  /// 응답의 근거 열람 상태. 받는 중·실패도 그대로 전합니다.
  ProviderListenable<AsyncValue<EvidenceAccess>> get access;

  /// 응답 안 [slotId] 슬롯의 근거 목록. 슬롯이 없거나 근거가 없으면 빈 목록입니다.
  ///
  /// server는 [access]가 `unlocked`일 때만 근거를 담습니다(D60). 근거 시트도 열렸을 때만 이 값을
  /// 읽습니다.
  ProviderListenable<AsyncValue<List<Evidence>>> evidenceOf(String slotId);

  /// 응답 안 [slotId] 슬롯의 오늘 그런 이유(`SlotText.todayReason`). 응답을 받는 중이거나 슬롯·
  /// 문장이 없거나 빈 문장이면 null입니다. 오늘 그런 이유가 없는 응답은 늘 null입니다.
  ProviderListenable<RenderedText?> todayReasonOf(String slotId);

  /// 캐시를 건너뛰고 응답을 다시 받습니다. 받는 동안과 실패 뒤에도 [access]는 이전 값
  /// 그대로이고(응답을 보이는 화면이 같은 실패를 따로 알리지 않게), 실패는 [AppError]로
  /// 던집니다. 오류는 근거 시트가 보입니다.
  Future<void> reload(Ref ref);
}

/// 오늘 응답(`getDaily`)의 근거. 잠금이 풀리면 [DailyController.refreshQuietly]로 다시 받습니다.
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
  ProviderListenable<AsyncValue<List<Evidence>>> evidenceOf(String slotId) =>
      dailyControllerProvider.select(
        (value) => value.whenData(
          (view) => dailySlotText(view.daily, slotId)?.evidence ?? const [],
        ),
      );

  @override
  ProviderListenable<RenderedText?> todayReasonOf(String slotId) =>
      dailyControllerProvider.select((value) {
        final view = value.value;
        final reason = view == null
            ? null
            : dailySlotText(view.daily, slotId)?.todayReason;
        return reason == null || isBlankText(reason) ? null : reason;
      });

  @override
  Future<void> reload(Ref ref) =>
      ref.read(dailyControllerProvider.notifier).refreshQuietly();

  @override
  bool operator ==(Object other) => other is DailyEvidenceSubject;

  @override
  int get hashCode => (DailyEvidenceSubject).hashCode;
}

/// [slotId] 슬롯의 근거를 담은 응답. 계획 6이 사주 표 계열 슬롯을 여기서 가릅니다.
EvidenceSubject evidenceSubjectFor(String slotId) =>
    const DailyEvidenceSubject();

/// 잠금 해제 흐름에서 화면이 알려야 하는 일(toast). 사용자가 광고 보기를 시작한 흐름에서만
/// 생깁니다(시트를 열 때의 확인은 결과가 무엇이든 조용합니다).
sealed class UnlockEvent {
  /// 하위 타입이 상속하는 기본 생성자입니다.
  const new();
}

/// 광고를 끝까지 봤지만 권한 확인이 오지 않았습니다(마감 시각이 지났거나, 권한이 생겼다는데
/// 다시 받은 응답이 여전히 잠김). `evidence-sheet.unlock.failed` toast입니다.
final class UnlockTimedOut extends UnlockEvent {
  /// 확인 시간 초과.
  const new();
}

/// 광고를 표시하지 못했거나, 광고를 본 뒤 권한 확인이 예상 밖 오류로 끝났습니다. 오류 toast입니다.
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

/// 광고를 본 뒤 권한 확인이 멈춘 까닭.
enum _GrantStop {
  /// 마감 시각이 지났습니다.
  expired,

  /// 다른 길로 열렸거나 흐름이 버려졌습니다.
  cancelled,
}

/// 이용권 한 번 묻기의 결과.
typedef _InsightAnswer = ({bool active, UnexpectedError? failure});

/// 근거 시트의 잠금 해제 흐름(A26, D60, spec §7).
///
/// 상태 기계:
/// * 처음: 응답이 `unlocked`면 [DepthLinkState.unlocked]이고 아무것도 하지 않습니다. 아니면
///   [DepthLinkState.locked]에서 광고를 미리 불러 두고(`adReady`, 없으면
///   [DepthLinkState.lockedNoAd]), 이용권을 한 번 물어 이미 권한이 있으면(확인 중에 시트를
///   닫았던 경우, 광고 제거권을 산 경우) 바로 다시 받습니다. 이 열 때 확인은 조용합니다.
///   다시 받은 응답이 아직 잠겨 있으면 toast 없이 `locked`입니다.
/// * [watchAd]: 끝까지 보면 [DepthLinkState.unlocking]에서 이용권을
///   [rewardPollTimingProvider] 간격으로 마감 시각(시작 + timeout)까지 묻습니다. 마감은
///   Timer로 재므로 요청이 늦어도 마감 시각에 끝나고, 마감에 걸린 요청의 결과는 버립니다.
///   권한이 생기면 `refreshing`(skeleton)으로 응답을 다시 받아 [DepthLinkState.unlocked]이고,
///   마감이 지나면 [UnlockTimedOut]과 `locked`입니다. 닫으면 그대로 `locked`, 표시 실패나
///   이용권 확인의 예상 밖 오류는 [UnlockFailed]와 `locked`이며 광고를 다시 불러 둡니다.
/// * 다시 받기가 실패하면 `refreshError`이고 [retry]로 다시 받습니다.
///
/// 시트가 닫혀 버려지면(autoDispose) 묻기와 기다림을 멈추고 이벤트를 내지 않습니다.
/// 권한은 server만 부여합니다. 열림은 응답의 `evidenceAccess`로만 정합니다.
class EvidenceUnlockController extends Notifier<EvidenceUnlockState> {
  /// [subject] 응답의 근거를 엽니다.
  new(this.subject);

  /// 근거를 담은 응답.
  final EvidenceSubject subject;

  /// 이벤트 통로. 다시 build(invalidate)되어도 notifier는 같은 인스턴스라 이어 쓰고, 시트가
  /// 닫혀 정말 버려졌을 때만 닫습니다([build]의 onDispose). 닫힌 뒤에는 [_emit]이 내보내지 않습니다.
  final _events = StreamController<UnlockEvent>.broadcast();

  /// 미리 불러 둔 광고. 한 번 보이면 버립니다.
  RewardedAdHandle? _ad;

  /// 확인 간격 기다림.
  Timer? _wait;

  /// 광고를 본 뒤 확인의 마감.
  Timer? _deadline;

  /// 광고를 본 뒤 확인을 멈추는 신호. 확인 중일 때만 있습니다.
  Completer<_GrantStop>? _grantStop;

  /// 마지막 다시 받기가 광고를 본 흐름에서 시작했는지([retry]가 같은 방식으로 되풀이).
  bool _refreshFromAd = false;

  /// 화면이 toast로 알릴 일.
  Stream<UnlockEvent> watchEvents() => _events.stream;

  @override
  EvidenceUnlockState build() {
    final container = ref.container;
    final self = evidenceUnlockControllerProvider(subject);
    ref
      ..onDispose(() {
        _stopGrant(_GrantStop.cancelled);
        _ad = null;
        // onDispose는 다시 build될 때도 불립니다. 정리가 끝난 뒤에도 container에 남아 있으면
        // 다시 build된 것이므로 통로를 이어 쓰고, 사라졌으면 버려진 것이므로 닫습니다.
        scheduleMicrotask(() {
          if (!container.exists(self)) {
            unawaited(_events.close());
          }
        });
      })
      ..listen(subject.access, _onAccess);
    if (ref.read(subject.access).value == EvidenceAccess.unlocked) {
      // 다른 길(오늘 화면의 다시 받기 등)로 이미 열려 있어도 잠긴 달 길흉을 버립니다(A32).
      _forgetLockedCalendars();
      return const EvidenceUnlockState(link: DepthLinkState.unlocked);
    }
    // build 안에서는 상태를 바꿀 수 없으므로 준비는 다음 차례에 합니다.
    unawaited(Future.microtask(_prepare));
    return const EvidenceUnlockState(link: DepthLinkState.locked);
  }

  /// 광고를 보입니다. 광고가 준비된 `locked`에서만 동작합니다.
  ///
  /// 끝까지 본 뒤의 확인이 끝나거나(열림·마감·실패), 다른 길로 열리거나, 흐름이 버려지면
  /// 끝납니다.
  Future<void> watchAd() async {
    final ad = _ad;
    if (ad == null || state.link != DepthLinkState.locked) {
      return;
    }
    final flow = ref;
    _ad = null;
    // 광고를 보는 동안 버튼을 꺼 두 번 누르지 않게 합니다.
    state = const EvidenceUnlockState(link: DepthLinkState.locked);
    RewardedResult result;
    try {
      result = await ad.show();
    } on AppError catch (error) {
      result = RewardFailed(error);
    }
    // 광고를 보는 동안 다른 길로 이미 열렸으면 더 할 일이 없습니다(확인 중으로 덮어쓰지 않음).
    if (!flow.mounted || state.link == DepthLinkState.unlocked) {
      return;
    }
    switch (result) {
      case RewardEarned():
        await _awaitGrant(flow);
      case RewardDismissed():
        await _loadAd(flow);
      case RewardFailed(:final error):
        _emit(flow, UnlockFailed(error));
        await _loadAd(flow);
    }
  }

  /// 시트 오류 화면의 다시 시도. 오류가 둘 중 무엇이냐에 따라 하는 일이 다릅니다.
  ///
  /// * 권한이 생긴 뒤 다시 받기가 실패했으면(`refreshError`) 그 다시 받기를 되풀이합니다.
  /// * 그렇지 않으면 근거를 담은 응답 자체를 아직 받지 못한 것이므로 응답을 다시 받습니다.
  ///   그 실패는 응답의 상태([EvidenceSubject.access])로 보입니다.
  Future<void> retry() async {
    final flow = ref;
    if (state.refreshError != null) {
      await _refresh(flow, fromAd: _refreshFromAd);
      return;
    }
    try {
      await subject.reload(ref);
    } on Object {
      // 실패는 응답의 상태로 보입니다.
    }
  }

  /// 광고를 불러 두고, 이미 권한이 있는지 한 번 묻습니다(조용한 확인).
  Future<void> _prepare() async {
    final flow = ref;
    if (!flow.mounted) {
      return;
    }
    await Future.wait([_loadAd(flow), _refreshIfGranted(flow)]);
  }

  Future<void> _refreshIfGranted(Ref flow) async {
    final answer = await _askInsight();
    if (flow.mounted && answer.active && _canRefresh) {
      await _refresh(flow, fromAd: false);
    }
  }

  /// 아직 잠겨 있고 다시 받는 중이 아니면 다시 받을 수 있습니다.
  bool get _canRefresh =>
      state.link != DepthLinkState.unlocked && !state.refreshing;

  /// 보상형 광고를 불러 둡니다. 이미 불러 둔 광고가 있으면 그것을 씁니다.
  ///
  /// 계정 id가 없거나(로그아웃 직후) 광고 SDK가 [AppError]를 주거나 광고가 없으면
  /// [DepthLinkState.lockedNoAd]입니다. 그 밖의 예외는 비정상 종료 보고에 요약을 남기고
  /// 마찬가지로 `lockedNoAd`입니다.
  Future<void> _loadAd(Ref flow) async {
    if (_ad != null) {
      _showAdReady(flow);
      return;
    }
    final reporter = ref.read(crashReporterProvider);
    RewardedAdHandle? ad;
    String? accountId;
    try {
      accountId = ref.read(currentAccountIdProvider);
    } on Object {
      accountId = null;
    }
    if (accountId != null) {
      try {
        ad = await ref.read(adsProvider).loadRewarded(userId: accountId);
      } on AppError {
        ad = null;
      } on Object catch (error, stack) {
        reporter.record(CrashSummary.from(error), stack);
        ad = null;
      }
    }
    if (!flow.mounted) {
      return;
    }
    // 동시에 불린 다른 준비가 먼저 불러 뒀으면 그것을 남깁니다.
    _ad ??= ad;
    _showAdReady(flow);
  }

  /// 잠긴 채라면 불러 둔 광고에 맞춰 버튼을 켜거나 `lockedNoAd`로 둡니다.
  /// 그사이 확인 중·다시 받는 중·열림으로 넘어갔으면 바꾸지 않습니다.
  void _showAdReady(Ref flow) {
    if (!flow.mounted ||
        (state.link != DepthLinkState.locked &&
            state.link != DepthLinkState.lockedNoAd)) {
      return;
    }
    state = _ad == null
        ? const EvidenceUnlockState(link: DepthLinkState.lockedNoAd)
        : const EvidenceUnlockState(link: DepthLinkState.locked, adReady: true);
  }

  /// 끝까지 본 뒤 마감 시각까지 권한을 묻습니다.
  Future<void> _awaitGrant(Ref flow) async {
    state = const EvidenceUnlockState(link: DepthLinkState.unlocking);
    final timing = ref.read(rewardPollTimingProvider);
    final stop = Completer<_GrantStop>();
    _grantStop = stop;
    _deadline = Timer(timing.timeout, () => _stopGrant(_GrantStop.expired));
    _GrantStop? stopped;
    _InsightAnswer? answer;
    while (true) {
      final waited = await Future.any<Object?>([
        _delay(timing.interval),
        stop.future,
      ]);
      if (waited is _GrantStop) {
        stopped = waited;
        break;
      }
      final asked = await Future.any<Object?>([_askInsight(), stop.future]);
      if (asked is _GrantStop) {
        // 마감에 걸린 요청의 결과는 버립니다.
        stopped = asked;
        break;
      }
      answer = asked! as _InsightAnswer;
      if (answer.active || answer.failure != null) {
        break;
      }
    }
    _stopGrant(_GrantStop.cancelled);
    if (!flow.mounted || stopped == _GrantStop.cancelled) {
      return;
    }
    final failure = answer?.failure;
    if (stopped == _GrantStop.expired || failure != null) {
      state = const EvidenceUnlockState(link: DepthLinkState.locked);
      _emit(
        flow,
        failure == null ? const UnlockTimedOut() : UnlockFailed(failure),
      );
      await _loadAd(flow);
      return;
    }
    await _refresh(flow, fromAd: true);
  }

  /// 광고를 본 뒤의 확인을 멈춥니다. 기다리는 [_awaitGrant]는 [reason]으로 끝납니다.
  void _stopGrant(_GrantStop reason) {
    _deadline?.cancel();
    _deadline = null;
    _wait?.cancel();
    _wait = null;
    final stop = _grantStop;
    _grantStop = null;
    if (stop != null && !stop.isCompleted) {
      stop.complete(reason);
    }
  }

  /// 권한이 생겼으니 응답을 다시 받습니다. 열림은 다시 받은 응답의 `evidenceAccess`로 정합니다.
  ///
  /// 다시 받은 응답이 아직 잠겨 있으면 `locked`이고, 광고를 본 흐름([fromAd])일 때만
  /// [UnlockTimedOut]을 알립니다.
  Future<void> _refresh(Ref flow, {required bool fromAd}) async {
    _refreshFromAd = fromAd;
    state = const EvidenceUnlockState(
      link: DepthLinkState.unlocking,
      refreshing: true,
    );
    try {
      await subject.reload(ref);
    } on Object catch (error) {
      if (flow.mounted) {
        state = EvidenceUnlockState(
          link: DepthLinkState.unlocking,
          refreshError: error is AppError ? error : UnexpectedError(error),
        );
      }
      return;
    }
    if (!flow.mounted) {
      return;
    }
    if (ref.read(subject.access).value == EvidenceAccess.unlocked) {
      state = const EvidenceUnlockState(link: DepthLinkState.unlocked);
      // 근거 권한이 생겼으므로 잠긴 채 받아 둔 달 길흉도 다시 받게 합니다(A32). 시트가 먼저
      // 열리도록 상태를 바꾼 뒤에 합니다. 실패는 그 안에서 보고하고 삼킵니다.
      await ref.read(calendarUnlockSyncProvider).forgetLocked();
      return;
    }
    // 권한이 생겼다는데 응답이 아직 잠김: 열지 않습니다.
    state = const EvidenceUnlockState(link: DepthLinkState.locked);
    if (fromAd) {
      _emit(flow, const UnlockTimedOut());
    }
    await _loadAd(flow);
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
      // 확인 중이었으면 멈춰 [watchAd]도 끝나게 합니다.
      _stopGrant(_GrantStop.cancelled);
      state = const EvidenceUnlockState(link: DepthLinkState.unlocked);
      _forgetLockedCalendars();
    } else if (access == EvidenceAccess.locked &&
        state.link == DepthLinkState.unlocked) {
      // 새 날짜의 응답처럼 다시 잠기면 처음처럼 준비합니다.
      state = const EvidenceUnlockState(link: DepthLinkState.locked);
      unawaited(_prepare());
    }
  }

  /// 잠긴 채 받아 둔 달 길흉을 버립니다(A32). 기다리지 않습니다. 여러 번 불려도 지울 것이
  /// 없으면 아무 일도 없고, 실패는 [CalendarUnlockSync.forgetLocked] 안에서 보고하고 삼킵니다.
  void _forgetLockedCalendars() =>
      unawaited(ref.read(calendarUnlockSyncProvider).forgetLocked());

  /// 근거 열람 권한을 한 번 묻습니다.
  ///
  /// 통신 실패([AppError])는 "아직 없음"으로 보고 다음 차례에 다시 묻습니다. 그 밖의 예외는
  /// 비정상 종료 보고에 요약을 남기고 `failure`로 돌려줍니다.
  Future<_InsightAnswer> _askInsight() async {
    final repository = ref.read(entitlementsRepositoryProvider);
    final reporter = ref.read(crashReporterProvider);
    try {
      final entitlements = await repository.fetch();
      return (active: entitlements.insight.active, failure: null);
    } on AppError {
      return (active: false, failure: null);
    } on Object catch (error, stack) {
      reporter.record(CrashSummary.from(error), stack);
      return (active: false, failure: UnexpectedError(error));
    }
  }

  /// [duration]만큼 기다립니다. 확인이 멈추면 Timer를 취소합니다(끝나지 않음).
  Future<void> _delay(Duration duration) {
    final done = Completer<void>();
    _wait = Timer(duration, done.complete);
    return done.future;
  }

  void _emit(Ref flow, UnlockEvent event) {
    if (flow.mounted && !_events.isClosed) {
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
