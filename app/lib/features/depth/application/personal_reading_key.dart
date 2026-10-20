import 'package:flutter/foundation.dart' show immutable;
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';

/// 근거 시트의 "내 사주에서는"(`evidence-sheet.personal.body`)에 보일 원국 개인 해석의 자리(A58).
///
/// 사주 표·만세력·대운 표에서 누른 용어의 (`kind`, `position`, `index`, `shinsal`)입니다. 계약의
/// 각 필드는 [kind]에 따라 있거나 없고(`PersonalReading` 설명), 없는 값은 비교하지 않습니다.
/// 원국 개인 해석은 나의 사주 응답(`Chart.personalReadings`)에만 있습니다.
@immutable
final class PersonalReadingKey {
  /// [kind] 항목의 자리를 만듭니다.
  const new({required this.kind, this.position, this.index, this.shinsal});

  /// 항목 종류.
  final PersonalReadingKindEnum kind;

  /// 원국 자리(원국 항목만).
  final Position? position;

  /// 지장간·대운·세운 순서(그 kind만).
  final int? index;

  /// 신살(신살 항목만).
  final ShinsalKind? shinsal;

  @override
  bool operator ==(Object other) =>
      other is PersonalReadingKey &&
      other.kind == kind &&
      other.position == position &&
      other.index == index &&
      other.shinsal == shinsal;

  @override
  int get hashCode => Object.hash(kind, position, index, shinsal);
}
