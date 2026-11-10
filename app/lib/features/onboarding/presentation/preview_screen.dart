import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/preview.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/birth_format.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/notice_text.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/action/button_pair.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/application/preview_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_navigation.dart';

/// IA `preview`의 출구 대상. 둘 다 진입 상태가 바뀌지 않는 이동이라 화면이 직접 이동합니다.
const Set<String> previewExits = {ScreenIds.login, ScreenIds.onboardCall};

/// IA `preview`가 직접 처리하는 상태. 오프라인은 오류 상태의 offline 변형으로 그립니다.
const Set<String> previewHandledStates = {
  'loading',
  'error',
  'offline',
  'time-unknown',
};

/// 첫 풀이(D50): 로그인 없이 온보딩 입력으로 오늘 풀이 일부를 한 번 보여 주고 저장(로그인)으로 잇습니다.
///
/// 날의 성격 배지와 총운 문장(`fortune.head`), 대표 태그가 있는 날은 이어지는 문장(`fortune.tag`)만
/// 보입니다. 이 화면은 `term-token`이 없는 화면이라 용어 조각도 일반 글자입니다(V28). 요청이 실패해도
/// 아래 버튼은 그대로라 저장하고 계속하기와 다시 입력을 막지 않습니다.
///
/// 이 기기에서 미리보기를 이미 썼으면(server `preview.used`, 설치당 1회 S70) 풀이 대신 입력한 정보를
/// 읽기 전용으로 보이고 안내와 저장하고 계속하기 하나만 둡니다(D117, A125).
class PreviewScreen extends ConsumerWidget {
  /// preview 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 입력이 덜 찬 채 열렸으면(딥링크·복원) 다시 시도 대신 첫 단계에서 입력을 마저 받습니다.
    ref.listen(previewProvider, (_, next) {
      // 로그인 화면이 위에 있는 동안(기존 계정 로그인이 초안을 비우는 중)에는 끼어들지 않습니다.
      if (next.error is OnboardingInputIncomplete &&
          ModalRoute.of(context)?.isCurrent == true) {
        goBackToOnboardCall(context);
      }
    });
    final preview = ref.watch(previewProvider);
    // 이미 쓴 기기면 미리보기를 요청한 그 입력(로그인 저장 전까지 기기에 남는 초안)을 보입니다.
    final used = isPreviewUsedError(preview.error);
    // 이미 쓴 기기면 그 입력(초안)을 읽는 상태를 따릅니다. 읽는 중은 skeleton, 실패는 오류 상태와
    // 다시 시도(초안을 다시 읽음)입니다.
    final usedDraft = used ? ref.watch(onboardingDraftProvider) : null;
    final save = PrimaryButton(
      key: const ValueKey(SlotIds.previewCtaSave),
      identifier: SlotIds.previewCtaSave,
      label: l10n.previewCtaSave,
      onPressed: () => context.push<void>(pathOf(ScreenIds.login)),
    );
    return Semantics(
      identifier: ScreenIds.preview,
      child: Scaffold(
        key: const ValueKey(ScreenIds.preview),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                // 스택 바닥(갈래의 첫 화면, 딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                title: AppLocalizations.of(context).previewBarTitle,
                titleIdentifier: SlotIds.previewBarTitle,
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: usedDraft != null
                    ? ScreenStateView<OnboardingDraft>(
                        value: usedDraft,
                        onRetry: () => ref.invalidate(onboardingDraftProvider),
                        skeleton: const _PreviewSkeleton(),
                        data: (draft) => _PreviewUsedBody(
                          draft: draft,
                          deviceRegionIsKorea: ref.watch(
                            deviceRegionIsKoreaProvider,
                          ),
                        ),
                      )
                    : ScreenStateView<Preview>(
                        value: preview,
                        onRetry: _retriable(preview.error)
                            ? () => ref.invalidate(previewProvider)
                            : null,
                        skeleton: const _PreviewSkeleton(),
                        dataWithNotice: (preview, offlineNotice) =>
                            _PreviewBody(
                              preview: preview,
                              offlineNotice: offlineNotice,
                            ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s20,
                  Space.s12,
                  Space.s20,
                  Space.s24,
                ),
                child: ToastAnchor(
                  // 이미 쓴 기기는 다시 입력해도 미리보기가 열리지 않아 다시 입력 링크가 없습니다(D117 ①③).
                  child: used
                      ? save
                      : ButtonPair(
                          filled: save,
                          quiet: PrimaryButton(
                            key: const ValueKey(SlotIds.previewCtaRestart),
                            identifier: SlotIds.previewCtaRestart,
                            variant: PrimaryButtonVariant.quiet,
                            label: l10n.previewCtaRestart,
                            // 입력은 초안에 남아 있어 onboard-call이 채워진 채로 열립니다.
                            onPressed: () => goBackToOnboardCall(context),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이 설치에서 미리보기를 이미 썼다는 server 오류 코드(S70).
const String previewUsedErrorCode = 'preview.used';

/// [error]가 이 기기에서 미리보기를 이미 썼다는 답이면 true입니다(D117).
bool isPreviewUsedError(Object? error) =>
    error is ProblemError && error.code == previewUsedErrorCode;

/// 같은 입력으로 다시 요청해도 소용없는 오류(이미 쓴 미리보기, 입력 검증 실패, 입력 미완)가
/// 아니면 true.
bool _retriable(Object? error) {
  if (error is OnboardingInputIncomplete) return false;
  if (error is! ProblemError) return true;
  final code = error.code;
  return code != previewUsedErrorCode &&
      code != 'request.inconsistent' &&
      !code.startsWith('birth.') &&
      !code.startsWith('date.') &&
      !code.startsWith('name.');
}

class _PreviewBody extends StatelessWidget {
  const new({required this.preview, required this.offlineNotice});

  final Preview preview;
  final Widget offlineNotice;

  /// 시간 모름 notice의 배너 문장([noticeTextOf]). 없으면 null입니다.
  String? _timeUnknownMessage() {
    for (final notice in preview.notices) {
      if (notice.code == NoticeCode.timeUnknown) {
        return noticeTextOf(notice);
      }
    }
    return null;
  }

  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final login = await showMyungliDialog(
      context,
      variant: DialogVariant.confirm,
      title: l10n.previewShareLoginNotice,
      identifier: SlotIds.previewShareLoginNotice,
      confirm: l10n.previewShareLoginNoticeConfirm,
      cancel: l10n.previewShareLoginNoticeCancel,
    );
    if (login && context.mounted) {
      await context.push<void>(pathOf(ScreenIds.login));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timeUnknown = _timeUnknownMessage();
    final tag = preview.fortune.tag;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          offlineNotice,
          if (timeUnknown != null)
            NoticeBanner(
              key: const ValueKey('preview.time-unknown'),
              variant: NoticeBannerVariant.timeUnknown,
              message: timeUnknown,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Space.s24),
                Semantics(
                  identifier: SlotIds.previewCharacterLabel,
                  container: true,
                  child: KeyedSubtree(
                    key: const ValueKey(SlotIds.previewCharacterLabel),
                    child: DayCharacter(
                      variant: dayCharacterVariantOf(preview.dayKind),
                      label: dayKindName(l10n, preview.dayKind),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),
                SentenceBlock(
                  variant: SentenceBlockVariant.card,
                  text: preview.fortune.head.text,
                  slotId: SlotIds.previewFortuneHead,
                ),
                if (tag != null) ...[
                  const SizedBox(height: Space.s12),
                  SentenceBlock(
                    variant: SentenceBlockVariant.body,
                    text: tag.text,
                    slotId: SlotIds.previewFortuneBody,
                  ),
                ],
                const SizedBox(height: Space.s24),
                ShareButton(
                  variant: ShareButtonVariant.soft,
                  label: l10n.shareLabel,
                  onPressed: () => _share(context),
                ),
                const SizedBox(height: Space.s16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 풀이를 계산하는 동안: [_PreviewBody]와 같은 배치(좌우 20, 위 24)에 `day-character` 뼈,
/// [Space.s16] 아래 총운 `sentence-block` `card` 뼈, [Space.s12] 아래 `body` 뼈(V66).
class _PreviewSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(Space.s20, Space.s24, Space.s20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DayCharacter.skeleton(),
        const SizedBox(height: Space.s16),
        SentenceBlock.skeleton(variant: SentenceBlockVariant.card, index: 2),
        const SizedBox(height: Space.s12),
        SentenceBlock.skeleton(variant: SentenceBlockVariant.body, index: 4),
      ],
    ),
  );
}

/// 미리보기를 이미 쓴 기기의 본문(D117 ②): 안내(`preview.used.notice`)와 입력한 정보의 읽기 전용
/// 목록(`preview.used.input`, 호칭, 생일, 태어난 시간, 성별, 출생지 기준).
///
/// 목록은 정보 수정(`profile-edit`)과 같은 `settings-row` 묶음 카드에 같은 항목 순서이고, 줄은
/// 누를 수 없어 화살표가 없습니다.
class _PreviewUsedBody extends StatelessWidget {
  const new({required this.draft, required this.deviceRegionIsKorea});

  /// 미리보기를 요청한 입력.
  final OnboardingDraft draft;

  /// 출생지 기준(D29). 한국 기기면 한국 기준이고 받아 둔 도시는 쓰지 않습니다.
  final bool deviceRegionIsKorea;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final calendar = draft.calendar;
    final date = draft.date;
    final time = draft.time;
    final gender = draft.gender;
    final city = deviceRegionIsKorea ? null : draft.city;
    final rows = [
      // 미리보기는 호칭까지 다 받은 입력으로만 요청하므로(`isCompleteFor`) 여기서 호칭은 늘 있습니다.
      // 그래서 빈 호칭의 대체 문구는 두지 않습니다.
      (l10n.previewUsedInputName, draft.honorific?.trim() ?? ''),
      if (calendar != null && date != null)
        (
          l10n.previewUsedInputBirth,
          _birthValue(
            l10n,
            calendar: calendar,
            isLeapMonth: draft.isLeapMonth,
            year: date.year,
            month: date.month,
            day: date.day,
          ),
        ),
      if (time != null) (l10n.previewUsedInputTime, _timeValue(l10n, time)),
      if (gender != null)
        (l10n.previewUsedInputGender, genderLabel(l10n, gender)),
      (
        l10n.previewUsedInputBirthplace,
        // 정보 수정의 출생지 줄과 같은 글자입니다(도시면 "도시, 나라").
        city == null ? l10n.profileEditBirthplaceKorea : birthCityLabel(city),
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.s20, Space.s24, Space.s20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: SlotIds.previewUsedNotice,
            container: true,
            child: Text(
              l10n.previewUsedNotice,
              key: const ValueKey(SlotIds.previewUsedNotice),
              style: tokens.typography.bodyUi.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: Space.s16),
          Semantics(
            identifier: SlotIds.previewUsedInput,
            container: true,
            child: SettingsGroup(
              key: const ValueKey(SlotIds.previewUsedInput),
              children: [
                for (final (label, value) in rows)
                  PreviewUsedInputRow(label: label, value: value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 생일 값 틀(계정 합치기 사주 줄과 같은 틀). 음력 윤달이면 윤달 틀입니다.
  ///
  /// 음력 날은 양력 달력에 없는 날일 수 있어 날 숫자를 그대로 씁니다([formatBirthDay]).
  static String _birthValue(
    AppLocalizations l10n, {
    required CalendarType calendar,
    required bool isLeapMonth,
    required int year,
    required int month,
    required int day,
  }) {
    final lunar = calendar == CalendarType.lunar;
    final calendarName = lunar ? l10n.calendarLunar : l10n.calendarSolar;
    final date = formatBirthDay(l10n.localeName, year, month, day);
    return lunar && isLeapMonth
        ? l10n.previewUsedInputBirthValueLeap(calendarName, date)
        : l10n.previewUsedInputBirthValue(calendarName, date);
  }

  /// 태어난 시간 값. 알면 그 언어의 시각, 모르면 "모름"입니다.
  static String _timeValue(AppLocalizations l10n, BirthTime time) {
    final value = time.value;
    if (time.status != BirthTimeStatusEnum.known || value == null) {
      return l10n.timeUnknownLabel;
    }
    return formatBirthClock(l10n.localeName, value);
  }
}

/// 입력 확인 목록의 읽기 전용 한 줄: `settings-row`의 줄 크기(높이 52 이상, 좌우 16)와 이름, 값
/// 글자(`body.ui`, 이름 `text.primary`, 값 `text.secondary`, 사이 8)를 따르되 누르는 자리와
/// 화살표가 없습니다.
///
/// 값은 오른쪽 끝에 붙고 줄 너비의 절반까지 쓰며 넘치면 값 쪽이 줄을 바꿉니다. 스크린리더는 항목
/// 이름 다음에 값을 이어 읽습니다(`preview.used.input` a11y).
class PreviewUsedInputRow extends StatelessWidget {
  /// 줄을 만듭니다.
  const new({required this.label, required this.value, super.key});

  /// 항목 이름.
  final String label;

  /// 입력한 값.
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.bodyUi;
    return Semantics(
      container: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SettingsRow.minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s16,
            vertical: Space.s12,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: style.copyWith(color: tokens.colors.textPrimary),
                  ),
                ),
                const SizedBox(width: Space.s8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: style.copyWith(color: tokens.colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
