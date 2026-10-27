import 'package:intl/intl.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';

/// `purchase-row` 견본(golden과 widgetbook이 함께 씁니다).
///
/// widgetbook은 별도 패키지라 test 코드를 import하지 못하므로 두 곳이 모두 읽을 수 있는
/// 앱 lib에 둡니다. 문구는 ARB(`purchase*`)에서 읽고 날짜는 고정 값(2026-10-13~2026-11-13)을
/// [localeTag]의 짧은 날짜 형식으로 만듭니다(가격이나 수익 수치는 쓰지 않음).
List<PurchaseRowData> purchaseRowSamples(
  AppLocalizations l10n,
  String localeTag,
) {
  final format = DateFormat.yMd(localeTag);
  final start = format.format(DateTime(2026, 10, 13));
  final end = format.format(DateTime(2026, 11, 13));
  final purchased = l10n.purchaseMetaPurchased(start);
  final period = l10n.purchaseMetaPeriod(start, end);
  PurchaseRowData row(
    String? status, {
    bool active = false,
    bool withPeriod = true,
  }) => PurchaseRowData(
    product: l10n.purchaseProductAdFreeMonth,
    status: status,
    active: active,
    purchased: purchased,
    period: withPeriod ? period : null,
  );
  return [
    row(l10n.purchaseStatusActive, active: true),
    row(l10n.purchaseStatusPending),
    row(l10n.purchaseStatusExpired),
    row(l10n.purchaseStatusRefunded, withPeriod: false),
    row(null, withPeriod: false),
  ];
}
