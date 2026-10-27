import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile_summary.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/birth_format.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/action/social_provider_text.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/account/application/account_merge_controller.dart';
import 'package:myungli_diary/features/account/presentation/merge_summary_box.dart';
import 'package:myungli_diary/features/auth/model/login_provider_order.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _checkCircle = AppGlyph(
  light: PhosphorIconsLight.checkCircle,
  regular: PhosphorIconsRegular.checkCircle,
);

/// 카드 순서(A → B)와 남길 프로필.
const List<MergeProfile> _cardProfiles = [
  MergeProfile.current,
  MergeProfile.other,
];

/// 계정 합치기(`account-merge`, D85 ④, V44, spec §9).
///
/// 한 화면이 두 단계로 바뀝니다. 제목은 두 단계에 같습니다.
///
/// * 인증 단계: 안내와 `social-login-button` 네 개(로그인 화면과 같은 순서·라벨). 누른 버튼만
///   `loading`이고 나머지는 꺼집니다. 합칠 계정이 없거나 요약을 받지 못하면 `dialog` `notice`
///   뒤 이 단계에 남습니다. 취소는 안내하지 않습니다.
/// * 요약을 받는 동안: 요약 상자와 카드 두 장 자리가 숨쉽니다(IA `loading`).
/// * 요약·고르기 단계: 설명, 가져올 기록·구매 상자, `account-choice`(A → B, 처음엔 고르지
///   않음), 같은 날 일기 안내(겹칠 때만), 화면 아래 합치기 버튼(고르기 전 꺼짐).
/// * 합치기는 `dialog` `destructive` 확인 뒤에만 합니다. 합치는 동안 버튼은 `loading`, 카드는
///   잠기고 뒤로 가기(app-bar·시스템)를 막습니다. 끝나면 진입이 회원 갈래 그대로일 때
///   `login-methods`로 돌아가고, 아니면 라우터가 진입 갈래의 화면으로 보냅니다.
/// * "합치지 않기" 버튼은 없습니다. 어느 단계에서든 뒤로 가기가 그만두기이고, 화면을 떠나면
///   합치기 토큰을 든 controller가 버려집니다.
class AccountMergeScreen extends ConsumerStatefulWidget {
  /// account-merge 화면을 만듭니다.
  const new({super.key});

  /// 합치기 버튼을 찾는 테스트용 키.
  static const Key mergeCtaKey = ValueKey(SlotIds.accountMergeCtaMerge);

  @override
  ConsumerState<AccountMergeScreen> createState() => _AccountMergeScreenState();
}

class _AccountMergeScreenState extends ConsumerState<AccountMergeScreen>
    with SingleOpenGuard<AccountMergeScreen> {
  AccountMergeController get _controller =>
      ref.read(accountMergeControllerProvider.notifier);

  Future<void> _authenticate(SocialProvider provider) async {
    final outcome = await _controller.authenticate(provider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final (body, identifier) = switch (outcome) {
      MergeNotOther(reason: MergeNotOtherReason.self) => (
        l10n.accountMergeNotOtherBodySelf,
        SlotIds.accountMergeNotOtherBody,
      ),
      MergeNotOther(reason: MergeNotOtherReason.none) => (
        l10n.accountMergeNotOtherBodyNone,
        SlotIds.accountMergeNotOtherBody,
      ),
      MergeAuthFailed() => (l10n.accountMergeError, null),
      MergeAuthDone() || MergeAuthCancelled() => (null, null),
    };
    if (body != null) {
      await _notice(body, identifier: identifier);
    }
  }

  /// 확인 창 뒤 합칩니다. 확인 창이 열려 있거나 합치는 중이면 두 번째 누름을 받지 않습니다.
  void _merge() => guardOpen(() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMyungliDialog(
      context,
      variant: DialogVariant.destructive,
      title: l10n.accountMergeMergeConfirm,
      confirm: l10n.accountMergeMergeConfirmMerge,
      cancel: l10n.accountMergeMergeConfirmCancel,
      identifier: SlotIds.accountMergeMergeConfirm,
    );
    if (!confirmed || !mounted) return;
    final outcome = await _controller.merge();
    if (!mounted) return;
    switch (outcome) {
      case MergeDone():
        unawaited(Haptics.light());
        // 진입이 다른 갈래로 바뀌었으면 라우터 redirect가 이미 그 화면으로 보냈습니다.
        final entry = ref.read(entryProvider);
        if (entry == EntryState.ready ||
            entry == EntryState.adConsentRequired) {
          context.pop();
        }
      case MergeTokenInvalid():
        await _notice(l10n.errorMergeTokenInvalid);
      case MergeFailed():
        await _notice(l10n.accountMergeError);
    }
  });

  Future<void> _notice(String body, {String? identifier}) => showMyungliNotice(
    context,
    body: body,
    identifier: identifier,
    confirm: AppLocalizations.of(context).actionConfirm,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 화면이 보이는 동안 controller(합치기 토큰)를 붙들어 둡니다.
    final state = ref.watch(accountMergeControllerProvider);
    final running = state is MergeRunning;
    return PopScope(
      // 합치는 동안 떠나면 되돌릴 수 없는 처리의 결과를 놓치므로 막습니다.
      canPop: !running,
      child: Semantics(
        identifier: ScreenIds.accountMerge,
        child: Scaffold(
          key: const ValueKey(ScreenIds.accountMerge),
          body: SafeArea(
            child: Column(
              children: [
                MyungliAppBar.inner(
                  title: l10n.accountMergeBarTitle,
                  titleIdentifier: SlotIds.accountMergeBarTitle,
                  showBack: !running && MyungliAppBar.canGoBack(context),
                ),
                Expanded(
                  child: switch (state) {
                    MergeAuth(:final busy) => _authStage(busy),
                    MergeSummaryLoading() => _summaryStage(
                      preview: null,
                      selected: null,
                      running: false,
                    ),
                    MergeChoosing(:final preview, :final selected) =>
                      _summaryStage(
                        preview: preview,
                        selected: selected,
                        running: false,
                      ),
                    MergeRunning(:final preview, :final selected) =>
                      _summaryStage(
                        preview: preview,
                        selected: selected,
                        running: true,
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title() {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s12, bottom: Space.s8),
      child: Semantics(
        identifier: SlotIds.accountMergeTitleHead,
        header: true,
        child: Text(
          AppLocalizations.of(context).accountMergeTitleHead,
          key: const ValueKey(SlotIds.accountMergeTitleHead),
          style: tokens.typography.title.copyWith(
            color: tokens.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _body(String text, String identifier) {
    final tokens = context.tokens;
    return Semantics(
      identifier: identifier,
      child: Text(
        text,
        key: ValueKey(identifier),
        style: tokens.typography.bodyUi.copyWith(
          color: tokens.colors.textSecondary,
        ),
      ),
    );
  }

  Widget _authStage(SocialProvider? busy) {
    final l10n = AppLocalizations.of(context);
    final order = loginProviderOrder(Localizations.localeOf(context));
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(Space.s20, 0, Space.s20, Space.s24 + bottom),
      children: [
        _title(),
        _body(l10n.accountMergeAuthBody, SlotIds.accountMergeAuthBody),
        const SizedBox(height: Space.s24),
        for (final (index, provider) in order.indexed) ...[
          if (index > 0) const SizedBox(height: Space.s12),
          SocialLoginButton(
            provider: provider,
            label: socialProviderLabel(l10n, provider),
            loading: busy == provider,
            // 다른 버튼이 처리 중이면 흐리게 꺼 둡니다.
            disabled: busy != null && busy != provider,
            onPressed: busy == null ? () => _authenticate(provider) : null,
          ),
        ],
      ],
    );
  }

  /// 요약·고르기 단계. [preview]가 null이면 요약을 받는 중입니다.
  Widget _summaryStage({
    required MergePreview? preview,
    required MergeProfile? selected,
    required bool running,
  }) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final summary = preview?.summary;
    final selectedIndex = selected == null
        ? null
        : _cardProfiles.indexOf(selected);
    return OnboardingPageLayout.top(
      body: [
        _title(),
        _body(l10n.accountMergeTitleBody, SlotIds.accountMergeTitleBody),
        const SizedBox(height: Space.s24),
        MergeSummaryBox(summary: summary),
        const SizedBox(height: Space.s24),
        Semantics(
          identifier: SlotIds.accountMergeChoiceLabel,
          child: Text(
            l10n.accountMergeChoiceLabel,
            style: tokens.typography.captionMd.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: Space.s8),
        AccountChoice(
          loading: summary == null,
          options: summary == null
              ? const [
                  AccountChoiceOption(name: '', current: true, saju: ''),
                  AccountChoiceOption(name: '', current: false, saju: ''),
                ]
              : [
                  _option(l10n, summary.current, current: true),
                  _option(l10n, summary.other, current: false),
                ],
          selectedIndex: selectedIndex,
          onSelected: running || summary == null
              ? null
              : (index) => _controller.choose(_cardProfiles[index]),
          groupLabel: l10n.accountMergeChoiceLabel,
          currentLabel: l10n.accountChoiceCurrent,
          otherLabel: l10n.accountChoiceOther,
        ),
        if (summary != null && summary.overlapDays > 0) ...[
          const SizedBox(height: Space.s16),
          _overlapNotice(l10n.accountMergeOverlapNotice),
        ],
      ],
      actions: [
        PrimaryButton(
          key: AccountMergeScreen.mergeCtaKey,
          identifier: SlotIds.accountMergeCtaMerge,
          label: l10n.accountMergeCtaMerge,
          loading: running,
          onPressed: selected == null || running ? null : _merge,
        ),
      ],
    );
  }

  /// 같은 날 일기가 겹친다는 안심 안내. 경고 표시 없이 `check-circle`과 caption입니다.
  Widget _overlapNotice(String text) {
    final tokens = context.tokens;
    final style = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
    );
    return Semantics(
      identifier: SlotIds.accountMergeOverlapNotice,
      child: Row(
        key: const ValueKey(SlotIds.accountMergeOverlapNotice),
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.s8,
        children: [
          // 아이콘을 첫 줄 글자 높이 가운데에 맞춥니다.
          SizedBox(
            height: style.fontSize! * style.height!,
            child: AppIcon(
              _checkCircle,
              size: AppIconSize.inline,
              color: tokens.colors.textSecondary,
            ),
          ),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }

  AccountChoiceOption _option(
    AppLocalizations l10n,
    MergeProfileSummary profile, {
    required bool current,
  }) => AccountChoiceOption(
    name: profile.honorific ?? '',
    current: current,
    saju: _sajuLine(l10n, profile),
  );
}

/// 카드의 사주 요약 줄(`ui.account-merge.saju`). 사주가 없으면 "사주 정보 없음"입니다.
String _sajuLine(AppLocalizations l10n, MergeProfileSummary profile) {
  final birth = profile.birth;
  if (profile.status == MergeProfileSummaryStatusEnum.none || birth == null) {
    return l10n.accountChoiceSajuEmpty;
  }
  final calendar = birth.calendar == CalendarType.lunar
      ? l10n.calendarLunar
      : l10n.calendarSolar;
  final date = formatBirthDay(
    l10n.localeName,
    birth.date.year,
    birth.date.month,
    birth.date.day,
  );
  final clock = birth.time.value;
  if (birth.time.status != BirthTimeStatusEnum.known || clock == null) {
    return l10n.accountChoiceSajuNoTime(date, calendar);
  }
  return l10n.accountChoiceSaju(
    date,
    calendar,
    formatBirthClock(l10n.localeName, clock),
  );
}
