import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/birth_format.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/load_feedback.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/onboarding/model/time_step_edit.dart';
import 'package:myungli_diary/features/profile/application/profile_edit_controller.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// IA `profile-edit`의 출구 대상. 줄마다 그 입력 화면을 수정 모드(`?mode=edit`, A19)로 엽니다.
/// 저장 뒤 `my-saju`로 가는 것은 스택을 바꾸는 이동(`go`)이라 IA 출구가 아닙니다.
const Set<String> profileEditExits = {
  ScreenIds.onboardCall,
  ScreenIds.onboardBirth,
  ScreenIds.onboardTime,
  ScreenIds.onboardGender,
  ScreenIds.birthplace,
};

/// IA `profile-edit`이 직접 처리하는 상태.
const Set<String> profileEditHandledStates = {'error'};

/// 생일 글자. 양력은 그 언어의 날짜(예 "양력 1990년 5월 15일")이고, 음력은 같은 모양에 윤달이면
/// 뒤에 윤달 표시를 붙입니다(예 "음력 1990년 5월 15일 (윤5월)").
///
/// 음력 날은 양력 달력에 없는 날(2월 30일)일 수 있어 날짜 계산 없이 날 숫자를 그대로 씁니다.
String birthDateLabel(AppLocalizations l10n, BirthDateValue value) {
  final lunar = value.calendar == BirthCalendar.lunar;
  final date = formatBirthDay(
    l10n.localeName,
    value.year,
    value.month,
    value.day,
  );
  final calendar = lunar ? l10n.calendarLunar : l10n.calendarSolar;
  final leap = lunar && value.isLeapMonth
      ? ' (${l10n.datePickerLeapMonthValue(value.month)})'
      : '';
  return '$calendar $date$leap';
}

/// 태어난 시간 글자. 알면 그 언어의 시각(예 "오후 2:30"), 모르면 "모름"입니다.
String birthTimeLabel(AppLocalizations l10n, BirthTime time) {
  final value = time.value;
  if (time.status != BirthTimeStatusEnum.known || value == null) {
    return l10n.timeUnknownLabel;
  }
  return formatBirthClock(l10n.localeName, value);
}

/// 성별 글자.
String genderLabel(AppLocalizations l10n, BirthGenderEnum gender) =>
    switch (gender) {
      BirthGenderEnum.female => l10n.genderFemale,
      BirthGenderEnum.male => l10n.genderMale,
    };

/// 출생지 글자. 도시면 "도시, 나라", 한국 기준이면 그 문구(D29)입니다. 도시 이름을 모르면 null입니다.
String? birthplaceLabel(AppLocalizations l10n, BirthplaceValue place) {
  if (place.cityId == null) return l10n.profileEditBirthplaceKorea;
  final city = place.city;
  return city == null ? null : '${city.name}, ${city.countryName}';
}

/// [values]의 [field] 글자입니다. 모르는 값(도시 이름)은 빈 글자입니다.
String birthFieldLabel(
  AppLocalizations l10n,
  BirthField field,
  BirthValues values,
) => switch (field) {
  BirthField.date => birthDateLabel(l10n, values.date),
  BirthField.time => birthTimeLabel(l10n, values.time),
  BirthField.gender => genderLabel(l10n, values.gender),
  BirthField.place => birthplaceLabel(l10n, values.place) ?? '',
};

/// 확인 창 본문의 바뀌기 전·뒤 글자. 바뀐 항목만 `, `로 잇습니다(A62).
({String before, String after}) recalcChangeLabels(
  AppLocalizations l10n,
  List<BirthField> changes, {
  required BirthValues before,
  required BirthValues after,
}) => (
  before: changes.map((f) => birthFieldLabel(l10n, f, before)).join(', '),
  after: changes.map((f) => birthFieldLabel(l10n, f, after)).join(', '),
);

/// 정보 수정(`profile-edit`, 결정 A62).
///
/// 묶음 두 개(`settings-row` 값 줄): ① 호칭 ② 생일·태어난 시간·성별·출생지. ② 위에 다시 계산
/// 안내(`profile-edit.recalc.notice`), 아래에 저장 버튼이 있습니다.
///
/// * 줄 값은 프로필 사본(없으면 `getProfile`로 받음, #312)에 화면 안 변경을 더한 값입니다. 받는
///   동안 줄은 값 없이 비활성이고, 받지 못하면 오류 toast를 보이고 줄을 누르면 다시 받습니다.
/// * 줄을 누르면 그 입력 화면을 수정 모드로 엽니다(`extra` = 지금 값, 출생지는 검색이라 없음).
///   돌아온 값은 저장하지 않고 화면 안 변경으로 듭니다. 화면이 열리는 동안 다른 줄을 다시
///   눌러도 또 열지 않습니다.
/// * 호칭은 가벼운 변경이라 돌아오면 바로 저장합니다. 실패하면 오류 toast와 이전 값입니다.
/// * 무거운 항목이 바뀌면 저장 버튼이 켜지고, 누르면 확인 창(`profile-edit.recalc.confirm`,
///   첫 초점 취소)이 바뀐 항목만 `before → after`로 보입니다. 확정하면 저장하고 바뀌기 전
///   사주의 캐시를 지운 뒤 `my-saju`로 갑니다(`go`).
/// * 저장이 실패하면 `profile-edit:error`: 오류 배너(`notice-banner`)와 "다시 시도" 버튼이고,
///   바꾼 값과 이전 캐시는 그대로입니다. 다시 시도는 이미 확인한 변경을 다시 보냅니다.
/// * 열 때 `extra`가 [City]면(settings 출생지 안내) 출생지를 그 도시로 바꾼 채 엽니다.
class ProfileEditScreen extends ConsumerStatefulWidget {
  /// profile-edit 화면을 만듭니다.
  const new({super.key});

  /// 호칭 줄.
  static const Key callRowKey = ValueKey('profile-edit.row.call');

  /// 생일 줄.
  static const Key birthRowKey = ValueKey('profile-edit.row.birth');

  /// 태어난 시간 줄.
  static const Key timeRowKey = ValueKey('profile-edit.row.time');

  /// 성별 줄.
  static const Key genderRowKey = ValueKey('profile-edit.row.gender');

  /// 출생지 줄.
  static const Key placeRowKey = ValueKey('profile-edit.row.birthplace');

  /// 저장(실패 뒤에는 다시 시도) 버튼.
  static const Key saveKey = ValueKey('profile-edit.save');

  /// 저장 실패 배너(`profile-edit:error`).
  static const Key errorKey = ValueKey('profile-edit.error');

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen>
    with SingleOpenGuard<ProfileEditScreen> {
  /// 열 때 넘겨받은 출생 도시(settings 출생지 안내).
  City? _initialCity;
  bool _routeRead = false;

  /// 사라지는 동안에도 보일 마지막 오류 글자.
  String _bannerMessage = '';

  NotifierProvider<ProfileEditController, ProfileEditState> get _provider =>
      profileEditControllerProvider(_initialCity);

  ProfileEditController get _controller => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    // 프로필을 받지 못하면 이유를 알립니다(다시 받을 때마다 새 오류면 다시 알림).
    listenLoadErrorToast(ref, context, profileProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeRead) return;
    _routeRead = true;
    final extra = GoRouterState.of(context).extra;
    _initialCity = extra is City ? extra : null;
  }

  void _toast(AppError error) {
    if (!mounted) return;
    showMyungliToast(
      context,
      errorMessage(AppLocalizations.of(context), error),
    );
  }

  /// [screenId] 입력 화면을 수정 모드로 열고 돌아온 값을 [onValue]로 넘깁니다.
  Future<void> _openStep<T extends Object>(
    String screenId,
    void Function(T value) onValue, {
    Object? extra,
  }) async {
    final value = await context.push<T>(editModePathOf(screenId), extra: extra);
    if (value == null || !mounted) return;
    onValue(value);
  }

  Future<void> _editHonorific(Profile profile) => _openStep<String>(
    ScreenIds.onboardCall,
    extra: profile.honorific,
    (honorific) {
      if (honorific == profile.honorific) return;
      unawaited(
        _controller.saveHonorific(honorific).catchError((Object error) {
          _toast(error is AppError ? error : UnexpectedError(error));
        }),
      );
    },
  );

  Future<void> _save(
    Profile profile,
    BirthValues before,
    BirthValues after,
  ) async {
    final l10n = AppLocalizations.of(context);
    // 실패 뒤 다시 시도는 이미 확인한 같은 변경이라 다시 묻지 않습니다.
    if (ref.read(_provider).error == null) {
      final labels = recalcChangeLabels(
        l10n,
        after.changesFrom(before),
        before: before,
        after: after,
      );
      // 파괴적이지 않은 무거운 변경이라 일반 확인 창입니다(V41).
      final confirmed = await showMyungliDialog(
        context,
        variant: DialogVariant.confirm,
        title: l10n.profileEditRecalcConfirmTitle,
        body: l10n.profileEditRecalcConfirmBody(labels.before, labels.after),
        confirm: l10n.profileEditRecalcConfirmSave,
        cancel: l10n.profileEditRecalcConfirmCancel,
        identifier: SlotIds.profileEditRecalcConfirm,
      );
      if (!confirmed || !mounted) return;
    }
    final saved = await _controller.saveBirth(profile);
    if (!saved || !mounted) return;
    context.go(pathOf(ScreenIds.mySaju));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final state = ref.watch(_provider);
    final profileState = ref.watch(profileProvider);
    final profile = profileState.value;
    final profileFailed = profileState.failedWithoutValue;
    final before = profile == null ? null : BirthValues.of(profile);
    final after = before?.applying(state.edits);
    final changed = before != null && after!.changesFrom(before).isNotEmpty;
    final error = state.error;
    if (error != null) _bannerMessage = errorMessage(l10n, error);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    /// 줄 동작: 값이 있으면 [edit], 받지 못했으면 다시 받기, 받는 중·저장 중이면 비활성.
    VoidCallback? rowTap(
      Future<void> Function(Profile profile, BirthValues values) edit, {
      bool busy = false,
    }) {
      if (profile != null && after != null) {
        return state.savingBirth || busy
            ? null
            : () => guardOpen(() => edit(profile, after));
      }
      return profileFailed ? () => ref.invalidate(profileProvider) : null;
    }

    final saveLabel = error == null ? l10n.onboardingSave : l10n.actionRetry;
    VoidCallback? onSave;
    if (profile != null &&
        before != null &&
        after != null &&
        changed &&
        !state.savingBirth &&
        state.savingHonorific == null) {
      onSave = () => guardOpen(() => _save(profile, before, after));
    }

    return Semantics(
      identifier: ScreenIds.profileEdit,
      child: Scaffold(
        key: const ValueKey(ScreenIds.profileEdit),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.profileEditBarTitle,
                titleIdentifier: SlotIds.profileEditBarTitle,
                // 스택 바닥(딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.s20,
                    Space.s8,
                    Space.s20,
                    Space.s24,
                  ),
                  children: [
                    // 오류 배너의 변형은 명세에 오류용이 없어 연결 없음 변형을 씁니다(design #354에 요청).
                    NoticeBanner(
                      key: ProfileEditScreen.errorKey,
                      variant: NoticeBannerVariant.offline,
                      message: _bannerMessage,
                      present: error != null,
                    ),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: ProfileEditScreen.callRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.onboardCallBarTitle,
                          value: state.savingHonorific ?? profile?.honorific,
                          onTap: rowTap(
                            (profile, _) => _editHonorific(profile),
                            busy: state.savingHonorific != null,
                          ),
                        ),
                      ],
                    ),
                    // 다시 계산 안내는 맞는 배너 변형이 없어 묶음 위 캡션입니다(design #354).
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.s16,
                        0,
                        Space.s16,
                        Space.s8,
                      ),
                      child: Semantics(
                        identifier: SlotIds.profileEditRecalcNotice,
                        container: true,
                        child: Text(
                          l10n.profileEditRecalcNotice,
                          key: const ValueKey(SlotIds.profileEditRecalcNotice),
                          style: tokens.typography.captionMd.copyWith(
                            color: tokens.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: ProfileEditScreen.birthRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.onboardBirthBarTitle,
                          value: after == null
                              ? null
                              : birthDateLabel(l10n, after.date),
                          onTap: rowTap(
                            (_, values) => _openStep<BirthDateValue>(
                              ScreenIds.onboardBirth,
                              extra: values.date,
                              _controller.editDate,
                            ),
                          ),
                        ),
                        SettingsRow(
                          key: ProfileEditScreen.timeRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.onboardTimeBarTitle,
                          value: after == null
                              ? null
                              : birthTimeLabel(l10n, after.time),
                          onTap: rowTap(
                            // 시진 확인이 화면 안에서 바꾼 생일을 쓰도록 함께 넘깁니다(D58).
                            (_, values) => _openStep<BirthTime>(
                              ScreenIds.onboardTime,
                              extra: TimeStepEdit(
                                time: values.time,
                                date: values.date,
                              ),
                              _controller.editTime,
                            ),
                          ),
                        ),
                        SettingsRow(
                          key: ProfileEditScreen.genderRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.onboardGenderBarTitle,
                          value: after == null
                              ? null
                              : genderLabel(l10n, after.gender),
                          onTap: rowTap(
                            (_, values) => _openStep<BirthGenderEnum>(
                              ScreenIds.onboardGender,
                              extra: values.gender,
                              _controller.editGender,
                            ),
                          ),
                        ),
                        SettingsRow(
                          key: ProfileEditScreen.placeRowKey,
                          variant: SettingsRowVariant.value,
                          label: l10n.birthplaceBarTitle,
                          value: after == null
                              ? null
                              : birthplaceLabel(l10n, after.place),
                          onTap: rowTap(
                            // 사본의 출생지는 도시 id라 검색칸은 비어서 시작합니다.
                            (_, _) => _openStep<City>(
                              ScreenIds.birthplace,
                              _controller.editCity,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Space.s20,
                  Space.s8,
                  Space.s20,
                  Space.s16 + bottom,
                ),
                child: PrimaryButton(
                  key: ProfileEditScreen.saveKey,
                  label: saveLabel,
                  loading: state.savingBirth,
                  onPressed: onSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
