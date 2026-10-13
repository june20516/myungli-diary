import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/text/keep_all.dart';

/// server가 렌더한 문장 조각 배열(`RenderedText.segments`)을 그대로 그립니다.
///
/// app은 문장을 고르거나 조사를 붙이지 않습니다. 조각을 순서대로 이어 하나의
/// [Text.rich]로 그려 줄바꿈이 문장 전체에서 자연스럽게 일어나게 하고, 조각 경계에
/// 공백이나 줄바꿈을 넣지 않습니다(결정 V28).
///
/// [onTerm]이 있으면 `term`이 있는 조각을 `term-token` `inline`으로 그리고 누르면
/// `term` 값을 넘깁니다. 없으면 `term` 조각도 일반 글자입니다. `term-token`이 없는
/// 화면, 공유 이미지, 카드 전체가 버튼인 곳(`diary-row`) 안에서는 [onTerm]을 주지 않습니다.
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
    this.onTerm,
    this.trailing,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  /// 조각 배열. 비어 있으면 아무것도 그리지 않습니다.
  final RenderedText text;

  /// 문장 글자 스타일(글자색 포함). 조각 모두와 용어 칩의 바탕 스타일입니다.
  final TextStyle style;

  /// 용어 조각을 눌렀을 때 `term` 값을 받습니다. null이면 용어도 일반 글자입니다.
  final ValueChanged<String>? onTerm;

  /// 문장 끝에 붙는 위젯(`depth-link` `inline-end`). 줄 끝에 다 들어가지 않으면
  /// 통째로 다음 줄로 넘어갑니다.
  final Widget? trailing;

  /// 최대 줄 수. 일기 목록 미리보기가 씁니다.
  final int? maxLines;

  /// 넘친 글자 처리.
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final segments = text.segments.where((s) => s.text.isNotEmpty).toList();
    if (segments.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    final glueParticles = _glueParticles(locale);
    final children = <InlineSpan>[
      for (var i = 0; i < segments.length; i++)
        ..._spansFor(segments, i, glueParticles, locale),
      if (trailing != null) ...[
        // 링크 앞 틈은 줄바꿈 없는 공백입니다.
        const TextSpan(text: '\u00A0\u2060'),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: trailing!,
        ),
      ],
    ];
    return Text.rich(
      TextSpan(style: style, children: children),
      maxLines: maxLines,
      overflow: overflow,
    );
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
    if (term != null && onTerm != null) {
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
    return [TextSpan(text: applyKeepAll(locale, shown), semanticsLabel: shown)];
  }

  /// [index]가 일반 조각이고 바로 앞 용어에 붙은 글자를 내줘야 하는지.
  bool _takesTail(List<Segment> segments, int index) =>
      index >= 0 && _isChip(segments[index]);

  /// [index]가 일반 조각이고 바로 뒤 용어에 붙은 글자를 내줘야 하는지.
  bool _takesHead(List<Segment> segments, int index) =>
      index < segments.length && _isChip(segments[index]);

  bool _isChip(Segment s) => s.term != null && onTerm != null;

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
