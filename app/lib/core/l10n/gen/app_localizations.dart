import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  /// 임시. 네트워크 연결이 없을 때의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되어 있지 않아요.'**
  String get errorOffline;

  /// 임시. 요청 시간이 초과됐을 때의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.'**
  String get errorTimeout;

  /// 임시. 요청이 거절됐을 때(4xx)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요.'**
  String get errorClient;

  /// 임시. 서버 오류(5xx)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.'**
  String get errorServer;

  /// 임시. 분류되지 않은 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'예기치 못한 문제가 생겼어요.'**
  String get errorUnexpected;

  /// 임시. 아직 구현되지 않은 기능의 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'아직 준비 중이에요.'**
  String get errorNotImplemented;

  /// 임시. 요청 본문을 읽지 못했을 때(400 request.malformed)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요.'**
  String get errorRequestMalformed;

  /// 임시. 입력 형식·범위가 맞지 않을 때(400 request.invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'입력한 값을 다시 확인해 주세요.'**
  String get errorRequestInvalid;

  /// 임시. 로그인 유지 시간이 지났을 때(401 auth.token_expired)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'로그인이 만료됐어요. 다시 로그인해 주세요.'**
  String get errorAuthTokenExpired;

  /// 임시. 로그인 정보가 유효하지 않을 때(401 auth.token_invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'다시 로그인해 주세요.'**
  String get errorAuthTokenInvalid;

  /// 임시. 로그인 갱신이 재사용으로 거절됐을 때(401 auth.refresh_reused)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'보안을 위해 로그아웃됐어요. 다시 로그인해 주세요.'**
  String get errorAuthRefreshReused;

  /// 임시. 카카오·Apple 로그인 확인에 실패했을 때(401 auth.provider_token_invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'로그인하지 못했어요. 다시 시도해 주세요.'**
  String get errorAuthProviderTokenInvalid;

  /// 임시. Apple 웹 로그인 복귀 코드가 만료·사용됨일 때(401 auth.exchange_invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'로그인 시간이 지났어요. 처음부터 다시 로그인해 주세요.'**
  String get errorAuthExchangeInvalid;

  /// 임시. 앱 무결성 확인에 실패했을 때(401 app_check.invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'앱을 확인하지 못했어요. 앱을 최신 버전으로 업데이트해 주세요.'**
  String get errorAppCheckInvalid;

  /// 임시. 약관 동의가 필요할 때(403 consent.required)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'약관 동의가 필요해요.'**
  String get errorConsentRequired;

  /// 임시. 미리보기를 이미 썼을 때(403 preview.used)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'미리보기는 한 번만 볼 수 있어요. 로그인하면 계속 볼 수 있어요.'**
  String get errorPreviewUsed;

  /// 임시. 요청 경로가 없을 때(404 route.not_found)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 앱을 업데이트해 주세요.'**
  String get errorRouteNotFound;

  /// 임시. 일기를 찾지 못했을 때(404 diary.not_found)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'일기를 찾지 못했어요.'**
  String get errorDiaryNotFound;

  /// 임시. 요청 방식이 맞지 않을 때(405 method.not_allowed)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 앱을 업데이트해 주세요.'**
  String get errorMethodNotAllowed;

  /// 임시. 프로필 없이 운세·일기를 요청했을 때(409 profile.required)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'먼저 생년월일시를 입력해 주세요.'**
  String get errorProfileRequired;

  /// 임시. 되살리려는 날짜에 일기가 이미 있을 때(409 diary.date_taken)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'그날에는 이미 일기가 있어요.'**
  String get errorDiaryDateTaken;

  /// 임시. 같은 요청이 처리 중일 때(409 idempotency.in_progress)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'처리 중이에요. 잠시 후 다시 확인해 주세요.'**
  String get errorIdempotencyInProgress;

  /// 임시. 요청이 너무 클 때(413 request.too_large)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'내용이 너무 길어요.'**
  String get errorRequestTooLarge;

  /// 임시. 요청 형식을 지원하지 않을 때(415 request.unsupported_media_type)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 앱을 업데이트해 주세요.'**
  String get errorRequestUnsupportedMediaType;

  /// 임시. 지원 범위 밖 날짜일 때(422 date.out_of_range)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'1900년 1월 31일부터 2099년 12월 31일까지의 날짜만 볼 수 있어요.'**
  String get errorDateOutOfRange;

  /// 임시. 지원 범위 밖 출생 정보일 때(422 birth.out_of_range)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'1900년 1월 31일부터 2099년 12월 31일 사이의 생년월일을 입력해 주세요.'**
  String get errorBirthOutOfRange;

  /// 임시. 달력에 없는 날짜일 때(422 date.invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'달력에 없는 날짜예요.'**
  String get errorDateInvalid;

  /// 임시. 입력 값끼리 맞지 않을 때(422 request.inconsistent)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'입력한 값을 다시 확인해 주세요.'**
  String get errorRequestInconsistent;

  /// 임시. 계산할 수 없는 출생 정보일 때(422 birth.invalid)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'입력한 생년월일시를 다시 확인해 주세요.'**
  String get errorBirthInvalid;

  /// 임시. 앞으로의 날짜에 일기를 쓰려 할 때(422 diary.future_date)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'오늘 이후의 일기는 쓸 수 없어요.'**
  String get errorDiaryFutureDate;

  /// 임시. 호칭이 비어 있을 때(422 name.empty)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'부를 이름을 입력해 주세요.'**
  String get errorNameEmpty;

  /// 임시. 호칭이 너무 길 때(422 name.too_long)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'부를 이름이 너무 길어요.'**
  String get errorNameTooLong;

  /// 임시. 호칭에 이모지가 있을 때(422 name.emoji)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'부를 이름에는 이모지를 쓸 수 없어요.'**
  String get errorNameEmoji;

  /// 임시. 호칭에 제어 문자가 있을 때(422 name.control)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'부를 이름에 쓸 수 없는 글자가 있어요.'**
  String get errorNameControl;

  /// 임시. 호칭에 괄호 등 받지 않는 글자가 있을 때(422 name.invalid_char)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'부를 이름에는 괄호를 쓸 수 없어요.'**
  String get errorNameInvalidChar;

  /// 임시. 같은 요청 키에 다른 내용일 때(422 idempotency.mismatch)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 다시 시도해 주세요.'**
  String get errorIdempotencyMismatch;

  /// 임시. 동의한 약관 버전이 바뀌었을 때(422 consent.version_mismatch)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'약관이 바뀌었어요. 다시 확인해 주세요.'**
  String get errorConsentVersionMismatch;

  /// 임시. 요청이 너무 잦을 때(429 rate_limited)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'요청이 많아요. 잠시 후 다시 시도해 주세요.'**
  String get errorRateLimited;

  /// 임시. 예상하지 못한 서버 오류(500 internal)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.'**
  String get errorInternal;

  /// 임시. 풀이 계산 오류(502 engine.error)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'풀이를 계산하지 못했어요.'**
  String get errorEngineError;

  /// 임시. 풀이 계산 서버에 연결하지 못할 때(503 engine.unavailable)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'풀이를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'**
  String get errorEngineUnavailable;

  /// 임시. 카카오·Apple 장애로 로그인하지 못할 때(503 auth.provider_unavailable)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'지금은 로그인할 수 없어요. 잠시 후 다시 시도해 주세요.'**
  String get errorAuthProviderUnavailable;

  /// 임시. 결제 서비스 장애일 때(503 billing.provider_unavailable)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'지금은 결제를 확인할 수 없어요. 잠시 후 다시 시도해 주세요.'**
  String get errorBillingProviderUnavailable;

  /// 임시. 서버가 일시적으로 처리하지 못할 때(503 service.unavailable)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'잠시 서비스를 이용할 수 없어요. 잠시 후 다시 시도해 주세요.'**
  String get errorServiceUnavailable;

  /// 임시. 풀이 계산 시간이 초과됐을 때(504 engine.timeout)의 오류 문구
  ///
  /// In ko, this message translates to:
  /// **'풀이 계산이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.'**
  String get errorEngineTimeout;

  /// 임시. 앱 이름(작업 전환기 등에 보임)
  ///
  /// In ko, this message translates to:
  /// **'명리일기'**
  String get appTitle;

  /// 임시. 앱 시작 준비가 실패했을 때의 안내 문구
  ///
  /// In ko, this message translates to:
  /// **'앱을 시작하지 못했어요. 앱을 완전히 종료한 뒤 다시 열어 주세요.'**
  String get bootstrapFailed;

  /// 임시. 오류 뒤 다시 시도 버튼 문구
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get actionRetry;

  /// 임시. 주 버튼이 처리 중일 때 스크린리더가 읽는 문구(primary-button busyAnnounced)
  ///
  /// In ko, this message translates to:
  /// **'처리 중'**
  String get actionBusy;

  /// 임시. 오류 화면에 보이는 추적 번호 표시
  ///
  /// In ko, this message translates to:
  /// **'문의 번호 {traceId}'**
  String traceIdLabel(String traceId);

  /// 임시. 탭 바 '오늘' 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get tabToday;

  /// 임시. 탭 바 '달력' 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'달력'**
  String get tabCalendar;

  /// 임시. 탭 바 '일기' 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'일기'**
  String get tabDiary;

  /// 임시. 탭 바 '나' 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'나'**
  String get tabMe;

  /// 임시. 앱 바 뒤로 버튼의 스크린리더 라벨
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get appBarBack;

  /// 임시. 시트 바깥 덮개·닫기의 스크린리더 라벨
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get sheetDismiss;

  /// 임시. 광고 배너 영역의 스크린리더 라벨
  ///
  /// In ko, this message translates to:
  /// **'광고'**
  String get adBannerLabel;

  /// 임시. 오프라인 안내 배너 문구
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되어 있지 않아 받아둔 내용을 보여 드려요.'**
  String get noticeOffline;

  /// 임시. 빈 상태 기본 문장
  ///
  /// In ko, this message translates to:
  /// **'아직 보여 드릴 내용이 없어요.'**
  String get emptyStateDefault;

  /// 임시. 불러오는 중 자리의 스크린리더 라벨
  ///
  /// In ko, this message translates to:
  /// **'불러오는 중'**
  String get skeletonLabel;

  /// 임시. 문의 번호를 길게 눌러 복사한 뒤의 토스트 문구
  ///
  /// In ko, this message translates to:
  /// **'문의 번호를 복사했어요.'**
  String get traceIdCopied;

  /// 임시. 근거 시트 구역 제목: 판정 근거
  ///
  /// In ko, this message translates to:
  /// **'판정 근거'**
  String get evidenceSheetSectionBasis;

  /// 임시. 근거 시트 구역 제목: 원전
  ///
  /// In ko, this message translates to:
  /// **'원전'**
  String get evidenceSheetSectionSource;

  /// 임시. 근거 시트 구역 제목: 내 사주에서는
  ///
  /// In ko, this message translates to:
  /// **'내 사주에서는'**
  String get evidenceSheetSectionPersonal;

  /// 임시. 근거와 해석이 잠겨 있다는 안내
  ///
  /// In ko, this message translates to:
  /// **'근거와 해석이 잠겨 있어요'**
  String get evidenceSheetLockHead;

  /// 임시. 보상 고지(광고 전 매번)
  ///
  /// In ko, this message translates to:
  /// **'광고 한 편을 보면 오늘 하루 근거와 해석이 모두 열려요.'**
  String get evidenceSheetLockReward;

  /// 임시. 광고 보고 열기 버튼
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 열기'**
  String get evidenceSheetLockCta;

  /// 임시. 광고 제거권 안내와 링크
  ///
  /// In ko, this message translates to:
  /// **'광고 제거권이 있으면 바로 열려요 ›'**
  String get evidenceSheetLockPass;

  /// 임시. 볼 수 있는 광고가 없다는 안내(버튼 꺼짐)
  ///
  /// In ko, this message translates to:
  /// **'지금 볼 수 있는 광고가 없어요. 잠시 뒤에 다시 와 주세요.'**
  String get evidenceSheetLockUnavailable;

  /// 임시. 접근성: 잠긴 구역 뒤에 붙는 '잠김'
  ///
  /// In ko, this message translates to:
  /// **'잠김'**
  String get evidenceSheetA11yLocked;

  /// 임시. 접근성: 잠금 해제를 확인하는 동안 버튼 상태
  ///
  /// In ko, this message translates to:
  /// **'확인 중'**
  String get evidenceSheetA11yChecking;

  /// 임시. 접근성: 근거와 해석이 열렸을 때 한 번 알림
  ///
  /// In ko, this message translates to:
  /// **'근거와 해석이 열렸어요'**
  String get evidenceSheetA11yUnlocked;

  /// 임시. 잠긴 용신 근거 줄의 '열기'
  ///
  /// In ko, this message translates to:
  /// **'열기'**
  String get sajuChartYongsinOpen;

  /// 임시. 용신 판정 근거 줄의 이름. 잠겼을 때 스크린리더 라벨(구역 이름 + 잠김)의 앞부분
  ///
  /// In ko, this message translates to:
  /// **'용신 판정 근거'**
  String get sajuChartYongsinTitle;

  /// 임시. 좋아요 반응 접근성 라벨
  ///
  /// In ko, this message translates to:
  /// **'이 문장 좋아요'**
  String get todayReactionLabel;

  /// 임시. 용어 토큰의 스크린리더 라벨(IA 슬롯 없음)
  ///
  /// In ko, this message translates to:
  /// **'{term} 풀이 보기'**
  String termTokenSemantics(String term);

  /// 임시. 온보딩 진행 막대의 스크린리더 라벨(input-step progressLabel)
  ///
  /// In ko, this message translates to:
  /// **'{stepCount}단계 중 {step}단계'**
  String inputStepProgress(int step, int stepCount);

  /// 임시. 글자 입력칸의 지우기 버튼 이름(text-field clear)
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get textFieldClear;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
