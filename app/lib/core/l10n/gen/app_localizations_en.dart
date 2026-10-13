// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorOffline => 'You are not connected to the internet.';

  @override
  String get errorTimeout =>
      'The response is taking too long. Please try again in a moment.';

  @override
  String get errorClient => 'The request could not be processed.';

  @override
  String get errorServer =>
      'Something went wrong on the server. Please try again in a moment.';

  @override
  String get errorUnexpected => 'Something unexpected happened.';

  @override
  String get errorNotImplemented => 'This is not available yet.';

  @override
  String get errorRequestMalformed => 'The request could not be processed.';

  @override
  String get errorRequestInvalid => 'Please check what you entered.';

  @override
  String get errorAuthTokenExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorAuthTokenInvalid => 'Please sign in again.';

  @override
  String get errorAuthRefreshReused =>
      'You were signed out for your security. Please sign in again.';

  @override
  String get errorAuthProviderTokenInvalid =>
      'Sign-in failed. Please try again.';

  @override
  String get errorAuthExchangeInvalid =>
      'Sign-in timed out. Please sign in again from the start.';

  @override
  String get errorAppCheckInvalid =>
      'We could not verify the app. Please update to the latest version.';

  @override
  String get errorConsentRequired => 'You need to agree to the terms.';

  @override
  String get errorPreviewUsed =>
      'The preview can be viewed only once. Sign in to keep going.';

  @override
  String get errorRouteNotFound =>
      'The request could not be processed. Please update the app.';

  @override
  String get errorDiaryNotFound => 'We could not find that diary entry.';

  @override
  String get errorMethodNotAllowed =>
      'The request could not be processed. Please update the app.';

  @override
  String get errorProfileRequired => 'Please enter your birth details first.';

  @override
  String get errorDiaryDateTaken =>
      'There is already a diary entry for that day.';

  @override
  String get errorIdempotencyInProgress =>
      'Still processing. Please check again in a moment.';

  @override
  String get errorRequestTooLarge => 'The content is too long.';

  @override
  String get errorRequestUnsupportedMediaType =>
      'The request could not be processed. Please update the app.';

  @override
  String get errorDateOutOfRange =>
      'Only dates from January 31, 1900 to December 31, 2099 are supported.';

  @override
  String get errorBirthOutOfRange =>
      'Please enter a birth date between January 31, 1900 and December 31, 2099.';

  @override
  String get errorDateInvalid => 'That date does not exist on the calendar.';

  @override
  String get errorRequestInconsistent => 'Please check what you entered.';

  @override
  String get errorBirthInvalid => 'Please check the birth details you entered.';

  @override
  String get errorDiaryFutureDate =>
      'You cannot write a diary entry for a future date.';

  @override
  String get errorNameEmpty => 'Please enter a name to be called.';

  @override
  String get errorNameTooLong => 'That name is too long.';

  @override
  String get errorNameEmoji => 'Names cannot include emoji.';

  @override
  String get errorNameControl =>
      'The name contains characters that cannot be used.';

  @override
  String get errorNameInvalidChar => 'Names cannot include brackets.';

  @override
  String get errorIdempotencyMismatch =>
      'The request could not be processed. Please try again.';

  @override
  String get errorConsentVersionMismatch =>
      'The terms have changed. Please review them again.';

  @override
  String get errorRateLimited =>
      'Too many requests. Please try again in a moment.';

  @override
  String get errorInternal =>
      'Something went wrong on the server. Please try again in a moment.';

  @override
  String get errorEngineError => 'We could not calculate your reading.';

  @override
  String get errorEngineUnavailable =>
      'We could not load your reading. Please try again in a moment.';

  @override
  String get errorAuthProviderUnavailable =>
      'Sign-in is unavailable right now. Please try again in a moment.';

  @override
  String get errorBillingProviderUnavailable =>
      'We cannot check purchases right now. Please try again in a moment.';

  @override
  String get errorServiceUnavailable =>
      'The service is temporarily unavailable. Please try again in a moment.';

  @override
  String get errorEngineTimeout =>
      'Calculating your reading is taking too long. Please try again in a moment.';

  @override
  String get appTitle => 'Myungli Diary';

  @override
  String get bootstrapFailed =>
      'The app could not start. Please close it completely and open it again.';

  @override
  String get actionRetry => 'Try again';

  @override
  String traceIdLabel(String traceId) {
    return 'Reference $traceId';
  }

  @override
  String get tabToday => 'Today';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabDiary => 'Diary';

  @override
  String get tabMe => 'Me';

  @override
  String get appBarBack => 'Back';

  @override
  String get sheetDismiss => 'Close';

  @override
  String get adBannerLabel => 'Ad';

  @override
  String get noticeOffline =>
      'You are offline, so this shows what was saved earlier.';

  @override
  String get emptyStateDefault => 'There is nothing to show yet.';

  @override
  String get skeletonLabel => 'Loading';

  @override
  String get traceIdCopied => 'Reference copied.';

  @override
  String get evidenceSheetSectionBasis => 'Basis';

  @override
  String get evidenceSheetSectionSource => 'Source text';

  @override
  String get evidenceSheetSectionPersonal => 'In your chart';

  @override
  String get evidenceSheetLockHead => 'The basis and reading are locked';

  @override
  String get evidenceSheetLockReward =>
      'Watch one ad to unlock the basis and reading for today.';

  @override
  String get evidenceSheetLockCta => 'Watch ad to unlock';

  @override
  String get evidenceSheetLockPass => 'Ad-free pass unlocks it right away ›';

  @override
  String get evidenceSheetLockUnavailable =>
      'No ad is available right now. Please check back soon.';

  @override
  String get evidenceSheetA11yLocked => 'Locked';

  @override
  String get evidenceSheetA11yChecking => 'Checking';

  @override
  String get evidenceSheetA11yUnlocked => 'The basis and reading are now open';

  @override
  String get sajuChartYongsinOpen => 'Open';

  @override
  String get sajuChartYongsinTitle => 'Yongsin basis';

  @override
  String get todayReactionLabel => 'Like this sentence';

  @override
  String termTokenSemantics(String term) {
    return 'View the meaning of $term';
  }
}
