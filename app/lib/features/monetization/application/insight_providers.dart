import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/features/monetization/application/entitlements_providers.dart';

/// 이 실행에서 계정 [accountId]가 받은 근거 열람 권한 [insight](`getEntitlements`).
@immutable
final class InsightGrant {
  /// 받은 권한을 담습니다.
  const new({required this.accountId, required this.insight});

  /// 권한을 받은 계정.
  final String accountId;

  /// 받은 권한(활성).
  final Insight insight;
}

/// 이 실행에서 마지막으로 받은 활성 근거 열람 권한.
///
/// 내 정보(`getMe`)는 진입 때 받아 두므로, 그 뒤 보상형 광고로 생긴 권한은 근거 시트가 묻는
/// 이용권(`getEntitlements`)에서 압니다. 비활성 답은 남기지 않고(끝남은 `expiresAt`으로 봄),
/// 같은 권한을 다시 받으면 바꾸지 않습니다.
class LatestInsightGrant extends Notifier<InsightGrant?> {
  @override
  InsightGrant? build() => null;

  /// [accountId] 계정이 받은 [insight]를 남깁니다. 활성이 아니면 무시합니다.
  void record(String accountId, Insight insight) {
    final current = state;
    if (!insight.active ||
        (current != null &&
            current.accountId == accountId &&
            current.insight == insight)) {
      return;
    }
    state = InsightGrant(accountId: accountId, insight: insight);
  }
}

/// [LatestInsightGrant] provider.
final NotifierProvider<LatestInsightGrant, InsightGrant?>
latestInsightGrantProvider =
    NotifierProvider<LatestInsightGrant, InsightGrant?>(LatestInsightGrant.new);

/// [candidates] 가운데 [now]에 아직 활성인 권한. 여럿이면 끝이 가장 늦은 것이고(server 규칙,
/// #952: 겹치면 끝이 가장 늦은 부여의 이유), 끝 시각이 없으면 끝나지 않는 것으로 봅니다.
/// 없으면 null입니다.
Insight? effectiveInsight(Iterable<Insight?> candidates, DateTime now) {
  Insight? best;
  for (final insight in candidates) {
    if (insight == null || !insight.active) continue;
    final end = insight.expiresAt;
    if (end != null && !end.isAfter(now)) continue;
    final bestEnd = best?.expiresAt;
    if (best == null ||
        (bestEnd != null && (end == null || end.isAfter(bestEnd)))) {
      best = insight;
    }
  }
  return best;
}

/// 지금 근거와 해석 열람 권한(D60, D118). 로그아웃이거나 권한이 없으면 null입니다.
///
/// 내 정보(`Me.insight`)와 이 실행에서 받은 권한([latestInsightGrantProvider], 같은 계정일
/// 때만) 가운데 지금 활성인 것을 고릅니다([effectiveInsight]). 끝 시각이 지나면 스스로 다시
/// 계산합니다(흐르는 시계일 때).
final currentInsightProvider = Provider<Insight?>((ref) {
  final me = ref.watch(meProvider);
  if (me == null) return null;
  final grant = ref.watch(latestInsightGrantProvider);
  final clock = ref.watch(clockProvider);
  final insight = effectiveInsight([
    me.insight,
    if (grant != null && grant.accountId == me.accountId) grant.insight,
  ], clock.nowUtc());
  final end = insight?.expiresAt;
  if (end != null && clock.advances) {
    final timer = Timer(end.difference(clock.nowUtc()), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return insight;
});

/// 지금 근거와 해석 열람 권한이 있는지. 근거 아이콘(`depth-link` `icon.unlocked`)이 씁니다.
final insightOpenProvider = Provider<bool>(
  (ref) => ref.watch(currentInsightProvider) != null,
);

/// 근거 시트 열림 꼬리표(`evidence-sheet.unlock.until`)가 쓰는 권한(열린 이유와 끝 시각).
///
/// 알고 있는 권한([currentInsightProvider])이 있으면 그것이고, 없으면(진입 뒤 다른 길로 열린
/// 응답) 이용권을 한 번 물어 남깁니다. 통신 실패나 권한 없음은 null이라 꼬리표를 그리지
/// 않습니다. 시트가 닫히면 버려집니다.
final FutureProvider<Insight?> unlockTagInsightProvider =
    FutureProvider.autoDispose<Insight?>((ref) async {
      final known = ref.watch(currentInsightProvider);
      if (known != null) return known;
      final me = ref.watch(meProvider);
      if (me == null) return null;
      try {
        final entitlements = await ref
            .read(entitlementsRepositoryProvider)
            .fetch();
        if (!ref.mounted) return null;
        ref
            .read(latestInsightGrantProvider.notifier)
            .record(me.accountId, entitlements.insight);
        return entitlements.insight.active ? entitlements.insight : null;
      } on AppError {
        return null;
      }
    });
