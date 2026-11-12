import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show
        NotifierProviderFamily,
        ProviderException,
        ProviderFamily,
        ProviderListenable;
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_preview.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/monetization/application/entitlements_providers.dart';
import 'package:myungli_diary/features/monetization/application/insight_providers.dart';
import 'package:myungli_diary/features/monetization/application/staging_reward_providers.dart';
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
/// 아래 `slotId`는 슬롯 id 또는 오늘 행운 카드의 카드 id(`<슬롯>#<카드 필드>`,
/// `dailyCardSlotId`, A134)입니다. 같은 슬롯을 여러 카드가 쓰는 자리는 카드 id로 그 카드를 찾습니다.
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

  /// 응답 안 [slotId] 슬롯의 잠긴 근거 문장 앞부분(`SlotText.evidencePreview`, D106). 근거 순서이고,
  /// 응답을 받는 중이거나 슬롯·미리보기가 없으면 빈 목록입니다.
  ///
  /// server는 [access]가 `locked`일 때만 담습니다. 근거 시트는 잠겼을 때만 이 값을 읽어 `lock.veil`의
  /// 앞부분으로 씁니다.
  ProviderListenable<List<EvidencePreview>> previewOf(String slotId);

  /// 응답 안 [slotId] 슬롯의 오늘 그런 이유(`SlotText.todayReason`). 응답을 받는 중이거나 슬롯·
  /// 문장이 없거나 빈 문장이면 null입니다. 오늘 그런 이유가 없는 응답은 늘 null입니다.
  ProviderListenable<RenderedText?> todayReasonOf(String slotId);

  /// 응답 안 [key] 자리의 원국 개인 해석("내 사주에서는", A58). 항목이 없거나(잠김·원고 없음)
  /// 개인 해석이 없는 응답이면 null입니다. 근거 시트는 열렸을 때만 이 값을 읽습니다.
  ProviderListenable<AsyncValue<RenderedText?>> personalOf(
    PersonalReadingKey key,
  );

  /// [slotId]가 근거 목록 없이 문장 자체가 근거인 슬롯이면 그 문장과 잠긴 앞부분을, 그런
  /// 슬롯이 아니면 null(provider 없음)을 줍니다(A129, #931).
  ///
  /// server가 근거(`evidence[]`) 없이 문장만 렌더하는 자리입니다(예 용신 판정 근거, 계약
  /// `Yongsin.basis`는 문장 하나). 근거 시트는 이 문장을 판정 근거 문단으로 보이고 원전 구역은
  /// 두지 않습니다.
  ProviderListenable<SentenceEvidence>? sentenceEvidenceOf(String slotId);

  /// 이 응답의 잠금을 지금 보상형 광고로 풀 수 있는지. false면 잠금 해제 흐름은 광고를 불러 두지
  /// 않고 보이지도 않으며, 버튼은 광고가 준비되지 않았을 때와 같은 꺼짐(`lockedNoAd`)입니다(A141 ④,
  /// D60 "광고가 준비됐을 때만 버튼을 켬"). 풀어도 다시 받는 응답이 이 응답이 아닐 때입니다.
  ProviderListenable<bool> get adUnlockable;

  /// 캐시를 건너뛰고 응답을 다시 받습니다. 받는 동안과 실패 뒤에도 [access]는 이전 값
  /// 그대로이고(응답을 보이는 화면이 같은 실패를 따로 알리지 않게), 실패는 [AppError]로
  /// 던집니다. 오류는 근거 시트가 보입니다.
  Future<void> reload(Ref ref);
}

/// 오늘 응답(`getDaily`)의 근거. 잠금이 풀리면 [DailyController.refreshQuietly]로 다시 받습니다.
///
/// 시트를 연 화면은 그때의 응답을 [opened]로 담습니다(A134 ⑧, A141). 지금 오늘 응답이 [opened]와
/// 같은 날짜면 지금 응답을 읽어, 잠금이 풀린 뒤 다시 받은 근거가 바로 보입니다. 시트를 연 채 자정을
/// 넘겨 지금 응답이 다른 날짜이거나 다음 날 응답을 받는 중, 받지 못한 뒤에는 [opened]에서 근거
/// 열람 상태, 근거, 앞부분, 오늘 그런 이유를 찾습니다. 그동안은 광고로 풀어도 다시 받는 응답이 다른
/// 날이라 보상형 광고 흐름을 시작하지 않고 버튼을 끕니다([adUnlockable]). [opened]가 없으면 늘 지금
/// 응답입니다.
@immutable
final class DailyEvidenceSubject implements EvidenceSubject {
  /// 오늘 응답의 근거. [opened]는 시트를 연 때의 응답입니다.
  const new({this.opened});

  /// 시트를 연 때의 오늘 응답. 없으면 늘 지금 응답을 읽습니다.
  final Daily? opened;

  /// 근거를 찾을 응답. [opened]가 있으면 지금 응답이 같은 날짜일 때만 지금 응답(받는 중, 실패
  /// 표시 없이 값만)이고, 아니면 [opened]입니다.
  AsyncValue<Daily> _dailyOf(AsyncValue<DailyView> live) {
    final opened = this.opened;
    if (opened == null) return live.whenData((view) => view.daily);
    final current = live.value?.daily;
    return AsyncData(
      current != null && current.date == opened.date ? current : opened,
    );
  }

  @override
  ProviderListenable<AsyncValue<EvidenceAccess>> get access =>
      dailyControllerProvider.select(
        (value) => _dailyOf(value).whenData((daily) => daily.evidenceAccess),
      );

  /// 연 때 응답 날짜가 지금 오늘([todayProvider])이고 지금 응답도 그 날짜일 때만 광고로 풉니다
  /// ([_adUnlockableOnProvider]). 풀면 오늘을 다시 받으므로, 오늘이 다른 날이면 광고를 헛되이 봅니다.
  @override
  ProviderListenable<bool> get adUnlockable {
    final opened = this.opened;
    if (opened == null) return _alwaysAdUnlockableProvider;
    return _adUnlockableOnProvider(opened.date);
  }

  @override
  ProviderListenable<AsyncValue<List<Evidence>>> evidenceOf(String slotId) =>
      dailyControllerProvider.select(
        (value) => _dailyOf(value).whenData(
          (daily) => dailySlotText(daily, slotId)?.evidence ?? const [],
        ),
      );

  @override
  ProviderListenable<List<EvidencePreview>> previewOf(String slotId) =>
      dailyControllerProvider.select((value) {
        final daily = _dailyOf(value).value;
        return daily == null
            ? const <EvidencePreview>[]
            : dailySlotText(daily, slotId)?.evidencePreview ??
                  const <EvidencePreview>[];
      });

  @override
  ProviderListenable<RenderedText?> todayReasonOf(String slotId) =>
      dailyControllerProvider.select((value) {
        final daily = _dailyOf(value).value;
        final reason = daily == null
            ? null
            : dailySlotText(daily, slotId)?.todayReason;
        return reason == null || isBlankText(reason) ? null : reason;
      });

  /// 오늘 응답에는 원국 개인 해석이 없습니다.
  @override
  ProviderListenable<AsyncValue<RenderedText?>> personalOf(
    PersonalReadingKey key,
  ) => dailyControllerProvider.select(
    (value) => _dailyOf(value).whenData((_) => null),
  );

  /// 오늘 응답의 근거 링크 슬롯은 모두 근거 목록을 가집니다.
  @override
  ProviderListenable<SentenceEvidence>? sentenceEvidenceOf(String slotId) =>
      null;

  @override
  Future<void> reload(Ref ref) =>
      ref.read(dailyControllerProvider.notifier).refreshQuietly();

  @override
  bool operator ==(Object other) =>
      other is DailyEvidenceSubject && other.opened == opened;

  @override
  int get hashCode => Object.hash(DailyEvidenceSubject, opened);
}

/// 문장 자체가 근거인 슬롯의 값([EvidenceSubject.sentenceEvidenceOf]). `sentence`는 열린 응답의
/// 문장, `lead`는 잠긴 응답의 앞부분(D106)이고 없거나 빈 문장이면 null입니다.
typedef SentenceEvidence = ({RenderedText? sentence, RenderedText? lead});

RenderedText? _nonBlank(RenderedText? text) =>
    text == null || isBlankText(text) ? null : text;

/// 잠긴 근거 앞부분이 없는 응답이 돌려주는 값.
final Provider<List<EvidencePreview>> _noPreviewProvider =
    Provider<List<EvidencePreview>>((_) => const []);

/// 늘 광고로 풀 수 있는 응답이 돌려주는 값.
final Provider<bool> _alwaysAdUnlockableProvider = Provider<bool>((_) => true);

/// [date](`Daily.date`) 응답의 잠금을 지금 광고로 풀 수 있는지(A141 ④).
///
/// 오늘 날짜를 함께 봅니다. 자정 뒤 다음 날 응답을 받는 중이거나 받지 못한 뒤에도 Riverpod은 오늘
/// 응답에 전날 값을 남기므로(`AsyncLoading`, `AsyncError`의 이전 값), 응답 날짜만으로는 날짜가
/// 바뀐 것을 알 수 없기 때문입니다. 지금 응답의 날짜도 보아, 오늘이 바뀐 뒤 아직 응답이 없을 때와
/// 그 반대의 짧은 틈에도 켜지지 않습니다.
final ProviderFamily<bool, String> _adUnlockableOnProvider =
    Provider.family<bool, String>(
      (ref, date) =>
          ref.watch(todayProvider).toIso() == date &&
          ref.watch(
                dailyControllerProvider.select((v) => v.value?.daily.date),
              ) ==
              date,
    );

/// 오늘 그런 이유가 없는 응답이 돌려주는 값.
final Provider<RenderedText?> _noTodayReasonProvider = Provider<RenderedText?>(
  (_) => null,
);

/// 나의 사주 응답(`getChart`)의 근거. 근거 시트를 여는 자리는 용신 판정 근거
/// (`saju-chart.yongsin.basis`)와 표 칸의 원국 개인 해석이고, 잠금이 풀리면
/// [ChartController.refreshQuietly]로 다시 받습니다(A56·A58). 오늘 그런 이유는 없습니다.
///
/// 용신 판정 근거는 문장 자체가 근거라 server가 근거 목록을 주지 않습니다(계약 `Yongsin.basis`).
/// 그래서 그 슬롯의 근거 목록과 앞부분은 늘 비고, 문장은 [sentenceEvidenceOf]로 줍니다(#931).
@immutable
final class ChartEvidenceSubject implements EvidenceSubject {
  /// 나의 사주 응답의 근거.
  const new();

  @override
  ProviderListenable<AsyncValue<EvidenceAccess>> get access =>
      chartControllerProvider.select(
        (value) => value.whenData((chart) => chart.evidenceAccess),
      );

  /// 나의 사주 응답에는 근거 목록이 있는 슬롯이 없습니다(용신 판정 근거는 문장 자체가 근거).
  @override
  ProviderListenable<AsyncValue<List<Evidence>>> evidenceOf(String slotId) =>
      chartControllerProvider.select(
        (value) => value.whenData((_) => const <Evidence>[]),
      );

  /// 나의 사주 응답에는 근거 목록의 앞부분이 없습니다(용신 판정 근거는 [sentenceEvidenceOf]).
  @override
  ProviderListenable<List<EvidencePreview>> previewOf(String slotId) =>
      _noPreviewProvider;

  @override
  ProviderListenable<SentenceEvidence>? sentenceEvidenceOf(String slotId) =>
      slotId == SlotIds.sajuChartYongsinBasis
      ? chartControllerProvider.select((value) {
          final yongsin = value.value?.yongsin;
          return (
            sentence: _nonBlank(yongsin?.basis?.text),
            lead: _nonBlank(yongsin?.basisPreview),
          );
        })
      : null;

  @override
  ProviderListenable<RenderedText?> todayReasonOf(String slotId) =>
      _noTodayReasonProvider;

  @override
  ProviderListenable<AsyncValue<RenderedText?>> personalOf(
    PersonalReadingKey key,
  ) => chartControllerProvider.select(
    (value) => value.whenData(
      (chart) => personalReadingOf(
        chart,
        kind: key.kind,
        position: key.position,
        index: key.index,
        shinsal: key.shinsal,
      )?.text,
    ),
  );

  /// 나의 사주 응답은 날짜에 묶이지 않아 늘 광고로 풉니다.
  @override
  ProviderListenable<bool> get adUnlockable => _alwaysAdUnlockableProvider;

  @override
  Future<void> reload(Ref ref) =>
      ref.read(chartControllerProvider.notifier).refreshQuietly();

  @override
  bool operator ==(Object other) => other is ChartEvidenceSubject;

  @override
  int get hashCode => (ChartEvidenceSubject).hashCode;
}

/// [slotId] 슬롯의 근거를 담은 응답. 사주 표(`saju-chart.*`) 슬롯은 나의 사주, 그 밖은 오늘입니다.
///
/// 원국 개인 해석([personal])을 보는 근거 시트는 늘 나의 사주입니다(개인 해석은 `Chart`에만 있음,
/// A58).
EvidenceSubject evidenceSubjectFor(
  String slotId, {
  PersonalReadingKey? personal,
}) => personal != null || slotId.startsWith('${ScreenIds.sajuChart}.')
    ? const ChartEvidenceSubject()
    : const DailyEvidenceSubject();

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
/// * [watchAd]: 끝까지 보면 staging에서는 먼저 보상을 staging 전용 경로로 보내고(D101 ④,
///   [stagingRewardDeliveryProvider]), [DepthLinkState.unlocking]에서 이용권을
///   [rewardPollTimingProvider] 간격으로 마감 시각(시작 + timeout)까지 묻습니다. 마감은
///   Timer로 재므로 요청이 늦어도 마감 시각에 끝나고, 마감에 걸린 요청의 결과는 버립니다.
///   권한이 생기면 `refreshing`(skeleton)으로 응답을 다시 받아 [DepthLinkState.unlocked]이고,
///   마감이 지나면 [UnlockTimedOut]과 `locked`입니다. 닫으면 그대로 `locked`, 표시 실패나
///   이용권 확인의 예상 밖 오류는 [UnlockFailed]와 `locked`이며 광고를 다시 불러 둡니다.
/// * 다시 받기가 실패하면 `refreshError`이고 [retry]로 다시 받습니다.
/// * 한 번 열리면 응답이 다시 잠겨도 시트를 닫을 때까지 열린 채입니다([_onAccess]).
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
      ..listen(subject.access, _onAccess)
      ..listen(subject.adUnlockable, _onAdUnlockable);
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
    if (ad == null ||
        state.link != DepthLinkState.locked ||
        !ref.read(subject.adUnlockable)) {
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
        await _deliverStagingReward(result);
        if (!flow.mounted || state.link == DepthLinkState.unlocked) {
          return;
        }
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
  ///
  /// 지금 광고로 풀 수 없는 응답([EvidenceSubject.adUnlockable] false)이면 광고도 권한도 묻지 않고
  /// 버튼을 끕니다(`lockedNoAd`, A141 ④).
  Future<void> _prepare() async {
    final flow = ref;
    if (!flow.mounted) {
      return;
    }
    if (!ref.read(subject.adUnlockable)) {
      _showAdReady(flow);
      return;
    }
    await Future.wait([_loadAd(flow), _refreshIfGranted(flow)]);
  }

  /// 광고로 풀 수 있는지가 바뀌면 버튼을 맞춥니다. 풀 수 없게 되면 꺼짐(`lockedNoAd`), 다시 풀 수
  /// 있게 되면 광고를 불러 둡니다.
  void _onAdUnlockable(bool? previous, bool next) {
    if (previous == next) return;
    if (next) {
      unawaited(_prepare());
    } else {
      _showAdReady(ref);
    }
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
    // 광고로 풀 수 없는 응답이면(A141 ④) 광고를 닫거나 실패한 뒤에도 새로 불러 두지 않습니다.
    if (!ref.read(subject.adUnlockable)) {
      _showAdReady(flow);
      return;
    }
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
    state = _ad == null || !ref.read(subject.adUnlockable)
        ? const EvidenceUnlockState(link: DepthLinkState.lockedNoAd)
        : const EvidenceUnlockState(link: DepthLinkState.locked, adReady: true);
  }

  /// staging이면 보상을 staging 전용 경로로 보냅니다(D101 ④). prod와 fake 모드는 할 일이
  /// 없습니다(SSV 콜백, 대역). 보내지 못하면 요약을 보고하고 그대로 권한을 묻습니다. 권한이 오지
  /// 않으면 마감에 [UnlockTimedOut]으로 끝납니다.
  Future<void> _deliverStagingReward(RewardEarned reward) async {
    final delivery = ref.read(stagingRewardDeliveryProvider);
    if (delivery == null) return;
    try {
      await delivery.deliver(reward);
    } on Object catch (error, stack) {
      ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
    }
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
      await forgetLockedCharts(ref);
      await refreshLockedDaily(ref);
      return;
    }
    // 권한이 생겼다는데 응답이 아직 잠김: 열지 않습니다.
    state = const EvidenceUnlockState(link: DepthLinkState.locked);
    if (fromAd) {
      _emit(flow, const UnlockTimedOut());
    }
    await _loadAd(flow);
  }

  /// 응답이 다른 길(오늘 화면의 다시 받기)로 열리면 따라갑니다. 다시 받는 중이면 그 결과는
  /// [_refresh]가 정합니다.
  ///
  /// 한 번 열린 시트는 응답이 다시 잠겨도(자정 뒤 새 날 응답, 광고 제거권 기간 끝) 닫을
  /// 때까지 [DepthLinkState.unlocked]로 둡니다(`depth-link` 자정 규칙, `unlock.glint`
  /// `stopWhen`). 이 흐름은 시트마다 있고 닫히면 버려지므로, 다음에 여는 시트부터 응답대로
  /// `locked`입니다.
  void _onAccess(
    AsyncValue<EvidenceAccess>? previous,
    AsyncValue<EvidenceAccess> next,
  ) {
    if (state.refreshing) {
      return;
    }
    if (next.value == EvidenceAccess.unlocked &&
        state.link != DepthLinkState.unlocked) {
      // 확인 중이었으면 멈춰 [watchAd]도 끝나게 합니다.
      _stopGrant(_GrantStop.cancelled);
      state = const EvidenceUnlockState(link: DepthLinkState.unlocked);
      _forgetLockedCalendars();
    }
  }

  /// 잠긴 채 받아 둔 달 길흉과 나의 사주를 버리고, 잠긴 오늘 응답을 다시 받습니다(A32·A56,
  /// Review Focus 5). 기다리지 않습니다. 여러 번 불려도 지울 것이 없으면 아무 일도 없고, 실패는
  /// 각 정리 안에서 보고하고 삼킵니다.
  void _forgetLockedCalendars() {
    unawaited(ref.read(calendarUnlockSyncProvider).forgetLocked());
    unawaited(forgetLockedCharts(ref));
    unawaited(refreshLockedDaily(ref));
  }

  /// 근거 열람 권한을 한 번 묻습니다. 활성이면 열림 꼬리표와 근거 아이콘이 쓰도록 남깁니다
  /// ([latestInsightGrantProvider]).
  ///
  /// 통신 실패([AppError])는 "아직 없음"으로 보고 다음 차례에 다시 묻습니다. 그 밖의 예외는
  /// 비정상 종료 보고에 요약을 남기고 `failure`로 돌려줍니다.
  Future<_InsightAnswer> _askInsight() async {
    final flow = ref;
    final repository = ref.read(entitlementsRepositoryProvider);
    final reporter = ref.read(crashReporterProvider);
    try {
      final entitlements = await repository.fetch();
      if (flow.mounted) _recordGrant(entitlements.insight);
      return (active: entitlements.insight.active, failure: null);
    } on AppError {
      return (active: false, failure: null);
    } on Object catch (error, stack) {
      reporter.record(CrashSummary.from(error), stack);
      return (active: false, failure: UnexpectedError(error));
    }
  }

  /// 받은 권한을 지금 계정의 것으로 남깁니다. 계정 id가 없으면 남기지 않습니다.
  ///
  /// 계정 id provider는 로그아웃 상태에서 `StateError`를 던지고(`entryOverrides`), override가
  /// 없으면(계정 범위 밖 테스트) `UnimplementedError`를 던집니다. Riverpod은 둘을
  /// [ProviderException]으로 감싸므로 그 두 경우만 "계정 없음"으로 보고, 다른 오류는 그대로
  /// 올립니다.
  void _recordGrant(Insight insight) {
    final String accountId;
    try {
      accountId = ref.read(currentAccountIdProvider);
    } on ProviderException catch (error) {
      final noAccount =
          error.exception is StateError ||
          error.exception is UnimplementedError;
      if (!noAccount) rethrow;
      return;
    }
    ref.read(latestInsightGrantProvider.notifier).record(accountId, insight);
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
