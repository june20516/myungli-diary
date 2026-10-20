import 'dart:async';

import 'package:flutter/widgets.dart';

/// 화면·시트·확인 창을 여는 동작을 한 번에 하나만 받는 [State] mixin.
///
/// 빠른 두 번 누르기(같은 프레임의 두 번째 누름 포함)로 같은 화면을 두 번 열거나 같은 요청을 두 번
/// 보내지 않게 합니다. 줄·버튼의 `onTap`에서 [guardOpen]으로 감쌉니다. 설정·정보 수정·약관·계정
/// 삭제 화면이 함께 씁니다.
mixin SingleOpenGuard<T extends StatefulWidget> on State<T> {
  bool _opening = false;

  /// 연 동작(열기와 그 뒤 처리)이 아직 끝나지 않았는지.
  bool get isOpening => _opening;

  /// [action]이 끝날 때까지 다른 동작을 받지 않습니다. 이미 진행 중이면 [action]을 버립니다.
  ///
  /// [action]의 오류는 [action] 안에서 처리합니다(화면이 toast 등으로 알림).
  void guardOpen(Future<void> Function() action) {
    if (_opening) return;
    _opening = true;
    unawaited(Future.sync(action).whenComplete(() => _opening = false));
  }
}
