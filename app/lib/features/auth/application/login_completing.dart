import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인이 사주 없는 계정의 미리보기 입력을 저장하는 동안 켜 두는 표시입니다(D90 ③, A79).
///
/// 켜져 있으면 라우터는 진입이 `profileRequired`가 되어도 `login`에 머뭅니다. 안 그러면
/// 진입 계산이 끝나는 순간 `onboard-call`로 보내져 저장하는 사이 그 화면을 거치기 때문입니다.
/// 끄면 라우터가 다시 평가해, 저장이 끝났으면 `notify-ask`로 가고 실패했으면 `onboard-call`로
/// 갑니다. 계정과 화면 수명과 상관없이 로그인 시도가 끝나면 반드시 끕니다.
class LoginCompleting extends Notifier<bool> {
  @override
  bool build() => false;

  /// 보류를 켭니다.
  void begin() => state = true;

  /// 보류를 끕니다.
  void end() => state = false;
}

/// 로그인 뒤 저장 동안의 라우터 보류 표시.
final loginCompletingProvider = NotifierProvider<LoginCompleting, bool>(
  LoginCompleting.new,
);
