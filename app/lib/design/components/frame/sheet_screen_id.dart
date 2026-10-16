import 'package:flutter/widgets.dart';

/// 시트 뿌리에 IA 화면 id를 Key와 Semantics `identifier`로 붙입니다(spec §6.6).
///
/// page 화면의 id 부착과 같은 방식이라 UI 테스트가 시트도 같은 id로 찾습니다.
class SheetScreenId extends StatelessWidget {
  /// [screenId]를 [child]에 붙입니다.
  const new({required this.screenId, required this.child, super.key});

  /// IA 화면 id.
  final String screenId;

  /// 시트 내용.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: Key(screenId),
      child: Semantics(identifier: screenId, child: child),
    );
  }
}
