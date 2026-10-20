import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
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
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';

/// 끝에서 이 줄 수 안쪽이 그려지면 다음 쪽을 받습니다.
const int _loadMoreThreshold = 3;

/// 일기 목록 본문(`diary-list`·`tag-diary` 공용): 달이 바뀌는 자리마다 달 머리, `diary-row`
/// 줄들, 끝 근처에서 다음 쪽 받기(A45).
///
/// [leading]은 목록 맨 위에 놓는 것(오프라인 배너, 태그 뜻 줄 등)입니다. 다음 쪽을 받는
/// 동안은 맨 아래에 skeleton 줄, 받지 못하면 다시 시도 버튼을 둡니다. 줄을 누르면 그날
/// `diary-view`, 태그 칩을 누르면 그 태그의 `tag-diary`입니다.
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
    final items = view.items;
    final entries = <Widget>[...leading];
    CalendarMonth? month;
    for (final (index, item) in items.indexed) {
      final date = CalendarDate.parse(item.date);
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
      entries.add(
        _DiaryPageRow(
          summary: item,
          date: date,
          isLast: index == items.length - 1 && !view.hasMore,
          onShown: index >= items.length - _loadMoreThreshold
              ? () => _loadMore(ref)
              : null,
        ),
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

/// 목록 한 줄: 그날 성격 배지(달 길흉 캐시, A46)와 대표 태그 칩을 채운 `diary-row`.
class _DiaryPageRow extends ConsumerStatefulWidget {
  const new({
    required this.summary,
    required this.date,
    required this.isLast,
    required this.onShown,
  });

  final DiarySummary summary;
  final CalendarDate date;
  final bool isLast;

  /// 처음 그려질 때 한 번 부릅니다(목록 끝 근처면 다음 쪽 받기).
  final VoidCallback? onShown;

  @override
  ConsumerState<_DiaryPageRow> createState() => _DiaryPageRowState();
}

class _DiaryPageRowState extends ConsumerState<_DiaryPageRow> {
  @override
  void initState() {
    super.initState();
    widget.onShown?.call();
  }

  @override
  void didUpdateWidget(_DiaryPageRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onShown == null) {
      widget.onShown?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = ref.watch(calendarDayProvider(widget.date));
    final names = ref.watch(glossaryProvider).value;
    final featured = widget.summary.featuredTags;
    final tag = featured.isEmpty ? null : featured.first;
    final tagName = tag == null ? null : names?.valueName('tag', tag.key);
    final kind = day.value?.dayKind;
    return DiaryRow(
      date: widget.date,
      excerpt: widget.summary.excerpt,
      character: kind == null ? null : dayCharacterVariantOf(kind),
      characterLabel: kind == null ? null : dayKindName(l10n, kind),
      characterPending: day.isLoading && !day.hasValue,
      tag: tag == null || tagName == null
          ? null
          : TagChip(
              name: tagName,
              variant: TagChipVariant.ofPolarity(tag.polarity),
              onTap: () => context.push<void>(taggedPathOf(tag.key)),
            ),
      isLast: widget.isLast,
      onTap: () =>
          context.push<void>(datedPathOf(ScreenIds.diaryView, widget.date)),
    );
  }
}
