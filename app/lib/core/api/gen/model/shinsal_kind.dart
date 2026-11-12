//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// 원국 신살 종류입니다. 열린 enum입니다. `cheondeok`(천덕귀인)부터 `amrok`(암록)까지 열셋은 D124 ①로 1.11.0에서 더했고, 규칙 버전 2026.11.7부터 나옵니다. 이 가운데 고신, 과숙, 원진은 오늘 사주 기운 태그(`gosin`, `gwasuk`, `wonjin`)로도 나옵니다.
enum ShinsalKind {
  @JsonValue(r'cheoneul_gwiin')
  cheoneulGwiin(r'cheoneul_gwiin'),
  @JsonValue(r'dohwa')
  dohwa(r'dohwa'),
  @JsonValue(r'yeokma')
  yeokma(r'yeokma'),
  @JsonValue(r'hwagae')
  hwagae(r'hwagae'),
  @JsonValue(r'yangin')
  yangin(r'yangin'),
  @JsonValue(r'gongmang')
  gongmang(r'gongmang'),
  @JsonValue(r'cheondeok')
  cheondeok(r'cheondeok'),
  @JsonValue(r'woldeok')
  woldeok(r'woldeok'),
  @JsonValue(r'geumyeo')
  geumyeo(r'geumyeo'),
  @JsonValue(r'gosin')
  gosin(r'gosin'),
  @JsonValue(r'gwasuk')
  gwasuk(r'gwasuk'),
  @JsonValue(r'wonjin')
  wonjin(r'wonjin'),
  @JsonValue(r'gugyo')
  gugyo(r'gugyo'),
  @JsonValue(r'cheonra_jimang')
  cheonraJimang(r'cheonra_jimang'),
  @JsonValue(r'goegang')
  goegang(r'goegang'),
  @JsonValue(r'sipak_daepae')
  sipakDaepae(r'sipak_daepae'),
  @JsonValue(r'eumchak_yangcha')
  eumchakYangcha(r'eumchak_yangcha'),
  @JsonValue(r'samgi')
  samgi(r'samgi'),
  @JsonValue(r'amrok')
  amrok(r'amrok'),

  /// 계약에 아직 없는 값. 열린 enum이라 모르는 값은 응답 decode를 실패시키지 않고 이 값이 됩니다(결정 A66).
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ShinsalKind(this.value);

  final String value;

  /// 계약이 정한 값이면 true, 모르는 값([unknownDefaultOpenApi])이면 false입니다.
  bool get isKnown => this != unknownDefaultOpenApi;

  @override
  String toString() => value;
}
