import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/text/keep_all.dart';

/// `term` 조각을 그리는 방식(결정 V28).
enum TermStyle {
  /// `term-token` `inline` 칩. 누르면 `onTerm`에 `term` 값을 넘깁니다.
  chip,

  /// 일반 글자. 누를 수 없습니다.
  plain,
}

/// server가 렌더한 문장 조각 배열(`RenderedText.segments`)을 그대로 그립니다.
///
/// app은 문장을 고르거나 조사를 붙이지 않습니다. 조각을 순서대로 이어 하나의
/// [Text.rich]로 그려 줄바꿈이 문장 전체에서 자연스럽게 일어나게 하고, 조각 경계에
/// 공백이나 줄바꿈을 넣지 않습니다(결정 V28).
///
/// [termStyle]이 [TermStyle.chip]이면 `term`이 있는 조각을 `term-token` `inline`으로
/// 그리고 누르면 [onTerm]에 `term` 값을 넘깁니다. 기본 [TermStyle.plain]이면 `term`
/// 조각도 일반 글자입니다. 칩은 IA에 `term-token`이 있는 화면에서만 씁니다(V28,
/// `SentenceBlock`이 정합니다). 공유 이미지와 `diary-row` 안은 항상 일반 글자입니다.
///
/// 한국어는 어절 단위로만 줄을 바꿉니다(`keep-all`, [applyKeepAll]). 스크린리더 라벨과
/// [onTerm]에 넘기는 값은 원문입니다.
///
/// 줄바꿈: 용어 칩은 한 덩어리로 줄이 바뀝니다. 한국어·영어는 공백 없이 붙은 앞뒤
/// 글자(조사)까지 같은 덩어리에 묶고, 일본어는 용어 앞뒤에서만 글자 단위로 끊습니다.
class RenderedTextView extends StatelessWidget {
  /// 조각 배열을 그립니다.
  const new({
    required this.text,
    required this.style,
    this.termStyle = TermStyle.plain,
    this.onTerm,
    this.trailing,
    this.hideTextSemantics = false,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  }) : assert(
         termStyle == TermStyle.plain || onTerm != null,
         '칩으로 그리려면 onTerm을 줘야 합니다.',
       );

  /// 조각 배열. 비어 있으면 아무것도 그리지 않습니다.
  final RenderedText text;

  /// 문장 글자 스타일(글자색 포함). 조각 모두와 용어 칩의 바탕 스타일입니다.
  final TextStyle style;

  /// `term` 조각을 그리는 방식.
  final TermStyle termStyle;

  /// 칩을 눌렀을 때 `term` 값을 받습니다. [TermStyle.chip]이면 필요합니다.
  final ValueChanged<String>? onTerm;

  /// 문장 끝에 붙는 위젯(`depth-link` `inline-end`). 줄 끝에 다 들어가지 않으면
  /// 통째로 다음 줄로 넘어갑니다.
  final Widget? trailing;

  /// true면 글자는 스크린리더에 읽히지 않고, 끼운 위젯([trailing]·용어 칩)만 자기 노드로
  /// 초점을 받습니다. 바깥에서 글자를 합친 라벨로 이미 읽을 때 중복 낭독을 막습니다.
  final bool hideTextSemantics;

  /// 최대 줄 수. 일기 목록 미리보기가 씁니다.
  final int? maxLines;

  /// 넘친 글자 처리.
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final segments = _mergePlain(
      text.segments.where((s) => s.text.isNotEmpty).toList(),
    );
    if (segments.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    final glueParticles = _glueParticles(locale);
    final children = <InlineSpan>[
      for (var i = 0; i < segments.length; i++)
        ..._spansFor(segments, i, glueParticles, locale),
      if (trailing != null) ...[
        // 링크 앞 틈은 줄바꿈 없는 공백(U+00A0)과 결합자(U+2060)라
        // 마지막 낱말과 링크가 함께 넘어갑니다.
        const TextSpan(text: '\u00A0\u2060'),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: trailing!,
        ),
      ],
    ];
    return Text.rich(
      TextSpan(
        style: style,
        children: hideTextSemantics
            ? children.map(_silenced).toList()
            : children,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// [span]의 글자를 읽지 않게(`semanticsLabel: ''`) 다시 만듭니다. 위젯 조각은 그대로입니다.
  static InlineSpan _silenced(InlineSpan span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      children: span.children?.map(_silenced).toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      locale: span.locale,
      spellOut: span.spellOut,
      semanticsLabel: '',
    );
  }

  /// 칩이 아닌 조각이 이어지면 하나로 합칩니다. 어절이 조각 경계에 걸려도 keep-all이
  /// 경계를 넘어 적용됩니다.
  List<Segment> _mergePlain(List<Segment> segments) {
    final merged = <Segment>[];
    for (final segment in segments) {
      if (merged.isNotEmpty && !_isChip(merged.last) && !_isChip(segment)) {
        merged[merged.length - 1] = Segment(
          text: merged.last.text + segment.text,
        );
      } else {
        merged.add(segment);
      }
    }
    return merged;
  }

  /// 조각 [index]를 그릴 span들. 앞뒤 조각의 붙은 글자를 용어가 가져가면 그만큼 뺍니다.
  List<InlineSpan> _spansFor(
    List<Segment> segments,
    int index,
    bool glueParticles,
    Locale locale,
  ) {
    final segment = segments[index];
    final term = segment.term;
    final onTerm = this.onTerm;
    if (term != null && onTerm != null && termStyle == TermStyle.chip) {
      final before = glueParticles ? _attachedBefore(segments, index) : '';
      final after = glueParticles ? _attachedAfter(segments, index) : '';
      return [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: TermToken(
            label: segment.text,
            variant: TermTokenVariant.inline,
            textStyle: style,
            before: before.isEmpty ? null : before,
            after: after.isEmpty ? null : after,
            onTap: () => onTerm(term),
          ),
        ),
      ];
    }
    final value = segment.text;
    final start = glueParticles && _takesTail(segments, index - 1)
        ? _leadingGlue(value).length
        : 0;
    final end = glueParticles && _takesHead(segments, index + 1)
        ? value.length - _trailingGlue(value.substring(start)).length
        : value.length;
    if (start >= end) return const [];
    final shown = value.substring(start, end);
    return keepAllSpans(locale, shown);
  }

  /// [index]가 일반 조각이고 바로 앞 용어에 붙은 글자를 내줘야 하는지.
  bool _takesTail(List<Segment> segments, int index) =>
      index >= 0 && _isChip(segments[index]);

  /// [index]가 일반 조각이고 바로 뒤 용어에 붙은 글자를 내줘야 하는지.
  bool _takesHead(List<Segment> segments, int index) =>
      index < segments.length && _isChip(segments[index]);

  bool _isChip(Segment s) =>
      s.term != null && onTerm != null && termStyle == TermStyle.chip;

  /// 용어 앞 일반 조각 끝의 공백 없는 글자.
  String _attachedBefore(List<Segment> segments, int index) {
    if (index == 0 || segments[index - 1].term != null) return '';
    final previous = segments[index - 1].text;
    // 앞 조각 앞머리를 앞쪽 용어가 먼저 가져갔다면 남은 부분에서만 가져옵니다.
    final start = index >= 2 && _isChip(segments[index - 2])
        ? _leadingGlue(previous).length
        : 0;
    return _trailingGlue(previous.substring(start));
  }

  /// 용어 뒤 일반 조각 앞머리의 공백 없는 글자.
  String _attachedAfter(List<Segment> segments, int index) {
    if (index + 1 >= segments.length || segments[index + 1].term != null) {
      return '';
    }
    return _leadingGlue(segments[index + 1].text);
  }

  static final RegExp _leading = RegExp(r'^\S+');
  static final RegExp _trailing = RegExp(r'\S+$');

  static String _leadingGlue(String value) =>
      _leading.firstMatch(value)?.group(0) ?? '';

  static String _trailingGlue(String value) =>
      _trailing.firstMatch(value)?.group(0) ?? '';

  /// 공백으로 어절을 나누는 언어만 붙은 글자를 용어와 묶습니다.
  static bool _glueParticles(Locale locale) =>
      locale.languageCode != 'ja' && locale.languageCode != 'zh';
}
