import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [InputStep] 변형(`input-step` `variants`).
enum InputStepVariant {
  /// 온보딩 단계. 맨 위에 진행 막대가 보입니다.
  onboarding,

  /// 알림 시간 묻기처럼 한 번만 묻는 화면. 진행 막대가 없습니다.
  standalone,
}

/// 질문 하나짜리 입력 화면 틀(`input-step`).
///
/// 위에서부터 진행 막대(온보딩만, 3px) → 질문 → 입력 → 도움말 → 오류 줄이고, 아래에
/// 주 버튼(`primary-button` filled)이 붙습니다. 키보드가 열리면 버튼이 키보드 위
/// `space.16`에 붙고 위쪽 내용은 스크롤됩니다.
///
/// [error]가 있으면 `out-of-range` 상태입니다. 오류 줄이 `appear.seep`으로 나타나고(빨간색
/// 없이 `mark.caution` + 본문색), 스크린리더가 바로 읽으며(assertive 알림), 버튼은
/// disabled입니다. 오류가 풀리면 줄이 사라집니다.
///
/// 화면 틀이라 [Scaffold]·앱 바는 쓰는 화면이 따로 둡니다.
class InputStep extends StatefulWidget {
  /// 입력 화면 틀을 만듭니다.
  ///
  /// [screenId]는 IA 화면 id입니다. 질문 영역 Semantics `identifier`를
  /// `<screenId>.question.head`로 붙입니다. [variant]가 `onboarding`이면 [step]
  /// (1부터)과 [stepCount]가 있어야 합니다. 도움말·오류·버튼의 슬롯 id는
  /// [helpIdentifier]·[errorIdentifier]·[actionIdentifier]로 넘깁니다.
  const new({
    required this.screenId,
    required this.variant,
    required this.question,
    required this.input,
    required this.actionLabel,
    required this.onAction,
    this.help,
    this.error,
    this.actionLoading = false,
    this.step,
    this.stepCount,
    this.helpIdentifier,
    this.errorIdentifier,
    this.actionIdentifier,
    super.key,
  }) : assert(
         variant != InputStepVariant.onboarding ||
             (step != null &&
                 stepCount != null &&
                 step >= 1 &&
                 step <= stepCount),
         'onboarding 변형은 1 <= step <= stepCount가 필요합니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'input-step',
    {'onboarding', 'standalone'},
    {'out-of-range', 'valid'},
  );

  /// 진행 막대 트랙을 찾는 테스트용 키.
  static const Key progressKey = ValueKey('input-step-progress');

  /// 진행 막대 채움을 찾는 테스트용 키.
  static const Key progressFillKey = ValueKey('input-step-progress-fill');

  static const double _progressHeight = 3;

  /// IA 화면 id.
  final String screenId;

  /// 변형.
  final InputStepVariant variant;

  /// 질문.
  final String question;

  /// 입력 위젯(text-field, segmented, 휠 등).
  final Widget input;

  /// 도움말. 없으면 그리지 않습니다.
  final String? help;

  /// 오류 문구. 있으면 `out-of-range`입니다.
  final String? error;

  /// 아래 버튼 글자.
  final String actionLabel;

  /// 아래 버튼을 눌렀을 때. null이면 disabled.
  final VoidCallback? onAction;

  /// 아래 버튼이 처리 중인지.
  final bool actionLoading;

  /// 지금 단계(1부터). `onboarding`에서 필수.
  final int? step;

  /// 전체 단계 수. `onboarding`에서 필수.
  final int? stepCount;

  /// 도움말의 IA 슬롯 id.
  final String? helpIdentifier;

  /// 오류 줄의 IA 슬롯 id.
  final String? errorIdentifier;

  /// 아래 버튼의 IA 슬롯 id.
  final String? actionIdentifier;

  @override
  State<InputStep> createState() => _InputStepState();
}

class _InputStepState extends State<InputStep> {
  /// 사라지는 동안에도 문구가 남도록 마지막 오류를 기억합니다.
  String _shownError = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final media = MediaQuery.of(context);
    // 키보드가 열리면 키보드 위, 아니면 아래 안전 영역 위에 space.16을 둡니다.
    // Scaffold가 키보드만큼 이미 줄였다면 viewInsets가 0이라 이중으로 띄우지 않습니다.
    final bottomInset = math.max(media.viewInsets.bottom, media.padding.bottom);
    final error = widget.error;
    if (error != null) _shownError = error;
    final help = widget.help;

    final content = <Widget>[
      const SizedBox(height: Space.s24),
      // 질문은 아래 form 노드의 라벨로 읽히므로 같은 글을 두 번 읽지 않게 합니다.
      ExcludeSemantics(
        child: Text(
          widget.question,
          style: tokens.typography.title.copyWith(color: colors.textPrimary),
        ),
      ),
      const SizedBox(height: Space.s24),
      widget.input,
      if (help != null) ...[
        const SizedBox(height: Space.s8),
        Semantics(
          identifier: widget.helpIdentifier,
          child: Text(
            help,
            style: tokens.typography.captionLg.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
      SeepPresence(
        present: error != null,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.s8),
          child: LiveAnnouncement(
            label: _shownError,
            role: SemanticsRole.alert,
            identifier: widget.errorIdentifier,
            child: _ErrorLine(text: _shownError),
          ),
        ),
      ),
      const SizedBox(height: Space.s24),
    ];

    return Semantics(
      container: true,
      role: SemanticsRole.form,
      label: widget.question,
      identifier: '${widget.screenId}.question.head',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.variant == InputStepVariant.onboarding)
            Padding(
              padding: const EdgeInsets.only(
                left: Space.s20,
                right: Space.s20,
                top: Space.s8,
              ),
              child: _ProgressBar(
                step: widget.step!,
                stepCount: widget.stepCount!,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Space.s20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Space.s20,
              Space.s8,
              Space.s20,
              Space.s16 + bottomInset,
            ),
            child: PrimaryButton(
              label: widget.actionLabel,
              loading: widget.actionLoading,
              identifier: widget.actionIdentifier,
              onPressed: error == null ? widget.onAction : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// 진행 막대. 채움 너비만 `standard` 곡선 `medium`(320ms) 동안 늘어납니다.
///
/// 단계마다 화면이 새로 열리므로 채움은 앞 단계 너비에서 이번 단계 너비로 자랍니다.
class _ProgressBar extends StatelessWidget {
  const new({required this.step, required this.stepCount});

  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final label = AppLocalizations.of(context)
        .inputStepProgress(step, stepCount);
    final reduce = MotionPrefs.of(context).reduceMotion;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: InputStep.progressKey,
          decoration: BoxDecoration(
            color: colors.line,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
          child: SizedBox(
            height: InputStep._progressHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.full),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: (step - 1) / stepCount,
                  end: step / stepCount,
                ),
                duration: reduce ? Duration.zero : Motion.medium,
                curve: Motion.standard,
                builder: (context, fraction, _) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: DecoratedBox(
                      key: InputStep.progressFillKey,
                      decoration: BoxDecoration(
                        color: colors.actionPrimary,
                        borderRadius: BorderRadius.circular(Radii.full),
                      ),
                      child: const SizedBox(height: InputStep._progressHeight),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 오류 줄. 빨간색 없이 경고 표시(`mark.caution`) + 본문색 글자입니다.
class _ErrorLine extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = context.tokens.typography.captionLg.copyWith(
      color: context.tokens.colors.textPrimary,
    );
    // 경고 표시는 주변 글자 크기와 색(DefaultTextStyle)을 따르고, 첫 줄 높이에 맞춰 놓습니다.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1);
    return DefaultTextStyle(
      style: style,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: lineHeight,
            child: const Center(child: AppIcon.caution()),
          ),
          const SizedBox(width: Space.s8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
