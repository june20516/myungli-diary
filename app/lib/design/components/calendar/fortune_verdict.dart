import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 길흉판정(`fortune-verdict`): 위치 막대, 세 이름, 그 아래 내역 [ScoreRow] 줄.
///
/// 막대는 왼쪽 조심할 날에서 오른쪽 잘 풀리는 날로 이어지는 그라데이션이고, 합한 점
/// [score]를 -3~+3으로 잘라 `(score + 3) / 6` 자리에 흰 원 표시를 둡니다. 표시는 움직이지
/// 않습니다(처음부터 제자리, 동작 줄이기와 상관없이 같음). 숫자는 보이지 않고 내역의 크기는
/// [ScoreRow] 점으로만 보입니다.
///
/// [items]가 null(내역이 계약에 없음, `noBreakdown`)이거나 비어(`noItems`) 있으면 막대와 이름만
/// 그립니다. 내역은 더함 먼저, 뺌 다음이고 같은 부호 안은 받은 순서(server 순서)이며 점수 0
/// 항목은 그리지 않습니다. 이름([nameOf])이나 한자 글자표가 없는 항목은 줄을 그리지 않고
/// [onUnrenderable]로 id를 알립니다(A112). 이 콜백은 다시 그릴 때마다 호출될 수 있어
/// 부르는 쪽이 중복을 제거해야 합니다. 스크린리더는 묶음 하나로 "섹션 제목, 단계 이름"을
/// 읽고 이어서 줄을 읽습니다.
class FortuneVerdict extends StatelessWidget {
  /// 길흉판정 카드를 만듭니다.
  const new({
    required this.score,
    required this.nameOf,
    required this.meaningOf,
    this.items,
    this.onItemTap,
    this.onUnrenderable,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('fortune-verdict', {}, {
    'loading',
    'noBreakdown',
    'noItems',
  });

  /// 막대 높이. 계약 `fortune-verdict.parts.track.height`.
  static const double trackHeight = 4;

  /// 위치 표시 지름. 계약 `parts.marker.size`.
  static const double markerSize = 18;

  /// 위치 표시 테두리 굵기. 계약 `parts.marker.border.width`.
  static const double markerBorderWidth = 2;

  /// 막대가 나타내는 점수 범위의 끝(`marker.position.clamp`).
  static const int scoreLimit = 3;

  /// 막대 키.
  static const Key trackKey = ValueKey('fortune-verdict-track');

  /// 위치 표시 키.
  static const Key markerKey = ValueKey('fortune-verdict-marker');

  /// 합한 점.
  final int score;

  /// 항목 id → 이름(태그 글자). 모르면 null입니다.
  final String? Function(String id) nameOf;

  /// 항목 id → 짧은 뜻. 모르면 null이고 뜻 자리를 비웁니다.
  final String? Function(String id) meaningOf;

  /// 내역. null이면 내역이 계약에 없는 상태입니다.
  final List<ScoreItem>? items;

  /// 내역 줄의 태그를 눌렀을 때.
  final void Function(ScoreItem item)? onItemTap;

  /// 그릴 수 없어 건너뛴 항목 id(이름이나 글자표가 없음)를 알립니다. 다시 그릴 때마다
  /// 호출될 수 있으니 부르는 쪽이 중복을 제거합니다.
  final void Function(List<String> ids)? onUnrenderable;

  /// [score]의 막대 위 자리(0~1): `(clamp(score, -3, 3) + 3) / 6`.
  static double positionOf(int score) =>
      (score.clamp(-scoreLimit, scoreLimit) + scoreLimit) / (2 * scoreLimit);

  /// [items]를 내역 순서로: 점수 0을 빼고 더함 먼저, 뺌 다음, 같은 부호는 받은 순서.
  static List<ScoreItem> orderedItems(List<ScoreItem> items) => [
    ...items.where((item) => item.score > 0),
    ...items.where((item) => item.score < 0),
  ];

  /// 로딩 자리(`states.loading.skeleton`): 막대 자리 글줄 하나와 [ScoreRow] 뼈 두 줄.
  /// 세 이름은 UI 글자라 바로 그립니다.
  static Widget skeleton({int index = 0, bool animated = true}) => Builder(
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonTextLines(index: index, animated: animated, widthFactor: 1),
            _Names(l10n: l10n),
            const SizedBox(height: Space.s12),
            for (var i = 0; i < 2; i++) ...[
              const ListDivider(),
              ScoreRow.skeleton(index: index + 1 + i, animated: animated),
            ],
          ],
        ),
      );
    },
  );

  /// 단계 이름: -2 이하 조심할 날, -1~+1 무난한 날, +2 이상 잘 풀리는 날(달력 범례와 같은 낱말).
  static String levelNameOf(AppLocalizations l10n, int score) {
    if (score <= -2) return l10n.calendarLegendBodyCaution;
    if (score >= 2) return l10n.calendarLegendBodyGood;
    return l10n.calendarLegendBodyNeutral;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[];
    final skipped = <String>[];
    for (final item in orderedItems(items ?? const [])) {
      final name = nameOf(item.id);
      final glyph = HanjaGlyphs.forScoreItem(item.id);
      if (name == null || glyph == null) {
        skipped.add(item.id);
        continue;
      }
      rows
        ..add(const ListDivider())
        ..add(
          ScoreRow.verdict(
            glyph: glyph,
            name: name,
            meaning: meaningOf(item.id) ?? '',
            score: item.score,
            onTagTap: onItemTap == null ? null : () => onItemTap!(item),
          ),
        );
    }
    if (skipped.isNotEmpty) {
      final report = onUnrenderable;
      if (report != null) {
        // build 중 상태를 바꾸지 않도록 그린 뒤에 알립니다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          report(skipped);
        });
      }
    }
    return Semantics(
      container: true,
      label: [
        l10n.daySheetVerdictTitle,
        levelNameOf(l10n, score),
      ].join(l10n.a11yListSeparator),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(child: _Track(position: positionOf(score))),
            ExcludeSemantics(child: _Names(l10n: l10n)),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: Space.s12),
              ...rows,
            ],
          ],
        ),
      ),
    );
  }
}

/// `bg.base` 카드.
class _Card extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.colors.bgBase,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
    ),
    child: Padding(padding: const EdgeInsets.all(Space.s16), child: child),
  );
}

/// 그라데이션 막대와 위치 표시. 양끝을 표시 반지름만큼 들여 표시가 카드 밖으로 나가지 않습니다.
class _Track extends StatelessWidget {
  const new({required this.position});

  final double position;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const radius = FortuneVerdict.markerSize / 2;
    return SizedBox(
      height: FortuneVerdict.markerSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final span = constraints.maxWidth - FortuneVerdict.markerSize;
          return Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: radius),
                child: DecoratedBox(
                  key: FortuneVerdict.trackKey,
                  decoration: BoxDecoration(
                    gradient: tokens.gradients.verdictTrack,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(Radii.full),
                    ),
                  ),
                  child: const SizedBox(
                    height: FortuneVerdict.trackHeight,
                    width: double.infinity,
                  ),
                ),
              ),
              // 움직이지 않는 표시라 위치만 계산해 바로 놓습니다(동작 줄이기와 상관없음).
              Positioned.directional(
                textDirection: Directionality.of(context),
                start: span * position,
                top: 0,
                child: DecoratedBox(
                  key: FortuneVerdict.markerKey,
                  decoration: BoxDecoration(
                    color: tokens.colors.bgSheet,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.colors.actionPrimary,
                      width: FortuneVerdict.markerBorderWidth,
                    ),
                  ),
                  child: const SizedBox(
                    width: FortuneVerdict.markerSize,
                    height: FortuneVerdict.markerSize,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 막대 아래 세 이름(조심할 날, 무난한 날, 잘 풀리는 날).
class _Names extends StatelessWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.captionMd.copyWith(
      color: tokens.colors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: Space.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l10n.calendarLegendBodyCaution,
              textAlign: TextAlign.start,
              style: style,
            ),
          ),
          Expanded(
            child: Text(
              l10n.calendarLegendBodyNeutral,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          Expanded(
            child: Text(
              l10n.calendarLegendBodyGood,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
