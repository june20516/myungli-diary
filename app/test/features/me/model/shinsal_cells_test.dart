import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_at.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/features/me/model/shinsal_cells.dart';

ShinsalAt _at(ShinsalKind kind, List<Position> positions, {Position? at}) =>
    ShinsalAt(kind: kind, position: at ?? positions.last, positions: positions);

List<ShinsalKind> _kinds(
  List<ShinsalAt> shinsal, {
  required Position stem,
  required Position branch,
}) => [
  for (final item in shinsalInPillar(shinsal, stem: stem, branch: branch))
    item.shinsal.kind,
];

List<ShinsalKind> _day(List<ShinsalAt> shinsal) =>
    _kinds(shinsal, stem: Position.dayStem, branch: Position.dayBranch);

void main() {
  test('한 칸 다섯: 천간 자리 → 일주 신살 → 지지 자리, 무리 안은 계약 열거 순서', () {
    // member fixture 일주 칸과 같은 구성을 받은 순서를 섞어 줍니다.
    final shinsal = [
      _at(ShinsalKind.gwasuk, [Position.dayBranch]),
      _at(ShinsalKind.sipakDaepae, [Position.dayStem, Position.dayBranch]),
      _at(ShinsalKind.hwagae, [Position.dayBranch]),
      _at(ShinsalKind.goegang, [Position.dayStem, Position.dayBranch]),
      _at(ShinsalKind.woldeok, [Position.dayStem]),
      _at(ShinsalKind.amrok, [Position.monthBranch]),
    ];
    final items = shinsalInPillar(
      shinsal,
      stem: Position.dayStem,
      branch: Position.dayBranch,
    );
    expect(
      [for (final item in items) item.shinsal.kind],
      [
        ShinsalKind.woldeok,
        ShinsalKind.goegang,
        ShinsalKind.sipakDaepae,
        ShinsalKind.hwagae,
        ShinsalKind.gwasuk,
      ],
    );
    expect(
      [for (final item in items) item.place],
      [
        ShinsalPlace.stem,
        ShinsalPlace.pillar,
        ShinsalPlace.pillar,
        ShinsalPlace.branch,
        ShinsalPlace.branch,
      ],
    );
  });

  test('일주 신살은 일주 칸 하나에만 놓입니다', () {
    final shinsal = [
      _at(ShinsalKind.goegang, [Position.dayStem, Position.dayBranch]),
    ];
    expect(_day(shinsal), [ShinsalKind.goegang]);
    for (final (stem, branch) in [
      (Position.hourStem, Position.hourBranch),
      (Position.monthStem, Position.monthBranch),
      (Position.yearStem, Position.yearBranch),
    ]) {
      expect(_kinds(shinsal, stem: stem, branch: branch), isEmpty);
    }
  });

  test('삼기는 걸친 세 칸마다 하나이고 어느 칸이든 대표 자리를 그대로 둡니다', () {
    final samgi = _at(ShinsalKind.samgi, [
      Position.yearStem,
      Position.monthStem,
      Position.dayStem,
    ], at: Position.yearStem);
    for (final (stem, branch) in [
      (Position.dayStem, Position.dayBranch),
      (Position.monthStem, Position.monthBranch),
      (Position.yearStem, Position.yearBranch),
    ]) {
      final items = shinsalInPillar([samgi], stem: stem, branch: branch);
      expect(items.single.shinsal.position, Position.yearStem);
      expect(items.single.place, ShinsalPlace.stem);
    }
    expect(
      _kinds([samgi], stem: Position.hourStem, branch: Position.hourBranch),
      isEmpty,
    );
  });

  test('같은 칸 같은 신살은 (kind, 기둥)으로 처음 것 하나만, 다른 기둥은 따로', () {
    final first = _at(ShinsalKind.woldeok, [Position.dayStem]);
    final shinsal = [
      first,
      _at(ShinsalKind.woldeok, [Position.dayBranch]),
      _at(ShinsalKind.woldeok, [Position.yearStem]),
    ];
    final items = shinsalInPillar(
      shinsal,
      stem: Position.dayStem,
      branch: Position.dayBranch,
    );
    expect(items.single.shinsal, same(first));
    expect(
      _kinds(shinsal, stem: Position.yearStem, branch: Position.yearBranch),
      [ShinsalKind.woldeok],
    );
  });

  test('positions가 비었거나 모르는 신살(열린 enum)은 칸에 놓지 않습니다', () {
    final shinsal = [
      _at(ShinsalKind.dohwa, [], at: Position.dayBranch),
      _at(ShinsalKind.unknownDefaultOpenApi, [Position.dayBranch]),
      _at(ShinsalKind.yeokma, [Position.dayBranch]),
    ];
    expect(_day(shinsal), [ShinsalKind.yeokma]);
  });
}
