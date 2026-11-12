import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
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

/// 근거 시트(`evidence-sheet`) 본문. [slotId] 슬롯의 근거를 보입니다. [slotId]는 슬롯 id 또는
/// 오늘 행운 카드의 카드 id(`<슬롯>#<카드 필드>`, `dailyCardSlotId`, A134)입니다.
///
/// 근거를 담은 응답([EvidenceSubject])의 `evidenceAccess`와 잠금 해제 흐름
/// ([EvidenceUnlockController])을 [EvidenceSheetBody]에 넘깁니다. 시트가 열리면 광고를 미리
/// 불러 두고, 닫히면 흐름이 버려져 권한 묻기가 멈추고 toast도 뜨지 않습니다.
///
/// 판정 근거·원전 문장은 [slotId] 슬롯 근거(`evidence[]`)의 `basis`·`source`를 순서대로 넘기고,
/// 문장이 없거나 빈 항목은 건너뜁니다(A42, A22 남은 규칙). 원전은 같은 `sourceRef`를 처음
/// 한 번만 그립니다(#924). 문장 자체가 근거인 슬롯(용신 판정 근거)은 근거 목록 대신 그 문장을
/// 판정 근거 문단 하나로 보이고 원전 구역을 두지 않습니다(A129, #931). 근거는 열렸을 때(`unlocked`이고 다시
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

  /// 이 시트가 한 번이라도 열렸는지. 열린 뒤에는 응답이 다시 받는 중이거나 실패해도 시트를
  /// 그대로 둡니다.
  bool _everOpened = false;

  /// 응답이 열려 있을 때 받은 마지막 근거와 원국 개인 해석. 보는 중에 응답이 다시 잠기면
  /// (자정 뒤 새 날 응답, 기간 끝) 이것을 시트를 닫을 때까지 그립니다(`depth-link` 자정 규칙,
  /// `unlock.glint` `stopWhen`). 다음에 여는 시트는 새 흐름이라 응답대로 잠깁니다.
  List<Evidence> _heldEvidence = const [];
  RenderedText? _heldPersonal;
  RenderedText? _heldSentence;

  /// 문장 자체가 근거인 슬롯이면 그 문장의 provider(A129, #931). 아니면 null입니다.
  late final ProviderListenable<SentenceEvidence>? _sentenceSource = _subject
      .sentenceEvidenceOf(widget.slotId);

  /// 열림 꼬리표에 보인 권한. 한 번 알면 시트를 닫을 때까지 그대로 두고 다시 묻지 않습니다.
  Insight? _tagInsight;

  /// initState가 끝났는지. 그 전(구독의 첫 알림)에는 setState 없이 값만 둡니다.
  bool _initialized = false;

  /// 문장 자체가 근거인 슬롯이 열렸는데 문장이 없어 시트를 닫았는지(한 번만 닫음).
  bool _closedWithoutSentence = false;

  /// 꼬리표 권한을 기다리는 구독. 권한을 알면 닫습니다.
  ProviderSubscription<AsyncValue<Insight?>>? _tagSubscription;

  @override
  void initState() {
    super.initState();
    // 응답이 열려 있는 동안 받은 근거를 붙잡아 둡니다. 다시 잠긴 응답의 빈 근거는 버립니다.
    ref.listenManual(_subject.evidenceOf(widget.slotId), (_, next) {
      final evidence = next.value;
      if (evidence != null && _accessUnlocked) _heldEvidence = evidence;
    }, fireImmediately: true);
    final sentenceSource = _sentenceSource;
    if (sentenceSource != null) {
      ref.listenManual(sentenceSource, (_, next) {
        if (next.sentence != null && _accessUnlocked) {
          _heldSentence = next.sentence;
        }
      }, fireImmediately: true);
    }
    final personalKey = widget.personal;
    if (personalKey != null) {
      ref.listenManual(_subject.personalOf(personalKey), (_, next) {
        if (next.hasValue && _accessUnlocked) _heldPersonal = next.value;
      }, fireImmediately: true);
    }
    // 열리면 꼬리표 권한을 한 번 구합니다.
    ref.listenManual(
      evidenceUnlockControllerProvider(_subject),
      (_, next) => _onUnlockState(next),
      fireImmediately: true,
    );
    // 흐름(notifier)이 바뀌면 새 흐름의 이벤트를 다시 구독합니다. 구독이 흐름을 붙잡아 두므로
    // 시트가 열려 있는 동안 버려지지 않습니다.
    ref.listenManual(evidenceUnlockControllerProvider(_subject).notifier, (
      _,
      controller,
    ) {
      unawaited(_events?.cancel());
      _events = controller.watchEvents().listen(_onEvent);
    }, fireImmediately: true);
    _initialized = true;
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _tagSubscription?.close();
    super.dispose();
  }

  /// 지금 응답이 열려 있는지.
  bool get _accessUnlocked =>
      ref.read(_subject.access).value == EvidenceAccess.unlocked;

  /// 시트가 열리면(다시 받는 중이 아님) 꼬리표 권한을 구독합니다. 이미 알면 묻지 않습니다.
  void _onUnlockState(EvidenceUnlockState state) {
    if (state.link != DepthLinkState.unlocked || state.refreshing) return;
    _everOpened = true;
    if (_tagInsight != null || _tagSubscription != null) return;
    final subscription = ref.listenManual(
      unlockTagInsightProvider,
      (_, next) => _onTagInsight(next.value),
      fireImmediately: true,
    );
    // 이미 받은 값이면 첫 알림(fireImmediately)에서 동기로 알게 되므로, 그때는 여기서 닫습니다.
    // 권한 없음(null)이 동기로 와도 아직 값을 받기 전이라 구독을 열어 두고 기다립니다.
    if (_tagInsight != null) {
      subscription.close();
    } else {
      _tagSubscription = subscription;
    }
  }

  void _onTagInsight(Insight? insight) {
    if (insight == null || _tagInsight != null) return;
    _tagInsight = insight;
    // 권한을 알았으니 더 묻지 않습니다(보는 중에 권한이 끝나도 꼬리표는 그대로).
    final subscription = _tagSubscription;
    _tagSubscription = null;
    scheduleMicrotask(() => subscription?.close());
    if (mounted && _initialized) setState(() {});
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
    // 응답이 다시 잠겨도 열린 시트는 붙잡아 둔 근거를 그립니다.
    final live = access.value == EvidenceAccess.unlocked;
    final evidence = !opened
        ? const <Evidence>[]
        : live
        ? ref.watch(_subject.evidenceOf(widget.slotId)).value ?? _heldEvidence
        : _heldEvidence;
    final personalKey = widget.personal;
    final personal = !opened || personalKey == null
        ? null
        : live
        ? ref.watch(_subject.personalOf(personalKey)).value
        : _heldPersonal;
    // 잠겼을 때만 앞부분을 읽습니다(열리면 본문을 그리고, 표 칸의 시트는 미리보기가 없음).
    final locked =
        unlock.link != DepthLinkState.unlocked &&
        !unlock.refreshing &&
        personalKey == null;
    final previews = locked
        ? ref.watch(_subject.previewOf(widget.slotId))
        : const <EvidencePreview>[];
    // 문장 자체가 근거인 슬롯(용신 판정 근거): 그 문장을 판정 근거 문단으로, 원전 구역은 없음.
    final sentenceSource = _sentenceSource;
    final sentence = sentenceSource == null ? null : ref.watch(sentenceSource);
    final sentenceBody = !opened || sentence == null
        ? null
        : live
        ? sentence.sentence ?? _heldSentence
        : _heldSentence;
    // 열렸는데 그 문장이 없으면(계약상 `Yongsin.basis`는 선택값) 보일 것이 없어 시트를 닫고
    // 사주 표로 돌아갑니다. 빈 시트를 남기지 않기 위해서입니다(A129 ⑤).
    if (sentence != null && opened && sentenceBody == null) {
      _closeWithoutSentence();
    }
    final target = widget.target;
    final unlockTag = opened
        ? unlockUntilText(l10n, _tagInsight, ref.watch(profileTimezoneProvider))
        : null;
    return ScreenStateView<EvidenceUnlockState>(
      value: _valueOf(access, unlock),
      onRetry: controller.retry,
      // 권한을 읽는 동안: 제목과 구역 제목은 UI 글자라 그대로, 구역 본문 자리만 뼈입니다
      // (받는 중 모양과 같은 배치, V66). 열람 상태를 아직 몰라 안내 영역은 두지 않습니다.
      skeleton: EvidenceSheetBody(
        state: DepthLinkState.unlocked,
        title: l10n.evidenceSheetTitle,
        targetTags: target.tags,
        target: target.sentence,
        showPersonal: personalKey != null,
        showJudgment: personalKey == null,
        showSource: sentenceSource == null,
        loading: true,
      ),
      dataWithNotice: (state, _) => EvidenceSheetBody(
        state: state.link,
        title: l10n.evidenceSheetTitle,
        titleSlotId: SlotIds.evidenceSheetSheetTitle,
        targetTags: target.tags,
        target: target.sentence,
        basis: sentence != null
            ? [?sentenceBody]
            : _sentences(evidence.map((item) => item.basis)),
        source: sentence != null ? const [] : _sourcesOnce(evidence),
        basisLead: sentence != null
            ? (locked ? sentence.lead : null)
            : _sentences(previews.map((item) => item.basis)).firstOrNull,
        sourceLead: _sentences(previews.map((item) => item.source_))
            .firstOrNull,
        personal: personal == null || isBlankText(personal) ? null : personal,
        showPersonal: personalKey != null,
        // 표 칸의 시트는 판정 근거·원전이 없는 자리라 내 사주에서는 구역 하나이고, 열렸는데
        // 그 자리의 해석이 없으면(원고 없음) 빈 안내를 둡니다.
        showJudgment: personalKey == null,
        showSource: sentenceSource == null,
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

  void _closeWithoutSentence() {
    if (_closedWithoutSentence) return;
    _closedWithoutSentence = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  /// 그릴 원전 문장. 판정 근거는 근거마다 그리지만, 원전은 같은 `sourceRef`(원전 목록 키)를
  /// 처음 한 번만 그립니다(#924). 용신의 날 보조 문장처럼 서로 다른 판정 둘이 같은 원전에
  /// 기댈 때 같은 원전 묶음이 두 번 나오지 않게 하기 위해서입니다. 받은 근거 목록은 바꾸지
  /// 않고 그리는 단계에서만 거르며, 문장끼리 비교하지 않습니다. 원전 문장이 없는 근거는 그
  /// 키를 차지하지 않아 뒤의 같은 키 근거의 원전이 그려집니다.
  List<RenderedText> _sourcesOnce(List<Evidence> evidence) {
    final drawnRefs = <String>{};
    return [
      for (final item in evidence)
        if (item.source_ case final text?
            when !isBlankText(text) && drawnRefs.add(item.sourceRef))
          text,
    ];
  }

  /// 근거 순서대로 문장만 남깁니다. 없거나 빈 문장은 건너뜁니다.
  List<RenderedText> _sentences(Iterable<RenderedText?> texts) => [
    for (final text in texts)
      if (text != null && !isBlankText(text)) text,
  ];

  /// 시트 상태. 다시 받기 실패가 먼저이고, 응답이 아직 없으면 응답의 상태를 따릅니다. 한 번
  /// 열린 시트는 응답을 다시 받는 중이거나 실패해도 붙잡은 내용을 그대로 그립니다.
  AsyncValue<EvidenceUnlockState> _valueOf(
    AsyncValue<EvidenceAccess> access,
    EvidenceUnlockState unlock,
  ) {
    final refreshError = unlock.refreshError;
    if (refreshError != null) {
      return AsyncError(refreshError, StackTrace.current);
    }
    if (!access.hasValue && !_everOpened) {
      final error = access.error;
      return error == null
          ? const AsyncLoading()
          : AsyncError(error, access.stackTrace ?? StackTrace.current);
    }
    return AsyncData(unlock);
  }
}
