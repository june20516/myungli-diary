// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get errorOffline => 'You\'re offline. Please check your connection.';

  @override
  String get errorTimeout =>
      'This is taking too long. Please try again in a moment.';

  @override
  String get errorClient => 'We couldn\'t complete that. Please try again.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Please try again in a moment.';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get errorNotImplemented => 'This isn\'t ready yet.';

  @override
  String get errorRequestMalformed =>
      'We couldn\'t complete that. Please try again.';

  @override
  String get errorRequestInvalid => 'Please check what you entered.';

  @override
  String get errorAuthTokenExpired =>
      'You\'ve been signed out. Please sign in again.';

  @override
  String get errorAuthTokenInvalid =>
      'We couldn\'t verify your sign-in. Please sign in again.';

  @override
  String get errorAuthRefreshReused =>
      'We signed you out to keep your account safe. Please sign in again.';

  @override
  String get errorAuthProviderTokenInvalid =>
      'Sign-in didn\'t work. Please try again.';

  @override
  String get errorAuthExchangeInvalid =>
      'Sign-in timed out. Please start again.';

  @override
  String get errorAppCheckInvalid =>
      'We couldn\'t verify the app. Please update to the latest version.';

  @override
  String get errorConsentRequired => 'Please agree to the terms to continue.';

  @override
  String get errorPreviewUsed =>
      'The preview is available once. Sign in to keep going.';

  @override
  String get errorRouteNotFound =>
      'We couldn\'t complete that. Please update the app.';

  @override
  String get errorDiaryNotFound => 'We couldn\'t find that diary entry.';

  @override
  String get errorMethodNotAllowed =>
      'We couldn\'t complete that. Please update the app.';

  @override
  String get errorProfileRequired =>
      'Please enter your birth date and time first.';

  @override
  String get errorDiaryDateTaken =>
      'There\'s already a diary entry for that day.';

  @override
  String get errorIdempotencyInProgress =>
      'Still working on it. Please check again in a moment.';

  @override
  String get errorRequestTooLarge => 'That\'s too long. Please shorten it.';

  @override
  String get errorRequestUnsupportedMediaType =>
      'We couldn\'t complete that. Please update the app.';

  @override
  String get errorDateOutOfRange =>
      'You can only view dates from January 31, 1900 to December 31, 2099.';

  @override
  String get errorBirthOutOfRange =>
      'We can only calculate dates from January 31, 1900 to December 31, 2099.';

  @override
  String get errorDateInvalid => 'That date isn\'t on the calendar.';

  @override
  String get errorRequestInconsistent => 'Please check what you entered.';

  @override
  String get errorBirthInvalid =>
      'Please check the birth date and time you entered.';

  @override
  String get errorDiaryFutureDate =>
      'You can\'t write a diary entry for a future date.';

  @override
  String get errorNameEmpty => 'Please enter a name for us to call you.';

  @override
  String get errorNameTooLong => 'That name is too long. Please shorten it.';

  @override
  String get errorNameEmoji => 'Names can\'t include emoji.';

  @override
  String get errorNameControl => 'The name has characters that can\'t be used.';

  @override
  String get errorNameInvalidChar => 'Names can\'t include brackets.';

  @override
  String get errorIdempotencyMismatch =>
      'We couldn\'t complete that. Please try again.';

  @override
  String get errorConsentVersionMismatch =>
      'The terms have changed. Please review them again.';

  @override
  String get errorRateLimited =>
      'Too many tries. Please wait a moment and try again.';

  @override
  String get errorInternal =>
      'Something went wrong on our side. Please try again in a moment.';

  @override
  String get errorEngineError =>
      'We couldn\'t calculate your reading. Please try again in a moment.';

  @override
  String get errorEngineUnavailable =>
      'We couldn\'t load your reading. Please try again in a moment.';

  @override
  String get errorAuthProviderUnavailable =>
      'Sign-in isn\'t available right now. Please try again in a moment.';

  @override
  String get errorBillingProviderUnavailable =>
      'We can\'t check purchases right now. Please try again in a moment.';

  @override
  String get errorServiceUnavailable =>
      'The app isn\'t available right now. Please try again in a moment.';

  @override
  String get errorEngineTimeout =>
      'Calculating your reading is taking too long. Please try again in a moment.';

  @override
  String get appTitle => 'Myungli Diary';

  @override
  String get bootstrapFailed =>
      'The app couldn\'t start. Please close it completely and open it again.';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionBusy => 'In progress';

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
      'You\'re offline, so this is what was saved earlier.';

  @override
  String get emptyStateDefault => 'Nothing here yet.';

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
    return 'See what $term means';
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
    return 'Leap month $month';
  }

  @override
  String datePickerSolarConfirm(String date) {
    return 'Solar: $date';
  }

  @override
  String citySearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
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
      'If your birthday is on the lunar calendar, choose Lunar. For a leap month, pick the leap month in the month list.';

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
    return 'You were born in the $branch hour, $start–$end.';
  }

  @override
  String get branchJa => 'Rat';

  @override
  String get branchChuk => 'Ox';

  @override
  String get branchIn => 'Tiger';

  @override
  String get branchMyo => 'Rabbit';

  @override
  String get branchJin => 'Dragon';

  @override
  String get branchSa => 'Snake';

  @override
  String get branchO => 'Horse';

  @override
  String get branchMi => 'Goat';

  @override
  String get branchShin => 'Monkey';

  @override
  String get branchYu => 'Rooster';

  @override
  String get branchSul => 'Dog';

  @override
  String get branchHae => 'Pig';

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
  String get birthplaceSearchLabel => 'Find your birth city';

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
  String get dayKindYongsinDay => 'Day in your favor';

  @override
  String get dayKindGwiinDay => 'Day of helpers';

  @override
  String get dayKindGisinDay => 'Day to go gently';

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
      'We couldn\'t confirm your sign-in. Please start again.';

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
  String get notifyAskCtaAllow => 'Turn on notifications';

  @override
  String get accountDeleteCtaDelete => 'Delete account';

  @override
  String get accountDeleteDataBody =>
      'Deleting your account permanently erases your chart details, diary, tags, events, and any remaining time on your purchases. Only information needed for legal reasons or fraud prevention is kept separately for a set period.';

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
  String adFreeStatusRemaining(String date) {
    return 'Ad-free until $date';
  }

  @override
  String get calcBasisConventionBody =>
      'Readings follow the standard widely used in Korea. It\'s one well-grounded approach among several schools.';

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
  String daySheetDiaryOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries this day',
      one: '$count entry this day',
    );
    return '$_temp0';
  }

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
  String get shareImageSemantics => 'Preview of today\'s sentence image';

  @override
  String get sharePreviewRatioGroup => 'Share image ratio';

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
  String get todayGuideCtaWritten => 'Write a new entry';

  @override
  String get todayGuideEyebrow => 'Today\'s question';

  @override
  String get todayGuideWritten => 'You wrote today\'s entry';

  @override
  String get todayGuideLabel => 'Diary question';

  @override
  String get todayReactionLabelSelected => 'Unlike';

  @override
  String get depthExplain => 'Reading';

  @override
  String get depthLinkEvidence => 'See the basis';

  @override
  String get todayLuckyColorName => 'Lucky color';

  @override
  String get todayLuckyDirectionName => 'Lucky direction';

  @override
  String get todayLuckyNumberName => 'Lucky number';

  @override
  String get todayLuckyTimeName => 'Best time to focus';

  @override
  String get evidenceSheetTitle => 'The basis for today\'s reading';

  @override
  String get a11yListSeparator => ', ';

  @override
  String get calendarBarTitle => 'Calendar';

  @override
  String get eventEditBarTitle => 'Event';

  @override
  String get calendarPrevMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String dayCellLunar(int month, int day) {
    return 'Lunar month $month, day $day';
  }

  @override
  String get dayCellLeapMonth => 'Leap month';

  @override
  String dayCellEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return '$_temp0';
  }

  @override
  String get dayCellDiaryWritten => 'Diary written';

  @override
  String get dayCellToday => 'Today';

  @override
  String eventRowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+$count more',
    );
    return '$_temp0';
  }

  @override
  String get eventRowAllDay => 'All day';

  @override
  String eventRowLabel(String status, String time, String title) {
    return '$status $time $title';
  }

  @override
  String todayEventSummaryNextAt(String time, String title) {
    return 'Next: $time $title';
  }

  @override
  String todayEventSummaryAllPast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count of today\'s events are done',
      one: 'Today\'s event is done',
    );
    return '$_temp0';
  }

  @override
  String get eventEditAllDay => 'All day';

  @override
  String get eventEditTimed => 'Set time';

  @override
  String get eventEditDateLabel => 'Date';

  @override
  String get eventEditTimeLabel => 'Time';

  @override
  String get eventEditSave => 'Save';

  @override
  String get eventEditDelete => 'Delete event';

  @override
  String get eventEditOfflineNotice =>
      'You\'re offline, so this can\'t be saved.';

  @override
  String get eventEditSaveFailed =>
      'We couldn\'t save the event. Please try again.';

  @override
  String get direction8N => 'North';

  @override
  String get direction8Ne => 'Northeast';

  @override
  String get direction8E => 'East';

  @override
  String get direction8Se => 'Southeast';

  @override
  String get direction8S => 'South';

  @override
  String get direction8Sw => 'Southwest';

  @override
  String get direction8W => 'West';

  @override
  String get direction8Nw => 'Northwest';

  @override
  String get birthplaceStandardLink => 'See how we calculate';

  @override
  String get birthplaceStandardNote =>
      'Myungli Diary calculates with the standard widely used in Korea. It\'s one well-grounded approach among several schools.';

  @override
  String calcBasisLongitudeBodySubtract(String longitude, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'We subtract $_temp0 from your birth time, based on $longitude. We don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';
  }

  @override
  String calcBasisLongitudeBodyAdd(String longitude, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'We add $_temp0 to your birth time, based on $longitude. We don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';
  }

  @override
  String calcBasisLongitudeBodyNone(String longitude) {
    return 'We use your birth time as is, based on $longitude. We don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';
  }

  @override
  String calcBasisLongitudeBodyEast(String degrees) {
    return '$degrees°E';
  }

  @override
  String calcBasisLongitudeBodyWest(String degrees) {
    return '$degrees°W';
  }

  @override
  String get calcBasisSchoolsBody =>
      'We show every hidden stem instead of picking just one. If you were born in the Rat hour, we count it as the next day, even before midnight. Schools handle these differently, so your results may differ from other apps or books.';

  @override
  String get accountDeleteBarTitle => 'Delete account';

  @override
  String get adFreeBarTitle => 'Remove ads';

  @override
  String get birthplaceBarTitle => 'Birthplace';

  @override
  String get calcBasisBarTitle => 'How we calculate';

  @override
  String calcBasisLongitudeBodyDstSubtract(
    String longitude,
    int minutes,
    int dstMinutes,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'We remove the $dstMinutes-minute daylight saving offset from your birth time, then subtract $_temp0 based on $longitude. We don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';
  }

  @override
  String calcBasisLongitudeBodyDstAdd(
    String longitude,
    int minutes,
    int dstMinutes,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '$minutes minute',
    );
    return 'We remove the $dstMinutes-minute daylight saving offset from your birth time, then add $_temp0 based on $longitude. We don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';
  }

  @override
  String calcBasisLongitudeBodyDstNone(String longitude, int dstMinutes) {
    return 'We remove the $dstMinutes-minute daylight saving offset from your birth time. Based on $longitude, there\'s no further adjustment. We don\'t use true solar time. If you were born within minutes of an hour boundary, your hour pillar may differ from other saju apps.';
  }

  @override
  String get consentBarTitle => 'Agree to terms';

  @override
  String get diaryEditBarTitle => 'Write';

  @override
  String get diaryListBarTitle => 'Diary';

  @override
  String diaryViewBarTitle(String date) {
    return '$date';
  }

  @override
  String get legalBarTitle => 'Terms & policies';

  @override
  String get loginBarTitle => 'Sign in';

  @override
  String get mySajuBarTitle => 'My chart';

  @override
  String get notifyAskBarTitle => 'Notifications';

  @override
  String get onboardBirthBarTitle => 'Birthday';

  @override
  String get onboardCallBarTitle => 'Your name';

  @override
  String get onboardGenderBarTitle => 'Gender';

  @override
  String get onboardTimeBarTitle => 'Birth time';

  @override
  String get previewBarTitle => 'Your first reading';

  @override
  String get profileEditBarTitle => 'Edit details';

  @override
  String get sajuChartBarTitle => 'Saju chart';

  @override
  String get settingsBarTitle => 'Settings';

  @override
  String tagDiaryBarTitle(String tag) {
    return 'Tag: $tag';
  }

  @override
  String get todayBarTitle => 'Today';

  @override
  String get errorReactionNotFound =>
      'We couldn\'t find the sentence you reacted to. Please refresh the screen.';

  @override
  String get errorScheduleNotFound =>
      'We couldn\'t find that event. Please refresh the list.';

  @override
  String get errorRangeTooLong =>
      'That date range is too long. Please choose a shorter range.';

  @override
  String get diaryEditSave => 'Save';

  @override
  String get diaryViewEditAction => 'Edit entry';

  @override
  String get diaryViewDeleteAction => 'Delete entry';

  @override
  String get diaryViewDeleted => 'Entry deleted.';

  @override
  String diaryListPickDateConfirm(String date) {
    return 'Write a $date entry';
  }

  @override
  String tagChipLabel(String tag) {
    return '#$tag';
  }

  @override
  String get tagChipPolarityGood => 'favorable';

  @override
  String get tagChipPolarityBad => 'take care';

  @override
  String get tagChipPolarityNeutral => 'neutral';

  @override
  String dayCellLeapNewMoon(int month) {
    return 'L$month.1';
  }

  @override
  String get errorCityNotFound =>
      'We couldn\'t find that city. Please choose your birthplace again.';

  @override
  String get errorTimezoneInvalid =>
      'We couldn\'t read the time zone. Please check your device\'s time zone setting.';

  @override
  String get settingsNotifyLabel => 'Reading time';

  @override
  String get settingsNotifyOff => 'Off';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLogoutLabel => 'Log out';

  @override
  String get profileEditBirthplaceKorea => 'South Korea';

  @override
  String get sajuChartTabNatal => 'Natal chart';

  @override
  String get sajuChartTabLuck => 'Pillars & cycles';

  @override
  String get sajuPillarHour => 'Hour';

  @override
  String get sajuPillarDay => 'Day';

  @override
  String get sajuPillarMonth => 'Month';

  @override
  String get sajuPillarYear => 'Year';

  @override
  String get manseRowHiddenStems => 'Hidden stems';

  @override
  String get manseRowTwelveStages => '12 stages';

  @override
  String get manseRowShinsal => 'Spirit stars';

  @override
  String get sajuTagMe => 'Me';

  @override
  String get daeunTagNow => 'Now';

  @override
  String get seunTagThisYear => 'This year';

  @override
  String daeunTableLabel(int age) {
    return 'Luck cycles from age $age';
  }

  @override
  String ohaengBarItem(String element, String count) {
    return '$element $count';
  }

  @override
  String get sajuPillarDayMaster => 'Day master';

  @override
  String get sajuPillarsTableLabel => 'Birth chart';

  @override
  String get manseTableLabel => 'Manseryeok table';

  @override
  String get evidenceSheetPersonalEmpty =>
      'The reading for this spot isn\'t ready yet.';

  @override
  String luckYearLabel(int year) {
    return '$year';
  }

  @override
  String get legalTermsLabel => 'Terms of Service';

  @override
  String get legalPrivacyLabel => 'Privacy Policy';

  @override
  String get legalLicensesLabel => 'Open source licenses';

  @override
  String get accountMergeBarTitle => 'Merge accounts';

  @override
  String get accountMergeChoiceLabel =>
      'Which account\'s chart details should we use?';

  @override
  String get accountMergeCtaMerge => 'Merge accounts';

  @override
  String get accountMergeMergeConfirm =>
      'Merge the two accounts? This can\'t be undone.';

  @override
  String get accountMergeMergeConfirmMerge => 'Merge';

  @override
  String get accountMergeMergeConfirmCancel => 'Cancel';

  @override
  String get accountMergeOverlapNotice =>
      'Entries from the same day also all move to this account.';

  @override
  String get accountMergeTitleBody =>
      'All records from the account you\'re bringing in move here. Chart details, name, and settings come from the one you pick, and that account and its sign-in methods are deleted. Purchases move here too.';

  @override
  String get accountMergeTitleHead =>
      'Bring another account\'s records into this one?';

  @override
  String get daySheetDiaryWriteCtaWritten => 'Write a new entry for this day';

  @override
  String get daySheetDiaryWriteCtaFull => 'You\'ve written enough for this day';

  @override
  String get loginMethodsBarTitle => 'Sign-in methods';

  @override
  String get loginMethodsErrorBodyLink =>
      'We couldn\'t link it. Please try again.';

  @override
  String get loginMethodsErrorBodyUnlink =>
      'We couldn\'t unlink it. Please try again.';

  @override
  String get loginMethodsIntroBody =>
      'Link more than one method and you can sign in to this account with any of them.';

  @override
  String get loginMethodsLastNotice => 'You need at least one way to sign in.';

  @override
  String loginMethodsUnlinkConfirm(String provider) {
    return 'Unlink $provider?';
  }

  @override
  String get loginMethodsUnlinkConfirmBody =>
      'You can keep signing in with your other linked methods.';

  @override
  String get loginMethodsUnlinkConfirmUnlink => 'Unlink';

  @override
  String get loginMethodsUnlinkConfirmCancel => 'Cancel';

  @override
  String get todayGuideCtaFull => 'You\'ve written enough for today';

  @override
  String get accountChoiceCurrent => 'Current account';

  @override
  String get accountMergeError =>
      'We couldn\'t merge the accounts. Both accounts are unchanged. Please try again.';

  @override
  String accountChoiceSaju(String date, String calendar, String time) {
    return '$calendar $date $time';
  }

  @override
  String accountChoiceSajuNoTime(String date, String calendar) {
    return '$calendar $date, time unknown';
  }

  @override
  String get accountChoiceSajuEmpty => 'No chart details';

  @override
  String get diaryListPickDateConfirmFull =>
      'You\'ve written enough for this day';

  @override
  String get errorDiaryDayFull => 'You\'ve written enough for this day.';

  @override
  String get loginProviderKakao => 'Kakao';

  @override
  String get loginProviderLine => 'LINE';

  @override
  String get loginProviderGoogle => 'Google';

  @override
  String get loginProviderApple => 'Apple';

  @override
  String get loginMethodsRowConnected => 'Linked';

  @override
  String get loginMethodsRowUnlink => 'Unlink';

  @override
  String get loginLineLabel => 'Log in with LINE';

  @override
  String get loginGoogleLabel => 'Sign in with Google';

  @override
  String get settingsLoginMethodsLabel => 'Sign-in methods';

  @override
  String get errorAuthIdentityNotFound =>
      'We couldn\'t find that sign-in method. Please reopen this screen.';

  @override
  String get errorAuthProviderTaken =>
      'Another account is already linked with the same sign-in method.';

  @override
  String get errorAuthIdentityInUse =>
      'This sign-in method is linked to another account.';

  @override
  String get errorAuthLastIdentity => 'You need at least one way to sign in.';

  @override
  String get accountMergeAuthBody => 'Verify the account you\'re bringing in.';

  @override
  String get accountMergeNotOtherBodySelf =>
      'You signed in with this account\'s sign-in method. Please sign in again with one from the account you\'re bringing in.';

  @override
  String get accountMergeNotOtherBodyNone =>
      'No account is linked to this sign-in method.';

  @override
  String get adFreeHistoryCta => 'Purchase history';

  @override
  String get calcBasisDaeunBody =>
      'The 10-year luck cycle\'s start age drops the months and counts whole years.';

  @override
  String get loginMethodsInUseBody =>
      'This sign-in method is already used by another account. Unlink it there, then link it again.';

  @override
  String get loginMethodsMergeCta => 'Bring in another account\'s records';

  @override
  String get previewRestartNotice =>
      'To see a reading with your new details, try signing in.';

  @override
  String get purchaseHistoryBarTitle => 'Purchase history';

  @override
  String get purchaseHistoryEmptyBody => 'No purchases yet.';

  @override
  String get purchaseHistoryMissingNotice =>
      'If something you paid for isn\'t listed, please contact us.';

  @override
  String get accountChoiceOther => 'Account to bring in';

  @override
  String get accountMergeSummaryHead => 'Records to bring in';

  @override
  String get accountMergeSummaryDiary => 'Diary';

  @override
  String get accountMergeSummaryEvent => 'Events';

  @override
  String get accountMergeSummaryAdFree => 'Ad-free time left';

  @override
  String accountMergeSummaryDiaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '$count entry',
    );
    return '$_temp0';
  }

  @override
  String accountMergeSummaryEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return '$_temp0';
  }

  @override
  String accountMergeSummaryAdFreeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String purchaseMetaPurchased(String date) {
    return 'Bought $date';
  }

  @override
  String purchaseMetaPeriod(String start, String end) {
    return '$start–$end';
  }

  @override
  String get purchaseMetaSeparator => ' · ';

  @override
  String get purchaseProductAdFreeMonth => 'Ad-free, 1 month';

  @override
  String get purchaseStatusActive => 'Active';

  @override
  String get purchaseStatusPending => 'Upcoming';

  @override
  String get purchaseStatusExpired => 'Expired';

  @override
  String get purchaseStatusRefunded => 'Refunded';

  @override
  String get errorMergeTokenInvalid =>
      'We couldn\'t continue the merge. Verify the account you\'re bringing in again.';

  @override
  String get adFreeBuyCta => 'Buy';
}
