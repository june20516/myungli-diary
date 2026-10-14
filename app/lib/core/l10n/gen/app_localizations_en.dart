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
  String get evidenceSheetSectionSource => 'Classical source';

  @override
  String get evidenceSheetSectionPersonal => 'In your chart';

  @override
  String get evidenceSheetLockHead => 'The basis and interpretation are locked';

  @override
  String get evidenceSheetLockReward =>
      'Watch one ad to see all the basis and interpretation for the rest of today.';

  @override
  String get evidenceSheetLockCta => 'Watch ad to unlock';

  @override
  String get evidenceSheetLockPass =>
      'With an ad-free pass, they stay unlocked the whole time.';

  @override
  String get evidenceSheetLockUnavailable =>
      'No ads are available right now. Please try again later.';

  @override
  String get evidenceSheetA11yLocked => 'Locked';

  @override
  String get evidenceSheetA11yChecking => 'Checking';

  @override
  String get evidenceSheetA11yUnlocked =>
      'The basis and interpretation are unlocked';

  @override
  String get sajuChartYongsinOpen => 'Unlock';

  @override
  String get sajuChartYongsinTitle => 'Yongsin basis';

  @override
  String get todayReactionLabel => 'Like';

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
  String get forceUpdateNoticeHead => 'Please update to the new version';

  @override
  String get forceUpdateNoticeBody =>
      'The way readings are calculated has changed, so this version can\'t open them.';

  @override
  String get forceUpdateCtaStore => 'Update';

  @override
  String get welcomeConceptHead =>
      'Today\'s day pillar, read for your own chart';

  @override
  String get welcomeConceptBody =>
      'One question based on that reading starts your diary for the day.';

  @override
  String get welcomeCtaStart => 'Get started';

  @override
  String get welcomeCtaSignin => 'I already have an account';

  @override
  String get onboardCallQuestionHead => 'What should we call you?';

  @override
  String get onboardCallInputHint => 'e.g. Alex';

  @override
  String get onboardCallNoteBody =>
      'It doesn\'t have to be your real name. You can change it later.';

  @override
  String get onboardBirthQuestionHead => 'When were you born?';

  @override
  String get onboardBirthCalendarHint =>
      'If your birthday is on the lunar calendar, choose Lunar, and mark Leap month if it applies.';

  @override
  String get onboardBirthBasisNote =>
      'We calculate as if you were born in Korea.';

  @override
  String get onboardBirthErrorRange =>
      'We can only calculate dates from January 31, 1900 to December 31, 2099.';

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
      'If you don\'t know the time, we read your chart from three pillars, leaving out the hour.';

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
      'We only use it to set the direction of your 10-year luck cycles.';

  @override
  String get birthplaceQuestionHead => 'Where were you born?';

  @override
  String get birthplaceWhyBody =>
      'We use your birthplace\'s time zone and longitude to pin down your birth hour.';

  @override
  String get birthplaceSearchHint => 'City name';

  @override
  String get birthplaceEmptyBody =>
      'No matching city. Try a larger city nearby.';

  @override
  String get birthplaceSearchLabel => 'Search birth city';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get previewCtaSave => 'Save and continue';

  @override
  String get previewCtaRestart => 'Start over';

  @override
  String get previewShareLoginNotice => 'Sign in to share today\'s reading.';

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
  String get actionClose => 'Close';

  @override
  String get loginTitleHead => 'Sign in to save your reading';

  @override
  String get loginTitleBody =>
      'Once you sign in, your chart and diary are available on any device.';

  @override
  String get loginDiscardNotice =>
      'If this account already has a saved chart, we\'ll use it instead of what you just entered.';

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
  String get consentTitleHead => 'Please review and agree';

  @override
  String get consentCtaAgree => 'Agree and continue';

  @override
  String get consentView => 'View';

  @override
  String get notifyAskQuestionHead =>
      'Would you like today\'s reading every morning?';

  @override
  String get notifyAskWhyBody =>
      'Each notification tells you what kind of day it is, with one line from your daily reading.';

  @override
  String get notifyAskCtaSkip => 'Not now';

  @override
  String get notifyAskCtaAllow => 'Turn on alerts';

  @override
  String get accountDeleteCtaDelete => 'Delete account';

  @override
  String get accountDeleteDataBody =>
      'Deleting your account permanently erases your chart details, diary, tags, events, and any remaining ad-free time.';

  @override
  String get accountDeleteDeleteConfirm =>
      'Delete your account for good? This can\'t be undone.';

  @override
  String get accountDeleteDeleteConfirmDelete => 'Delete';

  @override
  String get accountDeleteDeleteConfirmCancel => 'Cancel';

  @override
  String get accountDeleteTitleHead => 'Delete account';

  @override
  String get adFreeLegalNotice =>
      'Please review the Terms of Service and Privacy Policy before purchasing.';

  @override
  String get adFreeOfferHead =>
      'One month with no ads, and the basis and interpretation fully unlocked.';

  @override
  String adFreeOfferPrice(String price) {
    return '$price · 1 month · no auto-renewal';
  }

  @override
  String get adFreeRestoreCta => 'Restore purchase';

  @override
  String adFreeStatusRemaining(String date) {
    return 'Ad-free until $date';
  }

  @override
  String get calcBasisConventionBody =>
      'Readings follow one standard widely used in Korea.';

  @override
  String get calcBasisLongitudeBody =>
      'We subtract 30 minutes from your birth time, based on 127.5° east longitude, and don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';

  @override
  String get calcBasisLunarBody =>
      'Lunar dates follow the Korean lunar calendar published by the Korea Astronomy and Space Science Institute.';

  @override
  String get calendarLegendBodyGood => 'Smooth day';

  @override
  String get calendarLegendBodyCaution => 'Careful day';

  @override
  String get consentRequiredLabelTerms => '(Required) Terms of Service';

  @override
  String get consentRequiredLabelPrivacy =>
      '(Required) Collection and use of personal information';

  @override
  String get daySheetDiaryOpen => 'View this day\'s diary';

  @override
  String get daySheetDiaryWriteCta => 'Write about this day';

  @override
  String get daySheetEventAdd => 'Add event';

  @override
  String get daySheetEventEmpty => 'No events on this day.';

  @override
  String get diaryEditBodyPlaceholder => 'Write about your day';

  @override
  String get diaryEditDraftStatusLocal => 'Draft saved on this device';

  @override
  String get diaryEditDraftStatusSaving => 'Saving';

  @override
  String get diaryEditDraftStatusSaved => 'Saved';

  @override
  String get diaryEditOfflineNotice =>
      'We\'ll save it when you\'re back online. What you\'ve written stays on this device.';

  @override
  String get diaryEditSavedTags => 'Tags were added to your entry';

  @override
  String get diaryListEmptyBody =>
      'No diary entries yet. Why not start with today?';

  @override
  String get diaryListPickDateCta => 'Pick a date to write';

  @override
  String get diaryViewDeleteConfirm =>
      'Delete this entry? This can\'t be undone.';

  @override
  String get diaryViewDeleteConfirmDelete => 'Delete';

  @override
  String get diaryViewDeleteConfirmCancel => 'Cancel';

  @override
  String get eventEditDeleteConfirm => 'Delete this event?';

  @override
  String get eventEditDeleteConfirmDelete => 'Delete';

  @override
  String get eventEditDeleteConfirmCancel => 'Cancel';

  @override
  String get eventEditMemoHint => 'Notes';

  @override
  String get eventEditTitleHint => 'Event title';

  @override
  String get evidenceSheetLockPassLink => 'See ad-free pass';

  @override
  String get evidenceSheetUnlockFailed =>
      'Confirming the ad is taking longer than usual. Please try again shortly.';

  @override
  String get previewShareLoginNoticeConfirm => 'Sign in';

  @override
  String get previewShareLoginNoticeCancel => 'Close';

  @override
  String get profileEditRecalcConfirmTitle => 'Change your details?';

  @override
  String profileEditRecalcConfirmBody(String before, String after) {
    return '$before → $after\nToday, Calendar, and My Chart will be recalculated. Diary entries and tags you\'ve already written stay as they are.';
  }

  @override
  String get profileEditRecalcConfirmCancel => 'Cancel';

  @override
  String get profileEditRecalcConfirmSave => 'Change';

  @override
  String get profileEditRecalcNotice =>
      'Changing your birth date, time, gender, or birthplace recalculates your readings.';

  @override
  String get sajuChartTimeUnknownNotice =>
      'Your birth time is unknown, so the hour pillar is left out.';

  @override
  String get settingsAdFreeLabel => 'Remove ads';

  @override
  String settingsAdFreeLabelActive(String date) {
    return 'Until $date';
  }

  @override
  String get settingsDepthDesc =>
      'Choose how much of each reading to show at first.';

  @override
  String get settingsLanguageBirthplaceNotice =>
      'If you were born outside Korea, please enter your birthplace. It helps us match your birth hour more precisely.';

  @override
  String get settingsLanguageBirthplaceNoticeCta => 'Enter birthplace';

  @override
  String get settingsLogoutConfirm => 'Sign out?';

  @override
  String get settingsLogoutConfirmLogout => 'Sign out';

  @override
  String get settingsLogoutConfirmCancel => 'Cancel';

  @override
  String get sharePreviewCtaShare => 'Share';

  @override
  String get sharePreviewImageFooter => 'Myungli Diary';

  @override
  String get sharePreviewImageTagline =>
      'Today, read for your chart · Myungli Diary';

  @override
  String get sharePreviewRatioLabelStory => 'Story';

  @override
  String get sharePreviewRatioLabelFeed => 'Feed';

  @override
  String get sharePreviewRatioLabelSquare => 'Square';

  @override
  String get tagDiaryEmptyBody => 'No entries with this tag yet.';

  @override
  String todayEventSummary(int count, String title) {
    return 'Events today: $count · $title';
  }

  @override
  String get todayEventSummaryOngoing => 'Now';

  @override
  String get todayEventSummaryNext => 'Next';

  @override
  String get todayEventSummaryDone => 'All of today\'s events are done';

  @override
  String get todayGuideCta => 'Write in diary';

  @override
  String get todayGuideCtaWritten => 'View diary';

  @override
  String get todayReactionLabelSelected => 'Unlike';

  @override
  String get depthDefaultLabel => 'Reading detail';

  @override
  String get depthEvidence => 'Basis';

  @override
  String get depthExplain => 'Reading';

  @override
  String get depthSurface => 'Summary';
}
