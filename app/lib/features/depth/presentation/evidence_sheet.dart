import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/evidence.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_preview.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/presentation/unlock_until_text.dart';
import 'package:myungli_diary/features/monetization/application/insight_providers.dart';

/// 근거 시트(`evidence-sheet`) 본문. [slotId] 슬롯의 근거를 보입니다.
///
/// 근거를 담은 응답([EvidenceSubject])의 `evidenceAccess`와 잠금 해제 흐름
/// ([EvidenceUnlockController])을 [EvidenceSheetBody]에 넘깁니다. 시트가 열리면 광고를 미리
/// 불러 두고, 닫히면 흐름이 버려져 권한 묻기가 멈추고 toast도 뜨지 않습니다.
///
/// 판정 근거·원전 문장은 [slotId] 슬롯 근거(`evidence[]`)의 `basis`·`source`를 순서대로 넘기고,
/// 문장이 없거나 빈 항목은 건너뜁니다(A42, A22 남은 규칙). 근거는 열렸을 때(`unlocked`이고 다시
/// 받는 중이 아님)만 읽으므로 잠긴 시트는 문장을 받지도 그리지도 않습니다(D60).
///
/// [personal]이 있으면(사주 표 칸 용어에서 연 시트, A58) "내 사주에서는" 구역 하나만 두고(판정
/// 근거·원전 없음, 잠겨도 그 구역만 잠김), 열렸을 때 나의 사주 응답에서 그 자리의 원국 개인 해석을
/// 찾아 넘깁니다. 항목이 없으면 빈 안내입니다. 이 시트의 응답은 늘 나의 사주입니다
/// ([evidenceSubjectFor]).
///
/// 잠겼을 때(다시 받는 중 아님)는 [slotId] 슬롯의 앞부분(`evidencePreview`)을 읽어 판정 근거와
/// 원전 `lock.veil`의 또렷한 앞부분으로 넘깁니다(근거 순서에서 처음 있는 문장, D106). 미리보기가
/// 없으면 자리값만입니다. 시트 위 대상([target])은 잠기지 않고 늘 보입니다.
///
/// 열렸을 때는 제목 옆 열림 꼬리표에 열린 이유와 끝 시각(server 권한 응답 `insight`의
/// `source`, `expiresAt`, #952)으로 고른 문구를 넘깁니다([unlockUntilText]). 권한은 알고 있는
/// 것을 먼저 쓰고 없으면 이용권을 한 번 묻습니다([unlockTagInsightProvider]).
///
/// 상태: 응답이 아직 없으면 skeleton(`loading`), 받지 못했거나 잠금 해제 뒤 다시 받기에
/// 실패하면 오류 화면과 다시 시도(`error`), 권한이 생겨 다시 받는 동안은 구역 skeleton입니다.
class EvidenceSheet extends ConsumerStatefulWidget {
  /// [slotId] 슬롯의 근거 시트를 만듭니다. [personal]은 원국 개인 해석의 자리입니다.
  const new({
    required this.slotId,
    this.personal,
    this.target = EvidenceTarget.none,
    super.key,
  });

  /// 근거를 보는 writing 슬롯 id.
  final String slotId;

  /// "내 사주에서는"에 보일 원국 개인 해석의 자리. 문장 안 용어·근거 링크에서 열면 null입니다.
  final PersonalReadingKey? personal;

  /// 시트 위 대상(그 문장을 정한 태그와 대상 문장). 용어나 사주 표에서 열면 없습니다.
  final EvidenceTarget target;

  @override
  ConsumerState<EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<EvidenceSheet> {
  late final EvidenceSubject _subject = evidenceSubjectFor(
    widget.slotId,
    personal: widget.personal,
  );

  StreamSubscription<UnlockEvent>? _events;

  /// 열림 꼬리표에 보인 권한. 보는 중에 권한이 끝나도(자정, 기간 끝) 시트를 닫을 때까지 그대로
  /// 둡니다(`unlock.glint` `stopWhen`, 자정 규칙과 같음).
  Insight? _tagInsight;

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
      _events = controller.watchEvents().listen(_onEvent);
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
    final personalKey = widget.personal;
    final personal = opened && personalKey != null
        ? ref.watch(_subject.personalOf(personalKey)).value
        : null;
    // 잠겼을 때만 앞부분을 읽습니다(열리면 본문을 그리고, 표 칸의 시트는 미리보기가 없음).
    final locked =
        unlock.link != DepthLinkState.unlocked &&
        !unlock.refreshing &&
        personalKey == null;
    final previews = locked
        ? ref.watch(_subject.previewOf(widget.slotId))
        : const <EvidencePreview>[];
    final target = widget.target;
    if (opened) {
      _tagInsight = ref.watch(unlockTagInsightProvider).value ?? _tagInsight;
    }
    final unlockTag = opened
        ? unlockUntilText(l10n, _tagInsight, ref.watch(profileTimezoneProvider))
        : null;
    return ScreenStateView<EvidenceUnlockState>(
      value: _valueOf(access, unlock),
      onRetry: () => unawaited(controller.retry()),
      // 권한을 읽는 동안: 제목과 구역 제목은 UI 글자라 그대로, 구역 본문 자리만 뼈입니다
      // (받는 중 모양과 같은 배치, V66). 열람 상태를 아직 몰라 안내 영역은 두지 않습니다.
      skeleton: EvidenceSheetBody(
        state: DepthLinkState.unlocked,
        title: l10n.evidenceSheetTitle,
        targetTags: target.tags,
        target: target.sentence,
        showPersonal: personalKey != null,
        showJudgment: personalKey == null,
        loading: true,
      ),
      dataWithNotice: (state, _) => EvidenceSheetBody(
        state: state.link,
        title: l10n.evidenceSheetTitle,
        titleSlotId: SlotIds.evidenceSheetSheetTitle,
        targetTags: target.tags,
        target: target.sentence,
        basis: _sentences(evidence.map((item) => item.basis)),
        source: _sentences(evidence.map((item) => item.source_)),
        basisLead: _sentences(previews.map((item) => item.basis)).firstOrNull,
        sourceLead: _sentences(previews.map((item) => item.source_))
            .firstOrNull,
        personal: personal == null || isBlankText(personal) ? null : personal,
        showPersonal: personalKey != null,
        // 표 칸의 시트는 판정 근거·원전이 없는 자리라 내 사주에서는 구역 하나이고, 열렸는데
        // 그 자리의 해석이 없으면(원고 없음) 빈 안내를 둡니다.
        showJudgment: personalKey == null,
        personalEmpty: personalKey == null
            ? null
            : l10n.evidenceSheetPersonalEmpty,
        loading: state.refreshing,
        unlockTag: unlockTag,
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
