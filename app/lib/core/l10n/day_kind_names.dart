import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';

/// 날의 성격 이름(`day-character` 배지 글자). 서버가 이름 문장을 주지 않으므로 ARB에서 고릅니다.
String dayKindName(AppLocalizations l10n, DayKind kind) => switch (kind) {
  DayKind.yongsinDay => l10n.dayKindYongsinDay,
  DayKind.gwiinDay => l10n.dayKindGwiinDay,
  DayKind.gisinDay => l10n.dayKindGisinDay,
  DayKind.ordinaryDay => l10n.dayKindOrdinaryDay,
};
