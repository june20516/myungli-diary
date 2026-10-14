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
  String get actionBusy => 'Processing';

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

  @override
  String inputStepProgress(int step, int stepCount) {
    return 'Step $step of $stepCount';
  }

  @override
  String get textFieldClear => 'Clear';

  @override
  String textFieldCounter(int current, int max) {
    return '$current of $max characters';
  }

  @override
  String get datePickerYearLabel => 'Year';

  @override
  String get datePickerMonthLabel => 'Month';

  @override
  String get datePickerDayLabel => 'Day';

  @override
  String datePickerYearItem(int year) {
    return '$year';
  }

  @override
  String datePickerMonthItem(int month) {
    return '$month';
  }

  @override
  String datePickerDayItem(int day) {
    return '$day';
  }

  @override
  String get timePickerMeridiemLabel => 'AM or PM';

  @override
  String get timePickerHourLabel => 'Hour';

  @override
  String get timePickerMinuteLabel => 'Minute';

  @override
  String get timePickerAm => 'AM';

  @override
  String get timePickerPm => 'PM';

  @override
  String timePickerHourItem(int hour) {
    return '$hour';
  }

  @override
  String timePickerMinuteItem(String minute) {
    return '$minute';
  }

  @override
  String datePickerLeapMonthValue(int month) {
    return 'Leap $month';
  }

  @override
  String citySearchResults(int count) {
    return 'Results: $count';
  }

  @override
  String get forceUpdateNoticeHead => 'A new version is needed';

  @override
  String get forceUpdateNoticeBody =>
      'Please update to the latest version to keep using the app.';

  @override
  String get forceUpdateCtaStore => 'Update in the store';

  @override
  String get welcomeConceptHead => 'Read yourself today';

  @override
  String get welcomeConceptBody =>
      'Meet your day in words drawn from your birth chart, and keep it with a diary.';

  @override
  String get welcomeCtaStart => 'Get started';

  @override
  String get welcomeCtaSignin => 'I already have an account';

  @override
  String get onboardCallQuestionHead => 'What should I call you?';

  @override
  String get onboardCallInputHint => 'e.g. Star';

  @override
  String get onboardCallNoteBody => 'It doesn\'t have to be your real name.';

  @override
  String get onboardBirthQuestionHead => 'When were you born?';

  @override
  String get onboardBirthCalendarHint =>
      'For the lunar calendar, pick Lunar and check Leap month if it applies.';

  @override
  String get onboardBirthBasisNote =>
      'We calculate as if you were born in Korea.';

  @override
  String get onboardBirthErrorRange =>
      'We can calculate from January 31, 1900 to December 31, 2099.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSave => 'Save';

  @override
  String get calendarSolar => 'Solar';

  @override
  String get calendarLunar => 'Lunar';

  @override
  String get leapMonth => 'Leap month';

  @override
  String get onboardCallInputLabel => 'Name to call you';

  @override
  String get onboardTimeQuestionHead => 'What time were you born?';

  @override
  String get onboardTimeUnknownNote =>
      'If you don\'t know the time, we calculate with three pillars, leaving out the hour pillar.';

  @override
  String get timeUnknownLabel => 'Don\'t know';

  @override
  String onboardTimeHourConfirm(String branch, String start, String end) {
    return '$branch ($start–$end)';
  }

  @override
  String get branchJa => 'Rat hour';

  @override
  String get branchChuk => 'Ox hour';

  @override
  String get branchIn => 'Tiger hour';

  @override
  String get branchMyo => 'Rabbit hour';

  @override
  String get branchJin => 'Dragon hour';

  @override
  String get branchSa => 'Snake hour';

  @override
  String get branchO => 'Horse hour';

  @override
  String get branchMi => 'Goat hour';

  @override
  String get branchShin => 'Monkey hour';

  @override
  String get branchYu => 'Rooster hour';

  @override
  String get branchSul => 'Dog hour';

  @override
  String get branchHae => 'Pig hour';

  @override
  String get onboardGenderQuestionHead => 'What is your gender?';

  @override
  String get onboardGenderWhyBody =>
      'Used to work out the direction of your major luck cycles.';

  @override
  String get birthplaceQuestionHead => 'Where were you born?';

  @override
  String get birthplaceWhyBody =>
      'The time zone of your birth city is used to set your birth time.';

  @override
  String get birthplaceSearchHint => 'e.g. New York';

  @override
  String get birthplaceEmptyBody => 'No matching city. Try another name.';

  @override
  String get birthplaceSearchLabel => 'City name';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get previewCtaSave => 'Save and continue';

  @override
  String get previewCtaRestart => 'Enter again';

  @override
  String get previewShareLoginNotice => 'You can share after signing in.';

  @override
  String get dayKindYongsinDay => 'Day of your Yongsin';

  @override
  String get dayKindGwiinDay => 'Day of benefactors';

  @override
  String get dayKindGisinDay => 'Day of caution';

  @override
  String get dayKindOrdinaryDay => 'Ordinary day';

  @override
  String get shareLabel => 'Share';

  @override
  String get actionLogin => 'Sign in';

  @override
  String get actionClose => 'Close';

  @override
  String get loginTitleHead => 'Sign in to continue';

  @override
  String get loginTitleBody =>
      'Sign in to save your saju and get your reading every day.';

  @override
  String get loginDiscardNotice =>
      'This account already has a saved saju. We\'ll continue with it instead of the details you just entered.';

  @override
  String get loginKakaoLabel => 'Login with Kakao';

  @override
  String get loginAppleLabel => 'Sign in with Apple';

  @override
  String get loginCancelled => 'Sign-in was cancelled.';

  @override
  String get appleWebErrorStateMismatch =>
      'We couldn\'t verify the sign-in. Please sign in again from the start.';

  @override
  String get appleWebErrorCancelled => 'Sign in with Apple was cancelled.';

  @override
  String get appleWebErrorOther =>
      'We couldn\'t sign you in with Apple. Please try again.';

  @override
  String get actionConfirm => 'OK';

  @override
  String get consentTitleHead => 'Please agree to the terms to continue';

  @override
  String consentRequiredLabel(String document) {
    return '(Required) $document';
  }

  @override
  String consentOptionalLabel(String document) {
    return '(Optional) $document';
  }

  @override
  String get consentCtaAgree => 'Agree and continue';

  @override
  String get consentDocumentTerms => 'Terms of Service';

  @override
  String get consentDocumentPrivacy =>
      'Collection and use of personal information';

  @override
  String get consentView => 'View';
}
