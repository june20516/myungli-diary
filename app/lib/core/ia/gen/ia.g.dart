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
  static const String evidenceSheet = 'evidence-sheet';
  static const String sharePreview = 'share-preview';
  static const String systemShare = 'system-share';
  static const String calendar = 'calendar';
  static const String daySheet = 'day-sheet';
  static const String eventEdit = 'event-edit';
  static const String diaryList = 'diary-list';
  static const String diaryEdit = 'diary-edit';
  static const String diaryView = 'diary-view';
  static const String tagDiary = 'tag-diary';
  static const String mySaju = 'my-saju';
  static const String sajuChart = 'saju-chart';
  static const String settings = 'settings';
  static const String adFree = 'ad-free';
  static const String systemPurchase = 'system-purchase';
  static const String systemRewardedAd = 'system-rewarded-ad';
  static const String profileEdit = 'profile-edit';
  static const String calcBasis = 'calc-basis';
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
  static const String onboardCallQuestionHead = 'onboard-call.question.head';
  static const String onboardCallInputHint = 'onboard-call.input.hint';
  static const String onboardCallNoteBody = 'onboard-call.note.body';
  static const String onboardBirthQuestionHead = 'onboard-birth.question.head';
  static const String onboardBirthCalendarHint = 'onboard-birth.calendar.hint';
  static const String onboardBirthBasisNote = 'onboard-birth.basis.note';
  static const String onboardBirthErrorRange = 'onboard-birth.error.range';
  static const String onboardTimeQuestionHead = 'onboard-time.question.head';
  static const String onboardTimeUnknownNote = 'onboard-time.unknown.note';
  static const String onboardTimeHourConfirm = 'onboard-time.hour.confirm';
  static const String onboardGenderQuestionHead =
      'onboard-gender.question.head';
  static const String onboardGenderWhyBody = 'onboard-gender.why.body';
  static const String birthplaceQuestionHead = 'birthplace.question.head';
  static const String birthplaceWhyBody = 'birthplace.why.body';
  static const String birthplaceSearchHint = 'birthplace.search.hint';
  static const String birthplaceEmptyBody = 'birthplace.empty.body';
  static const String previewCharacterLabel = 'preview.character.label';
  static const String previewFortuneHead = 'preview.fortune.head';
  static const String previewFortuneBody = 'preview.fortune.body';
  static const String previewCtaSave = 'preview.cta.save';
  static const String previewCtaRestart = 'preview.cta.restart';
  static const String previewShareLoginNotice = 'preview.share.login-notice';
  static const String loginTitleHead = 'login.title.head';
  static const String loginTitleBody = 'login.title.body';
  static const String loginDiscardNotice = 'login.discard.notice';
  static const String consentTitleHead = 'consent.title.head';
  static const String consentRequiredLabel = 'consent.required.label';
  static const String consentCtaAgree = 'consent.cta.agree';
  static const String notifyAskQuestionHead = 'notify-ask.question.head';
  static const String notifyAskWhyBody = 'notify-ask.why.body';
  static const String notifyAskCtaAllow = 'notify-ask.cta.allow';
  static const String notifyAskCtaSkip = 'notify-ask.cta.skip';
  static const String systemPushMorningBody = 'system-push.morning.body';
  static const String systemAppleReturnPageTitle =
      'system-apple-return.page.title';
  static const String systemAppleReturnPageBody =
      'system-apple-return.page.body';
  static const String systemAppleReturnPageOpen =
      'system-apple-return.page.open';
  static const String systemAppleReturnPageInstall =
      'system-apple-return.page.install';
  static const String todayCharacterLabel = 'today.character.label';
  static const String todayCharacterReason = 'today.character.reason';
  static const String todayFortuneHead = 'today.fortune.head';
  static const String todayFortuneBody = 'today.fortune.body';
  static const String todayLuckyColorBody = 'today.lucky-color.body';
  static const String todayLuckyDirectionBody = 'today.lucky-direction.body';
  static const String todayLuckyNumberBody = 'today.lucky-number.body';
  static const String todayLuckyTimeBody = 'today.lucky-time.body';
  static const String todayGuideQuestion = 'today.guide.question';
  static const String todayGuideCta = 'today.guide.cta';
  static const String todayEventSummary = 'today.event.summary';
  static const String todayReactionLabel = 'today.reaction.label';
  static const String explainSheetTermMeaning = 'explain-sheet.term.meaning';
  static const String explainSheetTodayReason = 'explain-sheet.today.reason';
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
  static const String evidenceSheetUnlockFailed =
      'evidence-sheet.unlock.failed';
  static const String evidenceSheetA11yLocked = 'evidence-sheet.a11y.locked';
  static const String evidenceSheetA11yChecking =
      'evidence-sheet.a11y.checking';
  static const String evidenceSheetA11yUnlocked =
      'evidence-sheet.a11y.unlocked';
  static const String sharePreviewImageFooter = 'share-preview.image.footer';
  static const String sharePreviewImageTagline = 'share-preview.image.tagline';
  static const String sharePreviewRatioLabel = 'share-preview.ratio.label';
  static const String sharePreviewCtaShare = 'share-preview.cta.share';
  static const String calendarLegendBody = 'calendar.legend.body';
  static const String daySheetCharacterLabel = 'day-sheet.character.label';
  static const String daySheetCharacterReason = 'day-sheet.character.reason';
  static const String daySheetEventEmpty = 'day-sheet.event.empty';
  static const String daySheetEventAdd = 'day-sheet.event.add';
  static const String daySheetDiaryOpen = 'day-sheet.diary.open';
  static const String daySheetDiaryWriteCta = 'day-sheet.diary.write-cta';
  static const String eventEditCharacterHint = 'event-edit.character.hint';
  static const String eventEditTitleHint = 'event-edit.title.hint';
  static const String eventEditMemoHint = 'event-edit.memo.hint';
  static const String eventEditDeleteConfirm = 'event-edit.delete.confirm';
  static const String diaryListEmptyBody = 'diary-list.empty.body';
  static const String diaryListPickDateCta = 'diary-list.pick-date.cta';
  static const String diaryEditGuideQuestion = 'diary-edit.guide.question';
  static const String diaryEditBodyPlaceholder = 'diary-edit.body.placeholder';
  static const String diaryEditDraftStatus = 'diary-edit.draft.status';
  static const String diaryEditOfflineNotice = 'diary-edit.offline.notice';
  static const String diaryEditSavedTags = 'diary-edit.saved.tags';
  static const String diaryViewCharacterLabel = 'diary-view.character.label';
  static const String diaryViewDeleteConfirm = 'diary-view.delete.confirm';
  static const String tagDiaryTagMeaning = 'tag-diary.tag.meaning';
  static const String tagDiaryEmptyBody = 'tag-diary.empty.body';
  static const String mySajuIlganHead = 'my-saju.ilgan.head';
  static const String mySajuIlganBody = 'my-saju.ilgan.body';
  static const String mySajuYongsinBody = 'my-saju.yongsin.body';
  static const String sajuChartYongsinBasis = 'saju-chart.yongsin.basis';
  static const String sajuChartTimeUnknownNotice =
      'saju-chart.time-unknown.notice';
  static const String sajuChartYongsinOpen = 'saju-chart.yongsin.open';
  static const String sajuChartYongsinTitle = 'saju-chart.yongsin.title';
  static const String settingsDepthDesc = 'settings.depth.desc';
  static const String settingsLanguageBirthplaceNotice =
      'settings.language.birthplace-notice';
  static const String settingsLogoutConfirm = 'settings.logout.confirm';
  static const String settingsAdFreeLabel = 'settings.ad-free.label';
  static const String adFreeOfferHead = 'ad-free.offer.head';
  static const String adFreeOfferPrice = 'ad-free.offer.price';
  static const String adFreeStatusRemaining = 'ad-free.status.remaining';
  static const String adFreeRestoreCta = 'ad-free.restore.cta';
  static const String adFreeLegalNotice = 'ad-free.legal.notice';
  static const String profileEditRecalcNotice = 'profile-edit.recalc.notice';
  static const String profileEditRecalcConfirm = 'profile-edit.recalc.confirm';
  static const String calcBasisConventionBody = 'calc-basis.convention.body';
  static const String calcBasisLongitudeBody = 'calc-basis.longitude.body';
  static const String calcBasisLunarBody = 'calc-basis.lunar.body';
  static const String accountDeleteTitleHead = 'account-delete.title.head';
  static const String accountDeleteDataBody = 'account-delete.data.body';
  static const String accountDeleteCtaDelete = 'account-delete.cta.delete';
  static const String accountDeleteDeleteConfirm =
      'account-delete.delete.confirm';
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
    ],
    components: ['app-bar', 'input-step', 'city-search', 'empty-state'],
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
    ],
  ),
  IaScreen(
    id: 'login',
    tab: null,
    presentation: IaPresentation.page,
    auth: IaAuth.guest,
    states: ['error'],
    exits: [
      IaExit(to: 'consent', trigger: '새 계정'),
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
      IaExit(to: 'notify-ask', trigger: '동의(미리보기를 거친 새 계정)'),
      IaExit(to: 'onboard-call', trigger: '동의(그 외 새 계정)'),
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
      IaExit(to: 'diary-edit', trigger: '가이드 질문 카드(오늘 일기 없음)'),
      IaExit(to: 'diary-view', trigger: '가이드 질문 카드(오늘 일기 있음)'),
      IaExit(to: 'explain-sheet', trigger: '용어 토큰'),
      IaExit(to: 'evidence-sheet', trigger: '근거 보기'),
      IaExit(to: 'share-preview', trigger: '공유'),
      IaExit(to: 'day-sheet', trigger: '오늘 일정 한 줄'),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'day-character',
      'sentence-block',
      'term-token',
      'reaction-button',
      'lucky-card',
      'guide-question-card',
      'event-row',
      'share-button',
      'depth-link',
      'ad-banner',
    ],
  ),
  IaScreen(
    id: 'explain-sheet',
    tab: 'today',
    presentation: IaPresentation.halfSheet,
    auth: IaAuth.member,
    states: ['loading', 'error'],
    exits: [IaExit(to: 'evidence-sheet', trigger: '근거 보기')],
    components: ['sheet', 'sentence-block', 'depth-link'],
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
    presentation: IaPresentation.halfSheet,
    auth: IaAuth.member,
    states: ['loading', 'empty', 'error'],
    exits: [
      IaExit(to: 'event-edit', trigger: '일정 추가 또는 일정 누름'),
      IaExit(to: 'diary-view', trigger: '그날 일기 보기'),
      IaExit(to: 'diary-edit', trigger: '이날 일기 쓰기'),
      IaExit(to: 'explain-sheet', trigger: '용어 토큰'),
    ],
    components: ['sheet', 'day-character', 'event-row', 'term-token'],
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
    ],
  ),
  IaScreen(
    id: 'diary-list',
    tab: 'diary',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'empty', 'error', 'offline'],
    exits: [
      IaExit(to: 'diary-view', trigger: '일기 누름 또는 고른 날에 일기 있음'),
      IaExit(to: 'diary-edit', trigger: '날짜 골라 쓰기(그날 일기 없음)'),
      IaExit(to: 'tag-diary', trigger: '태그 칩'),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'diary-row',
      'tag-chip',
      'date-picker',
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
    exits: [IaExit(to: 'diary-view', trigger: '저장')],
    components: [
      'app-bar',
      'sentence-block',
      'diary-editor',
      'draft-indicator',
      'notice-banner',
      'tag-chip',
      'toast',
      'primary-button',
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
      IaExit(to: 'tag-diary', trigger: '태그 칩'),
      IaExit(to: 'explain-sheet', trigger: '날의 성격 누름'),
    ],
    components: [
      'app-bar',
      'day-character',
      'sentence-block',
      'tag-chip',
      'dialog',
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
      IaExit(to: 'saju-chart', trigger: '근거 보기'),
      IaExit(to: 'explain-sheet', trigger: '용어 토큰'),
      IaExit(to: 'settings', trigger: '상단 톱니'),
    ],
    components: [
      'app-bar',
      'tab-bar',
      'sentence-block',
      'term-token',
      'lucky-card',
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
      IaExit(to: 'explain-sheet', trigger: '용어 토큰'),
      IaExit(to: 'evidence-sheet', trigger: '잠긴 근거 열기'),
    ],
    components: [
      'app-bar',
      'saju-pillars',
      'ohaeng-bar',
      'manse-table',
      'daeun-table',
      'term-token',
      'notice-banner',
      'segmented',
      'sentence-block',
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
      IaExit(to: 'account-delete', trigger: '계정 삭제'),
      IaExit(to: 'legal', trigger: '약관·정책'),
      IaExit(to: 'welcome', trigger: '로그아웃 확인'),
    ],
    components: [
      'app-bar',
      'settings-row',
      'segmented',
      'time-picker',
      'sheet',
      'dialog',
    ],
  ),
  IaScreen(
    id: 'ad-free',
    tab: 'me',
    presentation: IaPresentation.page,
    auth: IaAuth.member,
    states: ['loading', 'error', 'offline'],
    exits: [
      IaExit(to: 'system-purchase', trigger: '구매'),
      IaExit(to: 'legal', trigger: '약관·정책 링크'),
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
    auth: IaAuth.member,
    states: [],
    exits: [],
    components: ['app-bar'],
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
