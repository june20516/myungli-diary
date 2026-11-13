import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 보고 있는 탭을 탭 바에서 다시 누른 일 하나.
///
/// [root]는 그 탭의 첫 화면 id(`tabRoots`)이고, [serial]은 누를 때마다 늘어 같은 탭을 연달아
/// 눌러도 듣는 쪽이 매번 알아챕니다.
final class TabReselect {
  /// 다시 누른 일을 만듭니다.
  const new({required this.root, required this.serial});

  /// 다시 누른 탭의 첫 화면 id.
  final String root;

  /// 다시 누른 차례(1부터).
  final int serial;
}

/// 탭 다시 누르기를 탭 첫 화면에 알립니다(V104, V127).
///
/// 탭 셸이 쌓인 화면을 걷은 뒤(`goBranch(initialLocation: true)`) [reselect]를 부르고, 첫
/// 화면은 자기 맨 위로 돌아갈 일이 있으면 듣습니다. 달력은 오늘이 든 달과 오늘 칸으로
/// 갑니다(`calendar-month` `todayReselect`).
class TabReselectNotifier extends Notifier<TabReselect?> {
  @override
  TabReselect? build() => null;

  /// [root] 탭을 다시 눌렀다고 알립니다.
  void reselect(String root) =>
      state = TabReselect(root: root, serial: (state?.serial ?? 0) + 1);
}

/// 마지막 탭 다시 누르기. 아직 없으면 null입니다.
final tabReselectProvider = NotifierProvider<TabReselectNotifier, TabReselect?>(
  TabReselectNotifier.new,
);
