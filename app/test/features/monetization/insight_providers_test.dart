import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_en.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/features/depth/presentation/unlock_until_text.dart';
import 'package:myungli_diary/features/monetization/application/insight_providers.dart';
import 'package:myungli_diary/features/purchase/model/ad_free_date.dart';

final DateTime _now = DateTime.utc(2026, 10, 13, 3);
final DateTime _midnight = DateTime.utc(2026, 10, 13, 15);
final DateTime _passEnd = DateTime.utc(2026, 11, 12, 3);

Insight _ad({DateTime? end}) => Insight(
  active: true,
  expiresAt: end ?? _midnight,
  source_: InsightSource_Enum.rewardedAd,
);

Insight _pass({DateTime? end}) => Insight(
  active: true,
  expiresAt: end ?? _passEnd,
  source_: InsightSource_Enum.adFreePass,
);

Me _me(Insight insight, {String accountId = 'a'}) => Me(
  accountId: accountId,
  consentRequired: false,
  requiredConsents: const [],
  hasProfile: true,
  adFree: AdFree(active: false),
  insight: insight,
);

ProviderContainer _container(Me? me) {
  final container = ProviderContainer(
    overrides: [
      meProvider.overrideWithValue(me),
      clockProvider.overrideWithValue(FixedClock(_now)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('effectiveInsight', () {
    test('비활성과 끝난 권한은 빼고, 겹치면 끝이 가장 늦은 것입니다(#952)', () {
      expect(effectiveInsight([Insight(active: false), null], _now), isNull);
      expect(
        effectiveInsight([_ad(end: _now)], _now),
        isNull,
        reason: '끝 시각이 지금이면 끝남',
      );
      expect(effectiveInsight([_ad(), _pass()], _now), _pass());
      expect(effectiveInsight([_pass(), _ad()], _now), _pass());
      final open = Insight(
        active: true,
        source_: InsightSource_Enum.subscription,
      );
      expect(
        effectiveInsight([_pass(), open], _now),
        open,
        reason: '끝 없음이 가장 늦음',
      );
    });
  });

  group('currentInsightProvider', () {
    test('내 정보의 권한을 씁니다', () {
      final container = _container(_me(_pass()));
      expect(container.read(currentInsightProvider), _pass());
      expect(container.read(insightOpenProvider), isTrue);
    });

    test('로그아웃이면 없습니다', () {
      final container = _container(null);
      expect(container.read(currentInsightProvider), isNull);
      expect(container.read(insightOpenProvider), isFalse);
    });

    test('이 실행에서 받은 같은 계정의 권한을 더하고, 다른 계정 것은 버립니다', () {
      final container = _container(_me(Insight(active: false)));
      expect(container.read(insightOpenProvider), isFalse);

      container.read(latestInsightGrantProvider.notifier).record('b', _ad());
      expect(container.read(insightOpenProvider), isFalse, reason: '다른 계정');

      container.read(latestInsightGrantProvider.notifier).record('a', _ad());
      expect(container.read(currentInsightProvider), _ad());
    });

    test('비활성 답은 남기지 않고, 같은 권한은 다시 알리지 않습니다', () {
      final container = _container(_me(Insight(active: false)));
      final notifier = container.read(latestInsightGrantProvider.notifier)
        ..record('a', Insight(active: false));
      expect(container.read(latestInsightGrantProvider), isNull);

      notifier.record('a', _ad());
      var changes = 0;
      container.listen(latestInsightGrantProvider, (_, _) => changes++);
      notifier.record('a', _ad());
      expect(changes, 0);
    });
  });

  group('unlockUntilText(evidence-sheet.unlock.until)', () {
    setUpAll(() => initializeDateFormatting('ko'));
    final ko = AppLocalizationsKo();
    final en = AppLocalizationsEn();

    test('광고 한 편이면 자정 문구(매개변수 없음)입니다', () {
      expect(
        unlockUntilText(ko, _ad(), 'Asia/Seoul'),
        ko.evidenceSheetUnlockUntilMidnight,
      );
      expect(
        unlockUntilText(en, _ad(), 'Asia/Seoul'),
        en.evidenceSheetUnlockUntilMidnight,
      );
    });

    test('광고 제거권, 구독, 모르는 이유는 기간 끝 날짜(프로필 시간대)입니다', () {
      final date = ko.evidenceSheetUnlockUntilDate(
        expiryDate('ko', _passEnd, 'Asia/Seoul'),
      );
      expect(unlockUntilText(ko, _pass(), 'Asia/Seoul'), date);
      for (final source in [
        InsightSource_Enum.subscription,
        InsightSource_Enum.unknownDefaultOpenApi,
      ]) {
        expect(
          unlockUntilText(
            ko,
            Insight(active: true, expiresAt: _passEnd, source_: source),
            'Asia/Seoul',
          ),
          date,
          reason: '$source',
        );
      }
    });

    test('날짜는 프로필 시간대의 날입니다', () {
      // 2026-11-11T20:00Z는 서울로 11월 12일, 로스앤젤레스로 11월 11일입니다.
      final end = DateTime.utc(2026, 11, 11, 20);
      expect(
        expiryDate('ko', end, 'Asia/Seoul'),
        expiryDate('ko', DateTime.utc(2026, 11, 12, 3), 'Asia/Seoul'),
      );
      expect(
        expiryDate('ko', end, 'America/Los_Angeles'),
        isNot(expiryDate('ko', end, 'Asia/Seoul')),
      );
    });

    test('권한이 없거나 날짜 문구인데 끝 시각이 없으면 꼬리표가 없습니다', () {
      expect(unlockUntilText(ko, null, 'Asia/Seoul'), isNull);
      expect(unlockUntilText(ko, Insight(active: false), 'Asia/Seoul'), isNull);
      expect(
        unlockUntilText(
          ko,
          Insight(active: true, source_: InsightSource_Enum.adFreePass),
          'Asia/Seoul',
        ),
        isNull,
      );
    });
  });
}
