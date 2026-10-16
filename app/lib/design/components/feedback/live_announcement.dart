import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// 상태 알림을 모바일 스크린리더에 자동으로 읽히게 하는 시맨틱 감싸개.
///
/// 명세 role(`status`·`alert`)만으로는 Android·iOS에서 초점 없이 알림이 일어난다는 근거가
/// 없고, Flutter는 role과 liveRegion을 한 노드에 함께 둘 수 없습니다(debug 검사). 그래서
/// 노드를 둘로 나눕니다. 바깥 노드는 [label]을 가진 liveRegion(모바일 알림), 안쪽 노드는
/// 명세 [role]만 가진 별도 노드(label 없음)입니다.
class LiveAnnouncement extends StatelessWidget {
  /// 알림 노드를 만듭니다. [child]는 시각 내용이며 시맨틱에서는 숨깁니다.
  const new({
    required this.label,
    required this.role,
    required this.child,
    this.identifier,
    super.key,
  });

  /// 읽을 문장(글자 그대로).
  final String label;

  /// 명세가 정한 역할(`status` 또는 `alert`).
  final SemanticsRole role;

  /// IA 슬롯 id. 있으면 바깥 노드의 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// 시각 내용.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      identifier: identifier,
      label: label,
      child: Semantics(
        container: true,
        role: role,
        child: ExcludeSemantics(child: child),
      ),
    );
  }
}

/// 보이는 내용 없이 상태 알림만 하는 [LiveAnnouncement].
///
/// 레이아웃 높이는 0이지만 알림 노드는 1x1 영역을 가져 TalkBack이 놓치지 않습니다.
/// 알림이 감싸는 내용을 의미에서 숨기면 안 되는 곳(결과 목록 위, 스크롤 영역 밖)에
/// 내용과 나란히 둡니다.
class SilentAnnouncement extends StatelessWidget {
  /// 알림 노드를 만듭니다. 인자는 [LiveAnnouncement]와 같습니다.
  const new({
    required this.label,
    required this.role,
    this.identifier,
    super.key,
  });

  /// 읽을 문장(글자 그대로).
  final String label;

  /// 명세가 정한 역할(`status` 또는 `alert`).
  final SemanticsRole role;

  /// IA 슬롯 id.
  final String? identifier;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            width: 1,
            height: 1,
            child: LiveAnnouncement(
              identifier: identifier,
              label: label,
              role: role,
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
