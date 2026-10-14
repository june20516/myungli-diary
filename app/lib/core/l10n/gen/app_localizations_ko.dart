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
  String get evidenceSheetLockHead => '근거와 해석이 잠겨 있어요';

  @override
  String get evidenceSheetLockReward => '광고 한 편을 보면 오늘 하루 근거와 해석이 모두 열려요.';

  @override
  String get evidenceSheetLockCta => '광고 보고 열기';

  @override
  String get evidenceSheetLockPass => '광고 제거권이 있으면 바로 열려요 ›';

  @override
  String get evidenceSheetLockUnavailable =>
      '지금 볼 수 있는 광고가 없어요. 잠시 뒤에 다시 와 주세요.';

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
  String get todayReactionLabel => '이 문장 좋아요';

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
}
