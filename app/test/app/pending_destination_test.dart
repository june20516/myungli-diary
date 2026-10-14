import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/pending_destination.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  PendingDestination notifier() =>
      container.read(pendingDestinationProvider.notifier);

  test('처음에는 기억한 목적지가 없습니다', () {
    expect(container.read(pendingDestinationProvider), isNull);
    expect(notifier().take(), isNull);
  });

  test('take는 기억한 목적지를 한 번만 줍니다', () {
    notifier().remember('/calendar');
    expect(container.read(pendingDestinationProvider), '/calendar');
    expect(notifier().take(), '/calendar');
    expect(notifier().take(), isNull);
    expect(container.read(pendingDestinationProvider), isNull);
  });

  test('다시 기억하면 마지막 목적지로 바꿉니다', () {
    notifier()
      ..remember('/calendar')
      ..remember('/today');
    expect(notifier().take(), '/today');
  });
}
