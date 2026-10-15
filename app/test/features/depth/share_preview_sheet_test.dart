import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/rendering/offscreen_renderer.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/design/theme/share_render_host.dart';
import 'package:myungli_diary/features/depth/presentation/share_preview_sheet.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/today_content.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

import '../../support/daily_fixture.dart';

final _ko = AppLocalizationsKo();
final Uint8List _png = Uint8List.fromList([137, 80, 78, 71]);

/// 테스트에서 프로필 시간대를 바꾸는 상태.
final class _Timezone extends Notifier<String> {
  @override
  String build() => 'Asia/Seoul';

  /// 시간대를 [value]로 바꿉니다.
  // ignore: use_setters_to_change_properties, 테스트 전용 상태 변경 메서드
  void change(String value) => state = value;
}

final _timezoneProvider = NotifierProvider<_Timezone, String>(_Timezone.new);

/// 호출을 기록하고, `hold`가 있으면 끝날 때까지 붙잡는 렌더러 대역.
final class _RecordingRenderer implements OffscreenRenderer {
  final calls = <({Widget image, Size size})>[];
  Completer<void>? hold;
  Exception? failWith;

  @override
  Future<Uint8List> render(Widget image, Size logicalSize) async {
    calls.add((image: image, size: logicalSize));
    await hold?.future;
    final error = failWith;
    if (error != null) {
      throw error;
    }
    return _png;
  }
}

TodayContent _content() => TodayContent(
  view: DailyView(
    date: CalendarDate(2026, 10, 13),
    daily: Daily.fromJson(memberDailyJson()),
    stale: false,
    cacheKey: null,
  ),
  names: const GlossaryNames({
    'color': {'wood': '초록'},
  }),
  diaryWritten: false,
);

Widget _app({
  required _RecordingRenderer renderer,
  required FakeShareSheet share,
  AsyncValue<TodayContent>? content,
  Brightness brightness = Brightness.light,
  FakeCrashReporter? crash,
  double? bodyHeight,
}) => ProviderScope(
  overrides: [
    todayContentProvider.overrideWithValue(content ?? AsyncData(_content())),
    profileTimezoneProvider.overrideWithValue('Asia/Seoul'),
    offscreenRendererProvider.overrideWithValue(renderer),
    shareSheetProvider.overrideWithValue(share),
    crashReporterProvider.overrideWithValue(crash ?? FakeCrashReporter()),
  ],
  child: MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildTheme(brightness: brightness, locale: const Locale('ko')),
    home: Scaffold(
      body: bodyHeight == null
          ? const SingleChildScrollView(child: SharePreviewSheet())
          : Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: bodyHeight,
                child: const SharePreviewSheet(),
              ),
            ),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view
    ..physicalSize = const Size(400, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump();
}

ShareImage _previewImage(WidgetTester tester) =>
    tester.widget<ShareImagePreview>(find.byType(ShareImagePreview)).image;

Segmented<ShareImageVariant> _segmented(WidgetTester tester) =>
    tester.widget<Segmented<ShareImageVariant>>(
      find.byType(Segmented<ShareImageVariant>),
    );

ShareImage _renderedImage(({Widget image, Size size}) call) {
  final host = call.image as ShareRenderHost;
  return host.child as ShareImage;
}

/// 정사각 PNG 왼쪽 아래(로고 자리)에 어두운 픽셀이 있는지, 지정 위치 색과 크기와 함께 돌려줍니다.
Future<({int width, int height, Color corner, bool logo})> _inspect(
  Uint8List png,
) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!;
  Color at(int x, int y) {
    final offset = (y * image.width + x) * 4;
    return Color.fromARGB(
      255,
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  }

  var logo = false;
  for (var y = image.height - 120; y < image.height - 60 && !logo; y++) {
    for (var x = 72; x < 400; x++) {
      if (at(x, y).computeLuminance() < 0.4) {
        logo = true;
        break;
      }
    }
  }
  return (
    width: image.width,
    height: image.height,
    corner: at(6, 6),
    logo: logo,
  );
}

ShareImage _plainImage(ShareImageVariant variant) => ShareImage(
  variant: variant,
  date: '10월 15일 목요일',
  dayKind: DayKind.yongsinDay,
  dayKindLabel: '좋은 날',
  sentence: RenderedText(segments: [Segment(text: '오늘은 좋은 날이에요.')]),
  items: const [],
  footer: '명리일기',
);

void main() {
  group('SharePreviewSheet', () {
    testWidgets('비율 선택은 스토리·피드·정사각 세 칸이고 기본은 스토리입니다', (tester) async {
      await _pump(
        tester,
        _app(renderer: _RecordingRenderer(), share: FakeShareSheet()),
      );
      final segmented = _segmented(tester);
      expect(segmented.items.map((item) => item.label), [
        _ko.sharePreviewRatioLabelStory,
        _ko.sharePreviewRatioLabelFeed,
        _ko.sharePreviewRatioLabelSquare,
      ]);
      expect(
        segmented.items.map((item) => item.value),
        ShareImageVariant.values,
      );
      expect(segmented.selected, ShareImageVariant.story);
      expect(segmented.identifier, SlotIds.sharePreviewRatioLabel);
      expect(_previewImage(tester).variant, ShareImageVariant.story);
    });

    testWidgets('비율을 고르면 미리보기 변형이 바뀌고 seep으로 나타납니다', (tester) async {
      await _pump(
        tester,
        _app(renderer: _RecordingRenderer(), share: FakeShareSheet()),
      );
      await tester.tap(find.text(_ko.sharePreviewRatioLabelFeed));
      await tester.pump();
      expect(_previewImage(tester).variant, ShareImageVariant.feed);
      expect(_segmented(tester).selected, ShareImageVariant.feed);
      await tester.pump(const Duration(milliseconds: 40));
      // 전환 중에는 아직 다 나타나지 않았습니다(컴포넌트의 appear.seep).
      final fade = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(ShareImagePreview),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(fade.opacity, lessThan(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ko.sharePreviewRatioLabelSquare));
      await tester.pumpAndSettle();
      expect(_previewImage(tester).variant, ShareImageVariant.square);
    });

    testWidgets('이미지 내용은 총운 문장(호칭 포함)·날짜·날의 성격·행운·footer입니다', (tester) async {
      await _pump(
        tester,
        _app(renderer: _RecordingRenderer(), share: FakeShareSheet()),
      );
      final image = _previewImage(tester);
      final daily = Daily.fromJson(memberDailyJson());
      expect(image.sentence.toJson(), daily.fortune.head.text.toJson());
      expect(image.sentence.segments.first.text, '하늘님, ');
      expect(image.date, '10월 13일 화요일');
      expect(image.dayKind, daily.dayKind);
      expect(image.dayKindLabel, _ko.dayKindYongsinDay);
      expect(image.footer, _ko.sharePreviewImageFooter);
      // 이유는 계약에 필드가 없어 비어 있습니다(A22).
      expect(image.reason, isNull);
      expect(image.items, hasLength(4));
      expect(image.items.first.variant, LuckyCardVariant.color);
      expect(image.items.first.value, '초록');
    });

    testWidgets('공유 버튼은 한 번 그려 sharePng에 태그라인과 함께 넘깁니다', (tester) async {
      final renderer = _RecordingRenderer();
      final share = FakeShareSheet();
      await _pump(tester, _app(renderer: renderer, share: share));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(renderer.calls, hasLength(1));
      final call = renderer.calls.single;
      expect(call.size, ShareImage.logicalSize(ShareImageVariant.story));
      expect(_renderedImage(call).variant, ShareImageVariant.story);
      expect(share.shared, hasLength(1));
      expect(share.shared.single.png, _png);
      expect(share.shared.single.text, _ko.sharePreviewImageTagline);
    });

    testWidgets('고른 비율로 그립니다', (tester) async {
      final renderer = _RecordingRenderer();
      await _pump(tester, _app(renderer: renderer, share: FakeShareSheet()));
      await tester.tap(find.text(_ko.sharePreviewRatioLabelSquare));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      final call = renderer.calls.single;
      expect(call.size, ShareImage.logicalSize(ShareImageVariant.square));
      expect(_renderedImage(call).variant, ShareImageVariant.square);
    });

    testWidgets('시트 높이가 모자라면 미리보기가 줄고 공유 버튼은 늘 보입니다', (tester) async {
      await _pump(
        tester,
        _app(
          renderer: _RecordingRenderer(),
          share: FakeShareSheet(),
          bodyHeight: 400,
        ),
      );
      expect(tester.takeException(), isNull);
      final preview = tester.getRect(find.byType(ShareImagePreview));
      final button = tester.getRect(find.byType(PrimaryButton));
      expect(preview.height, lessThan(360));
      expect(button.bottom, lessThanOrEqualTo(400));
      expect(preview.bottom, lessThanOrEqualTo(button.top));
    });

    testWidgets('프로필 시간대가 바뀌면 이미지의 집중 시간도 따라 바뀝니다(watch)', (tester) async {
      final app = ProviderScope(
        overrides: [
          todayContentProvider.overrideWithValue(AsyncData(_content())),
          profileTimezoneProvider.overrideWith(
            (ref) => ref.watch(_timezoneProvider),
          ),
          offscreenRendererProvider.overrideWithValue(_RecordingRenderer()),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            brightness: Brightness.light,
            locale: const Locale('ko'),
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: SharePreviewSheet()),
          ),
        ),
      );
      await _pump(tester, app);
      String timeOf() =>
          _previewImage(tester).items
              .firstWhere((item) => item.variant == LuckyCardVariant.time)
              .value;
      final seoul = timeOf();
      ProviderScope.containerOf(tester.element(find.byType(SharePreviewSheet)))
          .read(_timezoneProvider.notifier)
          .change('America/New_York');
      await tester.pump();
      expect(timeOf(), isNot(seoul));
    });

    testWidgets('공유 버튼 슬롯 id와 글자', (tester) async {
      await _pump(
        tester,
        _app(renderer: _RecordingRenderer(), share: FakeShareSheet()),
      );
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.label, _ko.sharePreviewCtaShare);
      expect(button.identifier, SlotIds.sharePreviewCtaShare);
      expect(button.loading, isFalse);
    });

    testWidgets('처리 중에는 점이 숨 쉬고 다시 눌러도 한 번만 공유합니다', (tester) async {
      final renderer = _RecordingRenderer()..hold = Completer<void>();
      final share = FakeShareSheet();
      await _pump(tester, _app(renderer: renderer, share: share));

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(find.byKey(PrimaryButton.dotsKey), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).loading,
        isTrue,
      );
      // 처리 중에 비율도 잠급니다(그리는 도중 바뀌어 다른 그림이 나가지 않게).
      expect(_segmented(tester).onChanged, isNull);

      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();
      expect(renderer.calls, hasLength(1));

      renderer.hold!.complete();
      await tester.pumpAndSettle();
      expect(share.shared, hasLength(1));
      expect(find.byKey(PrimaryButton.dotsKey), findsNothing);
      expect(_segmented(tester).onChanged, isNotNull);

      // 끝난 뒤에는 다시 공유할 수 있습니다.
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(share.shared, hasLength(2));
    });

    testWidgets('같은 프레임의 연타도 한 번만 공유합니다', (tester) async {
      final renderer = _RecordingRenderer()..hold = Completer<void>();
      await _pump(tester, _app(renderer: renderer, share: FakeShareSheet()));
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      expect(renderer.calls, hasLength(1));
      renderer.hold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('공유가 실패하면 오류 toast를 보이고 버튼이 돌아옵니다', (tester) async {
      final share = FakeShareSheet(failWith: const OfflineError());
      await _pump(tester, _app(renderer: _RecordingRenderer(), share: share));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ToastPill), findsOneWidget);
      expect(
        find.text(errorMessage(_ko, const OfflineError())),
        findsOneWidget,
      );
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).loading,
        isFalse,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('이미지를 그리지 못해도 오류 toast와 오류 보고를 남깁니다', (tester) async {
      final renderer = _RecordingRenderer()
        ..failWith = const FormatException('렌더 실패');
      final crash = FakeCrashReporter();
      await _pump(
        tester,
        _app(renderer: renderer, share: FakeShareSheet(), crash: crash),
      );
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(errorMessage(_ko, const UnexpectedError('x'))),
        findsOneWidget,
      );
      expect(crash.errors.single.errorType, 'FormatException');
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('렌더가 시간 초과로 끝나면 잠금이 풀리고 오류 toast를 보입니다', (tester) async {
      final renderer = _RecordingRenderer()
        ..failWith = const OffscreenRenderTimeout();
      await _pump(tester, _app(renderer: renderer, share: FakeShareSheet()));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ToastPill), findsOneWidget);
      final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
      expect(button.loading, isFalse);
      expect(_segmented(tester).onChanged, isNotNull);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('기기가 다크여도 미리보기와 공유 이미지는 라이트입니다(V5)', (tester) async {
      final renderer = _RecordingRenderer();
      await _pump(
        tester,
        _app(
          renderer: renderer,
          share: FakeShareSheet(),
          brightness: Brightness.dark,
        ),
      );
      final canvas = tester.element(find.byKey(ShareImage.canvasKey));
      expect(Theme.of(canvas).brightness, Brightness.light);
      // 시트 자체는 다크 테마를 따릅니다.
      expect(
        Theme.of(tester.element(find.byType(SharePreviewSheet))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('오늘 내용이 아직 없으면 불러오는 중이고 공유할 수 없습니다', (tester) async {
      await _pump(
        tester,
        _app(
          renderer: _RecordingRenderer(),
          share: FakeShareSheet(),
          content: const AsyncLoading(),
        ),
      );
      expect(find.byType(ShareImagePreview), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
    });
  });

  group('실제 렌더(ShareRenderHost + PngOffscreenRenderer)', () {
    for (final variant in ShareImageVariant.values) {
      testWidgets('${variant.name}: 폭 1080 PNG이고 기기가 다크여도 라이트이며 로고가 있습니다', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final size = ShareImage.logicalSize(variant);
        final inspected = (await tester.runAsync(() async {
          await ShareImage.precache();
          final png = await const PngOffscreenRenderer().render(
            ShareRenderHost(
              locale: const Locale('ko'),
              child: _plainImage(variant),
            ),
            size,
          );
          return await _inspect(png);
        }))!;
        expect(inspected.width, 1080);
        expect(inspected.height, (size.height * 3).round());
        expect(inspected.corner.computeLuminance(), greaterThan(0.8));
        expect(inspected.logo, isTrue);
      });
    }
  });

  group('공유 텍스트(태그라인)', () {
    test('공유 문구는 태그라인 슬롯의 ARB 문구입니다', () {
      expect(shareTextOf(_ko), _ko.sharePreviewImageTagline);
      expect(shareTextSlotId, SlotIds.sharePreviewImageTagline);
    });

    test('ARB 설명이 슬롯 id를 가리킵니다(footer·tagline)', () {
      final arb = jsonDecode(
        File('lib/core/l10n/arb/app_ko.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      String descriptionOf(String key) =>
          (arb['@$key'] as Map<String, dynamic>)['description'] as String;
      expect(
        descriptionOf('sharePreviewImageTagline'),
        startsWith(SlotIds.sharePreviewImageTagline),
      );
      expect(
        descriptionOf('sharePreviewImageFooter'),
        startsWith(SlotIds.sharePreviewImageFooter),
      );
    });
  });
}
