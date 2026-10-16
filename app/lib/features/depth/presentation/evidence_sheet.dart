import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 근거 시트(`evidence-sheet`) 본문. [slotId] 슬롯의 근거를 보입니다.
///
/// 근거를 담은 응답([EvidenceSubject])의 `evidenceAccess`와 잠금 해제 흐름
/// ([EvidenceUnlockController])을 [EvidenceSheetBody]에 넘깁니다. 시트가 열리면 광고를 미리
/// 불러 두고, 닫히면 흐름이 버려져 권한 묻기가 멈추고 toast도 뜨지 않습니다.
///
/// 판정 근거·원전 문장은 [slotId] 슬롯 근거(`evidence[]`)의 `basis`·`source`를 순서대로 넘기고,
/// 문장이 없거나 빈 항목은 건너뜁니다(A42, A22 남은 규칙). 근거는 열렸을 때(`unlocked`이고 다시
/// 받는 중이 아님)만 읽으므로 잠긴 시트는 문장을 받지도 그리지도 않습니다(D60). 원국표와
/// "내 사주에서는"은 계획 6이 [EvidenceSheetBody]의 `pillars`·`personal`에 값만 넘깁니다.
///
/// 상태: 응답이 아직 없으면 skeleton(`loading`), 받지 못했거나 잠금 해제 뒤 다시 받기에
/// 실패하면 오류 화면과 다시 시도(`error`), 권한이 생겨 다시 받는 동안은 구역 skeleton입니다.
class EvidenceSheet extends ConsumerStatefulWidget {
  /// [slotId] 슬롯의 근거 시트를 만듭니다.
  const new({required this.slotId, super.key});

  /// 근거를 보는 writing 슬롯 id.
  final String slotId;

  @override
  ConsumerState<EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<EvidenceSheet> {
  late final EvidenceSubject _subject = evidenceSubjectFor(widget.slotId);

  StreamSubscription<UnlockEvent>? _events;

  @override
  void initState() {
    super.initState();
    // 흐름(notifier)이 바뀌면 새 흐름의 이벤트를 다시 구독합니다. 구독이 흐름을 붙잡아 두므로
    // 시트가 열려 있는 동안 버려지지 않습니다.
    ref.listenManual(evidenceUnlockControllerProvider(_subject).notifier, (
      _,
      controller,
    ) {
      unawaited(_events?.cancel());
      _events = controller.events.listen(_onEvent);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  /// 확인 시간 초과·광고 표시 실패를 toast로 알립니다. 시트가 닫혔으면 알리지 않습니다.
  void _onEvent(UnlockEvent event) {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    showMyungliToast(context, switch (event) {
      UnlockTimedOut() => l10n.evidenceSheetUnlockFailed,
      UnlockFailed(:final error) => errorMessage(l10n, error),
    });
  }

  /// 광고 제거권 안내. 시트를 닫지 않고 그 위에 page를 엽니다(돌아오면 보던 근거 시트).
  void _openAdFree() {
    unawaited(context.push<void>(pathOf(ScreenIds.adFree)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = evidenceUnlockControllerProvider(_subject);
    final access = ref.watch(_subject.access);
    final unlock = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final l10n = AppLocalizations.of(context);
    final opened = unlock.link == DepthLinkState.unlocked && !unlock.refreshing;
    final evidence = opened
        ? ref.watch(_subject.evidenceOf(widget.slotId)).value ??
              const <Evidence>[]
        : const <Evidence>[];
    return ScreenStateView<EvidenceUnlockState>(
      value: _valueOf(access, unlock),
      onRetry: () => unawaited(controller.retry()),
      dataWithNotice: (state, _) => EvidenceSheetBody(
        state: state.link,
        title: l10n.evidenceSheetTitle,
        basis: _sentences(evidence.map((item) => item.basis)),
        source: _sentences(evidence.map((item) => item.source_)),
        loading: state.refreshing,
        onWatchAd: state.adReady ? () => unawaited(controller.watchAd()) : null,
        onPass: _openAdFree,
      ),
    );
  }

  /// 근거 순서대로 문장만 남깁니다. 없거나 빈 문장은 건너뜁니다.
  List<RenderedText> _sentences(Iterable<RenderedText?> texts) => [
    for (final text in texts)
      if (text != null && !isBlankText(text)) text,
  ];

  /// 시트 상태. 다시 받기 실패가 먼저이고, 응답이 아직 없으면 응답의 상태를 따릅니다.
  AsyncValue<EvidenceUnlockState> _valueOf(
    AsyncValue<EvidenceAccess> access,
    EvidenceUnlockState unlock,
  ) {
    final refreshError = unlock.refreshError;
    if (refreshError != null) {
      return AsyncError(refreshError, StackTrace.current);
    }
    if (!access.hasValue) {
      final error = access.error;
      return error == null
          ? const AsyncLoading()
          : AsyncError(error, access.stackTrace ?? StackTrace.current);
    }
    return AsyncData(unlock);
  }
}
