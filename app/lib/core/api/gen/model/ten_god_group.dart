//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 십성 묶음입니다. `TenGod` 두 개씩을 묶습니다(비겁 bigyeon·geopjae, 식상 siksin·sanggwan, 재성 pyeonjae·jeongjae, 관성 pyeongwan·jeonggwan, 인성 pyeonin·jeongin).
enum TenGodGroup {
  @JsonValue(r'bigyeop')
  bigyeop(r'bigyeop'),
  @JsonValue(r'siksang')
  siksang(r'siksang'),
  @JsonValue(r'jaeseong')
  jaeseong(r'jaeseong'),
  @JsonValue(r'gwanseong')
  gwanseong(r'gwanseong'),
  @JsonValue(r'inseong')
  inseong(r'inseong');

  const TenGodGroup(this.value);

  final String value;

  @override
  String toString() => value;
}
