import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';

/// `onboard-time` 수정 모드(`?mode=edit`, A19)의 시작 값(`push`의 `extra`).
///
/// 정보 수정은 생일을 화면 안에서 바꾼 뒤(아직 저장 전) 시간 화면을 열 수 있으므로, 시진 확인
/// (D58)에 쓸 생일 [date]를 시각과 함께 넘깁니다. 둘 다 null이면 프로필 사본 값입니다.
/// 돌려주는 값은 그대로 `BirthTime`입니다.
@immutable
final class TimeStepEdit {
  /// 시작 값을 만듭니다.
  const new({this.time, this.date});

  /// 휠이 시작할 태어난 시간.
  final BirthTime? time;

  /// 시진 확인에 보낼 생일.
  final BirthDateValue? date;

  @override
  bool operator ==(Object other) =>
      other is TimeStepEdit && other.time == time && other.date == date;

  @override
  int get hashCode => Object.hash(time, date);
}
