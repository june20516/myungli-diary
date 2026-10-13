import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/state_layout.dart';
import 'package:myungli_diary/design/components/feedback/text_action.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 오류 변형(`error-state` `variants`).
enum ErrorStateVariant {
  /// 불러오기 실패.
  generic(
    AppGlyph(
      light: PhosphorIconsLight.cloudWarning,
      regular: PhosphorIconsRegular.cloudWarning,
    ),
  ),

  /// 연결 없음 + 받아둔 내용도 없음.
  offline(
    AppGlyph(
      light: PhosphorIconsLight.wifiSlash,
      regular: PhosphorIconsRegular.wifiSlash,
    ),
  );

  new(this.glyph);

  /// 변형의 아이콘.
  final AppGlyph glyph;
}

/// 오류일 때: sage 원 안 아이콘 + 문장 + 다시 시도(`quiet`). 빨간색을 쓰지 않습니다.
///
/// [OfflineError]면 offline 변형, 그 밖은 generic 변형입니다. [ProblemError]에
/// `traceId`가 있으면 문의 번호를 보이고 길게 누르면 복사합니다.
class ErrorState extends StatelessWidget {
  /// 오류 화면을 만듭니다. 다시 시도를 누르면 [onRetry]가 불리고, 호출하는 쪽이
  /// 같은 자리에 skeleton이 다시 나오게 합니다.
  const new({required this.error, required this.onRetry, super.key});

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('error-state', {
    'generic',
    'offline',
  }, {});

  /// 보일 오류.
  final AppError error;

  /// 다시 시도.
  final VoidCallback onRetry;

  /// [error]에 맞는 변형.
  ErrorStateVariant get variant => error is OfflineError
      ? ErrorStateVariant.offline
      : ErrorStateVariant.generic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final traceId = switch (error) {
      ProblemError(:final traceId) when traceId.isNotEmpty => traceId,
      _ => null,
    };
    return StateLayout(
      icon: variant.glyph,
      sentence: errorMessage(l10n, error),
      alert: true,
      children: [
        const SizedBox(height: Space.s20),
        FeedbackTextAction(
          label: l10n.actionRetry,
          style: tokens.typography.labelLg.copyWith(
            color: colors.actionPrimary,
          ),
          onPressed: onRetry,
        ),
        if (traceId != null) _TraceId(traceId: traceId),
      ],
    );
  }
}

class _TraceId extends StatelessWidget {
  const new({required this.traceId});

  final String traceId;

  Future<void> _copy(BuildContext context) async {
    final message = AppLocalizations.of(context).traceIdCopied;
    await Clipboard.setData(ClipboardData(text: traceId));
    unawaited(Haptics.light());
    if (context.mounted) showMyungliToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final label = AppLocalizations.of(context).traceIdLabel(traceId);
    return Padding(
      padding: const EdgeInsets.only(top: Space.s12),
      child: Semantics(
        label: label,
        onLongPress: () => _copy(context),
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _copy(context),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: tokens.typography.captionMd.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
