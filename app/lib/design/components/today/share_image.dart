import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
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
  final end = trimmed.indexOf(RegExp('[.!?。！？]'));
  return end < 0 ? trimmed : trimmed.substring(0, end + 1);
}

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
    this.semanticLabel = defaultSemanticLabel,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'share-image',
    {'story', 'feed', 'square'},
    {'ratioChanged'},
  );

  /// 명세 `a11y.label`. 다른 언어는 [semanticLabel]로 줍니다.
  static const String defaultSemanticLabel = '오늘 문장 이미지 미리보기';

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

  static const double _width = 360;
  static const double _logoHeight = 28;
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Space.s24,
    Space.s32,
    Space.s24,
    Space.s24,
  );

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

  /// 행운 항목 전부. 변형이 보여 줄 만큼만 고릅니다.
  final List<LuckyItem> items;

  /// 아래 앱 이름 글자.
  final String footer;

  /// 이유 문장. story에서만 보입니다.
  final RenderedText? reason;

  /// 스크린리더 라벨. 기본은 명세의 한국어 문구입니다.
  final String semanticLabel;

  /// 변형이 보여 줄 칩. story는 앞에서 4개, feed·square는 시간을 뺀 색·방향·숫자 3개입니다.
  List<LuckyItem> _chipsFor() => switch (variant) {
    ShareImageVariant.story => items.take(4).toList(),
    ShareImageVariant.feed || ShareImageVariant.square =>
      items
          .where((item) => item.variant != LuckyCardVariant.time)
          .take(3)
          .toList(),
  };

  RenderedText get _shownSentence => switch (variant) {
    ShareImageVariant.square => RenderedText(
      segments: [Segment(text: firstSentence(_plain(sentence)))],
    ),
    ShareImageVariant.story || ShareImageVariant.feed => sentence,
  };

  static String _plain(RenderedText text) =>
      text.segments.map((segment) => segment.text).join();

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
          label: semanticLabel,
          value: _plain(sentence),
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
              // 내용이 남는 자리보다 길면 넘치지 않도록 줄여 담습니다.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: _width - _padding.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DayCharacterBadge(
                            variant: dayCharacterVariantOf(dayKind),
                            label: dayKindLabel,
                          ),
                          const SizedBox(height: Space.s16),
                          SentenceBlock(
                            key: sentenceKey,
                            variant: SentenceBlockVariant.card,
                            text: _shownSentence,
                            termStyle: TermStyle.plain,
                            maxLines: variant == ShareImageVariant.feed
                                ? 2
                                : null,
                          ),
                          if (showReason)
                            Padding(
                              key: reasonKey,
                              padding: const EdgeInsets.only(top: Space.s12),
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
                                LuckyChip(item: item, open: false, onTap: null),
                            ],
                          ),
                        ],
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
