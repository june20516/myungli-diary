import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/api/gen/model/merge_summary.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/elements/breathing.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 계정 합치기의 가져올 기록·구매 상자(컴포넌트 아님, design spec §3.2 ③).
///
/// `bg.sheet` 상자에 머리 한 줄과 이름·값 줄입니다. 줄 순서는 일기 편수 → 일정 개수 → 광고
/// 제거 남은 기간이고, 일기·일정은 0이어도 보이며 광고 제거 줄은 남은 기간이 있을 때만 있습니다.
/// [summary]가 null이면 요약을 받는 중이라 같은 크기의 빈 상자가 숨쉽니다(IA
/// `account-merge:loading`).
class MergeSummaryBox extends StatelessWidget {
  /// 요약 [summary]로 상자를 만듭니다. null이면 불러오는 중입니다.
  const new({required this.summary, this.animated = true, super.key});

  /// 불러오는 중 빈 상자를 찾는 테스트용 키.
  static const Key loadingKey = ValueKey('account-merge.summary.loading');

  /// 요약. null이면 불러오는 중.
  final MergeSummary? summary;

  /// false면 숨쉬기를 정지 상태로 그립니다(golden).
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    if (summary == null) {
      return Semantics(
        role: SemanticsRole.loadingSpinner,
        label: AppLocalizations.of(context).skeletonLabel,
        child: ExcludeSemantics(
          child: Breathing(
            key: loadingKey,
            animated: animated,
            child: const _Frame(child: _LoadingLines()),
          ),
        ),
      );
    }
    final l10n = AppLocalizations.of(context);
    final adFreeDays = summary.addedDays.adFree;
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s8,
        children: [
          _Head(l10n.accountMergeSummaryHead),
          _Row(
            name: l10n.accountMergeSummaryDiary,
            value: l10n.accountMergeSummaryDiaryCount(summary.diaries),
          ),
          _Row(
            name: l10n.accountMergeSummaryEvent,
            value: l10n.accountMergeSummaryEventCount(summary.schedules),
          ),
          if (adFreeDays > 0)
            _Row(
              name: l10n.accountMergeSummaryAdFree,
              value: l10n.accountMergeSummaryAdFreeDays(adFreeDays),
            ),
        ],
      ),
    );
  }
}

/// `bg.sheet`·`radius.md`·안쪽 `space.16` 상자.
class _Frame extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.colors.bgSheet,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
    ),
    child: Padding(padding: const EdgeInsets.all(Space.s16), child: child),
  );
}

class _Head extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      text,
      style: tokens.typography.captionMd.copyWith(
        color: tokens.colors.textSecondary,
      ),
    );
  }
}

/// 왼쪽 이름, 오른쪽 값(고정폭 숫자) 한 줄. 스크린리더는 한 줄로 읽습니다.
class _Row extends StatelessWidget {
  const new({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.bodyUi;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              name,
              style: style.copyWith(color: tokens.colors.textSecondary),
            ),
          ),
          const SizedBox(width: Space.s12),
          Text(
            value,
            style: style.copyWith(
              color: tokens.colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 불러오는 중의 글줄 자리. skeleton과 같이 그 줄 글자 높이의 60%입니다.
class _LoadingLines extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final typography = tokens.typography;
    final scaler = MediaQuery.textScalerOf(context);

    Widget line(TextStyle style, double widthFactor) {
      final lineHeight =
          scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.5);
      return SizedBox(
        height: lineHeight,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.skeletonBone,
                borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
              ),
              child: SizedBox(height: lineHeight * 0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s8,
      children: [
        line(typography.captionMd, 0.3),
        line(typography.bodyUi, 1),
        line(typography.bodyUi, 1),
      ],
    );
  }
}
