import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/rendered_text_plain.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _lock = AppGlyph(
  light: PhosphorIconsLight.lockSimple,
  regular: PhosphorIconsRegular.lockSimple,
);

/// 잠긴 구역의 본문 줄 수(`elements.json` `lock.veil.lines`). 앞부분과 자리값을 합한 줄 수이고
/// 실제 문장 길이와 맞추지 않습니다(D106, 결정 V92).
abstract final class LockVeilLines {
  /// 근거 시트 판정 근거.
  static const int basis = 3;

  /// 근거 시트 원전.
  static const int source = 2;

  /// 근거 시트 내 사주에서는.
  static const int personal = 3;

  /// `sentence-block` `locked`(사주 표 용신 판정 근거).
  static const int sentenceBlock = 2;
}

/// 잠긴 구역 하나(`lock.veil`, D60, D106, 결정 V25, V80).
///
/// [sectionTitle]이 있으면 자물쇠 + 또렷한 제목을 두고, 그 아래 `space.8`에 본문을 둡니다. 본문은
/// server가 준 문장 앞부분([lead], 2~3 단어)을 또렷하게 두고 바로 뒤 같은 줄부터 app이 준비한
/// 자리값 글자([placeholderFor])를 흐리게 이어 채우며, 앞부분을 포함해 [lines]줄입니다. 앞부분이
/// 없으면 자리값만입니다. 실제 내용은 내려받지 않습니다(D60 ④).
///
/// 같은 글줄을 두 층으로 겹쳐 그립니다: 또렷한 층은 앞부분만 보이고, 흐린 층(흐림 6px, 투명도 0.5)은
/// 자리값만 보입니다. 두 층은 같은 조각이라 줄바꿈 자리가 같습니다. 흐림은 대상 자신의 효과라 동작
/// 줄이기에서도 그대로 둡니다(결정 V14).
///
/// 스크린리더는 "제목, 앞부분, [stateLabel]" 순서로 읽고 자리값은 건너뜁니다.
class LockVeil extends StatelessWidget {
  /// 잠긴 구역을 만듭니다.
  const new({
    required this.lines,
    required this.stateLabel,
    this.sectionTitle,
    this.semanticTitle,
    this.lead,
    this.titleSlotId,
    this.bodySlotId,
    this.a11ySlotId,
    this.fontFallback = const [],
    super.key,
  }) : assert(lines > 0, 'lines는 양수여야 합니다.');

  /// 본문 자리(두 층을 겹친 것)를 찾는 테스트용 키.
  static const Key bodyKey = ValueKey('lock-veil-body');

  /// 또렷한 층(앞부분만 보임)의 글자를 찾는 테스트용 키.
  static const Key clearKey = ValueKey('lock-veil-clear');

  /// 흐린 층(자리값만 보임)의 글자를 찾는 테스트용 키.
  static const Key veilKey = ValueKey('lock-veil-veil');

  static const double _blurSigma = 6;
  static const double _bodyOpacity = 0.5;

  /// 자리값을 이어 붙일 최소 글자 수. 넓은 화면의 [LockVeilLines] 최대 줄 수를 넉넉히 채우고,
  /// 넘치는 몫은 줄 수에서 잘립니다.
  static const int _fillLength = 600;

  // 보이는 문구가 아닙니다. 흐림 6px, 투명도 0.5로 읽을 수 없게 그려지고 접근성 트리에서도
  // 빠지는 자리값이라 ARB를 거치지 않습니다(예외, elements.json lock.veil.placeholder
  // `source: app`). 뜻 없는 글자이고 언어마다 하나입니다.
  static const Map<String, String> _placeholders = {
    'ko': '가나다 라마바사 아자차카 타파하 거너더 러머버 서어저 처커터 퍼허 ',
    'en': 'lorem ipsum dolor sit amet consectetur adipiscing elit sed do ',
    'ja': 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほ',
  };

  /// [locale] 언어의 자리값 글자(`lock.veil.placeholder.text`). 모르는 언어는 영어입니다.
  static String placeholderFor(Locale locale) =>
      _placeholders[locale.languageCode] ?? _placeholders['en']!;

  /// 본문 줄 수(앞부분 포함). 구역마다 [LockVeilLines]의 값입니다.
  final int lines;

  /// 스크린리더가 끝에 읽는 상태 낱말("잠김", ARB 문구).
  final String stateLabel;

  /// 보이는 구역 제목(ARB 문구). 없으면 제목 줄 없이 본문만입니다.
  final String? sectionTitle;

  /// 제목 줄 없이 스크린리더만 읽는 구역 이름(`sentence-block` `locked`의 용신). 없으면
  /// [sectionTitle]을 읽습니다.
  final String? semanticTitle;

  /// server가 준 문장 앞부분(`evidencePreview`, `basisPreview`). 없으면 자리값만입니다.
  final RenderedText? lead;

  /// 제목이 채우는 IA 슬롯 id. 있으면 제목에 Key와 Semantics `identifier`를 붙입니다.
  final String? titleSlotId;

  /// 본문 자리가 채우는 IA 슬롯 id(예: `evidence-sheet.basis.body`). Key와 `identifier`.
  final String? bodySlotId;

  /// 스크린리더 상태 낱말의 IA 슬롯 id(`evidence-sheet.a11y.locked`). 라벨 노드의
  /// `identifier`입니다.
  final String? a11ySlotId;

  /// 본문 글꼴 앞에 둘 대체 글꼴. 원전 앞부분의 한자처럼 문장 글꼴에 글리프가 없는 글자를
  /// 그 글꼴로 그립니다(`sentence-block`의 `fontFallback`과 같음).
  final List<String> fontFallback;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = sectionTitle;
    final lead = this.lead;
    final leadText = lead == null ? '' : plainTextOf(lead).trim();
    // 라벨 노드가 제목, 앞부분, 상태 낱말을 읽고, 제목과 본문 자리는 슬롯 id만 가진 빈 노드입니다.
    final label = [
      ?(semanticTitle ?? title),
      if (leadText.isNotEmpty) leadText,
      stateLabel,
    ].join(', ');
    return Semantics(
      container: true,
      label: label,
      identifier: a11ySlotId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            _slot(titleSlotId, _titleRow(tokens, title)),
            const SizedBox(height: Space.s8),
          ],
          _slot(bodySlotId, _body(context, tokens, leadText)),
        ],
      ),
    );
  }

  Widget _titleRow(MyungliTokens tokens, String title) {
    final style = tokens.typography.labelMd.copyWith(
      color: tokens.colors.textSecondary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s4,
      children: [
        AppIcon(
          _lock,
          size: AppIconSize.adjacentText(style.fontSize ?? 13),
          weight: AppIconWeight.regular,
          color: tokens.colors.textSecondary,
          scalesWithText: true,
        ),
        Flexible(child: Text(title, style: style)),
      ],
    );
  }

  /// 같은 조각을 두 층으로 겹친 본문. 또렷한 층은 앞부분만, 흐린 층은 자리값만 칠합니다.
  Widget _body(BuildContext context, MyungliTokens tokens, String leadText) {
    final unit = placeholderFor(
      Localizations.maybeLocaleOf(context) ?? const Locale('en'),
    );
    final fill = List.filled((_fillLength / unit.length).ceil(), unit).join();
    final sentence = tokens.typography.sentenceBody;
    final base = fontFallback.isEmpty
        ? sentence
        : sentence.copyWith(
            fontFamilyFallback: [
              ...fontFallback,
              ...?sentence.fontFamilyFallback,
            ],
          );
    final shown = base.copyWith(color: tokens.colors.textPrimary);
    final hidden = base.copyWith(color: const Color(0x00000000));
    Text layer({required bool veil, required Key key}) => Text.rich(
      TextSpan(
        children: [
          if (leadText.isNotEmpty)
            TextSpan(text: '$leadText ', style: veil ? hidden : shown),
          TextSpan(text: fill, style: veil ? shown : hidden),
        ],
      ),
      key: key,
      maxLines: lines,
      overflow: TextOverflow.clip,
      style: base,
    );
    return SelectionContainer.disabled(
      child: Stack(
        key: bodyKey,
        children: [
          layer(veil: false, key: clearKey),
          Positioned.fill(
            child: Opacity(
              opacity: _bodyOpacity,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: _blurSigma,
                  sigmaY: _blurSigma,
                  tileMode: TileMode.decal,
                ),
                child: layer(veil: true, key: veilKey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 슬롯 id가 있으면 Key와 빈 `identifier` 노드를 붙이고, 안의 글자는 읽지 않습니다.
  Widget _slot(String? id, Widget child) {
    final hidden = ExcludeSemantics(child: child);
    if (id == null) return hidden;
    return KeyedSubtree(
      key: ValueKey(id),
      child: Semantics(container: true, identifier: id, child: hidden),
    );
  }
}
