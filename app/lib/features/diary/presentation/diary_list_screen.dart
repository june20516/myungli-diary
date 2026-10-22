import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/screen_breadcrumbs.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/input/month_date_picker.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/diary/application/diary_pages.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/model/diary_write_entry.dart';
import 'package:myungli_diary/features/diary/presentation/diary_page_list.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// IA `diary-list`가 직접 처리하는 상태.
const Set<String> diaryListHandledStates = {
  'loading',
  'empty',
  'error',
  'offline',
};

/// IA `diary-list`의 출구 대상.
const Set<String> diaryListExits = {
  ScreenIds.diaryView,
  ScreenIds.diaryEdit,
  ScreenIds.tagDiary,
};

const AppGlyph _calendarPlus = AppGlyph(
  light: PhosphorIconsLight.calendarPlus,
  regular: PhosphorIconsRegular.calendarPlus,
);

/// 일기 목록(탭 루트, `diary-list`): 쓴 일기를 날짜 내림차순으로 넘겨 보고, 날짜를 골라
/// 씁니다(D49, 미래 날짜는 고를 수 없음).
///
/// * 목록은 메모리에만 들고 있는 쪽 단위 목록입니다(A45). 화면에 들어올 때마다 처음 쪽부터
///   다시 묻고, 받는 동안에는 받아 둔 목록을 그대로 보입니다.
/// * 받는 중 skeleton(`loading`), 쓴 일기 없음(`empty`), 받지 못함(`error`), 다시 받기가
///   연결 오류로 실패하면 받아 둔 목록 위에 배너(`offline`)입니다.
/// * "날짜 골라 쓰기"는 앱 바 동작과 빈 화면 버튼이고, `date-picker` `calendar` 시트를
///   엽니다(A51). 고른 날에 일기가 있으면 `diary-view`, 없으면 `diary-edit`입니다.
class DiaryListScreen extends ConsumerStatefulWidget {
  /// diary-list 화면을 만듭니다.
  const new({super.key});

  /// 앱 바의 날짜 골라 쓰기 동작.
  static const Key pickDateKey = ValueKey('diary-list.pick-date');

  @override
  ConsumerState<DiaryListScreen> createState() => _DiaryListScreenState();
}

class _DiaryListScreenState extends ConsumerState<DiaryListScreen> {
  /// 화면 진입 듣기를 끝냅니다.
  late final void Function() _stopEntries;

  @override
  void initState() {
    super.initState();
    // 받아 둔 목록이 있으면 화면에 들어올 때(다른 탭·화면에서 돌아올 때 포함) 처음 쪽부터
    // 다시 묻습니다. 탭 셸은 화면 상태를 들고 있어 initState만으로는 돌아옴을 모릅니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _stopEntries = listenScreenEntered(
      ref.read(routerProvider),
      ScreenIds.diaryList,
      _refresh,
    );
  }

  @override
  void dispose() {
    _stopEntries();
    super.dispose();
  }

  void _refresh() {
    if (mounted && ref.read(diaryPagesProvider(null)).hasValue) {
      ref.invalidate(diaryPagesProvider(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = visibleDiaryPagesOf(ref.watch(diaryPagesProvider(null)));
    return Semantics(
      identifier: ScreenIds.diaryList,
      child: Scaffold(
        key: const ValueKey(ScreenIds.diaryList),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MyungliAppBar.tabRoot(
                title: l10n.diaryListBarTitle,
                titleIdentifier: SlotIds.diaryListBarTitle,
                actions: [
                  AppBarAction(
                    key: DiaryListScreen.pickDateKey,
                    icon: _calendarPlus,
                    semanticLabel: l10n.diaryListPickDateCta,
                    identifier: SlotIds.diaryListPickDateCta,
                    onPressed: () => unawaited(_pickDate()),
                  ),
                ],
              ),
              Expanded(
                child: ScreenStateView<DiaryPagesView>(
                  value: pages,
                  onRetry: () => ref.invalidate(diaryPagesProvider(null)),
                  skeleton: const DiaryPageListSkeleton(),
                  isEmpty: (view) => view.items.isEmpty,
                  empty: EmptyState(
                    body: l10n.diaryListEmptyBody,
                    identifier: SlotIds.diaryListEmptyBody,
                    action: PrimaryButton(
                      label: l10n.diaryListPickDateCta,
                      onPressed: () => unawaited(_pickDate()),
                    ),
                  ),
                  dataWithNotice: (view, notice) =>
                      DiaryPageList(tag: null, view: view, leading: [notice]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 날짜 시트를 열고(A51), 고른 날의 새 일기 쓰기로 갑니다(A67). 일기가 있는 날도 새
  /// 일기입니다(D83).
  Future<void> _pickDate() async {
    final date = await showMyungliSheet<CalendarDate>(
      context,
      size: SheetSize.half,
      semanticLabel: AppLocalizations.of(context).diaryListPickDateCta,
      builder: (_) => PickDateSheet(today: ref.read(todayProvider)),
    );
    if (date == null || !mounted) return;
    await context.push<void>(datedPathOf(ScreenIds.diaryEdit, date));
  }
}

/// 날짜 골라 쓰기 시트(`date-picker` `calendar`, A51): 보이는 달의 일기 쓴 날에 도장,
/// 미래 날짜는 막고, 아래 버튼을 누르면 고른 날을 돌려주며 닫힙니다. 고른 날 일기를 다
/// 채웠으면 버튼은 그 문구로 꺼집니다(D83 ②). 그날 일기를 받는 동안·받지 못하면 쓸 수 있는
/// 것으로 그리고, 저장 422가 막습니다(A69).
class PickDateSheet extends ConsumerStatefulWidget {
  /// [today]를 고른 채로 시트를 만듭니다.
  const new({required this.today, super.key});

  /// 오늘. 처음 고른 날이고 이 날 뒤는 고를 수 없습니다.
  final CalendarDate today;

  @override
  ConsumerState<PickDateSheet> createState() => _PickDateSheetState();
}

class _PickDateSheetState extends ConsumerState<PickDateSheet> {
  late CalendarMonth _month = CalendarMonth.of(widget.today);
  late CalendarDate _selected = widget.today;

  /// 시트가 열린 동안 고른 날들. 그날 일기 목록(autoDispose)을 붙잡아 같은 날로 돌아가도 다시
  /// 묻지 않게 합니다. 붙잡기(`listenManual`)는 시트가 닫히면 함께 풀립니다.
  final Set<CalendarDate> _kept = {};

  void _keep(CalendarDate date) {
    if (_kept.add(date)) {
      ref.listenManual(diariesOnProvider(date), (_, _) {});
    }
  }

  @override
  void initState() {
    super.initState();
    _keep(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final marked =
        ref.watch(diaryDatesProvider(_month)).value ?? const <CalendarDate>{};
    final dateLabel = DateFormat.MMMd(locale)
        .format(DateTime(_selected.year, _selected.month, _selected.day));
    final count = ref.watch(diariesOnProvider(_selected)).value?.length ?? 0;
    final full = diaryWriteEntryOf(count) == DiaryWriteEntry.full;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Space.s8),
      child: MonthDatePicker(
        month: _month,
        selected: _selected,
        today: widget.today,
        markedDates: marked,
        onSelect: (date) {
          _keep(date);
          setState(() => _selected = date);
        },
        onMonthChange: (month) => setState(() => _month = month),
        confirmLabel: full
            ? l10n.diaryListPickDateConfirmFull
            : l10n.diaryListPickDateConfirm(dateLabel),
        confirmIdentifier: SlotIds.diaryListPickDateConfirm,
        onConfirm: full ? null : () => Navigator.of(context).pop(_selected),
      ),
    );
  }
}
