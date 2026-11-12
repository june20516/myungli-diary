// 생성 코드: dart run tool/gen_ia.dart. 손으로 고치지 않습니다.

import 'package:myungli_diary/core/ia/ia_model.dart';

/// 화면 id 상수.
abstract final class ScreenIds {
  static const String launch = 'launch';
  static const String forceUpdate = 'force-update';
  static const String welcome = 'welcome';
  static const String onboardCall = 'onboard-call';
  static const String onboardBirth = 'onboard-birth';
  static const String onboardTime = 'onboard-time';
  static const String onboardGender = 'onboard-gender';
  static const String birthplace = 'birthplace';
  static const String preview = 'preview';
  static const String login = 'login';
  static const String consent = 'consent';
  static const String notifyAsk = 'notify-ask';
  static const String systemPush = 'system-push';
  static const String systemAppleReturn = 'system-apple-return';
  static const String adConsent = 'ad-consent';
  static const String today = 'today';
  static const String explainSheet = 'explain-sheet';
  static const String tagSheet = 'tag-sheet';
  static const String evidenceSheet = 'evidence-sheet';
  static const String sharePreview = 'share-preview';
  static const String systemShare = 'system-share';
  static const String calendar = 'calendar';
  static const String daySheet = 'day-sheet';
  static const String colorRuleSheet = 'color-rule-sheet';
  static const String eventEdit = 'event-edit';
  static const String diaryList = 'diary-list';
  static const String diaryEdit = 'diary-edit';
  static const String diaryView = 'diary-view';
  static const String tagDiary = 'tag-diary';
  static const String mySaju = 'my-saju';
  static const String sajuChart = 'saju-chart';
  static const String settings = 'settings';
  static const String contact = 'contact';
  static const String adFree = 'ad-free';
  static const String systemPurchase = 'system-purchase';
  static const String purchaseHistory = 'purchase-history';
  static const String systemRewardedAd = 'system-rewarded-ad';
  static const String profileEdit = 'profile-edit';
  static const String calcBasis = 'calc-basis';
  static const String loginMethods = 'login-methods';
  static const String accountMerge = 'account-merge';
  static const String accountDelete = 'account-delete';
  static const String legal = 'legal';
}

/// 슬롯 id 상수.
abstract final class SlotIds {
  static const String forceUpdateNoticeHead = 'force-update.notice.head';
  static const String forceUpdateNoticeBody = 'force-update.notice.body';
  static const String forceUpdateCtaStore = 'force-update.cta.store';
  static const String welcomeConceptHead = 'welcome.concept.head';
  static const String welcomeConceptBody = 'welcome.concept.body';
  static const String welcomeCtaStart = 'welcome.cta.start';
  static const String welcomeCtaSignin = 'welcome.cta.signin';
  static const String onboardCallBarTitle = 'onboard-call.bar.title';
  static const String onboardCallQuestionHead = 'onboard-call.question.head';
  static const String onboardCallInputHint = 'onboard-call.input.hint';
  static const String onboardCallNoteBody = 'onboard-call.note.body';
  static const String onboardBirthBarTitle = 'onboard-birth.bar.title';
  static const String onboardBirthQuestionHead = 'onboard-birth.question.head';
  static const String onboardBirthCalendarHint = 'onboard-birth.calendar.hint';
  static const String onboardBirthBasisNote = 'onboard-birth.basis.note';
  static const String onboardBirthErrorRange = 'onboard-birth.error.range';
  static const String onboardTimeBarTitle = 'onboard-time.bar.title';
  static const String onboardTimeQuestionHead = 'onboard-time.question.head';
  static const String onboardTimeUnknownNote = 'onboard-time.unknown.note';
  static const String onboardTimeHourConfirm = 'onboard-time.hour.confirm';
  static const String onboardGenderBarTitle = 'onboard-gender.bar.title';
  static const String onboardGenderQuestionHead =
      'onboard-gender.question.head';
  static const String onboardGenderWhyBody = 'onboard-gender.why.body';
  static const String birthplaceBarTitle = 'birthplace.bar.title';
  static const String birthplaceQuestionHead = 'birthplace.question.head';
  static const String birthplaceWhyBody = 'birthplace.why.body';
  static const String birthplaceStandardNote = 'birthplace.standard.note';
  static const String birthplaceStandardLink = 'birthplace.standard.link';
  static const String birthplaceSearchHint = 'birthplace.search.hint';
  static const String birthplaceEmptyBody = 'birthplace.empty.body';
  static const String previewBarTitle = 'preview.bar.title';
  static const String previewCharacterLabel = 'preview.character.label';
  static const String previewFortuneHead = 'preview.fortune.head';
  static const String previewFortuneBody = 'preview.fortune.body';
  static const String previewCtaSave = 'preview.cta.save';
  static const String previewCtaRestart = 'preview.cta.restart';
  static const String previewRestartNotice = 'preview.restart.notice';
  static const String previewUsedInput = 'preview.used.input';
  static const String previewUsedNotice = 'preview.used.notice';
  static const String previewShareLoginNotice = 'preview.share.login-notice';
  static const String loginBarTitle = 'login.bar.title';
  static const String loginTitleHead = 'login.title.head';
  static const String loginTitleBody = 'login.title.body';
  static const String loginSaveNote = 'login.save.note';
  static const String loginDiscardNotice = 'login.discard.notice';
  static const String loginErrorBody = 'login.error.body';
  static const String consentBarTitle = 'consent.bar.title';
  static const String consentTitleHead = 'consent.title.head';
  static const String consentRequiredLabel = 'consent.required.label';
  static const String consentCtaAgree = 'consent.cta.agree';
  static const String notifyAskBarTitle = 'notify-ask.bar.title';
  static const String notifyAskQuestionHead = 'notify-ask.question.head';
  static const String notifyAskWhyBody = 'notify-ask.why.body';
  static const String notifyAskTimeNote = 'notify-ask.time.note';
  static const String notifyAskCtaAllow = 'notify-ask.cta.allow';
  static const String notifyAskCtaSkip = 'notify-ask.cta.skip';
  static const String systemPushMorningBody = 'system-push.morning.body';
  static const String systemPushChannelMorning = 'system-push.channel.morning';
  static const String systemAppleReturnPageTitle =
      'system-apple-return.page.title';
  static const String systemAppleReturnPageBody =
      'system-apple-return.page.body';
  static const String systemAppleReturnPageOpen =
      'system-apple-return.page.open';
  static const String systemAppleReturnPageInstall =
      'system-apple-return.page.install';
  static const String todayBarTitle = 'today.bar.title';
  static const String todayDateSolar = 'today.date.solar';
  static const String todayDateLunar = 'today.date.lunar';
  static const String todayDateIljin = 'today.date.iljin';
  static const String todayDateVirtue = 'today.date.virtue';
  static const String todayFortuneTitle = 'today.fortune.title';
  static const String todayCharacterLabel = 'today.character.label';
  static const String todayTenGodLabel = 'today.ten-god.label';
  static const String todayFortuneHead = 'today.fortune.head';
  static const String todayFortuneBody = 'today.fortune.body';
  static const String todayFeaturedTitle = 'today.featured.title';
  static const String todayFeaturedEmpty = 'today.featured.empty';
  static const String todayLuckyTitle = 'today.lucky.title';
  static const String todayLuckyColorBody = 'today.lucky-color.body';
  static const String todayLuckyColorPairIntro = 'today.lucky-color.pair.intro';
  static const String todayLuckyColorSecondBody =
      'today.lucky-color.second.body';
  static const String todayLuckyDirectionBody = 'today.lucky-direction.body';
  static const String todayLuckyNumberBody = 'today.lucky-number.body';
  static const String todayLuckyTimeDayTitle = 'today.lucky-time.day.title';
  static const String todayLuckyTimeDayBody = 'today.lucky-time.day.body';
  static const String todayLuckyTimeNightTitle = 'today.lucky-time.night.title';
  static const String todayLuckyTimeNightBody = 'today.lucky-time.night.body';
  static const String todayLuckyTimeNightDawn = 'today.lucky-time.night.dawn';
  static const String todayLuckyTimeNightTonight =
      'today.lucky-time.night.tonight';
  static const String todayLuckyTimeBandDay = 'today.lucky-time.band.day';
  static const String todayLuckyTimeBandNight = 'today.lucky-time.band.night';
  static const String todayLuckyTimeBandNow = 'today.lucky-time.band.now';
  static const String todayLuckyTimeBandYesterday =
      'today.lucky-time.band.yesterday';
  static const String todayLuckyTimeBandTomorrow =
      'today.lucky-time.band.tomorrow';
  static const String todayEventTitle = 'today.event.title';
  static const String todayGuideTitle = 'today.guide.title';
  static const String todayGuideQuestion = 'today.guide.question';
  static const String todayGuideCta = 'today.guide.cta';
  static const String todayEventSummary = 'today.event.summary';
  static const String todayReactionLabel = 'today.reaction.label';
  static const String explainSheetTermMeaning = 'explain-sheet.term.meaning';
  static const String explainSheetTodayReason = 'explain-sheet.today.reason';
  static const String explainSheetTagDiaryLink = 'explain-sheet.tag.diary-link';
  static const String tagSheetTagMeaning = 'tag-sheet.tag.meaning';
  static const String tagSheetSentencesTitle = 'tag-sheet.sentences.title';
  static const String tagSheetSentencesEmpty = 'tag-sheet.sentences.empty';
  static const String tagSheetDiaryCta = 'tag-sheet.diary.cta';
  static const String evidenceSheetTargetBody = 'evidence-sheet.target.body';
  static const String evidenceSheetBasisBody = 'evidence-sheet.basis.body';
  static const String evidenceSheetSourceQuote = 'evidence-sheet.source.quote';
  static const String evidenceSheetPersonalBody =
      'evidence-sheet.personal.body';
  static const String evidenceSheetLockHead = 'evidence-sheet.lock.head';
  static const String evidenceSheetLockReward = 'evidence-sheet.lock.reward';
  static const String evidenceSheetLockCta = 'evidence-sheet.lock.cta';
  static const String evidenceSheetLockPass = 'evidence-sheet.lock.pass';
  static const String evidenceSheetLockUnavailable =
      'evidence-sheet.lock.unavailable';
  static const String evidenceSheetSectionBasis =
      'evidence-sheet.section.basis';
  static const String evidenceSheetSectionSource =
      'evidence-sheet.section.source';
  static const String evidenceSheetSectionPersonal =
      'evidence-sheet.section.personal';
  static const String evidenceSheetUnlockUntil = 'evidence-sheet.unlock.until';
  static const String evidenceSheetUnlockFailed =
      'evidence-sheet.unlock.failed';
  static const String evidenceSheetA11yLocked = 'evidence-sheet.a11y.locked';
  static const String evidenceSheetA11yChecking =
      'evidence-sheet.a11y.checking';
  static const String evidenceSheetA11yUnlocked =
      'evidence-sheet.a11y.unlocked';
  static const String evidenceSheetSheetTitle = 'evidence-sheet.sheet.title';
  static const String sharePreviewImageFooter = 'share-preview.image.footer';
  static const String sharePreviewImageTagline = 'share-preview.image.tagline';
  static const String sharePreviewRatioLabel = 'share-preview.ratio.label';
  static const String sharePreviewCtaShare = 'share-preview.cta.share';
  static const String calendarBarTitle = 'calendar.bar.title';
  static const String calendarLegendBody = 'calendar.legend.body';
  static const String calendarLegendRuleLink = 'calendar.legend.rule-link';
  static const String daySheetDateSolar = 'day-sheet.date.solar';
  static const String daySheetDateLunar = 'day-sheet.date.lunar';
  static const String daySheetCharacterLabel = 'day-sheet.character.label';
  static const String daySheetVerdictTitle = 'day-sheet.verdict.title';
  static const String daySheetVerdictItem = 'day-sheet.verdict.item';
  static const String daySheetVerdictExpand = 'day-sheet.verdict.expand';
  static const String daySheetVerdictCollapse = 'day-sheet.verdict.collapse';
  static const String daySheetEventTitle = 'day-sheet.event.title';
  static const String daySheetEventEmpty = 'day-sheet.event.empty';
  static const String daySheetEventAdd = 'day-sheet.event.add';
  static const String daySheetEventAllDay = 'day-sheet.event.all-day';
  static const String daySheetDiaryOpen = 'day-sheet.diary.open';
  static const String daySheetDiaryWriteCta = 'day-sheet.diary.write-cta';
  static const String colorRuleSheetSheetTitle = 'color-rule-sheet.sheet.title';
  static const String colorRuleSheetRuleBody = 'color-rule-sheet.rule.body';
  static const String eventEditBarTitle = 'event-edit.bar.title';
  static const String eventEditCharacterHint = 'event-edit.character.hint';
  static const String eventEditTitleHint = 'event-edit.title.hint';
  static const String eventEditMemoHint = 'event-edit.memo.hint';
  static const String eventEditDeleteConfirm = 'event-edit.delete.confirm';
  static const String eventEditSaveCta = 'event-edit.save.cta';
  static const String eventEditDeleteCta = 'event-edit.delete.cta';
  static const String eventEditOfflineNotice = 'event-edit.offline.notice';
  static const String eventEditSaveFailed = 'event-edit.save.failed';
  static const String diaryListBarTitle = 'diary-list.bar.title';
  static const String diaryListEmptyBody = 'diary-list.empty.body';
  static const String diaryListPickDateCta = 'diary-list.pick-date.cta';
  static const String diaryListPickDateConfirm = 'diary-list.pick-date.confirm';
  static const String diaryEditBarTitle = 'diary-edit.bar.title';
  static const String diaryEditDateDay = 'diary-edit.date.day';
  static const String diaryEditDateMonth = 'diary-edit.date.month';
  static const String diaryEditDateIljin = 'diary-edit.date.iljin';
  static const String diaryEditGuideQuestion = 'diary-edit.guide.question';
  static const String diaryEditGuideRemove = 'diary-edit.guide.remove';
  static const String diaryEditGuideAttach = 'diary-edit.guide.attach';
  static const String diaryEditBodyPlaceholder = 'diary-edit.body.placeholder';
  static const String diaryEditDraftStatus = 'diary-edit.draft.status';
  static const String diaryEditLengthCount = 'diary-edit.length.count';
  static const String diaryEditOfflineNotice = 'diary-edit.offline.notice';
  static const String diaryEditSavedTags = 'diary-edit.saved.tags';
  static const String diaryEditSaveCta = 'diary-edit.save.cta';
  static const String diaryViewBarTitle = 'diary-view.bar.title';
  static const String diaryViewCharacterLabel = 'diary-view.character.label';
  static const String diaryViewDeleteConfirm = 'diary-view.delete.confirm';
  static const String diaryViewDeletedToast = 'diary-view.deleted.toast';
  static const String tagDiaryBarTitle = 'tag-diary.bar.title';
  static const String tagDiaryTagMeaning = 'tag-diary.tag.meaning';
  static const String tagDiaryEmptyBody = 'tag-diary.empty.body';
  static const String mySajuBarTitle = 'my-saju.bar.title';
  static const String mySajuChartTitle = 'my-saju.chart.title';
  static const String mySajuChartLink = 'my-saju.chart.link';
  static const String mySajuIlganTitle = 'my-saju.ilgan.title';
  static const String mySajuIlganHead = 'my-saju.ilgan.head';
  static const String mySajuIlganBody = 'my-saju.ilgan.body';
  static const String mySajuYongsinTitle = 'my-saju.yongsin.title';
  static const String mySajuYongsinBody = 'my-saju.yongsin.body';
  static const String mySajuFlowTitle = 'my-saju.flow.title';
  static const String mySajuFlowLink = 'my-saju.flow.link';
  static const String mySajuRecordTitle = 'my-saju.record.title';
  static const String mySajuRecordFew = 'my-saju.record.few';
  static const String sajuChartBarTitle = 'saju-chart.bar.title';
  static const String sajuChartHeadTitle = 'saju-chart.head.title';
  static const String sajuChartPillarsTitle = 'saju-chart.pillars.title';
  static const String sajuChartPillarsDesc = 'saju-chart.pillars.desc';
  static const String sajuChartOhaengTitle = 'saju-chart.ohaeng.title';
  static const String sajuChartOhaengDesc = 'saju-chart.ohaeng.desc';
  static const String sajuChartYongsinBasis = 'saju-chart.yongsin.basis';
  static const String sajuChartTimeUnknownNotice =
      'saju-chart.time-unknown.notice';
  static const String sajuChartYongsinOpen = 'saju-chart.yongsin.open';
  static const String sajuChartYongsinTitle = 'saju-chart.yongsin.title';
  static const String sajuChartManseBasis = 'saju-chart.manse.basis';
  static const String sajuChartJijangganDesc = 'saju-chart.jijanggan.desc';
  static const String sajuChartUnseongDesc = 'saju-chart.unseong.desc';
  static const String sajuChartSinsalDesc = 'saju-chart.sinsal.desc';
  static const String sajuChartDaeunTitle = 'saju-chart.daeun.title';
  static const String sajuChartDaeunDesc = 'saju-chart.daeun.desc';
  static const String sajuChartSeunTitle = 'saju-chart.seun.title';
  static const String sajuChartSeunDesc = 'saju-chart.seun.desc';
  static const String settingsBarTitle = 'settings.bar.title';
  static const String settingsLanguageBirthplaceNotice =
      'settings.language.birthplace-notice';
  static const String settingsLogoutConfirm = 'settings.logout.confirm';
  static const String settingsAdFreeLabel = 'settings.ad-free.label';
  static const String settingsNotifyTimeNote = 'settings.notify-time.note';
  static const String contactBarTitle = 'contact.bar.title';
  static const String contactIntroBody = 'contact.intro.body';
  static const String contactMessageField = 'contact.message.field';
  static const String contactEmailField = 'contact.email.field';
  static const String contactAttachedNotice = 'contact.attached.notice';
  static const String contactSendCta = 'contact.send.cta';
  static const String contactSentToast = 'contact.sent.toast';
  static const String contactAddressNote = 'contact.address.note';
  static const String adFreeBarTitle = 'ad-free.bar.title';
  static const String adFreeOfferHead = 'ad-free.offer.head';
  static const String adFreeOfferPrice = 'ad-free.offer.price';
  static const String adFreeOfferPeriod = 'ad-free.offer.period';
  static const String adFreeBuyCta = 'ad-free.buy.cta';
  static const String adFreeUnavailableBody = 'ad-free.unavailable.body';
  static const String adFreeStatusRemaining = 'ad-free.status.remaining';
  static const String adFreeHistoryCta = 'ad-free.history.cta';
  static const String adFreeLegalNotice = 'ad-free.legal.notice';
  static const String purchaseHistoryBarTitle = 'purchase-history.bar.title';
  static const String purchaseHistoryEmptyBody = 'purchase-history.empty.body';
  static const String purchaseHistoryMissingNotice =
      'purchase-history.missing.notice';
  static const String profileEditBarTitle = 'profile-edit.bar.title';
  static const String profileEditRecalcNotice = 'profile-edit.recalc.notice';
  static const String profileEditRecalcConfirm = 'profile-edit.recalc.confirm';
  static const String calcBasisBarTitle = 'calc-basis.bar.title';
  static const String calcBasisConventionBody = 'calc-basis.convention.body';
  static const String calcBasisSchoolsBody = 'calc-basis.schools.body';
  static const String calcBasisLongitudeBody = 'calc-basis.longitude.body';
  static const String calcBasisLunarBody = 'calc-basis.lunar.body';
  static const String calcBasisDaeunBody = 'calc-basis.daeun.body';
  static const String loginMethodsBarTitle = 'login-methods.bar.title';
  static const String loginMethodsIntroBody = 'login-methods.intro.body';
  static const String loginMethodsLastNotice = 'login-methods.last.notice';
  static const String loginMethodsUnlinkConfirm =
      'login-methods.unlink.confirm';
  static const String loginMethodsInUseBody = 'login-methods.in-use.body';
  static const String loginMethodsMergeCta = 'login-methods.merge.cta';
  static const String loginMethodsErrorBody = 'login-methods.error.body';
  static const String accountMergeBarTitle = 'account-merge.bar.title';
  static const String accountMergeTitleHead = 'account-merge.title.head';
  static const String accountMergeAuthBody = 'account-merge.auth.body';
  static const String accountMergeNotOtherBody = 'account-merge.not-other.body';
  static const String accountMergeTitleBody = 'account-merge.title.body';
  static const String accountMergeChoiceLabel = 'account-merge.choice.label';
  static const String accountMergeOverlapNotice =
      'account-merge.overlap.notice';
  static const String accountMergeCtaMerge = 'account-merge.cta.merge';
  static const String accountMergeMergeConfirm = 'account-merge.merge.confirm';
  static const String accountDeleteBarTitle = 'account-delete.bar.title';
  static const String accountDeleteTitleHead = 'account-delete.title.head';
  static const String accountDeleteDataBody = 'account-delete.data.body';
  static const String accountDeleteCtaDelete = 'account-delete.cta.delete';
  static const String accountDeleteDeleteConfirm =
      'account-delete.delete.confirm';
  static const String legalBarTitle = 'legal.bar.title';
}

/// IA 화면 목록.
const List<IaScreen> iaScreens = [
  IaScreen(
    id: 'launch',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: ['loading', 'offline'],
    exits: [
      IaExit(to: 'today', trigger: '로그인 상태'),
      IaExit(to: 'ad-consent', trigger: '로그인 상태, 이 기기에서 광고 동의를 받지 않음'),
      IaExit(
        to: 'consent',
        trigger: '로그인 상태, 필수 동의가 없음(동의 화면에서 그만둔 계정, D90 ③)',
      ),
      IaExit(to: 'onboard-call', trigger: '로그인 상태, 동의는 했지만 사주가 없음(D90 ③)'),
      IaExit(to: 'welcome', trigger: '로그아웃 상태'),
      IaExit(to: 'force-update', trigger: '앱 버전이 최소 버전보다 낮음'),
    ],
    components: ['skeleton'],
  ),
  IaScreen(
    id: 'force-update',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: [],
    exits: [],
    components: ['primary-button'],
  ),
  IaScreen(
    id: 'welcome',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.guest,
    states: [],
    exits: [
      IaExit(to: 'onboard-call', trigger: '시작하기'),
      IaExit(to: 'login', trigger: '이미 계정이 있어요'),
    ],
    components: ['primary-button'],
  ),
  IaScreen(
    id: 'onboard-call',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: [],
    exits: [
      IaExit(to: 'onboard-birth', trigger: '다음'),
      IaExit(to: 'profile-edit', trigger: '정보 수정에서 온 경우 저장'),
    ],
    components: ['app-bar', 'input-step', 'text-field', 'primary-button'],
  ),
  IaScreen(
    id: 'onboard-birth',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: ['out-of-range'],
    exits: [
      IaExit(to: 'onboard-time', trigger: '다음'),
      IaExit(to: 'profile-edit', trigger: '정보 수정에서 온 경우 저장'),
    ],
    components: ['app-bar', 'input-step', 'date-picker', 'primary-button'],
  ),
  IaScreen(
    id: 'onboard-time',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: ['time-unknown'],
    exits: [
      IaExit(to: 'onboard-gender', trigger: '다음'),
      IaExit(to: 'profile-edit', trigger: '정보 수정에서 온 경우 저장'),
    ],
    components: ['app-bar', 'input-step', 'time-picker', 'primary-button'],
  ),
  IaScreen(
    id: 'onboard-gender',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: [],
    exits: [
      IaExit(to: 'preview', trigger: '다음(기기 지역이 한국)'),
      IaExit(to: 'birthplace', trigger: '다음(기기 지역이 한국 밖)'),
      IaExit(to: 'profile-edit', trigger: '정보 수정에서 온 경우 저장'),
      IaExit(to: 'notify-ask', trigger: '로그인한 새 계정이 미리보기 없이 온보딩을 마침(프로필 저장)'),
    ],
    components: ['app-bar', 'input-step', 'segmented', 'primary-button'],
  ),
  IaScreen(
    id: 'birthplace',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: ['loading', 'empty', 'error'],
    exits: [
      IaExit(to: 'preview', trigger: '온보딩에서 도시 선택'),
      IaExit(to: 'profile-edit', trigger: '정보 수정에서 도시 선택'),
      IaExit(to: 'settings', trigger: '언어 변경 안내에서 도시 선택'),
      IaExit(to: 'notify-ask', trigger: '로그인한 새 계정이 미리보기 없이 온보딩을 마침(프로필 저장)'),
      IaExit(to: 'calc-basis', trigger: '계산 기준 보기'),
    ],
    components: [
      'app-bar',
      'input-step',
      'city-search',
      'empty-state',
      'depth-link',
    ],
  ),
  IaScreen(
    id: 'preview',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.guest,
    states: ['loading', 'error', 'offline', 'time-unknown'],
    exits: [
      IaExit(to: 'login', trigger: '저장하고 계속하기'),
      IaExit(to: 'login', trigger: '공유 → 로그인 안내 창에서 로그인'),
      IaExit(to: 'onboard-call', trigger: '다시 입력'),
    ],
    components: [
      'app-bar',
      'day-character',
      'sentence-block',
      'share-button',
      'primary-button',
      'dialog',
      'settings-row',
    ],
  ),
  IaScreen(
    id: 'login',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.guest,
    states: ['error'],
    exits: [
      IaExit(
        to: 'consent',
        trigger: '필수 동의가 없는 계정(새 계정이거나 동의 화면에서 그만둔 계정, D90 ③)',
      ),
      IaExit(
        to: 'notify-ask',
        trigger: '동의는 했지만 사주가 없는 계정, 미리보기를 거침(미리보기 입력을 저장, D90 ③)',
      ),
      IaExit(
        to: 'onboard-call',
        trigger: '동의는 했지만 사주가 없는 계정, 미리보기를 거치지 않음(D90 ③)',
      ),
      IaExit(to: 'today', trigger: '사주가 저장된 계정'),
      IaExit(to: 'ad-consent', trigger: '사주가 저장된 계정, 이 기기에서 광고 동의를 받지 않음'),
    ],
    components: ['app-bar', 'social-login-button', 'dialog'],
  ),
  IaScreen(
    id: 'consent',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['error'],
    exits: [
      IaExit(to: 'notify-ask', trigger: '동의(미리보기를 거친 계정)'),
      IaExit(to: 'onboard-call', trigger: '동의(그 외 계정)'),
      IaExit(to: 'legal', trigger: '약관 전문 보기'),
    ],
    components: ['app-bar', 'check-row', 'primary-button'],
  ),
  IaScreen(
    id: 'notify-ask',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: [],
    exits: [IaExit(to: 'ad-consent', trigger: '허락 또는 건너뛰기')],
    components: ['app-bar', 'input-step', 'time-picker', 'primary-button'],
  ),
  IaScreen(
    id: 'system-push',
    tab: null,
    presentation: IaPresentation.system,
    auth: IaAuth.member,
    states: [],
    exits: [IaExit(to: 'today', trigger: '알림 누름')],
    components: [],
  ),
  IaScreen(
    id: 'system-apple-return',
    tab: null,
    presentation: IaPresentation.system,
    auth: IaAuth.any,
    states: [],
    exits: [IaExit(to: 'welcome', trigger: '앱에서 열기')],
    components: [],
  ),
  IaScreen(
    id: 'ad-consent',
    tab: null,
    presentation: IaPresentation.system,
    auth: IaAuth.member,
    states: [],
    exits: [IaExit(to: 'today', trigger: '허락 또는 거절')],
    components: [],
  ),
  IaScreen(
    id: 'today',
    tab: 'today',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'offline', 'time-unknown'],
    exits: [
      IaExit(to: 'diary-edit', trigger: '가이드 질문 카드의 일기 쓰기(새 일기)'),
      IaExit(to: 'diary-view', trigger: '오늘 쓴 일기 줄'),
      IaExit(to: 'explain-sheet', trigger: '날짜 머리의 덕일 표시(천덕일, 월덕일)'),
      IaExit(
        to: 'explain-sheet',
        trigger: '총운을 결정한 태그(날의 성격, 십성 묶음) 또는 문장 안 용어 토큰',
      ),
      IaExit(to: 'tag-sheet', trigger: '사주 기운 태그(사주 기운 섹션, 보조 문장 위 태그)'),
      IaExit(
        to: 'evidence-sheet',
        trigger: '근거 진입점 아이콘(헤드라인, 보조 문장)(스크린리더 이름은 design 공통 ui.depth.evidence_link)',
      ),
      IaExit(to: 'share-preview', trigger: '공유'),
      IaExit(to: 'day-sheet', trigger: '오늘 일정 한 줄'),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'date-header',
      'section-header',
      'hanja-tag',
      'sentence-block',
      'term-token',
      'reaction-button',
      'depth-link',
      'lucky-card',
      'explain-sheet',
      'event-row',
      'guide-question-card',
      'diary-row',
      'share-button',
      'ad-banner',
    ],
  ),
  IaScreen(
    id: 'explain-sheet',
    tab: 'today',
    presentation: IaPresentation.halfSheet,
    auth: IaAuth.member,
    states: ['loading', 'error'],
    exits: [
      IaExit(
        to: 'evidence-sheet',
        trigger: '근거 보기(행운 색 시트는 색마다, 행운 시간 시트는 낮과 밤마다 자기 근거, D123 ②)',
      ),
      IaExit(
        to: 'tag-diary',
        trigger: '대표 태그 시트의 "<태그>이 붙은 내 일기 보기" 꺾쇠 링크(page.push). 날의 성격 시트는 뜻만',
      ),
    ],
    components: [
      'sheet',
      'sentence-block',
      'depth-link',
      'hanja-tag',
      'stage-strip',
    ],
  ),
  IaScreen(
    id: 'tag-sheet',
    tab: 'today',
    presentation: IaPresentation.halfSheet,
    auth: IaAuth.member,
    states: ['empty'],
    exits: [
      IaExit(to: 'tag-diary', trigger: '그 태그가 붙은 내 일기 보기'),
      IaExit(to: 'evidence-sheet', trigger: '머리의 근거 진입점 아이콘'),
    ],
    components: [
      'sheet',
      'hanja-tag',
      'depth-link',
      'sentence-block',
      'tag-sentence-list',
    ],
  ),
  IaScreen(
    id: 'evidence-sheet',
    tab: 'today',
    presentation: IaPresentation.fullSheet,
    auth: IaAuth.member,
    states: ['loading', 'error'],
    exits: [
      IaExit(to: 'system-rewarded-ad', trigger: '광고 보고 열기'),
      IaExit(to: 'ad-free', trigger: '광고 제거권 안내'),
    ],
    components: [
      'sheet',
      'hanja-tag',
      'sentence-block',
      'saju-pillars',
      'primary-button',
      'toast',
    ],
  ),
  IaScreen(
    id: 'share-preview',
    tab: 'today',
    presentation: IaPresentation.halfSheet,
    auth: IaAuth.member,
    states: [],
    exits: [IaExit(to: 'system-share', trigger: '공유')],
    components: ['sheet', 'share-image', 'segmented', 'primary-button'],
  ),
  IaScreen(
    id: 'system-share',
    tab: 'today',
    presentation: IaPresentation.system,
    auth: IaAuth.member,
    states: [],
    exits: [],
    components: [],
  ),
  IaScreen(
    id: 'calendar',
    tab: 'calendar',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'offline'],
    exits: [
      IaExit(to: 'day-sheet', trigger: '날짜 누름'),
      IaExit(to: 'event-edit', trigger: '일정 추가'),
      IaExit(to: 'color-rule-sheet', trigger: '범례 끝 "길흉은 어떻게 정해지나요"'),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'calendar-month',
      'day-cell',
      'ad-banner',
    ],
  ),
  IaScreen(
    id: 'day-sheet',
    tab: 'calendar',
    presentation: IaPresentation.fullSheet,
    auth: IaAuth.member,
    states: ['loading', 'empty', 'error'],
    exits: [
      IaExit(to: 'event-edit', trigger: '일정 추가 또는 일정 누름'),
      IaExit(to: 'diary-view', trigger: '그날 일기 줄 누름'),
      IaExit(to: 'diary-edit', trigger: '<날짜> 일기 쓰기(새 일기)'),
      IaExit(to: 'explain-sheet', trigger: '한자 아이콘 태그(날의 성격, 길흉판정 내역)'),
    ],
    components: [
      'sheet',
      'date-header',
      'hanja-tag',
      'section-header',
      'fortune-verdict',
      'score-row',
      'event-row',
      'diary-row',
      'primary-button',
    ],
  ),
  IaScreen(
    id: 'color-rule-sheet',
    tab: 'calendar',
    presentation: IaPresentation.halfSheet,
    auth: IaAuth.member,
    states: [],
    exits: [],
    components: ['sheet', 'hanja-tag', 'score-row'],
  ),
  IaScreen(
    id: 'event-edit',
    tab: 'calendar',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'offline'],
    exits: [],
    components: [
      'app-bar',
      'text-field',
      'date-picker',
      'time-picker',
      'segmented',
      'primary-button',
      'dialog',
      'toast',
    ],
  ),
  IaScreen(
    id: 'diary-list',
    tab: 'diary',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'empty', 'error', 'offline'],
    exits: [
      IaExit(to: 'diary-view', trigger: '일기 누름'),
      IaExit(to: 'diary-edit', trigger: '일기 쓰기 → 날짜 고르기(기본값 오늘) → 고른 날의 새 일기'),
      IaExit(
        to: 'explain-sheet',
        trigger: '일기 줄의 태그(날의 성격 태그, 대표 태그) → 뜻 시트. 대표 태그 시트 안 꺾쇠 링크로 tag-diary(V73, V81)',
      ),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'diary-row',
      'hanja-tag',
      'date-picker',
      'primary-button',
      'empty-state',
      'ad-banner',
    ],
  ),
  IaScreen(
    id: 'diary-edit',
    tab: 'diary',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'offline', 'draft'],
    exits: [IaExit(to: 'diary-view', trigger: '상단 바 저장')],
    components: [
      'app-bar',
      'date-block',
      'sentence-block',
      'diary-editor',
      'draft-indicator',
      'notice-banner',
      'hanja-tag',
      'toast',
    ],
  ),
  IaScreen(
    id: 'diary-view',
    tab: 'diary',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error'],
    exits: [
      IaExit(to: 'diary-edit', trigger: '고치기'),
      IaExit(
        to: 'explain-sheet',
        trigger: '태그 누름 → 뜻 시트(대표 태그 시트 안 꺾쇠 링크로 tag-diary, V73)',
      ),
      IaExit(to: 'explain-sheet', trigger: '날의 성격 태그 누름'),
    ],
    components: [
      'app-bar',
      'diary-editor',
      'hanja-tag',
      'sentence-block',
      'dialog',
      'toast',
    ],
  ),
  IaScreen(
    id: 'tag-diary',
    tab: 'diary',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'empty', 'error'],
    exits: [
      IaExit(to: 'diary-view', trigger: '일기 누름'),
      IaExit(to: 'explain-sheet', trigger: '태그 뜻의 용어 토큰'),
    ],
    components: [
      'app-bar',
      'sentence-block',
      'hanja-tag',
      'term-token',
      'diary-row',
      'empty-state',
    ],
  ),
  IaScreen(
    id: 'my-saju',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'time-unknown'],
    exits: [
      IaExit(to: 'saju-chart', trigger: '사주 원국 섹션의 "사주 표"(오른쪽 꺾쇠)'),
      IaExit(
        to: 'saju-chart',
        trigger: '올해와 지금 섹션의 "대운 전체"(오른쪽 꺾쇠, 만세력과 대운 탭)',
      ),
      IaExit(to: 'explain-sheet', trigger: '용어 토큰, 십성 칩'),
      IaExit(to: 'settings', trigger: '상단 톱니'),
      IaExit(
        to: 'explain-sheet',
        trigger: '명리일기 회고의 자주 붙은 태그 → 뜻 시트(대표 태그 시트 안 꺾쇠 링크로 tag-diary, V81)',
      ),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'section-header',
      'saju-pillars',
      'ohaeng-bar',
      'sentence-block',
      'term-token',
      'lucky-card',
      'luck-pillar',
      'hanja-tag',
      'diary-summary',
      'depth-link',
      'ad-banner',
    ],
  ),
  IaScreen(
    id: 'saju-chart',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'time-unknown'],
    exits: [
      IaExit(to: 'explain-sheet', trigger: '용어 토큰(표 칸의 십성 등)'),
      IaExit(to: 'evidence-sheet', trigger: '잠긴 근거 열기'),
    ],
    components: [
      'app-bar',
      'segmented',
      'birth-info-row',
      'hanja-tag',
      'section-header',
      'saju-pillars',
      'ohaeng-bar',
      'sentence-block',
      'band-table',
      'manse-table',
      'explain-sheet',
      'stage-strip',
      'daeun-table',
      'luck-pillar',
      'scroll-hint',
      'term-token',
      'notice-banner',
    ],
  ),
  IaScreen(
    id: 'settings',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: [],
    exits: [
      IaExit(to: 'ad-free', trigger: '광고 제거'),
      IaExit(to: 'profile-edit', trigger: '정보 수정'),
      IaExit(to: 'birthplace', trigger: '언어 변경 안내에서 출생지 입력'),
      IaExit(to: 'calc-basis', trigger: '계산 기준'),
      IaExit(to: 'login-methods', trigger: '로그인 수단'),
      IaExit(to: 'account-delete', trigger: '계정 삭제'),
      IaExit(to: 'legal', trigger: '약관·정책'),
      IaExit(to: 'contact', trigger: '문의하기'),
      IaExit(to: 'welcome', trigger: '로그아웃 확인'),
    ],
    components: ['app-bar', 'settings-row', 'time-picker', 'sheet', 'dialog'],
  ),
  IaScreen(
    id: 'contact',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['error'],
    exits: [IaExit(to: 'settings', trigger: '보낸 뒤')],
    components: ['app-bar', 'text-field', 'primary-button', 'toast'],
  ),
  IaScreen(
    id: 'ad-free',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'offline', 'empty'],
    exits: [
      IaExit(to: 'system-purchase', trigger: '구매'),
      IaExit(to: 'legal', trigger: '약관·정책 링크'),
      IaExit(to: 'purchase-history', trigger: '구매 내역'),
    ],
    components: ['app-bar', 'offer-card', 'primary-button'],
  ),
  IaScreen(
    id: 'system-purchase',
    tab: 'me',
    presentation: IaPresentation.system,
    auth: IaAuth.member,
    states: [],
    exits: [IaExit(to: 'ad-free', trigger: '결제 완료 또는 취소')],
    components: [],
  ),
  IaScreen(
    id: 'purchase-history',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'empty', 'error', 'offline'],
    exits: [IaExit(to: 'contact', trigger: '문의해 주세요 안내')],
    components: ['app-bar', 'purchase-row'],
  ),
  IaScreen(
    id: 'system-rewarded-ad',
    tab: null,
    presentation: IaPresentation.system,
    auth: IaAuth.member,
    states: [],
    exits: [IaExit(to: 'evidence-sheet', trigger: '시청 완료 또는 닫기')],
    components: [],
  ),
  IaScreen(
    id: 'profile-edit',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['error'],
    exits: [
      IaExit(to: 'onboard-call', trigger: '호칭'),
      IaExit(to: 'onboard-birth', trigger: '생일'),
      IaExit(to: 'onboard-time', trigger: '태어난 시간'),
      IaExit(to: 'onboard-gender', trigger: '성별'),
      IaExit(to: 'birthplace', trigger: '출생지'),
    ],
    components: ['app-bar', 'settings-row', 'notice-banner', 'dialog'],
  ),
  IaScreen(
    id: 'calc-basis',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: [],
    exits: [],
    components: ['app-bar'],
  ),
  IaScreen(
    id: 'login-methods',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['error'],
    exits: [IaExit(to: 'account-merge', trigger: '계정 합치기')],
    components: ['app-bar', 'social-login-button', 'primary-button', 'dialog'],
  ),
  IaScreen(
    id: 'account-merge',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error'],
    exits: [IaExit(to: 'login-methods', trigger: '합치기 완료')],
    components: [
      'app-bar',
      'social-login-button',
      'account-choice',
      'primary-button',
      'dialog',
    ],
  ),
  IaScreen(
    id: 'account-delete',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['error'],
    exits: [IaExit(to: 'welcome', trigger: '삭제 완료')],
    components: ['app-bar', 'primary-button', 'dialog'],
  ),
  IaScreen(
    id: 'legal',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.any,
    states: [],
    exits: [],
    components: ['app-bar', 'settings-row'],
  ),
];
