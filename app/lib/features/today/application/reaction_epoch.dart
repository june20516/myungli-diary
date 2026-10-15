import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 반응이 server에서 확인된 횟수(확인 세대).
///
/// 반응이 확인될 때마다 올라갑니다. 오늘 응답은 받기 시작한 시점의 세대를 함께 들고 와,
/// 그 응답이 어느 반응 확인보다 앞서 시작했는지(그 확인이 반영되지 않았을 수 있는지)를
/// 가립니다. `DailyController`와 `ReactionController`가 같은 값을 보도록 따로 둡니다.
final class ReactionEpoch {
  int _value = 0;

  /// 지금까지 확인된 횟수.
  int get value => _value;

  /// 반응이 확인됐을 때 부르고, 올린 세대를 돌려줍니다.
  int advance() => ++_value;
}

/// 확인 세대 하나(앱 실행 동안 같은 값).
final reactionEpochProvider = Provider<ReactionEpoch>((ref) => ReactionEpoch());
