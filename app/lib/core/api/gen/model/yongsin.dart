//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:myungli_diary/core/api/gen/model/yongsin_method.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'yongsin.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Yongsin {
  /// Returns a new [Yongsin] instance.
  Yongsin({
    required this.yongsin,

    required this.huisin,

    required this.gisin,

    required this.tonggwan,

    required this.method,

    this.johuStem,

    this.basis,
  });

  @JsonKey(name: r'yongsin', required: true, includeIfNull: false)
  final FiveElement yongsin;

  @JsonKey(name: r'huisin', required: true, includeIfNull: false)
  final FiveElement huisin;

  @JsonKey(name: r'gisin', required: true, includeIfNull: false)
  final FiveElement gisin;

  @JsonKey(name: r'tonggwan', required: true, includeIfNull: false)
  final FiveElement tonggwan;

  @JsonKey(
    name: r'method',
    required: true,
    includeIfNull: false,
    unknownEnumValue: YongsinMethod.unknownDefaultOpenApi,
  )
  final YongsinMethod method;

  @JsonKey(name: r'johuStem', required: false, includeIfNull: false)
  final Stem? johuStem;

  @JsonKey(name: r'basis', required: false, includeIfNull: false)
  final SlotText? basis;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Yongsin &&
          other.yongsin == yongsin &&
          other.huisin == huisin &&
          other.gisin == gisin &&
          other.tonggwan == tonggwan &&
          other.method == method &&
          other.johuStem == johuStem &&
          other.basis == basis;

  @override
  int get hashCode =>
      yongsin.hashCode +
      huisin.hashCode +
      gisin.hashCode +
      tonggwan.hashCode +
      method.hashCode +
      johuStem.hashCode +
      basis.hashCode;

  factory Yongsin.fromJson(Map<String, dynamic> json) =>
      _$YongsinFromJson(json);

  Map<String, dynamic> toJson() => _$YongsinToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
