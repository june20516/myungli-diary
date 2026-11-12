import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:myungli_diary/design/components/feedback/skeleton.dart';

/// 오류 화면의 다시 시도를 누른 뒤 skeleton을 붙잡아 두는 일(결정 A126 ①, #922).
///
/// error-state 규칙 "다시 시도를 누르면 그 자리에 skeleton이 다시 나온다"를 화면 단위
/// (`ScreenStateView`)와 섹션 단위(나 탭 회고, 달력 달 오류)가 같은 방식으로 따르게 합니다.
///
/// * 누르면 지연 없이 skeleton입니다(처음 불러오기의 [SkeletonBlock.defaultDelay]는 쓰지 않음).
/// * 결과가 곧바로 와도 [minDuration]만큼은 skeleton을 둬, 곧바로 다시 실패해도 누른 것이 보입니다.
/// * 다시 시도가 [Future]를 돌려주면 그 끝까지 skeleton입니다(값을 loading으로 바꾸지 않고 다시
///   받는 controller가 skeleton 뒤에 이전 오류를 다시 비추지 않게).
/// * 값이 받는 중이면 skeleton입니다. Riverpod `invalidate` 뒤의 값은 이전 오류를 품은 채
///   받는 중(`hasError && isLoading`)이라, 쓰는 쪽은 그 상태를 오류로 그리지 않습니다.
///
/// 상태를 가진 위젯이 하나 만들어 [dispose]까지 들고, [onChanged]에 자기 `setState`를 넘깁니다.
final class RetryHold {
  /// [onChanged]는 붙잡기가 풀릴 수 있을 때 불립니다(쓰는 쪽이 다시 그림).
  new({required this.onChanged, this.minDuration = defaultMinDuration});

  /// 다시 시도 skeleton의 최소 시간 기본값. skeleton 계약이 "보이지 않을 만큼 짧다"고 보는
  /// 시간([SkeletonBlock.defaultDelay])과 같게 두어, 그보다 짧으면 누른 것이 보이지 않습니다.
  static const Duration defaultMinDuration = SkeletonBlock.defaultDelay;

  /// 다시 그리기 요청(쓰는 쪽의 `setState`).
  final VoidCallback onChanged;

  /// 다시 시도를 누른 뒤 skeleton을 두는 최소 시간. [start]가 따로 받으면 그 값을 씁니다.
  final Duration minDuration;

  /// 다시 시도를 누른 뒤 아직 결과를 보이지 않았는지.
  bool _retrying = false;

  /// 최소 시간 타이머. 도는 동안은 결과가 와도 skeleton입니다.
  Timer? _timer;

  /// 다시 시도가 돌려준 일이 아직 끝나지 않았는지.
  bool _pending = false;

  bool _disposed = false;

  /// [retry]를 부르고 skeleton 붙잡기를 시작합니다. 부른 쪽이 바로 다시 그립니다. 최소 시간은
  /// [minDuration] 인자가 있으면 그것, 없으면 생성 때 값입니다.
  void start(FutureOr<void> Function() retry, {Duration? minDuration}) {
    _timer?.cancel();
    _timer = Timer(minDuration ?? this.minDuration, () {
      _timer = null;
      _changed();
    });
    _retrying = true;
    final pending = retry();
    if (pending is Future<void>) {
      _pending = true;
      unawaited(
        pending.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
          _pending = false;
          _changed();
        }),
      );
    }
    _changed();
  }

  /// 지금 skeleton을 보여야 하는지. 값이 받는 중([isLoading])이면 붙잡고, 최소 시간과 돌려준 일이
  /// 모두 끝났고 받는 중도 아니면 붙잡기를 풉니다.
  bool holds({required bool isLoading}) {
    if (!_retrying) return false;
    if (_timer != null || _pending || isLoading) return true;
    _retrying = false;
    return false;
  }

  /// 타이머를 멈춥니다. 쓰는 위젯의 `dispose`에서 부릅니다.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _changed() {
    if (!_disposed) onChanged();
  }
}
