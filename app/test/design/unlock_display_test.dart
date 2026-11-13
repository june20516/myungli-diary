import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/unlock_mark.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

const _normal = MotionPrefs(
  reduceMotion: false,
  reduceTransparency: false,
  lowEnd: false,
);
const _reduce = MotionPrefs(
  reduceMotion: true,
  reduceTransparency: false,
  lowEnd: false,
);

const _title = '오늘 풀이의 근거';
const _tag = '자정까지 열림';

RenderedText _text(String text) =>
    RenderedText(segments: [Segment(text: text)]);

Widget _app(Widget home, {MotionPrefs prefs = _normal}) => MaterialApp(
  locale: const Locale('ko'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
  home: Scaffold(
    body: MotionPrefsScope(
      prefs: prefs,
      child: Align(alignment: Alignment.topLeft, child: home),
    ),
  ),
);

Widget _sheet({
  DepthLinkState state = DepthLinkState.unlocked,
  String title = _title,
  String? unlockTag = _tag,
  bool loading = false,
  bool showPersonal = true,
  RenderedText? personal,
  String? personalEmpty,
}) => SizedBox(
  width: 360,
  height: 900,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.s24),
    child: EvidenceSheetBody(
      state: state,
      title: title,
      target: _text('대상 문장'),
      pillars: const SizedBox(height: 40, child: Text('원국표')),
      basis: [_text('첫째 근거'), _text('둘째 근거')],
      source: [_text('뜻\n以義推之\n궁통보감 「오행총론」')],
      personal: personal,
      showPersonal: showPersonal,
      personalEmpty: personalEmpty,
      unlockTag: unlockTag,
      loading: loading,
    ),
  ),
);

/// [text]가 [UnlockGlint] 안에 있는지.
bool _inGlint(String text) => find
    .ancestor(
      of: find.text(text, findRichText: true),
      matching: find.byType(UnlockGlint),
    )
    .evaluate()
    .isNotEmpty;

void main() {
  group('근거 시트 열림 꼬리표(unlockTag, V112)', () {
    testWidgets('unlocked면 제목 줄 오른쪽 끝, 제목과 세로 가운데입니다', (tester) async {
      await tester.pumpWidget(_app(_sheet(title: '근거')));
      await tester.pump();

      final tag = find.byKey(const ValueKey(SlotIds.evidenceSheetUnlockUntil));
      expect(find.text(_tag), findsOneWidget);
      final body = tester.getRect(find.byType(EvidenceSheetBody));
      final title = tester.getRect(find.text('근거'));
      final tagRect = tester.getRect(tag);
      expect(tagRect.right, body.right, reason: '오른쪽 끝');
      expect(tagRect.center.dy, closeTo(title.center.dy, 0.5));
      expect(tagRect.height, EvidenceSheetBody.unlockTagHeight);
    });

    testWidgets('제목과 한 줄에 들어가지 않으면 제목 아래 space.8에 왼쪽 맞춤입니다', (tester) async {
      await tester.pumpWidget(
        _app(_sheet(title: '아주 긴 시트 제목이 한 줄을 다 채워서 꼬리표가 들어갈 자리가 없습니다')),
      );
      await tester.pump();

      final tag = tester.getRect(
        find.byKey(const ValueKey(SlotIds.evidenceSheetUnlockUntil)),
      );
      final title = tester.getRect(
        find.textContaining('아주 긴 시트 제목', findRichText: true),
      );
      expect(tag.top - title.bottom, Space.s8);
      expect(tag.left, tester.getRect(find.byType(EvidenceSheetBody)).left);
    });

    testWidgets('잠김, 받는 중, 문구 없음이면 꼬리표가 없습니다', (tester) async {
      for (final sheet in [
        _sheet(state: DepthLinkState.locked),
        _sheet(state: DepthLinkState.unlocking, loading: true),
        // 열린 채 응답을 다시 받는 중(구역 skeleton)에도 꼬리표를 두지 않습니다.
        _sheet(loading: true),
        _sheet(unlockTag: null),
      ]) {
        await tester.pumpWidget(_app(sheet));
        await tester.pump();
        expect(
          find.byKey(const ValueKey(SlotIds.evidenceSheetUnlockUntil)),
          findsNothing,
        );
      }
    });

    testWidgets('스크린리더는 제목 다음에 꼬리표 글자만 읽습니다(시계는 장식)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_sheet(title: '근거')));
      await tester.pump();

      final tag = find.byKey(const ValueKey(SlotIds.evidenceSheetUnlockUntil));
      expect(
        find.descendant(
          of: tag,
          matching: find.byWidgetPredicate(
            (widget) => widget is ExcludeSemantics && widget.child is AppIcon,
          ),
        ),
        findsOneWidget,
      );
      final order = [
        for (final node in tester.semantics.simulatedAccessibilityTraversal())
          if (node.label.isNotEmpty) node.label,
      ];
      expect(order, containsAllInOrder(['근거', _tag]));
      handle.dispose();
    });
  });

  group('근거 시트 반짝임 대상(unlock.glint, D118 ②)', () {
    testWidgets('세 구역 제목과 본문만 반짝이고 시트 제목, 꼬리표, 대상, 원국표는 아닙니다', (tester) async {
      await tester.pumpWidget(_app(_sheet(personal: _text('내 사주 해석'))));
      await tester.pump();

      for (final text in [
        '판정 근거',
        '원전',
        '내 사주에서는',
        '첫째 근거',
        '둘째 근거',
        '以義推之',
        '내 사주 해석',
      ]) {
        expect(_inGlint(text), isTrue, reason: text);
      }
      for (final text in [_title, _tag, '대상 문장', '원국표']) {
        expect(_inGlint(text), isFalse, reason: text);
      }
      expect(
        find.byType(UnlockGlintScope),
        findsOneWidget,
        reason: '시트 하나에 박자 하나',
      );
    });

    testWidgets('빈 해석 안내는 반짝이지 않습니다', (tester) async {
      await tester.pumpWidget(_app(_sheet(personalEmpty: '아직 이 자리의 해석이 없어요')));
      await tester.pump();

      expect(_inGlint('내 사주에서는'), isTrue);
      expect(_inGlint('아직 이 자리의 해석이 없어요'), isFalse);
    });

    testWidgets('잠겼거나 받는 중이면 반짝임이 없습니다', (tester) async {
      for (final sheet in [
        _sheet(state: DepthLinkState.locked),
        _sheet(state: DepthLinkState.unlocking, loading: true),
        _sheet(loading: true),
        _sheet(loading: true, personal: _text('내 사주 해석')),
      ]) {
        await tester.pumpWidget(_app(sheet));
        await tester.pump();
        expect(find.byType(UnlockGlint), findsNothing);
        expect(find.byType(UnlockMarkTitle), findsNothing);
      }
    });

    testWidgets('잠김이 풀리면 appear.seep 뒤 첫 반짝임이고 처음부터 열렸으면 바로입니다', (
      tester,
    ) async {
      int glinting() => tester.allRenderObjects
          .whereType<RenderUnlockGlint>()
          .toSet()
          .where((render) => render.glinting)
          .length;

      await tester.pumpWidget(_app(_sheet(state: DepthLinkState.unlocking)));
      await tester.pumpWidget(_app(_sheet()));
      await tester.pump();
      await tester.pump(
        InteractionPattern.appearSeep.duration -
            const Duration(milliseconds: 20),
      );
      expect(glinting(), 0, reason: '나타나는 동안');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 200));
      expect(glinting(), greaterThan(0));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(_sheet()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(glinting(), greaterThan(0), reason: '처음부터 열림');
    });

    testWidgets('동작 줄이기면 반짝임 대신 구역 제목 그라데이션 글자와 왼쪽 밖 12의 2px 세로선입니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_sheet(personal: _text('내 사주 해석')), prefs: _reduce),
      );
      await tester.pump();

      expect(find.byType(UnlockGlint), findsNothing);
      for (final title in ['판정 근거', '원전', '내 사주에서는']) {
        expect(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(UnlockMarkTitle),
          ),
          findsOneWidget,
          reason: title,
        );
      }
      expect(find.byType(UnlockMarkTitle), findsNWidgets(3));
      final rules = find.byKey(UnlockMarkRule.ruleKey);
      expect(rules, findsNWidgets(3));
      final basisTitle = tester.getRect(
        find.byKey(const ValueKey(SlotIds.evidenceSheetSectionBasis)),
      );
      final basisRule = tester.getRect(rules.first);
      expect(basisRule.width, UnlockMark.ruleWidth);
      expect(basisRule.left - basisTitle.left, UnlockMark.ruleOffsetStart);
      expect(basisRule.top, basisTitle.top, reason: '구역 제목 첫 줄 위에서');
      final basisBodies = find.byKey(
        const ValueKey(SlotIds.evidenceSheetBasisBody),
      );
      expect(
        basisRule.bottom,
        tester.getRect(basisBodies.last).bottom,
        reason: '구역 본문 끝까지',
      );
      // 시트 제목, 꼬리표는 그대로입니다.
      expect(
        find.ancestor(
          of: find.text(_title),
          matching: find.byType(UnlockMarkTitle),
        ),
        findsNothing,
      );
    });
  });

  group('sentence-block unlocked(사주 표 용신 판정 근거)', () {
    Widget block() => SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.all(Space.s16),
        child: SentenceBlock(
          variant: SentenceBlockVariant.body,
          text: _text('억부법으로 용신을 정했어요.'),
          unlocked: true,
          slotId: SlotIds.sajuChartYongsinBasis,
        ),
      ),
    );

    testWidgets('문장에 반짝임 박자 하나입니다', (tester) async {
      await tester.pumpWidget(_app(block()));
      await tester.pump();
      expect(find.byType(UnlockGlintScope), findsOneWidget);
      expect(_inGlint('억부법으로 용신을 정했어요.'), isTrue);
      expect(find.byKey(UnlockMarkRule.ruleKey), findsNothing);
    });

    testWidgets('동작 줄이기면 왼쪽 세로선만입니다(구역 제목 없음)', (tester) async {
      await tester.pumpWidget(_app(block(), prefs: _reduce));
      await tester.pump();
      expect(find.byType(UnlockGlint), findsNothing);
      expect(find.byType(UnlockMarkTitle), findsNothing);
      final rule = tester.getRect(find.byKey(UnlockMarkRule.ruleKey));
      final text = tester.getRect(
        find.byKey(const ValueKey(SlotIds.sajuChartYongsinBasis)),
      );
      expect(rule.left - text.left, UnlockMark.ruleOffsetStart);
      expect(rule.width, UnlockMark.ruleWidth);
    });

    testWidgets('unlocked가 아니면 반짝임이 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          SentenceBlock(
            variant: SentenceBlockVariant.body,
            text: _text('보통 문장'),
          ),
        ),
      );
      expect(find.byType(UnlockGlintScope), findsNothing);
    });
  });

  group('depth-link icon.unlocked', () {
    Widget link({required bool unlocked}) => EvidenceUnlockedScope(
      unlocked: unlocked,
      child: DepthLink.evidence(
        subject: '총운',
        placement: DepthLinkPlacement.headEnd,
        onTap: () {},
      ),
    );

    testWidgets('열람 권한이 있으면 아이콘 선을 135° gradient.unlocked로 칠합니다', (
      tester,
    ) async {
      await tester.pumpWidget(_app(link(unlocked: true)));
      final mask = tester.widget<ShaderMask>(
        find.descendant(
          of: find.byType(DepthLink),
          matching: find.byType(ShaderMask),
        ),
      );
      expect(mask.blendMode, BlendMode.srcIn);
      expect(
        find.descendant(
          of: find.byType(ShaderMask),
          matching: find.byType(AppIcon),
        ),
        findsOneWidget,
      );
      // 크기와 터치는 그대로입니다.
      expect(
        tester.getSize(find.byType(AppIcon)),
        Size.square(DepthLink.iconSize.logical),
      );
    });

    testWidgets('권한이 없거나 범위가 없으면 action.primary 그대로입니다', (tester) async {
      await tester.pumpWidget(_app(link(unlocked: false)));
      expect(
        find.descendant(
          of: find.byType(DepthLink),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );
      await tester.pumpWidget(
        _app(
          DepthLink.evidence(
            subject: '총운',
            placement: DepthLinkPlacement.headEnd,
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('열린 날에도 아이콘 이름은 같습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(link(unlocked: true)));
      final l10n = AppLocalizations.of(tester.element(find.byType(DepthLink)));
      expect(
        find.bySemanticsLabel(l10n.depthLinkEvidence('총운')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
