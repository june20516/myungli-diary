import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_at.dart';

/// 만세력 신살 칸 안의 무리. 열거 순서가 칸 안 순서입니다(`band-table`
/// `bands.shinsal.order`, 결정 V121).
enum ShinsalPlace {
  /// 천간 자리 신살(천덕, 월덕, 삼기).
  stem,

  /// 일주 신살(천간과 지지에 걸침: 괴강, 십악대패, 음착양차).
  pillar,

  /// 지지 자리 신살.
  branch,
}

/// 한 칸에 놓인 신살 하나와 그 무리.
typedef ShinsalCellItem = ({ShinsalAt shinsal, ShinsalPlace place});

/// [stem], [branch] 자리의 기둥 칸에 놓일 신살을 칸 안 순서대로 돌려줍니다(D124 ①, V121).
///
/// * 신살은 걸친 자리(`ShinsalAt.positions`)의 기둥마다 그 칸에 하나입니다. 천간 자리도 그
///   기둥 칸이고, 일주 신살은 일주 칸 하나, 세 기둥에 걸친 삼기는 세 칸마다 하나입니다.
/// * 무리는 그 기둥에 걸친 자리로 정합니다. 천간과 지지에 모두 걸치면 일주 신살, 천간만이면
///   천간 자리, 지지만이면 지지 자리입니다. 신살 이름으로 고르지 않습니다.
/// * 칸 안은 무리 순서([ShinsalPlace]) → 무리 안 계약 `ShinsalKind` 열거 순서입니다.
/// * 같은 칸에 같은 신살이 두 번 오면 `(kind, 기둥)` 키로 처음 것 하나만 둡니다. 받은
///   데이터를 고치지 않고 그리는 단계에서만 거릅니다.
/// * 모르는 신살(열린 enum)과 `positions`가 비었거나 이 기둥에 걸치지 않은 신살은 놓지
///   않습니다. 빈 `positions`는 오류가 아니라 칸에 자리가 없는 것입니다.
List<ShinsalCellItem> shinsalInPillar(
  Iterable<ShinsalAt> shinsal, {
  required Position stem,
  required Position branch,
}) {
  final seen = <Object>{};
  final items = <ShinsalCellItem>[];
  for (final item in shinsal) {
    if (!item.kind.isKnown) continue;
    final onStem = item.positions.contains(stem);
    final onBranch = item.positions.contains(branch);
    final place = switch ((onStem, onBranch)) {
      (true, true) => ShinsalPlace.pillar,
      (true, false) => ShinsalPlace.stem,
      (false, true) => ShinsalPlace.branch,
      (false, false) => null,
    };
    // 칸이 기둥 하나라 (kind, 기둥) 키는 이 칸 안에서 kind와 같습니다.
    if (place == null || !seen.add(item.kind)) continue;
    items.add((shinsal: item, place: place));
  }
  // 칸 안 kind가 하나씩이라 (무리, kind) 순서로 모두 정해집니다.
  return items..sort((a, b) {
    final byPlace = a.place.index.compareTo(b.place.index);
    return byPlace != 0
        ? byPlace
        : a.shinsal.kind.index.compareTo(b.shinsal.kind.index);
  });
}
