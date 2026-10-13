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
  String get appTitle => 'Myungli Diary';

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
  String get todayReactionLabel => 'Like this sentence';

  @override
  String termTokenSemantics(String term) {
    return 'View the meaning of $term';
  }
}
