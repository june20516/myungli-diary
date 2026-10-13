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
