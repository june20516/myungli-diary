// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get errorOffline => '인터넷에 연결되어 있지 않아요. 연결을 확인해 주세요.';

  @override
  String get errorTimeout => '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorClient => '요청을 처리하지 못했어요. 다시 시도해 주세요.';

  @override
  String get errorServer => '잠시 문제가 생겼어요. 조금 뒤에 다시 시도해 주세요.';

  @override
  String get errorUnexpected => '문제가 생겼어요. 다시 시도해 주세요.';

  @override
  String get errorNotImplemented => '아직 준비 중이에요.';

  @override
  String get errorRequestMalformed => '요청을 처리하지 못했어요. 다시 시도해 주세요.';

  @override
  String get errorRequestInvalid => '입력한 내용을 다시 확인해 주세요.';

  @override
  String get errorAuthTokenExpired => '로그인이 만료됐어요. 다시 로그인해 주세요.';

  @override
  String get errorAuthTokenInvalid => '로그인 정보를 확인하지 못했어요. 다시 로그인해 주세요.';

  @override
  String get errorAuthRefreshReused => '계정을 지키려고 로그아웃했어요. 다시 로그인해 주세요.';

  @override
  String get errorAuthProviderTokenInvalid => '로그인하지 못했어요. 다시 시도해 주세요.';

  @override
  String get errorAuthExchangeInvalid => '로그인 시간이 지났어요. 처음부터 다시 로그인해 주세요.';

  @override
  String get errorAppCheckInvalid => '앱을 확인하지 못했어요. 최신 버전으로 업데이트해 주세요.';

  @override
  String get errorConsentRequired => '약관에 동의해야 계속할 수 있어요.';

  @override
  String get errorPreviewUsed => '미리보기는 한 번만 볼 수 있어요. 로그인하면 이어서 읽을 수 있어요.';

  @override
  String get errorRouteNotFound => '요청을 처리하지 못했어요. 앱을 업데이트해 주세요.';

  @override
  String get errorDiaryNotFound => '일기를 찾지 못했어요.';

  @override
  String get errorMethodNotAllowed => '요청을 처리하지 못했어요. 앱을 업데이트해 주세요.';

  @override
  String get errorProfileRequired => '먼저 태어난 날과 시간을 입력해 주세요.';

  @override
  String get errorDiaryDateTaken => '그날에는 이미 일기가 있어요.';

  @override
  String get errorIdempotencyInProgress => '아직 처리하고 있어요. 잠시 후 다시 확인해 주세요.';

  @override
  String get errorRequestTooLarge => '내용이 너무 길어요. 조금 줄여 주세요.';

  @override
  String get errorRequestUnsupportedMediaType => '요청을 처리하지 못했어요. 앱을 업데이트해 주세요.';

  @override
  String get errorDateOutOfRange =>
      '1900년 1월 31일부터 2099년 12월 31일까지의 날짜만 볼 수 있어요.';

  @override
  String get errorBirthOutOfRange =>
      '1900년 1월 31일부터 2099년 12월 31일 사이의 날짜만 계산할 수 있어요.';

  @override
  String get errorDateInvalid => '달력에 없는 날짜예요.';

  @override
  String get errorRequestInconsistent => '입력한 내용을 다시 확인해 주세요.';

  @override
  String get errorBirthInvalid => '입력한 태어난 날과 시간을 다시 확인해 주세요.';

  @override
  String get errorDiaryFutureDate => '아직 오지 않은 날의 일기는 쓸 수 없어요.';

  @override
  String get errorNameEmpty => '불러 드릴 이름을 입력해 주세요.';

  @override
  String get errorNameTooLong => '이름이 너무 길어요. 조금 줄여 주세요.';

  @override
  String get errorNameEmoji => '이름에는 이모지를 쓸 수 없어요.';

  @override
  String get errorNameControl => '이름에 쓸 수 없는 글자가 있어요.';

  @override
  String get errorNameInvalidChar => '이름에는 괄호를 쓸 수 없어요.';

  @override
  String get errorIdempotencyMismatch => '요청을 처리하지 못했어요. 다시 시도해 주세요.';

  @override
  String get errorConsentVersionMismatch => '약관이 바뀌었어요. 다시 확인해 주세요.';

  @override
  String get errorRateLimited => '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorInternal => '잠시 문제가 생겼어요. 조금 뒤에 다시 시도해 주세요.';

  @override
  String get errorEngineError => '풀이를 계산하지 못했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorEngineUnavailable => '풀이를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorAuthProviderUnavailable => '지금은 로그인할 수 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorBillingProviderUnavailable =>
      '지금은 결제를 확인할 수 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorServiceUnavailable => '지금은 앱을 쓸 수 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorEngineTimeout => '풀이 계산이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get appTitle => '명리일기';

  @override
  String get bootstrapFailed => '앱을 열지 못했어요. 앱을 완전히 닫았다가 다시 열어 주세요.';

  @override
  String get actionRetry => '다시 시도';

  @override
  String get actionBusy => '처리 중';

  @override
  String traceIdLabel(String traceId) {
    return '문의 번호 $traceId';
  }

  @override
  String get tabToday => '오늘';

  @override
  String get tabCalendar => '달력';

  @override
  String get tabDiary => '일기';

  @override
  String get tabMe => '나';

  @override
  String get appBarBack => '뒤로';

  @override
  String get sheetDismiss => '닫기';

  @override
  String get adBannerLabel => '광고';

  @override
  String get noticeOffline => '인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.';

  @override
  String get emptyStateDefault => '아직 보여 드릴 내용이 없어요.';

  @override
  String get skeletonLabel => '불러오는 중';

  @override
  String get traceIdCopied => '문의 번호를 복사했어요.';

  @override
  String get evidenceSheetSectionBasis => '판정 근거';

  @override
  String get evidenceSheetSectionSource => '원전';

  @override
  String get evidenceSheetSectionPersonal => '내 사주에서는';

  @override
  String get evidenceSheetLockHead => '근거와 해석은 잠겨 있어요';

  @override
  String get evidenceSheetLockReward => '광고 한 편을 보면 오늘 하루 근거와 해석을 모두 볼 수 있어요.';

  @override
  String get evidenceSheetLockCta => '광고 보고 열기';

  @override
  String get evidenceSheetLockPass => '광고 제거권이 있으면 기간 내내 열려 있어요.';

  @override
  String get evidenceSheetLockUnavailable =>
      '지금은 볼 수 있는 광고가 없어요. 잠시 뒤에 다시 해 주세요.';

  @override
  String get evidenceSheetA11yLocked => '잠김';

  @override
  String get evidenceSheetA11yChecking => '확인 중';

  @override
  String get evidenceSheetA11yUnlocked => '근거와 해석이 열렸어요';

  @override
  String get sajuChartYongsinOpen => '열기';

  @override
  String get sajuChartYongsinTitle => '용신 판정 근거';

  @override
  String get todayReactionLabel => '좋아요';

  @override
  String termTokenSemantics(String term) {
    return '$term 뜻 보기';
  }

  @override
  String inputStepProgress(int step, int stepCount) {
    return '$stepCount단계 중 $step단계';
  }

  @override
  String get textFieldClear => '지우기';

  @override
  String textFieldCounter(int current, int max) {
    return '$max자 중 $current자';
  }

  @override
  String get datePickerYearLabel => '연도';

  @override
  String get datePickerMonthLabel => '월';

  @override
  String get datePickerDayLabel => '일';

  @override
  String datePickerYearItem(int year) {
    return '$year년';
  }

  @override
  String datePickerMonthItem(int month) {
    return '$month월';
  }

  @override
  String datePickerDayItem(int day) {
    return '$day일';
  }

  @override
  String get timePickerMeridiemLabel => '오전·오후';

  @override
  String get timePickerHourLabel => '시';

  @override
  String get timePickerMinuteLabel => '분';

  @override
  String get timePickerAm => '오전';

  @override
  String get timePickerPm => '오후';

  @override
  String timePickerHourItem(int hour) {
    return '$hour시';
  }

  @override
  String timePickerMinuteItem(String minute) {
    return '$minute분';
  }

  @override
  String datePickerLeapMonthValue(int month) {
    return '윤$month월';
  }

  @override
  String datePickerSolarConfirm(String date) {
    return '양력 $date';
  }

  @override
  String citySearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '결과 $_temp0';
  }

  @override
  String get forceUpdateNoticeHead => '새 버전으로 업데이트해 주세요';

  @override
  String get forceUpdateNoticeBody => '풀이를 계산하는 방식이 바뀌어서 지금 버전으로는 열 수 없어요.';

  @override
  String get forceUpdateCtaStore => '업데이트하기';

  @override
  String get welcomeConceptHead => '오늘 일진을 내 사주에 맞춰 풀어 드려요';

  @override
  String get welcomeConceptBody => '풀이에 맞춘 질문 하나로 그날 일기를 시작해요.';

  @override
  String get welcomeCtaStart => '시작하기';

  @override
  String get welcomeCtaSignin => '이미 계정이 있어요';

  @override
  String get onboardCallQuestionHead => '어떻게 불러 드릴까요?';

  @override
  String get onboardCallInputHint => '예: 민지';

  @override
  String get onboardCallNoteBody => '실명이 아니어도 돼요. 나중에 바꿀 수 있어요.';

  @override
  String get onboardBirthQuestionHead => '언제 태어났나요?';

  @override
  String get onboardBirthCalendarHint =>
      '음력 생일이면 음력을 골라 주세요. 윤달이면 달 목록에 있는 윤달을 고르면 돼요.';

  @override
  String get onboardBirthBasisNote => '한국에서 태어난 것을 기준으로 계산해요.';

  @override
  String get onboardBirthErrorRange =>
      '1900년 1월 31일부터 2099년 12월 31일 사이의 날짜만 계산할 수 있어요.';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingSave => '저장';

  @override
  String get calendarSolar => '양력';

  @override
  String get calendarLunar => '음력';

  @override
  String get onboardCallInputLabel => '불러 드릴 이름';

  @override
  String get onboardTimeQuestionHead => '몇 시에 태어났나요?';

  @override
  String get onboardTimeUnknownNote => '시간을 모르면 태어난 시를 빼고 세 기둥으로 풀어요.';

  @override
  String get timeUnknownLabel => '모름';

  @override
  String onboardTimeHourConfirm(String branch, String start, String end) {
    return '$branch시, $start~$end에 태어났어요.';
  }

  @override
  String get branchJa => '자';

  @override
  String get branchChuk => '축';

  @override
  String get branchIn => '인';

  @override
  String get branchMyo => '묘';

  @override
  String get branchJin => '진';

  @override
  String get branchSa => '사';

  @override
  String get branchO => '오';

  @override
  String get branchMi => '미';

  @override
  String get branchShin => '신';

  @override
  String get branchYu => '유';

  @override
  String get branchSul => '술';

  @override
  String get branchHae => '해';

  @override
  String get onboardGenderQuestionHead => '성별이 어떻게 되나요?';

  @override
  String get onboardGenderWhyBody => '대운이 흐르는 방향을 정할 때만 써요.';

  @override
  String get birthplaceQuestionHead => '어디에서 태어났나요?';

  @override
  String get birthplaceWhyBody => '태어난 곳의 시간대와 경도로 태어난 시를 정확히 맞춰요.';

  @override
  String get birthplaceSearchHint => '도시 이름';

  @override
  String get birthplaceEmptyBody => '찾는 도시가 없어요. 가까운 큰 도시로 찾아보세요.';

  @override
  String get birthplaceSearchLabel => '태어난 도시 찾기';

  @override
  String get genderMale => '남성';

  @override
  String get genderFemale => '여성';

  @override
  String get previewCtaSave => '저장하고 계속하기';

  @override
  String get previewCtaRestart => '다시 입력하기';

  @override
  String get previewShareLoginNotice => '로그인하면 오늘 풀이를 공유할 수 있어요.';

  @override
  String get dayKindYongsinDay => '용신의 날';

  @override
  String get dayKindGwiinDay => '귀인의 날';

  @override
  String get dayKindGisinDay => '기신의 날';

  @override
  String get dayKindOrdinaryDay => '평범한 날';

  @override
  String get shareLabel => '공유';

  @override
  String get actionClose => '닫기';

  @override
  String get loginTitleHead => '로그인하고 풀이를 저장해요';

  @override
  String get loginTitleBody => '로그인하면 다른 기기에서도 내 사주와 일기를 볼 수 있어요.';

  @override
  String get loginDiscardNotice => '이미 사주를 저장한 계정이면 방금 입력한 정보 대신 저장된 정보를 써요.';

  @override
  String get loginKakaoLabel => '카카오 로그인';

  @override
  String get loginAppleLabel => 'Apple로 로그인';

  @override
  String get loginCancelled => '로그인을 취소했어요.';

  @override
  String get appleWebErrorStateMismatch => '로그인을 확인하지 못했어요. 처음부터 다시 로그인해 주세요.';

  @override
  String get appleWebErrorCancelled => 'Apple 로그인을 취소했어요.';

  @override
  String get appleWebErrorOther => 'Apple로 로그인하지 못했어요. 다시 시도해 주세요.';

  @override
  String get actionConfirm => '확인';

  @override
  String get consentTitleHead => '약관에 동의해 주세요';

  @override
  String get consentCtaAgree => '동의하고 계속하기';

  @override
  String get consentView => '보기';

  @override
  String get notifyAskQuestionHead => '아침마다 오늘 풀이를 알려 드릴까요?';

  @override
  String get notifyAskWhyBody => '알림에는 그날이 어떤 날인지와 총운 한 문장이 담겨요.';

  @override
  String get notifyAskCtaSkip => '나중에';

  @override
  String get notifyAskCtaAllow => '알림 받기';

  @override
  String get accountDeleteCtaDelete => '계정 지우기';

  @override
  String get accountDeleteDataBody =>
      '계정을 지우면 사주 정보, 일기, 태그, 일정, 남은 광고 제거 기간이 모두 지워지고 되돌릴 수 없어요.';

  @override
  String get accountDeleteDeleteConfirm => '정말 지울까요? 지운 계정은 되돌릴 수 없어요.';

  @override
  String get accountDeleteDeleteConfirmDelete => '지우기';

  @override
  String get accountDeleteDeleteConfirmCancel => '취소';

  @override
  String get accountDeleteTitleHead => '계정 삭제';

  @override
  String get adFreeLegalNotice => '구매 전에 이용약관과 개인정보 처리방침을 확인해 주세요.';

  @override
  String get adFreeOfferHead => '한 달 동안 광고 없이, 근거와 해석까지 모두 열어 봐요.';

  @override
  String adFreeOfferPrice(String price) {
    return '$price · 1개월 · 자동 갱신 없음';
  }

  @override
  String get adFreeRestoreCta => '구매 복원';

  @override
  String adFreeStatusRemaining(String date) {
    return '$date까지 광고 없이 볼 수 있어요';
  }

  @override
  String get calcBasisConventionBody =>
      '명리 해석은 한국에서 널리 쓰는 기준을 따라요. 여러 유파 가운데 하나로, 근거가 있는 기준이에요.';

  @override
  String get calcBasisLunarBody => '음력은 한국천문연구원 기준의 한국 음력을 따라요.';

  @override
  String get calendarLegendBodyGood => '잘 풀리는 날';

  @override
  String get calendarLegendBodyCaution => '조심할 날';

  @override
  String get consentRequiredLabelTerms => '(필수) 이용약관';

  @override
  String get consentRequiredLabelPrivacy => '(필수) 개인정보 수집·이용';

  @override
  String daySheetDiaryOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count편',
    );
    return '이날 쓴 일기 $_temp0';
  }

  @override
  String get daySheetDiaryWriteCta => '이날 일기 쓰기';

  @override
  String get daySheetEventAdd => '일정 추가';

  @override
  String get daySheetEventEmpty => '이날은 일정이 없어요.';

  @override
  String get diaryEditBodyPlaceholder => '오늘 있었던 일을 적어 보세요';

  @override
  String get diaryEditDraftStatusLocal => '기기에 임시 저장됨';

  @override
  String get diaryEditDraftStatusSaving => '저장 중';

  @override
  String get diaryEditDraftStatusSaved => '저장됨';

  @override
  String get diaryEditOfflineNotice => '인터넷에 연결되면 저장할게요. 쓴 내용은 기기에 남아 있어요.';

  @override
  String get diaryEditSavedTags => '일기에 태그가 붙었어요';

  @override
  String get diaryListEmptyBody => '아직 쓴 일기가 없어요. 오늘 하루부터 적어 볼까요?';

  @override
  String get diaryListPickDateCta => '날짜 골라 쓰기';

  @override
  String get diaryViewDeleteConfirm => '이 일기를 지울까요? 지우면 되돌릴 수 없어요.';

  @override
  String get diaryViewDeleteConfirmDelete => '지우기';

  @override
  String get diaryViewDeleteConfirmCancel => '취소';

  @override
  String get eventEditDeleteConfirm => '이 일정을 지울까요?';

  @override
  String get eventEditDeleteConfirmDelete => '지우기';

  @override
  String get eventEditDeleteConfirmCancel => '취소';

  @override
  String get eventEditMemoHint => '메모';

  @override
  String get eventEditTitleHint => '일정 제목';

  @override
  String get evidenceSheetLockPassLink => '광고 제거 보기';

  @override
  String get evidenceSheetUnlockFailed => '광고 확인이 늦어지고 있어요. 잠시 뒤에 다시 열어 주세요.';

  @override
  String get previewShareLoginNoticeConfirm => '로그인하기';

  @override
  String get previewShareLoginNoticeCancel => '닫기';

  @override
  String get profileEditRecalcConfirmTitle => '정보를 바꿀까요?';

  @override
  String profileEditRecalcConfirmBody(String before, String after) {
    return '$before → $after\n오늘·달력·나의 사주를 다시 계산해요. 이미 쓴 일기와 태그는 그대로 남아요.';
  }

  @override
  String get profileEditRecalcConfirmCancel => '취소';

  @override
  String get profileEditRecalcConfirmSave => '바꾸기';

  @override
  String get profileEditRecalcNotice => '생일·시간·성별·출생지를 바꾸면 풀이를 다시 계산해요.';

  @override
  String get sajuChartTimeUnknownNotice => '태어난 시간을 몰라 시주는 빼고 보여 드려요.';

  @override
  String get settingsAdFreeLabel => '광고 제거';

  @override
  String settingsAdFreeLabelActive(String date) {
    return '$date까지';
  }

  @override
  String get settingsLanguageBirthplaceNotice =>
      '한국 밖에서 태어났다면 출생지를 입력해 주세요. 태어난 시를 더 정확히 맞출 수 있어요.';

  @override
  String get settingsLanguageBirthplaceNoticeCta => '출생지 입력하기';

  @override
  String get settingsLogoutConfirm => '로그아웃할까요?';

  @override
  String get settingsLogoutConfirmLogout => '로그아웃';

  @override
  String get settingsLogoutConfirmCancel => '취소';

  @override
  String get sharePreviewCtaShare => '공유하기';

  @override
  String get sharePreviewImageFooter => '명리일기';

  @override
  String get sharePreviewImageTagline => '내 사주로 푼 오늘, 명리일기';

  @override
  String get sharePreviewRatioLabelStory => '스토리';

  @override
  String get sharePreviewRatioLabelFeed => '피드';

  @override
  String get sharePreviewRatioLabelSquare => '정사각';

  @override
  String get shareImageSemantics => '오늘 문장 이미지 미리보기';

  @override
  String get sharePreviewRatioGroup => '공유 이미지 비율';

  @override
  String get tagDiaryEmptyBody => '이 태그가 붙은 일기가 아직 없어요.';

  @override
  String todayEventSummary(int count, String title) {
    return '오늘 일정 $count개 · $title';
  }

  @override
  String get todayEventSummaryOngoing => '진행 중';

  @override
  String get todayEventSummaryNext => '다음';

  @override
  String get todayEventSummaryDone => '오늘 일정이 모두 끝났어요';

  @override
  String get todayGuideCta => '일기 쓰기';

  @override
  String get todayGuideCtaWritten => '새 일기 쓰기';

  @override
  String get todayGuideEyebrow => '오늘의 질문';

  @override
  String get todayGuideWritten => '오늘 일기를 썼어요';

  @override
  String get todayGuideLabel => '일기 질문';

  @override
  String get todayReactionLabelSelected => '좋아요 취소';

  @override
  String get depthExplain => '풀이';

  @override
  String get depthLinkEvidence => '근거 보기';

  @override
  String get todayLuckyColorName => '행운 색';

  @override
  String get todayLuckyDirectionName => '행운 방향';

  @override
  String get todayLuckyNumberName => '행운 숫자';

  @override
  String get todayLuckyTimeName => '집중하기 좋은 시간';

  @override
  String get evidenceSheetTitle => '오늘 풀이의 근거';

  @override
  String get a11yListSeparator => ', ';

  @override
  String get calendarBarTitle => '달력';

  @override
  String get eventEditBarTitle => '일정';

  @override
  String get calendarPrevMonth => '이전 달';

  @override
  String get calendarNextMonth => '다음 달';

  @override
  String dayCellLunar(int month, int day) {
    return '음력 $month월 $day일';
  }

  @override
  String get dayCellLeapMonth => '윤달';

  @override
  String dayCellEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '일정 $_temp0';
  }

  @override
  String get dayCellDiaryWritten => '일기 있음';

  @override
  String get dayCellToday => '오늘';

  @override
  String eventRowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '외 $_temp0';
  }

  @override
  String get eventRowAllDay => '하루 종일';

  @override
  String eventRowLabel(String status, String time, String title) {
    return '$status $time $title';
  }

  @override
  String todayEventSummaryNextAt(String time, String title) {
    return '다음 $time $title';
  }

  @override
  String todayEventSummaryAllPast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '오늘 일정 $_temp0가 모두 지났어요';
  }

  @override
  String get eventEditAllDay => '하루 종일';

  @override
  String get eventEditTimed => '시간 지정';

  @override
  String get eventEditDateLabel => '날짜';

  @override
  String get eventEditTimeLabel => '시간';

  @override
  String get eventEditSave => '저장';

  @override
  String get eventEditDelete => '일정 지우기';

  @override
  String get eventEditOfflineNotice => '인터넷에 연결되어 있지 않아 저장할 수 없어요.';

  @override
  String get eventEditSaveFailed => '일정을 저장하지 못했어요. 다시 시도해 주세요.';

  @override
  String get direction8N => '북';

  @override
  String get direction8Ne => '북동';

  @override
  String get direction8E => '동';

  @override
  String get direction8Se => '남동';

  @override
  String get direction8S => '남';

  @override
  String get direction8Sw => '남서';

  @override
  String get direction8W => '서';

  @override
  String get direction8Nw => '북서';

  @override
  String get birthplaceStandardLink => '계산 기준 보기';

  @override
  String get birthplaceStandardNote =>
      '명리일기는 한국에서 널리 쓰는 기준으로 계산해요. 여러 유파 가운데 하나로, 근거가 있는 방식이에요.';

  @override
  String calcBasisLongitudeBodySubtract(String longitude, int minutes) {
    return '출생 시각은 $longitude 기준으로 $minutes분을 빼서 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';
  }

  @override
  String calcBasisLongitudeBodyAdd(String longitude, int minutes) {
    return '출생 시각은 $longitude 기준으로 $minutes분을 더해서 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';
  }

  @override
  String calcBasisLongitudeBodyNone(String longitude) {
    return '출생 시각은 $longitude 기준이라 따로 보정하지 않고 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';
  }

  @override
  String calcBasisLongitudeBodyEast(String degrees) {
    return '동경 $degrees°';
  }

  @override
  String calcBasisLongitudeBodyWest(String degrees) {
    return '서경 $degrees°';
  }

  @override
  String get calcBasisSchoolsBody =>
      '지장간은 하나만 고르지 않고 모두 보여 드려요. 자시에 태어났다면 자정 전이라도 다음 날로 계산해요. 유파마다 처리가 달라서 다른 앱이나 책과 결과가 다를 수 있어요.';

  @override
  String get accountDeleteBarTitle => '계정 삭제';

  @override
  String get adFreeBarTitle => '광고 제거';

  @override
  String get birthplaceBarTitle => '출생지';

  @override
  String get calcBasisBarTitle => '계산 기준';

  @override
  String calcBasisLongitudeBodyDstSubtract(
    String longitude,
    int minutes,
    int dstMinutes,
  ) {
    return '출생 시각은 서머타임 $dstMinutes분을 먼저 빼고, $longitude 기준으로 $minutes분을 더 빼서 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';
  }

  @override
  String calcBasisLongitudeBodyDstAdd(
    String longitude,
    int minutes,
    int dstMinutes,
  ) {
    return '출생 시각은 서머타임 $dstMinutes분을 먼저 빼고, $longitude 기준으로 $minutes분을 더해서 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';
  }

  @override
  String calcBasisLongitudeBodyDstNone(String longitude, int dstMinutes) {
    return '출생 시각은 서머타임 $dstMinutes분만 빼고 계산해요. $longitude 기준이라 경도 보정은 따로 하지 않아요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';
  }

  @override
  String get consentBarTitle => '약관 동의';

  @override
  String get diaryEditBarTitle => '일기 쓰기';

  @override
  String get diaryListBarTitle => '일기';

  @override
  String diaryViewBarTitle(String date) {
    return '$date의 일기';
  }

  @override
  String get legalBarTitle => '약관·정책';

  @override
  String get loginBarTitle => '로그인';

  @override
  String get mySajuBarTitle => '나의 사주';

  @override
  String get notifyAskBarTitle => '알림';

  @override
  String get onboardBirthBarTitle => '생일';

  @override
  String get onboardCallBarTitle => '호칭';

  @override
  String get onboardGenderBarTitle => '성별';

  @override
  String get onboardTimeBarTitle => '태어난 시간';

  @override
  String get previewBarTitle => '첫 풀이';

  @override
  String get profileEditBarTitle => '정보 수정';

  @override
  String get sajuChartBarTitle => '사주 표';

  @override
  String get settingsBarTitle => '설정';

  @override
  String tagDiaryBarTitle(String tag) {
    return '$tag 태그';
  }

  @override
  String get todayBarTitle => '오늘';

  @override
  String get errorReactionNotFound => '반응을 남길 문장을 찾지 못했어요. 화면을 새로 고쳐 주세요.';

  @override
  String get errorScheduleNotFound => '일정을 찾지 못했어요. 목록을 새로 고쳐 주세요.';

  @override
  String get errorRangeTooLong => '한 번에 볼 수 있는 기간을 넘었어요. 기간을 줄여 주세요.';

  @override
  String get diaryEditSave => '저장';

  @override
  String get diaryViewEditAction => '일기 고치기';

  @override
  String get diaryViewDeleteAction => '일기 지우기';

  @override
  String get diaryViewDeleted => '일기를 지웠어요.';

  @override
  String diaryListPickDateConfirm(String date) {
    return '$date 일기 쓰기';
  }

  @override
  String tagChipLabel(String tag) {
    return '#$tag';
  }

  @override
  String get tagChipPolarityGood => '좋은 흐름';

  @override
  String get tagChipPolarityBad => '조심할 흐름';

  @override
  String get tagChipPolarityNeutral => '무난한 흐름';

  @override
  String dayCellLeapNewMoon(int month) {
    return '윤$month.1';
  }

  @override
  String get errorCityNotFound => '출생지 도시를 찾지 못했어요. 도시를 다시 골라 주세요.';

  @override
  String get errorTimezoneInvalid => '시간대를 확인하지 못했어요. 기기의 시간대 설정을 확인해 주세요.';

  @override
  String get settingsNotifyLabel => '알림 시각';

  @override
  String get settingsNotifyOff => '꺼짐';

  @override
  String get settingsLanguageLabel => '언어';

  @override
  String get settingsLogoutLabel => '로그아웃';

  @override
  String get profileEditBirthplaceKorea => '한국';

  @override
  String get sajuChartTabNatal => '원국';

  @override
  String get sajuChartTabLuck => '만세력·대운';

  @override
  String get sajuPillarHour => '시주';

  @override
  String get sajuPillarDay => '일주';

  @override
  String get sajuPillarMonth => '월주';

  @override
  String get sajuPillarYear => '연주';

  @override
  String get manseRowHiddenStems => '지장간';

  @override
  String get manseRowTwelveStages => '12운성';

  @override
  String get manseRowShinsal => '신살';

  @override
  String get sajuTagMe => '나';

  @override
  String get daeunTagNow => '지금';

  @override
  String get seunTagThisYear => '올해';

  @override
  String daeunTableLabel(int age) {
    return '대운 $age세부터';
  }

  @override
  String ohaengBarItem(String element, String count) {
    return '$element $count';
  }

  @override
  String get sajuPillarDayMaster => '일간';

  @override
  String get sajuPillarsTableLabel => '원국표';

  @override
  String get manseTableLabel => '만세력 표';

  @override
  String get evidenceSheetPersonalEmpty => '이 자리의 해석은 아직 준비 중이에요.';

  @override
  String luckYearLabel(int year) {
    return '$year년';
  }

  @override
  String get legalTermsLabel => '이용약관';

  @override
  String get legalPrivacyLabel => '개인정보 처리방침';

  @override
  String get legalLicensesLabel => '오픈소스 라이선스';

  @override
  String get accountMergeBarTitle => '계정 합치기';

  @override
  String get accountMergeChoiceLabel => '남길 계정을 골라 주세요';

  @override
  String get accountMergeCtaCancel => '합치지 않기';

  @override
  String get accountMergeCtaMerge => '계정 합치기';

  @override
  String get accountMergeMergeConfirm => '두 계정을 합칠까요? 합친 뒤에는 되돌릴 수 없어요.';

  @override
  String get accountMergeMergeConfirmMerge => '합치기';

  @override
  String get accountMergeMergeConfirmCancel => '취소';

  @override
  String get accountMergeOverlapNotice => '같은 날 쓴 일기도 모두 이 계정으로 옮겨요.';

  @override
  String get accountMergeTitleBody =>
      '합치면 고른 계정의 사주 정보·호칭·설정이 남아요. 일기는 두 계정 것을 모두 옮기고, 남은 광고 제거 기간은 더해요. 고르지 않은 계정은 지워져요.';

  @override
  String get accountMergeTitleHead => '두 계정을 하나로 합칠까요?';

  @override
  String get daySheetDiaryWriteCtaWritten => '이날 새 일기 쓰기';

  @override
  String get daySheetDiaryWriteCtaFull => '이날은 충분히 썼어요';

  @override
  String get loginMethodsBarTitle => '로그인 수단';

  @override
  String get loginMethodsErrorBodyLink => '연결하지 못했어요. 다시 시도해 주세요.';

  @override
  String get loginMethodsErrorBodyUnlink => '연결을 끊지 못했어요. 다시 시도해 주세요.';

  @override
  String get loginMethodsIntroBody => '여러 수단을 연결해 두면 어느 것으로든 이 계정에 로그인할 수 있어요.';

  @override
  String get loginMethodsLastNotice => '로그인할 수단이 하나는 남아 있어야 해요.';

  @override
  String loginMethodsUnlinkConfirm(String provider) {
    return '$provider 연결을 끊을까요?';
  }

  @override
  String get loginMethodsUnlinkConfirmBody => '연결한 다른 수단으로 계속 로그인할 수 있어요.';

  @override
  String get loginMethodsUnlinkConfirmUnlink => '연결 끊기';

  @override
  String get loginMethodsUnlinkConfirmCancel => '취소';

  @override
  String get todayGuideCtaFull => '오늘은 충분히 썼어요';

  @override
  String accountChoiceDiaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count편',
    );
    return '일기 $_temp0';
  }

  @override
  String get accountChoiceCurrent => '현재 계정';

  @override
  String get accountChoiceProviderSeparator => ' · ';

  @override
  String get accountMergeError => '계정을 합치지 못했어요. 두 계정 모두 그대로 있어요. 다시 시도해 주세요.';

  @override
  String accountChoiceSaju(String date, String calendar, String time) {
    return '$calendar $date $time';
  }

  @override
  String accountChoiceSajuNoTime(String date, String calendar) {
    return '$calendar $date 시각 모름';
  }

  @override
  String get accountChoiceSajuEmpty => '사주 정보 없음';

  @override
  String get diaryListPickDateConfirmFull => '이날은 충분히 썼어요';

  @override
  String get errorDiaryDayFull => '이날은 충분히 썼어요.';

  @override
  String get loginProviderKakao => '카카오';

  @override
  String get loginProviderLine => 'LINE';

  @override
  String get loginProviderGoogle => 'Google';

  @override
  String get loginProviderApple => 'Apple';

  @override
  String get loginMethodsRowConnected => '연결됨';

  @override
  String get loginMethodsRowUnlink => '연결 끊기';

  @override
  String get loginLineLabel => 'LINE으로 로그인';

  @override
  String get loginGoogleLabel => 'Google 계정으로 로그인';

  @override
  String get settingsLoginMethodsLabel => '로그인 수단';
}
