import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// [EventRow] 변형(`event-row` `variants`).
enum EventRowVariant {
  /// 오늘 화면 요약 한 줄.
  summary,

  /// 그날 시트의 일정 목록 한 줄.
  list,
}

/// `summary`의 상태 꼬리표(`tag.status` `values`: `in-progress`·`next`).
enum EventRowStatus {
  /// 진행 중.
  inProgress,

  /// 다음 일정.
  next,
}

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

/// `summary`를 한 줄로 둘 때 제목에 남겨야 하는 최소 자리(글자 수). 모자라면 두 줄로 내립니다.
///
/// 임시, design 확인 대기 #218. 글자 하나 폭을 글자 크기로 어림하므로 영어처럼 글자가
/// 좁은 언어에서는 실제로 들어가는 글자 수가 더 많습니다.
const int _summaryTitleMinChars = 4;

/// 일정 한 줄(`event-row`).
///
/// [EventRow.summary]는 오늘 화면 요약(상태 꼬리표·시각·제목·'외 N개' 또는 개수 문장 한 줄),
/// [EventRow.list]는 그날 시트 목록(시각 칸 58px·제목 두 줄·화살표·구분선)입니다.
/// 시각이 null이면 하루 종일 일정이고 '하루 종일' 글자는 이 컴포넌트가 ARB에서 고릅니다.
/// 눌림은 `press.ink`이고 [onTap]이 null이면 누를 수 없는 표시 줄입니다. 스크린리더는
/// "상태 시각 제목"(+ '외 N개') 한 덩어리로 읽습니다.
class EventRow extends StatelessWidget {
  /// 오늘 화면 요약 한 줄. [allPastSentence]가 있으면 그 문장 한 줄만 그립니다.
  ///
  /// [time]이 null이면 하루 종일 일정입니다. [moreCount]가 0보다 크면 '외 N개'를 붙입니다.
  const new summary({
    required this.status,
    required this.title,
    this.time,
    this.moreCount = 0,
    this.allPastSentence,
    this.onTap,
    this.identifier,
    super.key,
  }) : variant = EventRowVariant.summary,
       showDivider = false;

  /// 그날 시트 목록 한 줄. [time]은 'HH:mm'이고 null이면 하루 종일 일정입니다.
  ///
  /// [showDivider]가 true면 줄 아래에 1px 구분선을 긋습니다(마지막 줄은 쓰는 쪽이 끔).
  const new list({
    required this.time,
    required this.title,
    this.showDivider = true,
    this.onTap,
    this.identifier,
    super.key,
  }) : variant = EventRowVariant.list,
       status = null,
       moreCount = 0,
       allPastSentence = null;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'event-row',
    {'summary', 'list'},
    {'pressed'},
  );

  /// `list` 시각 칸 너비(`parts.timeColumn.width`).
  static const double timeColumnWidth = 58;

  /// `list` 시각 칸 안에서 시각 글자 뒤에 남기는 여백. 글자는 칸 너비에서 이만큼 뺀 자리에 들어갑니다.
  static const double timeColumnGap = Space.s8;

  /// 줄 최소 높이(`parts.row.minHeight`, `a11y.minTarget`).
  static const double minHeight = 48;

  /// `list` 구분선 두께(`parts.row.divider.width`).
  static const double dividerWidth = 1;

  /// `list` 시각 칸을 찾는 테스트용 키.
  static const Key timeColumnKey = ValueKey('event-row-time-column');

  /// 구분선 위 줄 내용을 찾는 테스트용 키.
  static const Key contentKey = ValueKey('event-row-content');

  /// `list` 구분선을 찾는 테스트용 키.
  static const Key dividerKey = ValueKey('event-row-divider');

  /// 변형.
  final EventRowVariant variant;

  /// `summary` 상태. null이면 꼬리표 없이 시각·제목만입니다.
  final EventRowStatus? status;

  /// 시각('HH:mm'). null이면 하루 종일입니다.
  final String? time;

  /// 일정 제목.
  final String title;

  /// 첫 일정 말고 더 있는 일정 수. 0이면 '외 N개'를 붙이지 않습니다.
  final int moreCount;

  /// 그날 일정이 모두 지났을 때의 개수 문장.
  final String? allPastSentence;

  /// `list` 아래 구분선을 그을지.
  final bool showDivider;

  /// 눌렀을 때. null이면 누를 수 없습니다.
  final VoidCallback? onTap;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  String? _statusLabel(AppLocalizations l10n) => switch (status) {
    EventRowStatus.inProgress => l10n.todayEventSummaryOngoing,
    EventRowStatus.next => l10n.todayEventSummaryNext,
    null => null,
  };

  String _timeText(AppLocalizations l10n) => time ?? l10n.eventRowAllDay;

  String? _moreText(AppLocalizations l10n) =>
      moreCount > 0 ? l10n.eventRowMore(moreCount) : null;

  /// 스크린리더 라벨: 개수 문장, 또는 라벨 틀(상태 시각 제목)에 구분자로 '외 N개'를 이은 것.
  ///
  /// 상태가 없는 줄은 틀 앞에 빈자리가 생기므로 다듬습니다.
  String _semanticLabel(AppLocalizations l10n) {
    final sentence = allPastSentence;
    if (sentence != null) return sentence;
    final label = l10n
        .eventRowLabel(_statusLabel(l10n) ?? '', _timeText(l10n), title)
        .trim();
    final more = _moreText(l10n);
    return more == null ? label : '$label${l10n.a11yListSeparator}$more';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = ConstrainedBox(
      key: contentKey,
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: switch (variant) {
          EventRowVariant.summary => _summary(context, l10n),
          EventRowVariant.list => _list(context, l10n),
        },
      ),
    );
    final label = _semanticLabel(l10n);
    if (!showDivider) return _pressable(context, label, content);
    // 구분선까지 한 덩어리로 눌리고 읽힙니다.
    return _pressable(
      context,
      label,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          ColoredBox(
            key: dividerKey,
            color: context.tokens.colors.line,
            child: const SizedBox(height: dividerWidth),
          ),
        ],
      ),
    );
  }

  Widget _pressable(BuildContext context, String label, Widget content) {
    final onTap = this.onTap;
    if (onTap == null) {
      return Semantics(
        container: true,
        identifier: identifier,
        label: label,
        child: ExcludeSemantics(child: content),
      );
    }
    return PressInkTarget(
      semanticLabel: label,
      identifier: identifier,
      onTap: onTap,
      inkColor: context.tokens.colors.textPrimary,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.sm)),
      child: content,
    );
  }

  Widget _summary(BuildContext context, AppLocalizations l10n) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final type = tokens.typography;
    final secondaryCaption = type.captionLg.copyWith(
      color: colors.textSecondary,
    );
    final sentence = allPastSentence;
    if (sentence != null) return Text(sentence, style: secondaryCaption);

    final statusLabel = _statusLabel(l10n);
    final timeText = _timeText(l10n);
    final moreText = _moreText(l10n);
    final timeStyle = type.bodyUi.copyWith(
      color: colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final lead = [
      if (statusLabel != null) StatusTag(statusLabel),
      Text(timeText, style: timeStyle),
    ];
    // 제목만 줄어들고 '외 N개'는 제목 바로 뒤에 붙어 잘리지 않습니다.
    final tail = [
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.bodyUi.copyWith(color: colors.textPrimary),
        ),
      ),
      if (moreText != null) Text(moreText, style: secondaryCaption),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        double width(String text, TextStyle style) =>
            _textWidth(context, text, style);
        final fixed = [
          if (statusLabel != null)
            width(statusLabel, type.labelMd) + StatusTag.padding.horizontal,
          width(timeText, timeStyle),
          if (moreText != null) width(moreText, secondaryCaption),
        ];
        final gaps = fixed.length * Space.s8;
        final titleMinWidth =
            scaler.scale(type.bodyUi.fontSize!) * _summaryTitleMinChars;
        final fitsOneLine =
            fixed.fold<double>(0, (sum, w) => sum + w) + gaps + titleMinWidth <=
            constraints.maxWidth;
        if (fitsOneLine) {
          return Row(spacing: Space.s8, children: [...lead, ...tail]);
        }
        // 큰 글자에서 제목 자리가 모자라면 상태·시각 / 제목·외 N개 두 줄로 내립니다.
        // 좁은 폭에서 상태·시각도 한 줄에 못 들어가면 시각이 다음 줄로 넘어갑니다.
        // 임시, design 확인 대기 #218.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.s4,
          children: [
            Wrap(
              spacing: Space.s8,
              runSpacing: Space.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: lead,
            ),
            Row(spacing: Space.s8, children: tail),
          ],
        );
      },
    );
  }

  /// [context]의 글자 배율·방향으로 그린 [text] 한 줄의 너비.
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _list(BuildContext context, AppLocalizations l10n) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final type = tokens.typography;
    final timeText = _timeText(l10n);
    final timeStyle = type.numericTable.copyWith(color: colors.textSecondary);
    final titleAndChevron = Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.bodyUi.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(width: Space.s8),
        AppIcon(
          _caretRight,
          size: AppIconSize.inline,
          color: colors.textSecondary,
        ),
      ],
    );
    // 시각 글자는 줄이지 않습니다. 배율 그대로 칸에 들어가면 58 고정 칸(하루 종일도
    // 같은 폭), 들어가지 않으면 시각 / 제목·화살표 두 줄로 내립니다. 판정은 칸 폭(고정값)과
    // 글자 폭만 보므로 부모 제약이 필요 없습니다.
    // 큰 글자 처리는 임시, design 확인 대기 #218.
    final timeFits =
        _textWidth(context, timeText, timeStyle) <=
        timeColumnWidth - timeColumnGap;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s8),
      child: timeFits
          ? Row(
              children: [
                SizedBox(
                  key: timeColumnKey,
                  width: timeColumnWidth,
                  child: Text(timeText, maxLines: 1, style: timeStyle),
                ),
                Expanded(child: titleAndChevron),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.s4,
              children: [
                Text(timeText, key: timeColumnKey, style: timeStyle),
                titleAndChevron,
              ],
            ),
    );
  }
}

/// 그날 일정이 없을 때의 목록 자리(`event-row` `list` `parts.empty`): 빈 문장 + `quiet` 버튼.
class EventRowListEmpty extends StatelessWidget {
  /// 빈 목록 자리를 만듭니다.
  ///
  /// [messageIdentifier]·[addIdentifier]는 IA 슬롯 id(예: `day-sheet.event.empty`·
  /// `day-sheet.event.add`)입니다.
  const new({
    required this.message,
    required this.addLabel,
    required this.onAdd,
    this.messageIdentifier,
    this.addIdentifier,
    super.key,
  });

  /// 빈 문장.
  final String message;

  /// 일정 추가 버튼 글자.
  final String addLabel;

  /// 일정 추가를 눌렀을 때.
  final VoidCallback onAdd;

  /// 빈 문장의 IA 슬롯 id.
  final String? messageIdentifier;

  /// 일정 추가 버튼의 IA 슬롯 id.
  final String? addIdentifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final messageIdentifier = this.messageIdentifier;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s4,
      children: [
        Semantics(
          identifier: messageIdentifier,
          child: Text(
            message,
            key: messageIdentifier == null
                ? null
                : ValueKey<String>(messageIdentifier),
            textAlign: TextAlign.center,
            style: tokens.typography.captionLg.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ),
        PrimaryButton(
          label: addLabel,
          onPressed: onAdd,
          variant: PrimaryButtonVariant.quiet,
          identifier: addIdentifier,
        ),
      ],
    );
  }
}
