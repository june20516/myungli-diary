import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/feedback/load_feedback.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';

final _ko = AppLocalizationsKo();

/// 값을 바꿔 가며 보낼 수 있는 시험용 상태.
final class _Value extends Notifier<AsyncValue<int>> {
  @override
  AsyncValue<int> build() => const AsyncLoading();

  /// 다시 받는 중으로 둡니다.
  void reload() => state = const AsyncLoading();

  /// [error]로 실패합니다.
  void fail(Object error) => state = AsyncError(error, StackTrace.empty);
}

/// 값을 받은 뒤 실패하는 provider(이전 값이 남는 오류).
final class _Loaded extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 1;

  void fail() => state = const AsyncError(OfflineError(), StackTrace.empty);
}

/// 처음부터 받지 못하는 provider. [retry]하면 다시 받는 중입니다.
final class _Failing extends AsyncNotifier<int> {
  @override
  Future<int> build() async => throw const OfflineError();

  void retry() => state = const AsyncLoading();
}

final _loadedProvider = AsyncNotifierProvider<_Loaded, int>(_Loaded.new);
final _failingProvider = AsyncNotifierProvider<_Failing, int>(
  _Failing.new,
  retry: (_, _) => null,
);

final _valueProvider = NotifierProvider<_Value, AsyncValue<int>>(_Value.new);

class _Host extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  @override
  void initState() {
    super.initState();
    listenLoadErrorToast(ref, context, _valueProvider);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox());
}

void main() {
  test('failedWithoutValue는 값 없이 실패해 끝났을 때만 참입니다', () async {
    const error = OfflineError();
    expect(
      const AsyncError<int>(error, StackTrace.empty).failedWithoutValue,
      isTrue,
    );
    expect(const AsyncLoading<int>().failedWithoutValue, isFalse);
    expect(const AsyncData(1).failedWithoutValue, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 값을 받은 뒤의 실패는 이전 값이 남아 있습니다.
    container.listen(_loadedProvider, (_, _) {});
    await container.read(_loadedProvider.future);
    container.read(_loadedProvider.notifier).fail();
    expect(container.read(_loadedProvider).failedWithoutValue, isFalse);

    // 다시 받는 중이면 아직 실패로 끝나지 않았습니다.
    container.listen(_failingProvider, (_, _) {});
    await expectLater(
      container.read(_failingProvider.future),
      throwsA(isA<OfflineError>()),
    );
    expect(container.read(_failingProvider).failedWithoutValue, isTrue);
    container.read(_failingProvider.notifier).retry();
    expect(container.read(_failingProvider).failedWithoutValue, isFalse);
  });

  testWidgets('새 오류마다 한 번 toast로 알리고, 받는 중·같은 오류는 다시 알리지 않습니다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildTheme(
            brightness: Brightness.light,
            locale: const Locale('ko'),
          ),
          home: const _Host(),
        ),
      ),
    );
    const error = OfflineError();
    container.read(_valueProvider.notifier).reload();
    await tester.pump();
    expect(find.text(_ko.errorOffline), findsNothing);

    container.read(_valueProvider.notifier).fail(error);
    await tester.pump();
    expect(find.text(_ko.errorOffline), findsOneWidget);

    // 바로 앞과 같은 오류 객체면 새로 알리지 않습니다.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text(_ko.errorOffline), findsNothing);
    container.read(_valueProvider.notifier).fail(error);
    await tester.pump();
    expect(find.text(_ko.errorOffline), findsNothing);
  });
}
