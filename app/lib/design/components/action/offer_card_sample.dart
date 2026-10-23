import 'package:intl/intl.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';

/// `offer-card` 견본(golden과 widgetbook이 함께 씁니다).
///
/// widgetbook은 별도 패키지라 test 코드를 import하지 못하므로 두 곳이 모두 읽을 수 있는
/// 앱 lib에 둡니다. 문구는 ARB(`adFree*`)에서 읽습니다. 가격 자리는 '가격'이고(공개 저장소라
/// 가격 수치를 쓰지 않음) 남은 기간 날짜는 고정 값(2026-11-23)을 [localeTag]의
/// 짧은 날짜(yMMMd) 형식으로 만듭니다(화면의 `adFreeExpiryDate`와 같음).
/// [animated]가 false면 구매 버튼의 점이 정지 상태로 그려집니다.
OfferCard offerCardSample(
  AppLocalizations l10n,
  String localeTag,
  OfferCardState state, {
  bool animated = true,
}) => OfferCard(
  state: state,
  head: l10n.adFreeOfferHead,
  price: l10n.adFreeOfferPrice('가격'),
  buyLabel: l10n.adFreeBuyCta,
  historyLabel: l10n.adFreeHistoryCta,
  legalNotice: l10n.adFreeLegalNotice,
  statusLabel: l10n.purchaseStatusActive,
  remaining: l10n.adFreeStatusRemaining(
    DateFormat.yMMMd(localeTag).format(DateTime(2026, 11, 23)),
  ),
  onBuy: () {},
  onHistory: () {},
  onLegal: () {},
  animated: animated,
);
