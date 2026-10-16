import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/feedback/text_action.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/bottom_bar_inset_scope.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Widget _app(
  Widget home, {
  Locale locale = const Locale('ko'),
  FakeCrashReporter? crash,
}) => ProviderScope(
  overrides: [
    crashReporterProvider.overrideWithValue(crash ?? FakeCrashReporter()),
  ],
  child: MaterialApp(
    navigatorKey: _navigatorKey,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildTheme(brightness: Brightness.light, locale: locale),
    home: Scaffold(body: home),
  ),
);

SemanticsRole _roleOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData().role;

/// [finder] 노드와 그 아래 시맨틱 노드의 데이터를 모읍니다.
List<SemanticsData> _treeData(WidgetTester tester, Finder finder) {
  final result = <SemanticsData>[];
  void visit(SemanticsNode node) {
    result.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return result;
}

/// 바깥 노드는 label을 가진 liveRegion(모바일 알림), 안쪽 노드는 [role]만 가진 별도 노드.
void _expectAnnouncement(
  WidgetTester tester,
  String label,
  SemanticsRole role,
) {
  final data = _treeData(tester, find.bySemanticsLabel(label));
  expect(data.first.label, label);
  expect(data.first.flagsCollection.isLiveRegion, isTrue);
  expect(
    data.first.role,
    isNot(role),
    reason: '바깥 노드는 role과 liveRegion을 함께 갖지 않음',
  );
  final inner = data.skip(1).where((d) => d.role == role);
  expect(inner, hasLength(1), reason: '안쪽 노드가 명세 role을 가짐');
  expect(inner.single.label, isEmpty);
  expect(inner.single.flagsCollection.isLiveRegion, isFalse);
}

List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

const ProblemError _problem = ProblemError(
  code: 'x',
  status: 500,
  fieldErrors: [],
  traceId: 'trace-abc',
);

class _Probe extends AsyncNotifier<String> {
  @override
  Future<String> build() async => '캐시';

  void fail(Object error) => state = AsyncError(error, StackTrace.empty);

  void reload() => state = const AsyncLoading();
}

class _Failing extends AsyncNotifier<String> {
  @override
  Future<String> build() async => throw const TimeoutError();

  void reload() => state = const AsyncLoading();
}

final _probe = AsyncNotifierProvider<_Probe, String>(_Probe.new);
final _failing = AsyncNotifierProvider<_Failing, String>(
  _Failing.new,
  retry: (_, _) => null,
);

/// Riverpod이 만드는 그대로의 상태를 얻습니다(값을 가진 채 실패, 값을 가진 채 갱신 중 등).
Future<AsyncValue<String>> _states(
  WidgetTester tester,
  void Function(_Probe probe) step,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.runAsync(() => container.read(_probe.future));
  step(container.read(_probe.notifier));
  // AsyncValue는 Future가 아니라 값입니다(린트 오탐).
  // ignore: async_return_with_no_await
  return container.read(_probe);
}

/// 값 없이 실패한 뒤 다시 불러오는 중인 상태.
Future<AsyncValue<String>> _afterFailedLoad(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sub = container.listen(_failing, (_, _) {});
  addTearDown(sub.close);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  container.read(_failing.notifier).reload();
  // AsyncValue는 Future가 아니라 값입니다(린트 오탐).
  // ignore: async_return_with_no_await
  return container.read(_failing);
}

Widget _view(
  AsyncValue<String> value, {
  bool Function(String)? isEmpty,
  bool Function(String)? isStale,
  VoidCallback? onRetry,
  void Function(AppError)? onStaleError,
  FakeCrashReporter? crash,
}) => _app(
  crash: crash,
  ScreenStateView<String>(
    value: value,
    onRetry: onRetry ?? () {},
    isEmpty: isEmpty,
    isStale: isStale,
    onStaleError: onStaleError,
    data: (v) => Center(child: Text('값:$v')),
  ),
);

void main() {
  group('dialog', () {
    Future<bool> open(
      WidgetTester tester,
      DialogVariant variant, {
      List<bool>? result,
    }) async {
      await tester.pumpWidget(_app(const SizedBox.expand()));
      final future = showMyungliDialog(
        _navigatorKey.currentContext!,
        variant: variant,
        title: '일기를 지울까요?',
        body: '지우면 되돌릴 수 없어요.',
        confirm: '지우기',
        cancel: '취소',
      );
      unawaited(future.then((v) => result?.add(v)));
      await tester.pumpAndSettle();
      return true;
    }

    testWidgets('destructive: 처음 초점은 취소입니다', (tester) async {
      await open(tester, DialogVariant.destructive);
      expect(Focus.of(tester.element(find.text('취소'))).hasPrimaryFocus, isTrue);
      expect(
        Focus.of(tester.element(find.text('지우기'))).hasPrimaryFocus,
        isFalse,
      );
    });

    testWidgets('confirm: 처음 초점은 확정입니다', (tester) async {
      await open(tester, DialogVariant.confirm);
      expect(
        Focus.of(tester.element(find.text('지우기'))).hasPrimaryFocus,
        isTrue,
      );
    });

    testWidgets('destructive: 경고 표시가 제목 앞에 있고 빨간색이 없습니다', (tester) async {
      await open(tester, DialogVariant.destructive);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(DialogCard),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, const AppIcon.caution().icon.light);
      final tokens = tester.element(find.byType(DialogCard)).tokens;
      final confirm = tester.widget<Text>(find.text('지우기'));
      expect(confirm.style!.color, tokens.colors.textPrimary);
      expect(confirm.style!.fontWeight, FontWeight.w700);
      final cancel = tester.widget<Text>(find.text('취소'));
      expect(cancel.style!.color, tokens.colors.actionPrimary);
    });

    testWidgets('confirm에는 경고 표시가 없습니다', (tester) async {
      await open(tester, DialogVariant.confirm);
      expect(
        find.descendant(
          of: find.byType(DialogCard),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('destructive: 바깥을 눌러도 닫히지 않습니다', (tester) async {
      await open(tester, DialogVariant.destructive);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(DialogCard), findsOneWidget);
    });

    testWidgets('confirm: 바깥을 누르면 false로 닫힙니다', (tester) async {
      final results = <bool>[];
      await open(tester, DialogVariant.confirm, result: results);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(DialogCard), findsNothing);
      expect(results, [false]);
    });

    testWidgets('확정은 true, 취소는 false', (tester) async {
      final results = <bool>[];
      await open(tester, DialogVariant.destructive, result: results);
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      await open(tester, DialogVariant.destructive, result: results);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(results, [true, false]);
    });

    testWidgets('햅틱 medium은 destructive 확정에서만 울립니다', (tester) async {
      final haptics = _recordHaptics(tester);
      await open(tester, DialogVariant.destructive);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      await open(tester, DialogVariant.destructive);
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
      haptics.clear();
      await open(tester, DialogVariant.confirm);
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('버튼 터치 영역은 44 이상입니다', (tester) async {
      await open(tester, DialogVariant.destructive);
      for (final label in ['취소', '지우기']) {
        final box = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(box.height, greaterThanOrEqualTo(44), reason: label);
        expect(box.width, greaterThanOrEqualTo(44), reason: label);
      }
    });

    testWidgets('alertdialog 의미와 제목 라벨', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, DialogVariant.destructive);
      expect(
        tester.getSemantics(find.byType(DialogCard)),
        matchesSemantics(
          label: '일기를 지울까요?',
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      handle.dispose();
    });

    group('notice', () {
      Future<List<String>> openNotice(WidgetTester tester) async {
        final closed = <String>[];
        await tester.pumpWidget(_app(const SizedBox.expand()));
        unawaited(
          showMyungliNotice(
            _navigatorKey.currentContext!,
            body: '이미 사주를 저장한 계정이면 저장된 정보를 써요.',
            confirm: '확인',
          ).then((_) => closed.add('closed')),
        );
        await tester.pumpAndSettle();
        return closed;
      }

      testWidgets('확인 버튼 하나뿐이고 오른쪽 끝에 놓이며 처음 초점을 받습니다', (tester) async {
        await openNotice(tester);
        final card = find.byType(DialogCard);
        expect(
          find.descendant(of: card, matching: find.byType(FeedbackTextAction)),
          findsOneWidget,
        );
        expect(
          Focus.of(tester.element(find.text('확인'))).hasPrimaryFocus,
          isTrue,
        );
        // 확인 버튼은 카드 안쪽 여백(space.24)만큼 떨어진 오른쪽 끝입니다.
        final confirmRight = tester
            .getTopRight(
              find
                  .ancestor(
                    of: find.text('확인'),
                    matching: find.byType(FeedbackTextAction),
                  )
                  .first,
            )
            .dx;
        expect(confirmRight, tester.getTopRight(card).dx - Space.s24);
        // confirm과 같은 모양(action.primary, 굵게 하지 않음), 경고 표시 없음.
        final tokens = tester.element(card).tokens;
        final confirm = tester.widget<Text>(find.text('확인'));
        expect(confirm.style!.color, tokens.colors.actionPrimary);
        expect(confirm.style!.fontWeight, isNot(FontWeight.w700));
        expect(
          find.descendant(of: card, matching: find.byType(Icon)),
          findsNothing,
        );
      });

      testWidgets('확인을 누르면 닫히고 햅틱은 없습니다', (tester) async {
        final haptics = _recordHaptics(tester);
        final closed = await openNotice(tester);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(find.byType(DialogCard), findsNothing);
        expect(closed, ['closed']);
        expect(haptics, isEmpty);
      });

      testWidgets('바깥을 누르면 확인과 같이 닫힙니다', (tester) async {
        final closed = await openNotice(tester);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byType(DialogCard), findsNothing);
        expect(closed, ['closed']);
      });

      testWidgets('뒤로 가기도 확인과 같이 닫힙니다', (tester) async {
        final closed = await openNotice(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(DialogCard), findsNothing);
        expect(closed, ['closed']);
      });

      testWidgets('제목이 없으면 본문이 창 이름(alertdialog 라벨)입니다', (tester) async {
        final handle = tester.ensureSemantics();
        await openNotice(tester);
        expect(
          tester.getSemantics(find.byType(DialogCard)),
          matchesSemantics(
            label: '이미 사주를 저장한 계정이면 저장된 정보를 써요.',
            scopesRoute: true,
            namesRoute: true,
          ),
        );
        handle.dispose();
      });

      test('notice는 showMyungliDialog로 열 수 없고, 카드는 notice만 취소가 없습니다', () {
        expect(
          () => DialogCard(
            variant: DialogVariant.confirm,
            title: 't',
            confirm: 'c',
          ),
          throwsAssertionError,
        );
        expect(
          () => DialogCard(
            variant: DialogVariant.notice,
            body: 'b',
            confirm: 'c',
            cancel: 'x',
          ),
          throwsAssertionError,
        );
      });
    });

    testWidgets('앱 안의 앱(바깥 작업대 MaterialApp)에서는 안쪽 navigator에 안쪽 테마로 쌓입니다', (
      tester,
    ) async {
      // Widgetbook처럼 바깥 MaterialApp 안에 MyungliTokens 테마 MaterialApp이 있는 경우.
      late BuildContext outer;
      late BuildContext inner;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              outer = context;
              return MaterialApp(
                locale: const Locale('ko'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: buildTheme(
                  brightness: Brightness.light,
                  locale: const Locale('ko'),
                ),
                home: Builder(
                  builder: (context) {
                    inner = context;
                    return const SizedBox.expand();
                  },
                ),
              );
            },
          ),
        ),
      );
      unawaited(
        showMyungliDialog(
          inner,
          variant: DialogVariant.confirm,
          title: '알림을 켤까요?',
          confirm: '켜기',
          cancel: '나중에',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DialogCard), findsOneWidget);
      expect(Navigator.of(inner).canPop(), isTrue);
      expect(Navigator.of(outer).canPop(), isFalse);
    });
  });

  group('toast', () {
    const hostKey = ValueKey('toast-host');
    Future<void> pumpHost(WidgetTester tester) =>
        tester.pumpWidget(_app(const SizedBox.expand(key: hostKey)));
    BuildContext hostContext(WidgetTester tester) =>
        tester.element(find.byKey(hostKey));

    testWidgets('2.5초 뒤 사라집니다', (tester) async {
      await pumpHost(tester);
      showMyungliToast(hostContext(tester), '저장했어요');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('저장했어요'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.text('저장했어요'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text('저장했어요'), findsNothing);
    });

    testWidgets('새 토스트가 오면 하나만 남습니다', (tester) async {
      await pumpHost(tester);
      showMyungliToast(hostContext(tester), '하나');
      await tester.pump(const Duration(milliseconds: 600));
      showMyungliToast(hostContext(tester), '둘');
      await tester.pumpAndSettle();
      expect(find.text('하나'), findsNothing);
      expect(find.text('둘'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('둘'), findsNothing);
    });

    testWidgets('위치: BottomBarInsetScope 높이 위 16px, 없으면 안전 영역 위 16px', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const BottomBarInsetScope(
            height: 120,
            child: SizedBox.expand(key: hostKey),
          ),
        ),
      );
      showMyungliToast(hostContext(tester), '위치');
      await tester.pumpAndSettle();
      expect(800 - tester.getBottomLeft(find.byType(ToastPill)).dy, 136);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await pumpHost(tester);
      showMyungliToast(hostContext(tester), '위치');
      await tester.pumpAndSettle();
      expect(800 - tester.getBottomLeft(find.byType(ToastPill)).dy, 16);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('scope 높이가 바뀌면 다음 토스트부터 따라갑니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget host(double height) => _app(
        BottomBarInsetScope(
          height: height,
          child: const SizedBox.expand(key: hostKey),
        ),
      );
      await tester.pumpWidget(host(50));
      showMyungliToast(hostContext(tester), '위치');
      await tester.pumpAndSettle();
      expect(800 - tester.getBottomLeft(find.byType(ToastPill)).dy, 66);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.pumpWidget(host(90));
      showMyungliToast(hostContext(tester), '위치');
      await tester.pumpAndSettle();
      expect(800 - tester.getBottomLeft(find.byType(ToastPill)).dy, 106);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('알약이고 반전색이며 live region입니다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester);
      showMyungliToast(hostContext(tester), '저장했어요');
      await tester.pumpAndSettle();
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(ToastPill),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final tokens = tester.element(find.byType(ToastPill)).tokens;
      expect(decoration.color, tokens.colors.inverseBg);
      expect(decoration.borderRadius, BorderRadius.circular(Radii.full));
      expect(
        tester.getSemantics(find.byType(ToastPill)),
        matchesSemantics(label: '저장했어요', isLiveRegion: true),
      );
      handle.dispose();
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });

  group('notice-banner', () {
    testWidgets('present가 false가 되면 사라진 뒤 자리를 비웁니다', (tester) async {
      Widget banner({required bool present}) => _app(
        NoticeBanner(
          variant: NoticeBannerVariant.draft,
          message: '이어 쓸 일기가 있어요',
          present: present,
        ),
      );
      await tester.pumpWidget(banner(present: true));
      await tester.pumpAndSettle();
      expect(find.text('이어 쓸 일기가 있어요'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      await tester.pumpWidget(banner(present: false));
      await tester.pumpAndSettle();
      expect(find.text('이어 쓸 일기가 있어요'), findsNothing);
    });

    testWidgets('변형마다 아이콘이 다릅니다', (tester) async {
      final seen = <IconData>{};
      for (final variant in NoticeBannerVariant.values) {
        await tester.pumpWidget(
          _app(NoticeBanner(variant: variant, message: variant.name)),
        );
        await tester.pumpAndSettle();
        seen.add(tester.widget<Icon>(find.byType(Icon)).icon!);
      }
      expect(seen, hasLength(3));
    });
  });

  group('skeleton', () {
    testWidgets('300ms 안에는 보이지 않고 그 뒤에 나타납니다', (tester) async {
      await tester.pumpWidget(_app(const SkeletonBlock()));
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.byType(SkeletonBone), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(SkeletonBone), findsNWidgets(3));
    });

    testWidgets('글줄 높이는 줄 높이의 60%, 마지막 줄은 너비 60%', (tester) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            child: SkeletonBlock(delay: Duration.zero),
          ),
        ),
      );
      final sizes = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byType(SkeletonBone).at(i)),
      ];
      expect(sizes[0].width, 300);
      expect(sizes[2].width, closeTo(180, 0.01));
      final tokens = tester.element(find.byType(SkeletonBlock)).tokens;
      final style = tokens.typography.bodyUi;
      expect(
        sizes[0].height,
        closeTo(style.fontSize! * style.height! * 0.6, 0.01),
      );
    });

    testWidgets('읽어 주는 라벨은 불러오는 중이고 자식은 숨깁니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const SkeletonBlock(delay: Duration.zero)));
      expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
      handle.dispose();
    });
  });

  group('empty-state', () {
    testWidgets('문장과 주 버튼을 보이고 세로 40% 자리에 둡니다', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          EmptyState(
            body: '아직 쓴 일기가 없어요',
            action: PrimaryButton(label: '쓰기', onPressed: () {}),
          ),
        ),
      );
      expect(find.text('아직 쓴 일기가 없어요'), findsOneWidget);
      expect(find.text('쓰기'), findsOneWidget);
      final circle = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 56 && w.height == 56,
        ),
      );
      final stack = tester.getRect(
        find
            .descendant(
              of: find.byType(EmptyState),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(circle.center.dx, 200);
      // 내용 가운데가 부모(Scaffold 몸통)의 세로 40%.
      final body = tester.getRect(find.byType(CustomSingleChildLayout));
      expect(stack.center.dy, closeTo(body.top + body.height * 0.4, 1));
    });
  });

  group('error-state', () {
    testWidgets('OfflineError는 offline 변형입니다', (tester) async {
      await tester.pumpWidget(
        _app(ErrorState(error: const OfflineError(), onRetry: () {})),
      );
      final state = tester.widget<ErrorState>(find.byType(ErrorState));
      expect(state.variant, ErrorStateVariant.offline);
      expect(find.text('인터넷에 연결되어 있지 않아요. 연결을 확인해 주세요.'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        ErrorStateVariant.offline.glyph.light,
      );
    });

    testWidgets('그 밖의 오류는 generic 변형이고 다시 시도가 있습니다', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _app(ErrorState(error: const TimeoutError(), onRetry: () => retried++)),
      );
      expect(
        tester.widget<ErrorState>(find.byType(ErrorState)).variant,
        ErrorStateVariant.generic,
      );
      await tester.tap(find.text('다시 시도'));
      expect(retried, 1);
    });

    testWidgets('traceId가 있으면 문의 번호를 보이고 길게 눌러 복사합니다', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _app(ErrorState(error: _problem, onRetry: () {})),
      );
      expect(find.text('문의 번호 trace-abc'), findsOneWidget);
      await tester.longPress(find.text('문의 번호 trace-abc'));
      await tester.pump();
      expect(copied, 'trace-abc');
      expect(find.text('문의 번호를 복사했어요.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('traceId가 비어 있으면 문의 번호를 보이지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          ErrorState(
            error: const ProblemError(
              code: 'x',
              status: 500,
              fieldErrors: [],
              traceId: '',
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(find.textContaining('문의 번호'), findsNothing);
    });
  });

  group('ScreenStateView', () {
    testWidgets('로딩은 skeleton이고 스피너가 없습니다', (tester) async {
      await tester.pumpWidget(_view(const AsyncLoading<String>()));
      await tester.pump(const Duration(milliseconds: 301));
      expect(find.byType(SkeletonBone), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
    });

    testWidgets('값이 있으면 데이터를 보입니다', (tester) async {
      await tester.pumpWidget(_view(const AsyncData('a')));
      await tester.pumpAndSettle();
      expect(find.text('값:a'), findsOneWidget);
      expect(find.byType(NoticeBanner), findsOneWidget); // present=false: 빈 자리
      expect(find.text('인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'), findsNothing);
    });

    testWidgets('값 없는 OfflineError는 error-state offline', (tester) async {
      await tester.pumpWidget(
        _view(const AsyncError<String>(OfflineError(), StackTrace.empty)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ErrorState>(find.byType(ErrorState)).variant,
        ErrorStateVariant.offline,
      );
      expect(find.byType(NoticeBanner), findsNothing);
    });

    testWidgets('값 없는 ProblemError는 generic이고 traceId를 보입니다', (tester) async {
      await tester.pumpWidget(
        _view(const AsyncError<String>(_problem, StackTrace.empty)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ErrorState>(find.byType(ErrorState)).variant,
        ErrorStateVariant.generic,
      );
      expect(find.text('문의 번호 trace-abc'), findsOneWidget);
    });

    testWidgets('AppError가 아닌 오류도 예기치 못한 오류로 보입니다', (tester) async {
      await tester.pumpWidget(
        _view(AsyncError<String>(StateError('x'), StackTrace.empty)),
      );
      await tester.pumpAndSettle();
      expect(find.text('문제가 생겼어요. 다시 시도해 주세요.'), findsOneWidget);
    });

    testWidgets('isStale이 true인 값은 오류가 없어도 offline 배너를 보이고, 풀리면 사라집니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _view(const AsyncData('cache'), isStale: (v) => v == 'cache'),
      );
      await tester.pumpAndSettle();
      expect(find.text('값:cache'), findsOneWidget);
      expect(find.text('인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'), findsOneWidget);

      await tester.pumpWidget(
        _view(const AsyncData('server'), isStale: (v) => v == 'cache'),
      );
      await tester.pumpAndSettle();
      expect(find.text('값:server'), findsOneWidget);
      expect(find.text('인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'), findsNothing);
    });

    testWidgets('캐시가 있는 오프라인은 데이터와 offline 배너를 함께 보입니다', (tester) async {
      await tester.pumpWidget(
        _view(await _states(tester, (p) => p.fail(const OfflineError()))),
      );
      await tester.pumpAndSettle();
      expect(find.text('값:캐시'), findsOneWidget);
      expect(find.text('인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('연결이 돌아오면 배너가 사라지고 데이터는 남습니다', (tester) async {
      final offline = await _states(
        tester,
        (p) => p.fail(const OfflineError()),
      );
      expect(offline.hasValue && offline.hasError, isTrue);
      await tester.pumpWidget(_view(offline));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_view(const AsyncData('새값')));
      await tester.pumpAndSettle();
      expect(find.text('값:새값'), findsOneWidget);
      expect(find.text('인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'), findsNothing);
    });

    testWidgets('값이 있는 갱신 중에는 데이터를 그대로 보입니다', (tester) async {
      await tester.pumpWidget(_view(await _states(tester, (p) => p.reload())));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('값:캐시'), findsOneWidget);
      expect(find.byType(SkeletonBone), findsNothing);
    });

    testWidgets('오류 뒤 다시 시도 중(값 없음)이면 그 자리에 skeleton', (tester) async {
      await tester.pumpWidget(_view(await _afterFailedLoad(tester)));
      await tester.pump(const Duration(milliseconds: 301));
      expect(find.byType(SkeletonBone), findsWidgets);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('isEmpty면 empty-state', (tester) async {
      await tester.pumpWidget(
        _view(const AsyncData(''), isEmpty: (v) => v.isEmpty),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('아직 보여 드릴 내용이 없어요.'), findsOneWidget);
    });

    testWidgets('dataWithNotice는 배너를 내용 안에 놓습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          ScreenStateView<String>(
            value: await _states(tester, (p) => p.fail(const OfflineError())),
            onRetry: () {},
            dataWithNotice: (v, notice) =>
                ListView(children: [notice, Text('값:$v')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(NoticeBanner),
        ),
        findsOneWidget,
      );
    });

    testWidgets('다시 시도 버튼이 onRetry를 부릅니다', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _view(
          const AsyncError<String>(TimeoutError(), StackTrace.empty),
          onRetry: () => retried++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 시도'));
      expect(retried, 1);
    });
  });

  group('a11y role (명세) + 모바일 liveRegion', () {
    testWidgets('toast: status role 노드 + liveRegion 노드', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const ToastPill(message: '저장했어요')));
      _expectAnnouncement(tester, '저장했어요', SemanticsRole.status);
      handle.dispose();
    });

    testWidgets('notice-banner: status role 노드 + liveRegion 노드', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const NoticeBanner(variant: NoticeBannerVariant.draft, message: '초안'),
        ),
      );
      await tester.pumpAndSettle();
      _expectAnnouncement(tester, '초안', SemanticsRole.status);
      handle.dispose();
    });

    testWidgets('error-state: alert role 노드 + liveRegion 노드', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(ErrorState(error: const TimeoutError(), onRetry: () {})),
      );
      _expectAnnouncement(
        tester,
        '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
        SemanticsRole.alert,
      );
      handle.dispose();
    });

    testWidgets('skeleton: loadingSpinner', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const SkeletonBlock(delay: Duration.zero)));
      expect(
        _roleOf(tester, find.byType(SkeletonBlock)),
        SemanticsRole.loadingSpinner,
      );
      handle.dispose();
    });

    testWidgets('empty-state: 하나의 묶음 노드(group)로 문장을 읽습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const EmptyState(body: '비었어요')));
      final data = tester
          .getSemantics(find.bySemanticsLabel('비었어요'))
          .getSemanticsData();
      expect(data.label, '비었어요');
      // SemanticsRole에 group이 없어 role은 none이고 묶음(container)으로 둡니다.
      expect(data.role, SemanticsRole.none);
      handle.dispose();
    });
  });

  group('추가 동작', () {
    testWidgets('dialog: 2.0배 긴 본문에서도 넘치지 않고 버튼이 보입니다', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: _app(const SizedBox.expand()),
        ),
      );
      unawaited(
        showMyungliDialog(
          _navigatorKey.currentContext!,
          variant: DialogVariant.destructive,
          title: '일기를 지울까요?',
          body: List.filled(40, '지우면 되돌릴 수 없어요.').join(' '),
          confirm: '지우기',
          cancel: '취소',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('지우기'), findsOneWidget);
      expect(tester.getRect(find.text('지우기')).bottom, lessThanOrEqualTo(640));
    });

    testWidgets('값이 있고 500: 데이터 유지, 화면 안 표시 없음, onStaleError는 한 번', (
      tester,
    ) async {
      final errors = <AppError>[];
      final stale = await _states(tester, (p) => p.fail(_problem));
      await tester.pumpWidget(_view(stale, onStaleError: errors.add));
      await tester.pumpAndSettle();
      expect(find.text('값:캐시'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'), findsNothing);
      expect(errors, [_problem]);
      // 같은 값으로 다시 그려도 반복해 알리지 않습니다.
      await tester.pumpWidget(_view(stale, onStaleError: errors.add));
      await tester.pumpAndSettle();
      expect(errors, hasLength(1));
    });

    testWidgets('값이 있고 오프라인이면 onStaleError를 부르지 않습니다', (tester) async {
      final errors = <AppError>[];
      final stale = await _states(tester, (p) => p.fail(const OfflineError()));
      await tester.pumpWidget(_view(stale, onStaleError: errors.add));
      await tester.pumpAndSettle();
      expect(errors, isEmpty);
    });

    testWidgets('AppError가 아닌 오류는 크래시 보고에 한 번 기록합니다', (tester) async {
      final crash = FakeCrashReporter();
      final value = AsyncError<String>(StateError('x'), StackTrace.empty);
      await tester.pumpWidget(_view(value, crash: crash));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_view(value, crash: crash));
      await tester.pumpAndSettle();
      expect(crash.errors.map((e) => e.errorType), ['UnexpectedError']);
    });

    testWidgets('AppError는 크래시 보고에 기록하지 않습니다', (tester) async {
      final crash = FakeCrashReporter();
      await tester.pumpWidget(
        _view(
          const AsyncError<String>(_problem, StackTrace.empty),
          crash: crash,
        ),
      );
      await tester.pumpAndSettle();
      expect(crash.errors, isEmpty);
    });
  });
}
