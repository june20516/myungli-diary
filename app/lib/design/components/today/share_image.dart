import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/rendering/offscreen_renderer.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/text/keep_all.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 공유 이미지 비율 변형(`share-image` `variants`).
enum ShareImageVariant {
  /// 9:16. 이유와 문장 전체, 칩 4개.
  story,

  /// 4:5. 문장 두 줄, 칩 3개.
  feed,

  /// 1:1. 첫 문장, 칩 3개.
  square,
}

/// [text]의 첫 문장입니다. 첫 `.`·`。`·`!`·`?`(전각 `！`·`？` 포함)까지를 문장부호째로
/// 돌려주고, 끝 문장부호가 없으면 전체를 돌려줍니다. 앞뒤 공백은 다듬습니다.
String firstSentence(String text) {
  final trimmed = text.trim();
  for (var i = 0; i < trimmed.length; i++) {
    if (!_sentenceEnds.contains(trimmed[i])) continue;
    // 숫자 사이의 `.`은 소수점이라 문장 끝이 아닙니다.
    if (trimmed[i] == '.' &&
        i > 0 &&
        i + 1 < trimmed.length &&
        _isDigit(trimmed[i - 1]) &&
        _isDigit(trimmed[i + 1])) {
      continue;
    }
    var end = i + 1;
    // 문장부호 바로 뒤에 붙은 닫는 따옴표·괄호는 문장에 포함합니다.
    while (end < trimmed.length && _closers.contains(trimmed[end])) {
      end++;
    }
    return trimmed.substring(0, end);
  }
  return trimmed;
}

const String _sentenceEnds = '.!?。！？';
const String _closers = '”’"\'」』）)]〕】》〉';

bool _isDigit(String char) =>
    char.compareTo('0') >= 0 && char.compareTo('9') <= 0;

/// 공유 이미지(`share-image`). 오늘 문장·행운 칩·로고를 라이트 고정으로 한 장에 담습니다.
///
/// 크기는 [logicalSize]로 정해져 있고 안쪽 배치는 이 크기에만 의존합니다. 화면 미리보기
/// ([ShareImagePreview])는 같은 위젯을 줄여 보이고, PNG는 이 크기를 `pixelRatio: 3`으로
/// 그려 1080 폭을 얻습니다. 기기 글자 크기 설정과 다크 모드는 따르지 않습니다(결정 V5,
/// 그림은 기기와 상관없이 같아야 합니다). 그리는 쪽이 [Directionality]·[Localizations]를
/// 위에 두어야 합니다(언어로 글꼴 묶음을 고릅니다).
///
/// 장식 그림이라 눌리지 않고 햅틱이 없습니다. 스크린리더는 이미지 하나로 읽고,
/// 라벨은 [semanticLabel], 대체 글(`altText`)은 문장 전체입니다.
class ShareImage extends StatelessWidget {
  /// 공유 이미지를 만듭니다.
  ///
  /// [date]는 표시할 날짜 글자(언어별 서식은 만드는 쪽이 정합니다), [dayKindLabel]은
  /// 배지 글자, [footer]는 `share-preview.image.footer` 문구입니다. [items]는 전부 주고
  /// 변형별로 고릅니다([_chipsFor]). [reason]은 story에서만 보입니다.
  const new({
    required this.variant,
    required this.date,
    required this.dayKind,
    required this.dayKindLabel,
    required this.sentence,
    required this.items,
    required this.footer,
    this.reason,
    this.semanticLabel,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'share-image',
    {'story', 'feed', 'square'},
    {'ratioChanged'},
  );

  /// 그림 판(캔버스)을 찾는 테스트용 키.
  static const Key canvasKey = ValueKey('share-image-canvas');

  /// 이미지 의미 노드를 찾는 테스트용 키.
  static const Key semanticsKey = ValueKey('share-image-semantics');

  /// 문장을 찾는 테스트용 키.
  static const Key sentenceKey = ValueKey('share-image-sentence');

  /// 이유 줄을 찾는 테스트용 키.
  static const Key reasonKey = ValueKey('share-image-reason');

  /// 로고를 찾는 테스트용 키.
  static const Key logoKey = ValueKey('share-image-logo');

  /// 로고 자산(`parts.logo`).
  static const String logoAsset = 'assets/brand/myungli/lockup.svg';

  /// 로고를 미리 읽어 둡니다. 화면 밖에서 그리기 전에 부르면 로고가 비지 않은 채 캡처됩니다.
  ///
  /// [context]가 있으면 그 자산 묶음(`DefaultAssetBundle`), 없으면 앱 묶음에서 읽습니다. 렌더와 같은 상한
  /// ([offscreenRenderTimeout])을 넘으면 [OffscreenRenderTimeout]을 던집니다.
  static Future<void> precache([BuildContext? context]) =>
      const SvgAssetLoader(logoAsset)
          .loadBytes(context)
          .timeout(
            offscreenRenderTimeout,
            onTimeout: () => throw const OffscreenRenderTimeout(),
          );

  static const double _width = 360;
  static const double _contentWidth = _width - Space.s24 * 2;
  static const double _logoHeight = 28;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Space.s24,
    Space.s32,
    Space.s24,
    Space.s24,
  );

  /// 긴 내용을 줄여 담을 때의 배율 하한(가독성).
  ///
  /// 줄어든 문장 글자(`sentence.card`)가 같은 그림 안의 이유 글자(`caption.lg`)보다 작아지지
  /// 않는 배율입니다. 이 아래로는 줄이지 않고, 문장을 자르고 마지막 줄을 말줄임표로 끝냅니다.
  /// 명세에는 하한이 없어 토큰 두 값에서 구합니다(1080px 폭 기준 글자 약 39px 이상).
  static double minContentScale(TypeTokens typography) =>
      (typography.captionLg.fontSize! / typography.sentenceCard.fontSize!)
          .clamp(0, 1);

  /// [variant]의 논리 크기. 폭 360 x pixelRatio 3 = 1080(명세 `canvas.width`).
  static Size logicalSize(ShareImageVariant variant) => switch (variant) {
    ShareImageVariant.story => const Size(_width, 640),
    ShareImageVariant.feed => const Size(_width, 450),
    ShareImageVariant.square => const Size(_width, 360),
  };

  /// 비율.
  final ShareImageVariant variant;

  /// 표시할 날짜 글자.
  final String date;

  /// 서버가 내려 준 날의 성격. 배지 변형을 정합니다.
  final DayKind dayKind;

  /// 배지 글자.
  final String dayKindLabel;

  /// 오늘 문장(server가 렌더한 조각).
  final RenderedText sentence;

  /// 행운 항목 전부. 변형이 보여 줄 만큼만 고릅니다. 대표 태그 칩은 그리지 않습니다.
  final List<LuckyItem> items;

  /// 아래 앱 이름 글자.
  final String footer;

  /// 이유 문장. story에서만 보입니다.
  final RenderedText? reason;

  /// 스크린리더 라벨. null이면 ARB `shareImageSemantics`(명세 `a11y.label`)를 읽습니다.
  final String? semanticLabel;

  /// 변형이 보여 줄 칩. story는 앞에서 4개, feed·square는 시간을 뺀 색·방향·숫자 3개입니다.
  List<LuckyItem> _chipsFor() {
    // 칩 줄에 tag 칩을 넣지 않습니다(`lucky-card` rules, 행운 4종만).
    final lucky = items.where(
      (item) => LuckyCardVariant.luckyValues.contains(item.variant),
    );
    return switch (variant) {
      ShareImageVariant.story => lucky.take(4).toList(),
      ShareImageVariant.feed || ShareImageVariant.square =>
        lucky
            .where((item) => item.variant != LuckyCardVariant.time)
            .take(3)
            .toList(),
    };
  }

  RenderedText get _shownSentence => switch (variant) {
    ShareImageVariant.square => RenderedText(
      segments: [Segment(text: firstSentence(plainTextOf(sentence)))],
    ),
    ShareImageVariant.story || ShareImageVariant.feed => sentence,
  };

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    // 공유 이미지만 라이트 토큰으로 고정하고(V5) 기기 글자 크기 설정을 따르지 않습니다.
    return Theme(
      data: buildTheme(brightness: Brightness.light, locale: locale),
      child: MediaQuery.withNoTextScaling(
        child: Semantics(
          key: semanticsKey,
          container: true,
          image: true,
          label:
              semanticLabel ?? AppLocalizations.of(context).shareImageSemantics,
          value: plainTextOf(sentence),
          child: ExcludeSemantics(
            child: Material(
              type: MaterialType.transparency,
              child: Builder(builder: _buildCanvas),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final typography = tokens.typography;
    final reasonText = reason;
    final showReason =
        variant == ShareImageVariant.story &&
        reasonText != null &&
        reasonText.segments.isNotEmpty;
    return SizedBox.fromSize(
      key: canvasKey,
      size: logicalSize(variant),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.gradients.today),
        child: Padding(
          padding: _padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: typography.captionMd.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              // 내용이 남는 자리보다 길면 하한([minContentScale])까지 줄여 담고, 그래도
              // 길면 문장을 말줄임표로 자릅니다.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        // 하한 배율에서 자리에 딱 맞는 높이. 문장이 이 안에서 줄 수를 정합니다.
                        constraints: BoxConstraints(
                          maxHeight:
                              constraints.maxHeight /
                              minContentScale(typography),
                        ),
                        child: SizedBox(
                          width: _contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DayCharacterBadge(
                                variant: dayCharacterVariantOf(dayKind),
                                label: dayKindLabel,
                              ),
                              const SizedBox(height: Space.s16),
                              Flexible(
                                child: _FittedSentence(
                                  key: sentenceKey,
                                  text: _shownSentence,
                                  maxLines: variant == ShareImageVariant.feed
                                      ? 2
                                      : null,
                                ),
                              ),
                              if (showReason)
                                Padding(
                                  key: reasonKey,
                                  padding: const EdgeInsets.only(
                                    top: Space.s12,
                                  ),
                                  child: RenderedTextView(
                                    text: reasonText,
                                    style: typography.captionLg.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: Space.s20),
                              Wrap(
                                spacing: Space.s8,
                                runSpacing: Space.s8,
                                children: [
                                  for (final item in _chipsFor())
                                    LuckyChip(
                                      item: item,
                                      open: false,
                                      onTap: null,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SvgPicture.asset(
                    logoAsset,
                    key: logoKey,
                    height: _logoHeight,
                  ),
                  const Spacer(),
                  Text(
                    footer,
                    style: typography.captionSm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 남는 높이에 들어가는 줄 수까지만 보이는 큰 문장(`sentence-block` `card`).
///
/// 부모가 준 높이 제한 안에 전체 문장이 들어가면 그대로 그리고, 넘치면 들어가는 줄까지만
/// 그려 마지막 줄을 말줄임표로 끝냅니다. [maxLines]는 변형이 정한 줄 수 상한입니다.
class _FittedSentence extends StatelessWidget {
  const new({required this.text, required this.maxLines, super.key});

  final RenderedText text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final style = context.tokens.typography.sentenceCard;
    return LayoutBuilder(
      builder: (context, constraints) {
        final plain = plainTextOf(text);
        final fitted = _linesThatFit(
          context,
          plain,
          style,
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final limit = [maxLines, fitted].nonNulls.fold<int?>(
          null,
          (least, value) => least == null || value < least ? value : least,
        );
        return SentenceBlock(
          variant: SentenceBlockVariant.card,
          text: text,
          termStyle: TermStyle.plain,
          maxLines: limit,
        );
      },
    );
  }

  /// [maxHeight] 안에 들어가는 줄 수. 전체가 들어가거나 높이 제한이 없으면 null입니다.
  /// 줄이 하나도 안 들어가도 1줄은 남깁니다.
  ///
  /// 실제로 그리는 `Text.rich`(`RenderedTextView`)와 같은 조건으로 잽니다: keep-all 조각,
  /// 기본 글자 스타일 병합, 방향, 글자 배율, 언어, 줄 높이 처리.
  static int? _linesThatFit(
    BuildContext context,
    String plain,
    TextStyle style,
    double maxWidth,
    double maxHeight,
  ) {
    if (!maxHeight.isFinite || plain.isEmpty) return null;
    final defaults = DefaultTextStyle.of(context);
    final locale = Localizations.localeOf(context);
    final painter = TextPainter(
      text: TextSpan(
        style: defaults.style.merge(style),
        children: keepAllSpans(locale, plain),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: locale,
      textHeightBehavior:
          defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      textWidthBasis: defaults.textWidthBasis,
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    var used = 0.0;
    var count = 0;
    for (final line in lines) {
      used += line.height;
      if (used > maxHeight + _tolerance) break;
      count++;
    }
    if (count >= lines.length) return null;
    return count < 1 ? 1 : count;
  }

  /// 부동소수 오차로 마지막 줄이 잘못 잘리지 않게 두는 여유.
  static const double _tolerance = 0.5;
}

/// 화면 미리보기(`share-image` `preview`). 논리 크기의 [ShareImage]를 주어진 폭에 맞춰
/// 줄여 보이고, 그림자(`shadow.raised`)와 모서리(`radius.md`)를 입힙니다.
///
/// 비율([ShareImage.variant])이 바뀌면 `appear.seep`으로 새로 나타납니다(`ratioChanged`).
/// 동작 줄이기면 흐림 없이 투명도만 바뀝니다. 처음 나타날 때와 같은 비율에서 내용만
/// 바뀔 때는 전환하지 않습니다. PNG로 내보낼 때는 이 위젯이 아니라 [ShareImage]를
/// 논리 크기로 직접 그립니다.
class ShareImagePreview extends StatefulWidget {
  /// 미리보기를 만듭니다. 폭은 부모가 정하고 높이는 비율을 따릅니다.
  const new({required this.image, super.key});

  /// 줄여 보일 공유 이미지.
  final ShareImage image;

  /// 미리보기 틀을 찾는 테스트용 키.
  static const Key frameKey = ValueKey('share-image-preview-frame');

  @override
  State<ShareImagePreview> createState() => _ShareImagePreviewState();
}

class _ShareImagePreviewState extends State<ShareImagePreview>
    with SingleTickerProviderStateMixin {
  // 처음에는 전환 없이 다 나타난 상태(1)로 시작합니다.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: InteractionPattern.appearSeep.duration,
    value: 1,
  );

  @override
  void didUpdateWidget(ShareImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.variant != widget.image.variant) {
      _in.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = ShareImage.logicalSize(widget.image.variant);
    const radius = BorderRadius.all(Radius.circular(Radii.md));
    return AspectRatio(
      key: ShareImagePreview.frameKey,
      aspectRatio: size.width / size.height,
      child: animate(
        InteractionPattern.appearSeep,
        t: _in,
        prefs: MotionPrefs.of(context),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: radius,
            boxShadow: Shadows.raised,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: FittedBox(
              child: SizedBox.fromSize(size: size, child: widget.image),
            ),
          ),
        ),
      ),
    );
  }
}
