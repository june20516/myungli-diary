import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/saju/stage_strip.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../input/input_harness.dart';

const Map<TwelveStage, String> _names = {
  TwelveStage.jangsaeng: '장생',
  TwelveStage.mokyok: '목욕',
  TwelveStage.gwandae: '관대',
  TwelveStage.geonrok: '건록',
  TwelveStage.jewang: '제왕',
  TwelveStage.soe: '쇠',
  TwelveStage.byeong: '병',
  TwelveStage.sa: '사',
  TwelveStage.myo: '묘',
  TwelveStage.jeol: '절',
  TwelveStage.tae: '태',
  TwelveStage.yang: '양',
};

/// 하늘님 예: 월주 장생, 연주 목욕, 시주 관대, 일주 양.
const Map<PillarPosition, TwelveStage> _haneul = {
  PillarPosition.month: TwelveStage.jangsaeng,
  PillarPosition.year: TwelveStage.mokyok,
  PillarPosition.hour: TwelveStage.gwandae,
  PillarPosition.day: TwelveStage.yang,
};

Widget _strip(
  Map<PillarPosition, TwelveStage> positions, {
  double width = 336,
}) => SizedBox(
  width: width,
  child: StageStrip(positions: positions, stageNames: _names),
);

void main() {
  testWidgets('열두 칸은 높이 6, 사이 space.2이고 내 자리만 action.primary입니다', (
    tester,
  ) async {
    await tester.pumpWidget(inputApp(_strip(_haneul)));
    final context = tester.element(find.byType(StageStrip));
    final colors = context.tokens.colors;
    final rects = [
      for (final stage in StageStrip.order)
        tester.getRect(find.byKey(StageStrip.cellKey(stage))),
    ];
    for (final rect in rects) {
      expect(rect.height, 6);
    }
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left - rects[i - 1].right, moreOrLessEquals(Space.s2));
    }
    Color? fill(TwelveStage stage) =>
        ((tester
                    .widget<DecoratedBox>(find.byKey(StageStrip.cellKey(stage)))
                    .decoration)
                as BoxDecoration)
            .color;
    for (final stage in StageStrip.order) {
      final mine = _haneul.containsValue(stage);
      expect(
        fill(stage),
        mine ? colors.actionPrimary : colors.line,
        reason: '$stage',
      );
    }
  });

  testWidgets('내 자리 칸 위에 원 18 꼬리표(시/일/월/연), 아래에 단계 이름', (tester) async {
    await tester.pumpWidget(inputApp(_strip(_haneul)));
    final context = tester.element(find.byType(StageStrip));
    final l10n = AppLocalizations.of(context);
    for (final (position, label) in [
      (PillarPosition.hour, l10n.sajuStageMarkerHour),
      (PillarPosition.day, l10n.sajuStageMarkerDay),
      (PillarPosition.month, l10n.sajuStageMarkerMonth),
      (PillarPosition.year, l10n.sajuStageMarkerYear),
    ]) {
      final marker = find.byKey(StageStrip.markerKey(position));
      expect(tester.getSize(marker), const Size(18, 18));
      expect(
        find.descendant(of: marker, matching: find.text(label)),
        findsOneWidget,
      );
      final cell = tester.getRect(
        find.byKey(StageStrip.cellKey(_haneul[position]!)),
      );
      expect(
        tester.getRect(marker).center.dx,
        moreOrLessEquals(cell.center.dx, epsilon: 0.5),
      );
      expect(tester.getRect(marker).bottom, lessThanOrEqualTo(cell.top));
    }
    // 단계 이름은 칸 아래.
    final name = tester.getRect(find.text('장생'));
    expect(
      name.top,
      greaterThanOrEqualTo(
        tester
            .getRect(find.byKey(StageStrip.cellKey(TwelveStage.jangsaeng)))
            .bottom,
      ),
    );
  });

  testWidgets('스크린리더는 내 자리가 있는 단계만 막대 순서로 하나로 읽습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(inputApp(_strip(_haneul)));
    final context = tester.element(find.byType(StageStrip));
    final l10n = AppLocalizations.of(context);
    // ARB 틀(a11yListSeparator, 기둥 이름)로 조립한 값과 같습니다.
    final expected = [
      '장생${l10n.a11yListSeparator}${l10n.sajuPillarMonth}',
      '목욕${l10n.a11yListSeparator}${l10n.sajuPillarYear}',
      '관대${l10n.a11yListSeparator}${l10n.sajuPillarHour}',
      '양${l10n.a11yListSeparator}${l10n.sajuPillarDay}',
    ].join(' / ');
    expect(expected, '장생, 월주 / 목욕, 연주 / 관대, 시주 / 양, 일주');
    expect(find.bySemanticsLabel(expected), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^사,')), findsNothing);
    handle.dispose();
  });

  testWidgets('같은 단계에 자리가 둘이면 시, 일, 월, 연 순서로 나란히 읽고 그립니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      inputApp(
        _strip({
          PillarPosition.year: TwelveStage.tae,
          PillarPosition.hour: TwelveStage.tae,
        }),
      ),
    );
    final hour = tester.getRect(
      find.byKey(StageStrip.markerKey(PillarPosition.hour)),
    );
    final year = tester.getRect(
      find.byKey(StageStrip.markerKey(PillarPosition.year)),
    );
    expect(year.left - hour.right, Space.s2);
    expect(find.bySemanticsLabel('태, 시주, 연주'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('트랙 양 끝 밖으로는 자리 표시가 나가지 않습니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _strip({
            for (final position in PillarPosition.values)
              position: TwelveStage.jangsaeng,
          }, width: 300),
        ),
      ),
    );
    final track = tester.getRect(find.byType(StageStrip));
    for (final position in PillarPosition.values) {
      final rect = tester.getRect(find.byKey(StageStrip.markerKey(position)));
      expect(rect.left, greaterThanOrEqualTo(track.left - 0.01));
      expect(rect.right, lessThanOrEqualTo(track.right + 0.01));
    }
  });

  testWidgets('시간 모름이면 시주 자리 표시는 그리지 않습니다', (tester) async {
    await tester.pumpWidget(
      inputApp(_strip({PillarPosition.day: TwelveStage.yang})),
    );
    expect(find.byKey(StageStrip.markerKey(PillarPosition.hour)), findsNothing);
    expect(
      find.byKey(StageStrip.markerKey(PillarPosition.day)),
      findsOneWidget,
    );
  });

  testWidgets('칸 폭에 이름이 안 들어가는 언어는 내 자리 이름만 보입니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        SizedBox(
          width: 336,
          child: StageStrip(
            positions: const {PillarPosition.day: TwelveStage.yang},
            stageNames: {
              for (final stage in StageStrip.order)
                stage: 'Long ${stage.value}',
            },
          ),
        ),
      ),
    );
    expect(find.text('Long yang'), findsOneWidget);
    expect(find.text('Long jangsaeng'), findsNothing);
  });

  testWidgets('loading 뼈는 트랙 전체 폭, 높이 6입니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        SizedBox(width: 300, child: StageStrip.skeleton(animated: false)),
      ),
    );
    expect(tester.getSize(find.byType(SkeletonBone)), const Size(300, 6));
  });

  testWidgets('트랙 양 끝 칸의 내 자리 이름이 칸보다 넓어도 트랙 밖으로 나가지 않습니다', (tester) async {
    await tester.pumpWidget(
      inputApp(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: 300,
            child: StageStrip(
              positions: const {
                PillarPosition.month: TwelveStage.jangsaeng,
                PillarPosition.day: TwelveStage.yang,
              },
              stageNames: {
                for (final stage in StageStrip.order)
                  stage: 'Long ${stage.value}',
              },
            ),
          ),
        ),
      ),
    );
    final track = tester.getRect(find.byType(StageStrip));
    for (final name in ['Long jangsaeng', 'Long yang']) {
      final rect = tester.getRect(find.text(name));
      expect(rect.left, greaterThanOrEqualTo(track.left - 0.01), reason: name);
      expect(rect.right, lessThanOrEqualTo(track.right + 0.01), reason: name);
    }
  });
}
