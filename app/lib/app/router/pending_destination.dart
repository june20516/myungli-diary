import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 진입 계산(launch) 전에 들어온 목적지 위치(경로와 query)를 기억했다가 계산 뒤 한 번
/// 돌려줍니다.
///
/// 딥링크나 알림 열기가 진입 계산 전에 오면 라우터가 `/launch`로 모으면서 원래 위치를
/// [remember]하고, 계산이 끝나 `/launch`를 떠날 때 [take]로 꺼냅니다. query(예
/// `?mode=edit`)도 그대로 둡니다. 그 위치가 갈래에서 허용되는지는 `entryRedirect`가 가립니다.
class PendingDestination extends Notifier<String?> {
  @override
  String? build() => null;

  /// [location]을 기억합니다. 이미 기억한 위치가 있으면 마지막 것으로 바꿉니다.
  // 기억하기는 take와 짝을 이루는 동작이라 setter가 아닌 메서드로 둡니다.
  // ignore: use_setters_to_change_properties
  void remember(String location) => state = location;

  /// 기억한 위치를 꺼내고 비웁니다. 없으면 null입니다.
  String? take() {
    final location = state;
    state = null;
    return location;
  }
}

/// 진입 계산 뒤 돌아갈 목적지.
final pendingDestinationProvider =
    NotifierProvider<PendingDestination, String?>(PendingDestination.new);
