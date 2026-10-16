import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/schedule_draft.dart';
import 'package:myungli_diary/features/schedule/model/schedule_gone.dart';

/// IA `event-edit`이 직접 처리하는 상태.
///
/// * `loading`: 그날 성격 한 줄을 기다리는 동안 그 자리만 skeleton입니다.
/// * `error`: 연결 오류가 아닌 저장 실패. toast를 띄우고 화면과 입력을 지킵니다.
/// * `offline`: 저장이 연결 오류로 실패하면 배너를 보입니다. 앱에 연결 상태를 미리 아는
///   provider가 없어 실패로 알고, 입력은 지키며 저장은 다시 누를 수 있습니다(D47②).
const Set<String> eventEditHandledStates = {'loading', 'error', 'offline'};

/// 제목 글자 수 상한(계약 `ScheduleInput.title`).
const int _titleMaxLength = 100;

/// 메모 글자 수 상한(계약 `ScheduleInput.memo`).
const int _memoMaxLength = 2000;

/// 시간 지정으로 처음 바꿀 때 휠이 시작하는 시각.
const String _defaultTime = '09:00';

/// `time-picker` `notify`의 분 간격.
const int _minuteStep = 5;

/// 일정 만들기·고치기·지우기(IA `event-edit`, D47·A34~A37·A41).
///
/// * `extra: Schedule`이면 그 일정을 고치고 지울 수 있습니다.
/// * 아니면 `?date=YYYY-MM-DD`(없거나 읽을 수 없으면 오늘)의 새 일정입니다.
///
/// 저장·삭제가 성공하면 화면을 닫고, 바뀐 날짜를 품은 일정 범위는 [ScheduleEditor]가 다시
/// 받습니다(달력 점 갱신). 일정이 이미 없으면(404) 목록을 다시 받은 뒤 닫고 일반 오류
/// toast를 띄웁니다(A41).
class EventEditScreen extends ConsumerWidget {
  /// event-edit 화면을 만듭니다.
  const new({super.key});

  /// 저장 버튼을 찾는 테스트용 키.
  static const Key saveKey = ValueKey('event-edit.save');

  /// 일정 지우기 버튼을 찾는 테스트용 키.
  static const Key deleteKey = ValueKey('event-edit.delete');

  /// 저장 중 날짜 휠을 막는 층을 찾는 테스트용 키.
  static const Key dateWheelsKey = ValueKey('event-edit.date-wheels');

  /// 저장 중 시각 휠을 막는 층을 찾는 테스트용 키.
  static const Key timeWheelsKey = ValueKey('event-edit.time-wheels');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final extra = routeState.extra;
    final original = extra is Schedule ? extra : null;
    final today = ref.read(todayProvider);
    final initialDate =
        _dateOf(routeState.uri.queryParameters[dateQuery]) ?? today;
    final saving = ref.watch(scheduleEditorProvider);
    // 저장·삭제 중에는 뒤로 가기(기기·app-bar 모두 이 route의 pop을 거침)를 막습니다.
    // 결과를 기다리는 동안 화면이 사라지면 실패를 알릴 곳이 없습니다.
    return PopScope(
      canPop: !saving,
      child: Semantics(
        identifier: ScreenIds.eventEdit,
        child: Scaffold(
          key: const ValueKey(ScreenIds.eventEdit),
          body: SafeArea(
            child: Column(
              children: [
                MyungliAppBar.inner(
                  title: AppLocalizations.of(context).eventEditBarTitle,
                  titleIdentifier: SlotIds.eventEditBarTitle,
                  // 스택 바닥(딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                  showBack: MyungliAppBar.canGoBack(context),
                ),
                Expanded(
                  child: _EventEditForm(
                    original: original,
                    initialDate: initialDate,
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

/// query 값을 날짜로 읽습니다. 없거나 형식·범위가 틀리면 null입니다.
CalendarDate? _dateOf(String? source) {
  if (source == null) return null;
  try {
    final date = CalendarDate.parse(source);
    return date.isSupported ? date : null;
  } on FormatException {
    return null;
  }
}

/// 'HH:MM'을 휠 값으로 바꿉니다. 분은 5분 아래로 맞춰 보입니다(A36).
TimeOfDay _wheelTimeOf(String hhmm) {
  final parts = hhmm.split(':');
  final minute = int.parse(parts[1]);
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: minute - minute % _minuteStep,
  );
}

/// 휠 값을 'HH:MM'으로 바꿉니다.
String _hhmmOf(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

BirthDateValue _pickerValueOf(CalendarDate date) => BirthDateValue(
  calendar: BirthCalendar.solar,
  year: date.year,
  month: date.month,
  day: date.day,
);

class _EventEditForm extends ConsumerStatefulWidget {
  const new({required this.original, required this.initialDate});

  /// 고치는 일정. 새 일정이면 null입니다.
  final Schedule? original;

  /// 새 일정의 날짜.
  final CalendarDate initialDate;

  @override
  ConsumerState<_EventEditForm> createState() => _EventEditFormState();
}

class _EventEditFormState extends ConsumerState<_EventEditForm> {
  late ScheduleDraft _draft = _initialDraft();

  /// 날짜 휠 값. 지원 범위 밖 날짜(1900-01-01~30)도 휠에는 그대로 둡니다.
  late BirthDateValue _dateValue = _pickerValueOf(_draft.date);

  late final TextEditingController _title = TextEditingController(
    text: _draft.title,
  );
  late final TextEditingController _memo = TextEditingController(
    text: _draft.memo,
  );

  /// 마지막 저장·삭제가 연결 오류로 실패했는지(IA `offline`).
  bool _offline = false;

  bool get _editing => widget.original != null;

  ScheduleDraft _initialDraft() {
    final original = widget.original;
    if (original != null) return ScheduleDraft.of(original);
    return ScheduleDraft(date: widget.initialDate, allDay: true, title: '');
  }

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _setDate(BirthDateValue value) {
    setState(() {
      _dateValue = value;
      if (value.isWithinSupportedRange) {
        _draft = _draft.copyWith(
          date: CalendarDate(value.year, value.month, value.day),
        );
      }
    });
  }

  void _setAllDay(bool allDay) {
    setState(() {
      var next = _draft.copyWith(allDay: allDay);
      // 시각이 없던 일정을 시간 지정으로 바꾸면 휠이 보이는 시각을 그대로 고른 것으로 봅니다.
      if (!allDay && next.time == null) next = next.withTime(_defaultTime);
      _draft = next;
    });
  }

  bool get _savable => _draft.isSavable && _dateValue.isWithinSupportedRange;

  Future<void> _save() async {
    if (!_savable) return;
    final editor = ref.read(scheduleEditorProvider.notifier);
    try {
      final saved = await editor.save(_draft, original: widget.original);
      // null은 처리 중에 다시 누른 것이라 무시합니다.
      if (saved == null || !mounted) return;
      _close();
    } on ScheduleGone {
      _closeGone();
    } on AppError catch (error) {
      if (!mounted) return;
      _showFailure(error, AppLocalizations.of(context).eventEditSaveFailed);
    }
  }

  Future<void> _delete() async {
    final original = widget.original;
    if (original == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMyungliDialog(
      context,
      variant: DialogVariant.destructive,
      title: l10n.eventEditDeleteConfirm,
      identifier: SlotIds.eventEditDeleteConfirm,
      confirm: l10n.eventEditDeleteConfirmDelete,
      cancel: l10n.eventEditDeleteConfirmCancel,
    );
    if (!confirmed || !mounted) return;
    try {
      final deleted = await ref
          .read(scheduleEditorProvider.notifier)
          .delete(original);
      if (!deleted || !mounted) return;
      _close();
    } on ScheduleGone {
      _closeGone();
    } on AppError catch (error) {
      if (!mounted) return;
      _showFailure(error, errorMessage(AppLocalizations.of(context), error));
    }
  }

  /// 연결 오류면 배너(offline), 그 밖이면 [message] toast(error)입니다. 입력은 그대로 둡니다.
  void _showFailure(AppError error, String message) {
    final offline = isConnectivityError(error);
    setState(() => _offline = offline);
    if (!offline) showMyungliToast(context, message);
  }

  /// 일정이 이미 없음(A41): 목록은 [ScheduleEditor]가 다시 받았으므로 닫고 알립니다.
  void _closeGone() {
    if (!mounted) return;
    showMyungliToast(context, AppLocalizations.of(context).errorUnexpected);
    _close();
  }

  /// 화면을 닫습니다. 스택 바닥(딥링크·복원)이면 달력 탭으로 갑니다.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(pathOf(ScreenIds.calendar));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final saving = ref.watch(scheduleEditorProvider);
    final labelStyle = tokens.typography.labelMd.copyWith(
      color: tokens.colors.textSecondary,
    );
    final time = _draft.time;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.s20,
              Space.s8,
              Space.s20,
              Space.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NoticeBanner(
                  variant: NoticeBannerVariant.offline,
                  message: l10n.eventEditOfflineNotice,
                  present: _offline,
                ),
                _CharacterHint(date: _draft.date),
                const SizedBox(height: Space.s24),
                MyungliTextField(
                  key: const ValueKey(SlotIds.eventEditTitleHint),
                  identifier: SlotIds.eventEditTitleHint,
                  label: l10n.eventEditTitleHint,
                  hint: l10n.eventEditTitleHint,
                  controller: _title,
                  maxLength: _titleMaxLength,
                  enabled: !saving,
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(title: value.trim()),
                  ),
                  // 완료는 키보드만 내립니다. 저장은 버튼으로만 합니다.
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: Space.s24),
                Text(l10n.eventEditDateLabel, style: labelStyle),
                const SizedBox(height: Space.s8),
                IgnorePointer(
                  key: EventEditScreen.dateWheelsKey,
                  ignoring: saving,
                  child: BirthDatePicker(
                    value: _dateValue,
                    onChanged: _setDate,
                    lunarAllowed: false,
                    calendarLabelSolar: l10n.calendarSolar,
                    calendarLabelLunar: l10n.calendarLunar,
                    leapMonthLabel: l10n.leapMonth,
                  ),
                ),
                const SizedBox(height: Space.s24),
                Text(l10n.eventEditTimeLabel, style: labelStyle),
                const SizedBox(height: Space.s8),
                Segmented<bool>(
                  label: l10n.eventEditTimeLabel,
                  items: [
                    SegmentedItem(true, l10n.eventEditAllDay),
                    SegmentedItem(false, l10n.eventEditTimed),
                  ],
                  selected: _draft.allDay,
                  onChanged: saving ? null : _setAllDay,
                ),
                if (!_draft.allDay && time != null) ...[
                  const SizedBox(height: Space.s12),
                  IgnorePointer(
                    key: EventEditScreen.timeWheelsKey,
                    ignoring: saving,
                    child: TimePicker(
                      variant: TimePickerVariant.notify,
                      value: _wheelTimeOf(time),
                      onChanged: (value) => setState(
                        () => _draft = _draft.withTime(_hhmmOf(value)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Space.s24),
                MyungliTextField(
                  key: const ValueKey(SlotIds.eventEditMemoHint),
                  identifier: SlotIds.eventEditMemoHint,
                  label: l10n.eventEditMemoHint,
                  hint: l10n.eventEditMemoHint,
                  controller: _memo,
                  maxLength: _memoMaxLength,
                  maxLines: MyungliTextField.maxLinesLimit,
                  enabled: !saving,
                  // 공백뿐인 메모는 메모 없음입니다(빈 문자열은 만들기에서 빠지고 고치기에서 지움).
                  onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(
                      memo: value.trim().isEmpty ? '' : value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.s20,
            Space.s8,
            Space.s20,
            Space.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                key: EventEditScreen.saveKey,
                label: l10n.eventEditSave,
                loading: saving,
                onPressed: _savable ? () => unawaited(_save()) : null,
              ),
              if (_editing) ...[
                const SizedBox(height: Space.s8),
                PrimaryButton(
                  key: EventEditScreen.deleteKey,
                  variant: PrimaryButtonVariant.quiet,
                  label: l10n.eventEditDelete,
                  onPressed: saving ? null : () => unawaited(_delete()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 그날 성격 한 줄(`event-edit.character.hint`). 달 길흉 캐시의 `characterReason`입니다.
///
/// 받는 동안은 그 자리만 skeleton(IA `loading`)이고, 받지 못하면 줄을 그리지 않습니다
/// (저장 실패가 아니므로 화면 오류가 아님). 용어 조각은 일반 글자입니다(V28: 이 화면에는
/// `term-token`이 없음).
class _CharacterHint extends ConsumerWidget {
  const new({required this.date});

  final CalendarDate date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final style = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
    );
    final month = ref.watch(calendarMonthProvider(CalendarMonth.of(date)));
    final iso = date.toIso();
    final Widget child;
    if (month.hasValue) {
      final reason = month.requireValue.days
          .where((day) => day.date == iso)
          .firstOrNull
          ?.characterReason;
      child = reason == null
          ? const SizedBox.shrink()
          : RenderedTextView(text: reason.text, style: style);
    } else if (month.hasError) {
      child = const SizedBox.shrink();
    } else {
      child = SkeletonBlock(lines: 1, lineStyle: style);
    }
    return Semantics(
      identifier: SlotIds.eventEditCharacterHint,
      container: true,
      child: KeyedSubtree(
        key: const ValueKey(SlotIds.eventEditCharacterHint),
        child: child,
      ),
    );
  }
}
