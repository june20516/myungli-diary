import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';

/// 뜻 아래 신살 마무리 한 줄(`explain-sheet` `weighingNote`, D124 ⑦, 결정 V120, V125)을 둘
/// 신살입니다.
///
/// 목록의 주인은 design 계약 `frame.json` `explain-sheet.parts.weighingNote.targets`
/// (7.6.0, 열하나)이고, 계약이 "app은 이 목록을 상수로 씀"이라고 정합니다(#1091). 확정 일곱은
/// 지휘(D124 ⑦), 모호한 다섯(도화, 화개, 공망, 양인, 괴강) 가운데 붙는 넷은 writing 판단
/// (W74)입니다. 붙지 않는 신살은 `notTargets`(천을귀인, 천덕, 월덕, 금여, 암록, 삼기, 역마,
/// 화개)입니다. 목록이 바뀌면 이 상수만 고칩니다. 계약과의 대조는 `test/contract/component_contract_test.dart`입니다(A137 ③).
const Set<ShinsalKind> weighingShinsal = {
  ShinsalKind.gosin,
  ShinsalKind.gwasuk,
  ShinsalKind.wonjin,
  ShinsalKind.gugyo,
  ShinsalKind.cheonraJimang,
  ShinsalKind.sipakDaepae,
  ShinsalKind.eumchakYangcha,
  ShinsalKind.dohwa,
  ShinsalKind.gongmang,
  ShinsalKind.yangin,
  ShinsalKind.goegang,
};

/// 용어 [termId]의 뜻 시트에 마무리 한 줄을 두는지.
///
/// 원국 신살 용어(`shinsal.<kind>`)와 같은 신살의 오늘 태그 용어(`tag.<key>`, 태그 키는 신살
/// 값과 같음)가 대상입니다. 다른 범주는 값이 같아도 대상이 아닙니다.
bool hasWeighingNote(String termId) {
  final dot = termId.indexOf('.');
  if (dot < 0) return false;
  final category = termId.substring(0, dot);
  if (category != 'shinsal' && category != 'tag') return false;
  return isWeighingKey(termId.substring(dot + 1));
}

/// 신살 값 또는 오늘 태그 키 [key]가 마무리 한 줄 대상인지.
bool isWeighingKey(String key) =>
    weighingShinsal.any((kind) => kind.value == key);
