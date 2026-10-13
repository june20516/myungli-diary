import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/term_mark.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _heart = AppGlyph(
  light: PhosphorIconsLight.heart,
  regular: PhosphorIconsRegular.heart,
);

Widget _app(Widget child) => MaterialApp(
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppIcon', () {
    testWidgets('light·regular는 해당 굵기 글꼴로 그립니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              AppIcon(_heart),
              AppIcon(_heart, weight: AppIconWeight.regular),
            ],
          ),
        ),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons[0].icon!.fontFamily, 'Phosphor-Light');
      expect(icons[1].icon!.fontFamily, 'Phosphor-Regular');
    });

    test('공개 굵기 타입은 light·regular뿐입니다(fill은 caution 전용)', () {
      expect(AppIconWeight.values, [
        AppIconWeight.light,
        AppIconWeight.regular,
      ]);
    });

    testWidgets('caution은 주변 글자 높이·색을 따릅니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 20, color: Color(0xFF123456)),
              child: AppIcon.caution(),
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, closeTo(20 * 2 * AppIcon.capHeightRatio, 0.001));
      expect(icon.color, const Color(0xFF123456));
      expect(icon.icon!.fontFamily, 'Phosphor-Fill');
      expect(icon.icon, PhosphorIconsFill.warningCircle);
    });

    testWidgets('크기: tab·bar 24, inline 16, state 28', (tester) async {
      expect(AppIconSize.tab.logical, 24);
      expect(AppIconSize.bar.logical, 24);
      expect(AppIconSize.inline.logical, 16);
      expect(AppIconSize.state.logical, 28);
    });
  });

  group('Seal', () {
    testWidgets('fill: 글자는 knock, 아이콘은 on-primary', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              Seal(size: SealSize.paper, child: Text('13')),
              Seal(size: SealSize.row, child: AppIcon(_heart)),
            ],
          ),
        ),
      );
      const colors = lightColors;
      final text = tester.widget<Text>(find.text('13'));
      final style = DefaultTextStyle.of(tester.element(find.text('13'))).style;
      expect(text.style, isNull);
      expect(style.color, colors.sealKnock);
      final iconTheme = IconTheme.of(tester.element(find.byType(Icon)));
      expect(iconTheme.color, colors.actionOnPrimary);
    });

    testWidgets('soft: 글자·아이콘 모두 본문색', (tester) async {
      await tester.pumpWidget(
        _app(
          const Seal(
            size: SealSize.row,
            variant: SealVariant.soft,
            child: AppIcon(_heart),
          ),
        ),
      );
      expect(
        IconTheme.of(tester.element(find.byType(Icon))).color,
        lightColors.textPrimary,
      );
    });

    testWidgets('크기 안에 내용이 가운데 놓입니다', (tester) async {
      await tester.pumpWidget(
        _app(const Seal(size: SealSize.paper, child: Text('13'))),
      );
      expect(tester.getSize(find.byType(Seal)), const Size(64, 64));
      expect(
        tester.getCenter(find.text('13')).dx,
        closeTo(tester.getCenter(find.byType(Seal)).dx, 0.5),
      );
    });

    test('크기는 26·34·52·64', () {
      expect(SealSize.values.map((s) => s.logical), [26, 34, 52, 64]);
    });
  });

  group('SkeletonBone', () {
    testWidgets('주어진 크기이고 스크린리더에서 빠집니다', (tester) async {
      await tester.pumpWidget(
        _app(const SkeletonBone(width: 120, height: 16, borderRadius: 4)),
      );
      expect(tester.getSize(find.byType(SkeletonBone)), const Size(120, 16));
      expect(
        find.descendant(
          of: find.byType(SkeletonBone),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('TermMark', () {
    testWidgets('글자를 굵게 하지 않고 가로 3px 안쪽 여백을 둡니다', (tester) async {
      await tester.pumpWidget(_app(const TermMark('식신')));
      final text = tester.widget<Text>(find.text('식신'));
      expect(text.style?.fontWeight, isNull);
      expect(
        tester.getSize(find.byType(TermMark)).width,
        tester.getSize(find.text('식신')).width + 6,
      );
    });
  });

  group('LockVeil', () {
    test('lengthHint는 양수여야 합니다', () {
      const hint = 0;
      expect(
        () => LockVeil(title: 't', semanticLabel: 't', lengthHint: hint),
        throwsAssertionError,
      );
    });

    testWidgets('제목은 또렷하고 본문은 흐리며 읽지 않습니다', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const LockVeil(title: '판정 근거', semanticLabel: '판정 근거, 잠김')),
      );
      expect(find.text('판정 근거'), findsOneWidget);
      expect(find.bySemanticsLabel('판정 근거, 잠김'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
      final filtered = tester.widget<ImageFiltered>(find.byType(ImageFiltered));
      expect(filtered.enabled, isTrue);
      expect(
        find.descendant(
          of: find.byType(LockVeil),
          matching: find.byType(SelectionContainer),
        ),
        findsWidgets,
      );
      semantics.dispose();
    });

    testWidgets('길이 힌트가 없으면 본문이 두 줄입니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            child: LockVeil(title: 't', semanticLabel: 't, 잠김'),
          ),
        ),
      );
      final body = find.byKey(LockVeil.bodyKey);
      final text = tester.widget<Text>(
        find.descendant(of: body, matching: find.byType(Text)),
      );
      expect(text.maxLines, 2);
    });

    testWidgets('길이 힌트가 있으면 그 글자 수만큼 채웁니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 200,
            child: LockVeil(title: 't', semanticLabel: 't, 잠김', lengthHint: 37),
          ),
        ),
      );
      final body = find.byKey(LockVeil.bodyKey);
      final text = tester.widget<Text>(
        find.descendant(of: body, matching: find.byType(Text)),
      );
      expect(text.data!.characters.length, 37);
      expect(text.maxLines, isNull);
    });
  });
}
