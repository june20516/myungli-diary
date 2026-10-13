import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 잠긴 구역 하나: 자물쇠 + 또렷한 제목, 그 아래 흐린 자리 채우기 본문(D60, V25).
///
/// 실제 내용은 내려받지 않으므로 본문은 뜻 없는 자리 채우기입니다.
/// 흐림(6px)은 대상 자신의 효과라 동작 줄이기에서도 그대로 둡니다.
class LockVeil extends StatelessWidget {
  /// 잠긴 구역을 만듭니다.
  const new({
    required this.title,
    required this.semanticLabel,
    this.lengthHint,
    this.titleSlotId,
    this.bodySlotId,
    this.a11ySlotId,
    super.key,
  }) : assert(lengthHint == null || lengthHint > 0, 'lengthHint는 양수여야 합니다.'),
       _singleLine = false;

  /// 제목 없이 흐린 한 줄만 그리는 모양(`sentence-block` `locked`, `lines: 1`).
  ///
  /// 스크린리더 라벨은 "잠김" 같은 [semanticLabel]만 읽습니다.
  const new line({
    required this.semanticLabel,
    this.bodySlotId,
    this.a11ySlotId,
    super.key,
  }) : title = null,
       titleSlotId = null,
       lengthHint = null,
       _singleLine = true;

  /// 흐린 본문을 찾는 테스트용 키.
  static const Key bodyKey = ValueKey('lock-veil-body');

  static const double _blurSigma = 6;
  static const double _bodyOpacity = 0.5;
  // 보이는 문구가 아닙니다. 흐림 6px·투명도 0.5로 읽을 수 없게 그려지고 접근성
  // 트리에서도 빠지는 자리 채움 글이라 ARB를 거치지 않습니다(예외).
  static const String _filler = '가나다라마바사아자차카타파하고노도로모보소오조초코토포호';

  /// 구역 제목(ARB 문구). [LockVeil.line]이면 없습니다.
  final String? title;

  final bool _singleLine;

  /// 스크린리더 라벨: 구역 제목 + "잠김"(ARB 문구). 흐린 본문은 읽지 않습니다.
  final String semanticLabel;

  /// 제목이 채우는 IA 슬롯 id. 있으면 제목에 Key와 Semantics `identifier`를 붙입니다.
  final String? titleSlotId;

  /// 본문 자리가 채우는 IA 슬롯 id(예: `evidence-sheet.basis.body`). Key와 `identifier`.
  final String? bodySlotId;

  /// 스크린리더 "잠김" 문구의 IA 슬롯 id(`evidence-sheet.a11y.locked`).
  /// 라벨 노드의 `identifier`입니다.
  final String? a11ySlotId;

  /// server가 준 본문 길이 힌트(글자 수). 없으면 두 줄입니다.
  final int? lengthHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hint = lengthHint;
    final title = this.title;
    final placeholder = hint == null
        ? List.filled(20, _filler).join()
        : List.generate(hint, (i) => _filler[i % _filler.length]).join();
    final body = SelectionContainer.disabled(
      key: bodyKey,
      child: Opacity(
        opacity: _bodyOpacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
            tileMode: TileMode.decal,
          ),
          child: Text(
            placeholder,
            maxLines: _singleLine ? 1 : (hint == null ? 2 : null),
            overflow: _singleLine || hint == null ? TextOverflow.clip : null,
            style: tokens.typography.sentenceBody.copyWith(
              color: tokens.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
    // 라벨 노드가 제목 + "잠김"을 읽고, 제목·본문 자리는 슬롯 id만 가진 빈 노드입니다.
    // 흐린 자리 채우기 글과 제목 글자는 읽지 않습니다.
    return Semantics(
      container: true,
      label: semanticLabel,
      identifier: a11ySlotId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            _slot(
              titleSlotId,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.lockSimple,
                    size: 14,
                    color: tokens.colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      style: tokens.typography.labelMd.copyWith(
                        color: tokens.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          _slot(bodySlotId, body),
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
