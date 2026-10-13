import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// empty-state·error-state가 함께 쓰는 배치: sage 원(56px) 안 Light 아이콘 28px + 문장.
///
/// 화면 세로 40% 자리에 둡니다. 아래 [children]이 문장 밑에 이어집니다.
class StateLayout extends StatelessWidget {
  /// 배치를 만듭니다.
  const new({
    required this.icon,
    required this.sentence,
    required this.children,
    required this.alert,
    super.key,
  });

  /// 원 안 아이콘.
  final AppGlyph icon;

  /// 문장.
  final String sentence;

  /// 문장 아래 요소(버튼·문의 정보).
  final List<Widget> children;

  /// true면 오류 알림(`alert`), false면 묶음(`group`).
  final bool alert;

  /// 원 지름(px).
  static const double circleSize = 56;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return _FortyPercent(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              // 명세 role: 오류는 alert. 빈 상태의 group은 대응하는 SemanticsRole이 없어
              // 하나의 묶음 노드(container)로 둡니다.
              role: alert ? SemanticsRole.alert : SemanticsRole.none,
              label: sentence,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.statusBg,
                        borderRadius: BorderRadius.circular(Radii.full),
                      ),
                      child: SizedBox.square(
                        dimension: circleSize,
                        child: Center(
                          child: AppIcon(
                            icon,
                            size: AppIconSize.state,
                            color: colors.actionPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s16),
                    Text(
                      sentence,
                      textAlign: TextAlign.center,
                      style: tokens.typography.sentenceBody.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 내용의 가운데를 부모 높이의 40% 지점에 둡니다(화면 가운데보다 조금 위).
///
/// 높이가 정해지지 않은 곳(스크롤 안 등)에서는 그냥 내용 높이만 차지합니다.
class _FortyPercent extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? CustomSingleChildLayout(
              delegate: const _FortyPercentDelegate(),
              // 글자를 크게 키워 내용이 높이를 넘으면 스크롤됩니다.
              child: SingleChildScrollView(primary: false, child: child),
            )
          : child,
    );
  }
}

class _FortyPercentDelegate extends SingleChildLayoutDelegate {
  const new();

  /// 내용 가운데가 놓이는 높이 비율.
  static const double _anchor = 0.4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = (size.height * _anchor - childSize.height / 2).clamp(
      0,
      size.height - childSize.height,
    );
    return Offset((size.width - childSize.width) / 2, top.toDouble());
  }

  @override
  bool shouldRelayout(_FortyPercentDelegate oldDelegate) => false;
}
