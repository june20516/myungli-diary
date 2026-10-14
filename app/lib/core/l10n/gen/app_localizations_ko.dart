// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get errorOffline => '인터넷에 연결되어 있지 않아요.';

  @override
  String get errorTimeout => '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorClient => '요청을 처리하지 못했어요.';

  @override
  String get errorServer => '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorUnexpected => '예기치 못한 문제가 생겼어요.';

  @override
  String get errorNotImplemented => '아직 준비 중이에요.';

  @override
  String get errorRequestMalformed => '요청을 처리하지 못했어요.';

  @override
  String get errorRequestInvalid => '입력한 값을 다시 확인해 주세요.';

  @override
  String get errorAuthTokenExpired => '로그인이 만료됐어요. 다시 로그인해 주세요.';

  @override
  String get errorAuthTokenInvalid => '다시 로그인해 주세요.';

  @override
  String get errorAuthRefreshReused => '보안을 위해 로그아웃됐어요. 다시 로그인해 주세요.';

  @override
  String get errorAuthProviderTokenInvalid => '로그인하지 못했어요. 다시 시도해 주세요.';

  @override
  String get errorAuthExchangeInvalid => '로그인 시간이 지났어요. 처음부터 다시 로그인해 주세요.';

  @override
  String get errorAppCheckInvalid => '앱을 확인하지 못했어요. 앱을 최신 버전으로 업데이트해 주세요.';

  @override
  String get errorConsentRequired => '약관 동의가 필요해요.';

  @override
  String get errorPreviewUsed => '미리보기는 한 번만 볼 수 있어요. 로그인하면 계속 볼 수 있어요.';

  @override
  String get errorRouteNotFound => '요청을 처리하지 못했어요. 앱을 업데이트해 주세요.';

  @override
  String get errorDiaryNotFound => '일기를 찾지 못했어요.';

  @override
  String get errorMethodNotAllowed => '요청을 처리하지 못했어요. 앱을 업데이트해 주세요.';

  @override
  String get errorProfileRequired => '먼저 생년월일시를 입력해 주세요.';

  @override
  String get errorDiaryDateTaken => '그날에는 이미 일기가 있어요.';

  @override
  String get errorIdempotencyInProgress => '처리 중이에요. 잠시 후 다시 확인해 주세요.';

  @override
  String get errorRequestTooLarge => '내용이 너무 길어요.';

  @override
  String get errorRequestUnsupportedMediaType => '요청을 처리하지 못했어요. 앱을 업데이트해 주세요.';

  @override
  String get errorDateOutOfRange =>
      '1900년 1월 31일부터 2099년 12월 31일까지의 날짜만 볼 수 있어요.';

  @override
  String get errorBirthOutOfRange =>
      '1900년 1월 31일부터 2099년 12월 31일 사이의 생년월일을 입력해 주세요.';

  @override
  String get errorDateInvalid => '달력에 없는 날짜예요.';

  @override
  String get errorRequestInconsistent => '입력한 값을 다시 확인해 주세요.';

  @override
  String get errorBirthInvalid => '입력한 생년월일시를 다시 확인해 주세요.';

  @override
  String get errorDiaryFutureDate => '오늘 이후의 일기는 쓸 수 없어요.';

  @override
  String get errorNameEmpty => '부를 이름을 입력해 주세요.';

  @override
  String get errorNameTooLong => '부를 이름이 너무 길어요.';

  @override
  String get errorNameEmoji => '부를 이름에는 이모지를 쓸 수 없어요.';

  @override
  String get errorNameControl => '부를 이름에 쓸 수 없는 글자가 있어요.';

  @override
  String get errorNameInvalidChar => '부를 이름에는 괄호를 쓸 수 없어요.';

  @override
  String get errorIdempotencyMismatch => '요청을 처리하지 못했어요. 다시 시도해 주세요.';

  @override
  String get errorConsentVersionMismatch => '약관이 바뀌었어요. 다시 확인해 주세요.';

  @override
  String get errorRateLimited => '요청이 많아요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorInternal => '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorEngineError => '풀이를 계산하지 못했어요.';

  @override
  String get errorEngineUnavailable => '풀이를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorAuthProviderUnavailable => '지금은 로그인할 수 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorBillingProviderUnavailable =>
      '지금은 결제를 확인할 수 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorServiceUnavailable => '잠시 서비스를 이용할 수 없어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get errorEngineTimeout => '풀이 계산이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get appTitle => '명리일기';

  @override
  String get bootstrapFailed => '앱을 시작하지 못했어요. 앱을 완전히 종료한 뒤 다시 열어 주세요.';

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
  String get noticeOffline => '인터넷에 연결되어 있지 않아 받아둔 내용을 보여 드려요.';

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
    return '$term 풀이 보기';
  }

  @override
  String inputStepProgress(int step, int stepCount) {
    return '$stepCount단계 중 $step단계';
  }

  @override
  String get textFieldClear => '지우기';

  @override
  String textFieldCounter(int current, int max) {
    return '글자 수 $current/$max';
  }

  @override
  String get datePickerYearLabel => '년';

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
    return '윤 $month월';
  }

  @override
  String citySearchResults(int count) {
    return '결과 $count개';
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
  String get onboardBirthCalendarHint => '음력 생일이면 음력을 고르고, 윤달이면 윤달에도 표시해 주세요.';

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
  String get leapMonth => '윤달';

  @override
  String get onboardCallInputLabel => '호칭';

  @override
  String get onboardTimeQuestionHead => '몇 시에 태어났나요?';

  @override
  String get onboardTimeUnknownNote => '시간을 모르면 태어난 시를 빼고 세 기둥으로 풀어요.';

  @override
  String get timeUnknownLabel => '모름';

  @override
  String onboardTimeHourConfirm(String branch, String start, String end) {
    return '$branch($start~$end)';
  }

  @override
  String get branchJa => '자시';

  @override
  String get branchChuk => '축시';

  @override
  String get branchIn => '인시';

  @override
  String get branchMyo => '묘시';

  @override
  String get branchJin => '진시';

  @override
  String get branchSa => '사시';

  @override
  String get branchO => '오시';

  @override
  String get branchMi => '미시';

  @override
  String get branchShin => '신시';

  @override
  String get branchYu => '유시';

  @override
  String get branchSul => '술시';

  @override
  String get branchHae => '해시';

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
  String get birthplaceSearchLabel => '도시 이름';

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
  String get calcBasisConventionBody => '명리 해석은 한국에서 널리 쓰는 기준 하나로 맞췄어요.';

  @override
  String get calcBasisLongitudeBody =>
      '출생 시각은 동경 127.5° 기준으로 30분을 빼서 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.';

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
  String get daySheetDiaryOpen => '이날 일기 보기';

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
  String get settingsDepthDesc => '풀이를 처음에 어디까지 펼쳐 볼지 골라요.';

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
  String get todayGuideCtaWritten => '쓴 일기 보기';

  @override
  String get todayReactionLabelSelected => '좋아요 취소';

  @override
  String get depthDefaultLabel => '명리 풀이 보기';

  @override
  String get depthEvidence => '원리';

  @override
  String get depthExplain => '풀이';

  @override
  String get depthSurface => '요약';
}
