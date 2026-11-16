import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/monetization/application/insight_providers.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

/// 근거 열람 권한이 끝나면 들고 있는 열린 응답(오늘, 나의 사주)을 다시 받아 잠급니다(D132).
///
/// 광고로 연 근거는 본 때부터 2시간이라 하루 안에도 다시 잠깁니다. 오늘 응답은 자정에만 스스로
/// 다시 받으므로, 권한이 끝난 뒤에도 열린 응답을 들고 있으면 다음에 여는 근거 시트가 열린 채
/// 열립니다. 그래서 지금 권한([currentInsightProvider], 끝 시각에 스스로 다시 계산)이 있다가
/// 없어지면 열린 응답만 조용히 다시 받습니다. 보는 중인 시트는 붙잡아 둔 근거를 닫을 때까지
/// 그립니다(D118, V113).
///
/// 로그아웃으로 권한이 없어진 때(내 정보 없음)는 다시 받지 않습니다. 앱 셸이 구독해 살려 둡니다.
final Provider<void> insightExpiryRelockProvider = Provider<void>((ref) {
  ref.listen<Insight?>(currentInsightProvider, (previous, next) {
    if (previous == null || next != null || ref.read(meProvider) == null) {
      return;
    }
    unawaited(refreshUnlockedDaily(ref));
    unawaited(refreshUnlockedChart(ref));
  });
});
