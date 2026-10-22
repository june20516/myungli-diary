import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/app/router/diary_entry_data.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/day_kind_names.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_pages.dart';
import 'package:myungli_diary/features/diary/model/diary_day_groups.dart';
import 'package:myungli_diary/features/diary/presentation/diary_tag_chips.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// 끝에서 이 줄 수 안쪽이 그려지면 다음 쪽을 받습니다.
const int _loadMoreThreshold = 3;

/// 일기 목록 본문(`diary-list`·`tag-diary` 공용): 달이 바뀌는 자리마다 달 머리, 날짜마다
/// `diary-row` 한 줄(두 편 이상이면 묶음 카드, A72), 끝 근처에서 다음 쪽 받기(A45).
///
/// 날짜가 같은 이웃은 한 묶음이고([groupDiariesByDate]), 받은 쪽을 이어 붙인 목록에서 묶으므로
/// 한 날짜가 두 쪽에 나뉘어도 다음 쪽을 받은 뒤 같은 카드가 커집니다.
///
/// [leading]은 목록 맨 위에 놓는 것(오프라인 배너, 태그 뜻 줄 등)입니다. 다음 쪽을 받는
/// 동안은 맨 아래에 skeleton 줄, 받지 못하면 다시 시도 버튼을 둡니다. 줄을 누르면 그 일기의
/// `diary-view`, 태그 칩을 누르면 그 태그의 `tag-diary`입니다. 목록의 태그([tag])와 같은
/// 칩은 같은 화면을 다시 쌓지 않도록 누를 수 없는 표시입니다.
class DiaryPageList extends ConsumerWidget {
  /// [view] 목록을 그립니다. [tag]는 [diaryPagesProvider]의 family 값입니다.
  const new({
    required this.tag,
    required this.view,
    this.leading = const [],
    super.key,
  });

  /// 목록의 태그(null이면 모든 일기).
  final String? tag;

  /// 받아 둔 목록.
  final DiaryPagesView view;

  /// 목록 맨 위에 놓는 위젯들.
  final List<Widget> leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final groups = groupDiariesByDate(view.items);
    final entries = <Widget>[...leading];
    CalendarMonth? month;
    for (final (index, group) in groups.indexed) {
      final date = CalendarDate.parse(group.first.date);
      final itemMonth = CalendarMonth.of(date);
      if (itemMonth != month) {
        month = itemMonth;
        entries.add(
          Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : Space.s12,
              bottom: Space.s12,
            ),
            child: DiaryMonthHeader(
              label: calendarMonthTitle(locale, itemMonth),
            ),
          ),
        );
      }
      final row = DiaryDayRow(
        summaries: group,
        listTag: tag,
        isLast: index == groups.length - 1 && !view.hasMore,
      );
      entries.add(
        index >= groups.length - _loadMoreThreshold
            ? _OnShown(
                // 다음 쪽이 끝 묶음에 같은 날 일기만 더하면 묶음 수가 그대로여서, 편수를 key에
                // 넣어 커질 때마다 다시 다음 쪽을 묻습니다.
                key: ValueKey('${group.first.id}:${group.length}'),
                onShown: () => _loadMore(ref),
                child: row,
              )
            : row,
      );
    }
    if (view.loadingMore) {
      entries.add(const DiaryRowSkeleton(key: ValueKey('diary-list.more')));
    } else if (view.moreError != null) {
      entries.add(
        PrimaryButton(
          variant: PrimaryButtonVariant.quiet,
          label: l10n.actionRetry,
          onPressed: () => _loadMore(ref),
        ),
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom + Space.s32;
    return ListView(
      padding: EdgeInsets.fromLTRB(Space.s20, Space.s8, Space.s20, bottom),
      children: entries,
    );
  }

  void _loadMore(WidgetRef ref) {
    // 그리는 중에는 provider를 바꿀 수 없어 다음 프레임에 묻습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(diaryPagesProvider(tag).notifier).loadMore());
    });
  }
}

/// 첫 쪽을 받는 동안의 목록 skeleton(`diary-row` 모양 세 줄).
class DiaryPageListSkeleton extends StatelessWidget {
  /// skeleton을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(Space.s20, Space.s8, Space.s20, 0),
    child: Column(
      children: [
        DiaryRowSkeleton(),
        DiaryRowSkeleton(index: 2),
        DiaryRowSkeleton(index: 4),
      ],
    ),
  );
}

/// 한 날짜의 일기 줄: 한 편이면 [DiarySummaryRow], 두 편 이상이면 같은 날 묶음 카드
/// ([DiaryDayGroup], A72)입니다. 배지와 태그는 날짜에 붙어 그날 일기 모두에 같습니다(D83 ①).
///
/// [summaries]는 같은 날짜의 일기들(server 순서, 한 편 이상)입니다.
class DiaryDayRow extends ConsumerWidget {
  /// [summaries] 날짜의 줄을 만듭니다.
  const new({
    required this.summaries,
    this.isLast = false,
    this.listTag,
    super.key,
  }) : assert(summaries.length > 0, '일기가 한 편 이상이어야 합니다.');

  /// 같은 날짜의 일기들(작성 순).
  final List<DiarySummary> summaries;

  /// 묶음의 마지막 줄인지(아래 흐름 줄 없음).
  final bool isLast;

  /// 이 줄이 놓인 목록의 태그(태그 모아보기). 그 밖은 null입니다.
  final String? listTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (summaries.length == 1) {
      return DiarySummaryRow(
        summary: summaries.first,
        isLast: isLast,
        listTag: listTag,
      );
    }
    final l10n = AppLocalizations.of(context);
    final date = CalendarDate.parse(summaries.first.date);
    final day = ref.watch(calendarDayProvider(date));
    final kind = day.value?.dayKind;
    return DiaryDayGroup(
      date: date,
      entries: diaryEntriesDataOf(context, summaries),
      character: kind == null ? null : dayCharacterVariantOf(kind),
      characterLabel: kind == null ? null : dayKindName(l10n, kind),
      characterPending: day.isLoading && !day.hasValue,
      tag: _featuredTagChip(context, ref, summaries.first, listTag),
      isLast: isLast,
    );
  }
}

/// [summary]의 대표 태그 칩(없으면 null). [listTag]와 같은 태그는 누를 수 없는 표시입니다.
TagChip? _featuredTagChip(
  BuildContext context,
  WidgetRef ref,
  DiarySummary summary,
  String? listTag,
) {
  final featured = summary.featuredTags;
  if (featured.isEmpty) {
    return null;
  }
  return diaryTagChipOf(
    context,
    ref.watch(glossaryProvider).value,
    featured.first,
    linked: featured.first.key != listTag,
  );
}

/// 일기 한 편의 줄: 그날 성격 배지(달 길흉 캐시, A46)와 대표 태그 칩을 채운 `diary-row`.
///
/// 일기 목록·태그 모아보기가 같은 날 한 편일 때 씁니다. 누르면 그 일기의 `diary-view`(A67)이고,
/// 대표 태그 칩을 누르면 그 태그의 `tag-diary`입니다. 목록의 태그([listTag])와 같은 칩은 같은
/// 화면을 다시 쌓지 않도록 누를 수 없는 표시입니다.
class DiarySummaryRow extends ConsumerWidget {
  /// [summary] 일기의 줄을 만듭니다.
  const new({
    required this.summary,
    this.isLast = false,
    this.listTag,
    super.key,
  });

  /// 일기 요약.
  final DiarySummary summary;

  /// 묶음의 마지막 줄인지(아래 구분선 없음).
  final bool isLast;

  /// 이 줄이 놓인 목록의 태그(태그 모아보기). 그 밖은 null입니다.
  final String? listTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final date = CalendarDate.parse(summary.date);
    final day = ref.watch(calendarDayProvider(date));
    final kind = day.value?.dayKind;
    return DiaryRow(
      date: date,
      excerpt: summary.excerpt,
      character: kind == null ? null : dayCharacterVariantOf(kind),
      characterLabel: kind == null ? null : dayKindName(l10n, kind),
      characterPending: day.isLoading && !day.hasValue,
      tag: _featuredTagChip(context, ref, summary, listTag),
      isLast: isLast,
      onTap: () =>
          context.push<void>(diaryPathOf(ScreenIds.diaryView, summary.id)),
    );
  }
}

/// [onShown]을 State가 생길 때 한 번 부릅니다. 목록 끝 근처 줄만 이것으로 감싸므로, 쪽이 늘어
/// 어떤 줄이 새로 끝 근처가 되면 감싸기가 새로 생겨(새 State) 다시 부르고, 계속 감싸인 줄은
/// 다시 부르지 않습니다. 목록 끝 근처 줄이 다음 쪽 받기를 알립니다.
class _OnShown extends StatefulWidget {
  const new({required this.onShown, required this.child, super.key});

  final VoidCallback onShown;
  final Widget child;

  @override
  State<_OnShown> createState() => _OnShownState();
}

class _OnShownState extends State<_OnShown> {
  @override
  void initState() {
    super.initState();
    widget.onShown();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
