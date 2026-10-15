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

  /// evidence-sheet.section.basis: 구역 제목: 판정 근거. 잠겼을 때도 또렷하게 보임
  ///
  /// In ko, this message translates to:
  /// **'판정 근거'**
  String get evidenceSheetSectionBasis;

  /// evidence-sheet.section.source: 구역 제목: 원전. 잠겼을 때도 또렷하게 보임
  ///
  /// In ko, this message translates to:
  /// **'원전'**
  String get evidenceSheetSectionSource;

  /// evidence-sheet.section.personal: 구역 제목: 내 사주에서는. 잠겼을 때도 또렷하게 보임
  ///
  /// In ko, this message translates to:
  /// **'내 사주에서는'**
  String get evidenceSheetSectionPersonal;

  /// evidence-sheet.lock.head: 근거와 해석이 잠겨 있다는 안내
  ///
  /// In ko, this message translates to:
  /// **'근거와 해석은 잠겨 있어요'**
  String get evidenceSheetLockHead;

  /// evidence-sheet.lock.reward: 보상 고지: 광고 한 편을 보면 오늘 하루 근거와 해석이 모두 열림(광고 전 매번)
  ///
  /// In ko, this message translates to:
  /// **'광고 한 편을 보면 오늘 하루 근거와 해석을 모두 볼 수 있어요.'**
  String get evidenceSheetLockReward;

  /// evidence-sheet.lock.cta: 광고 보고 열기 버튼
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 열기'**
  String get evidenceSheetLockCta;

  /// evidence-sheet.lock.pass: 광고 제거권으로도 열린다는 안내와 링크
  ///
  /// In ko, this message translates to:
  /// **'광고 제거권이 있으면 기간 내내 열려 있어요.'**
  String get evidenceSheetLockPass;

  /// evidence-sheet.lock.unavailable: 지금 볼 수 있는 광고가 없다는 안내(버튼 꺼짐)
  ///
  /// In ko, this message translates to:
  /// **'지금은 볼 수 있는 광고가 없어요. 잠시 뒤에 다시 해 주세요.'**
  String get evidenceSheetLockUnavailable;

  /// evidence-sheet.a11y.locked: 접근성 문구: 잠긴 구역을 읽을 때 "잠김"
  ///
  /// In ko, this message translates to:
  /// **'잠김'**
  String get evidenceSheetA11yLocked;

  /// evidence-sheet.a11y.checking: 접근성 문구: 잠금 해제를 확인하는 동안의 버튼 상태 "확인 중"
  ///
  /// In ko, this message translates to:
  /// **'확인 중'**
  String get evidenceSheetA11yChecking;

  /// evidence-sheet.a11y.unlocked: 접근성 문구: 근거와 해석이 열렸을 때 한 번 알림
  ///
  /// In ko, this message translates to:
  /// **'근거와 해석이 열렸어요'**
  String get evidenceSheetA11yUnlocked;

  /// saju-chart.yongsin.open: 잠긴 용신 근거 줄의 "열기"
  ///
  /// In ko, this message translates to:
  /// **'열기'**
  String get sajuChartYongsinOpen;

  /// saju-chart.yongsin.title: 용신 판정 근거 줄의 이름. 잠겼을 때 스크린리더 라벨(구역 이름 + 잠김)의 앞부분
  ///
  /// In ko, this message translates to:
  /// **'용신 판정 근거'**
  String get sajuChartYongsinTitle;

  /// today.reaction.label: 좋아요 반응 접근성 라벨
  ///
  /// In ko, this message translates to:
  /// **'좋아요'**
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

  /// 임시. 글자 입력칸의 글자 수 표시를 스크린리더가 읽는 문구(text-field counter)
  ///
  /// In ko, this message translates to:
  /// **'글자 수 {current}/{max}'**
  String textFieldCounter(int current, int max);

  /// 임시. 날짜 휠 중 년 휠의 스크린리더 라벨(date-picker)
  ///
  /// In ko, this message translates to:
  /// **'년'**
  String get datePickerYearLabel;

  /// 임시. 날짜 휠 중 월 휠의 스크린리더 라벨(date-picker)
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get datePickerMonthLabel;

  /// 임시. 날짜 휠 중 일 휠의 스크린리더 라벨(date-picker)
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get datePickerDayLabel;

  /// 임시. 년 휠의 칸 글자(date-picker)
  ///
  /// In ko, this message translates to:
  /// **'{year}년'**
  String datePickerYearItem(int year);

  /// 임시. 월 휠의 칸 글자(date-picker)
  ///
  /// In ko, this message translates to:
  /// **'{month}월'**
  String datePickerMonthItem(int month);

  /// 임시. 일 휠의 칸 글자(date-picker)
  ///
  /// In ko, this message translates to:
  /// **'{day}일'**
  String datePickerDayItem(int day);

  /// 임시. 시간 휠 중 오전·오후 휠의 스크린리더 라벨(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'오전·오후'**
  String get timePickerMeridiemLabel;

  /// 임시. 시간 휠 중 시 휠의 스크린리더 라벨(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'시'**
  String get timePickerHourLabel;

  /// 임시. 시간 휠 중 분 휠의 스크린리더 라벨(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'분'**
  String get timePickerMinuteLabel;

  /// 임시. 오전(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'오전'**
  String get timePickerAm;

  /// 임시. 오후(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'오후'**
  String get timePickerPm;

  /// 임시. 시 휠의 칸 글자(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'{hour}시'**
  String timePickerHourItem(int hour);

  /// 임시. 분 휠의 칸 글자. 두 자리로 맞춘 글자(time-picker)
  ///
  /// In ko, this message translates to:
  /// **'{minute}분'**
  String timePickerMinuteItem(String minute);

  /// 임시. 윤달이 켜졌을 때 월 휠을 스크린리더가 읽는 값(date-picker, '윤'을 붙임)
  ///
  /// In ko, this message translates to:
  /// **'윤 {month}월'**
  String datePickerLeapMonthValue(int month);

  /// 임시. 도시 검색 결과 수를 스크린리더가 알리는 문구(city-search resultsAnnounced "결과 N개")
  ///
  /// In ko, this message translates to:
  /// **'결과 {count}개'**
  String citySearchResults(int count);

  /// force-update.notice.head: 업데이트가 필요하다는 제목
  ///
  /// In ko, this message translates to:
  /// **'새 버전으로 업데이트해 주세요'**
  String get forceUpdateNoticeHead;

  /// force-update.notice.body: 업데이트해야 하는 이유
  ///
  /// In ko, this message translates to:
  /// **'풀이를 계산하는 방식이 바뀌어서 지금 버전으로는 열 수 없어요.'**
  String get forceUpdateNoticeBody;

  /// force-update.cta.store: 스토어로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'업데이트하기'**
  String get forceUpdateCtaStore;

  /// welcome.concept.head: 컨셉 한 문장
  ///
  /// In ko, this message translates to:
  /// **'오늘 일진을 내 사주에 맞춰 풀어 드려요'**
  String get welcomeConceptHead;

  /// welcome.concept.body: 앱이 해주는 일 설명
  ///
  /// In ko, this message translates to:
  /// **'풀이에 맞춘 질문 하나로 그날 일기를 시작해요.'**
  String get welcomeConceptBody;

  /// welcome.cta.start: 시작하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get welcomeCtaStart;

  /// welcome.cta.signin: 이미 계정이 있어요 버튼
  ///
  /// In ko, this message translates to:
  /// **'이미 계정이 있어요'**
  String get welcomeCtaSignin;

  /// onboard-call.question.head: 호칭을 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'어떻게 불러 드릴까요?'**
  String get onboardCallQuestionHead;

  /// onboard-call.input.hint: 입력칸 예시
  ///
  /// In ko, this message translates to:
  /// **'예: 민지'**
  String get onboardCallInputHint;

  /// onboard-call.note.body: 실명이 아니어도 된다는 안내
  ///
  /// In ko, this message translates to:
  /// **'실명이 아니어도 돼요. 나중에 바꿀 수 있어요.'**
  String get onboardCallNoteBody;

  /// onboard-birth.question.head: 생일을 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'언제 태어났나요?'**
  String get onboardBirthQuestionHead;

  /// onboard-birth.calendar.hint: 음력·윤달 고르는 법
  ///
  /// In ko, this message translates to:
  /// **'음력 생일이면 음력을 고르고, 윤달이면 윤달에도 표시해 주세요.'**
  String get onboardBirthCalendarHint;

  /// onboard-birth.basis.note: 한국 출생 기준으로 계산한다는 안내
  ///
  /// In ko, this message translates to:
  /// **'한국에서 태어난 것을 기준으로 계산해요.'**
  String get onboardBirthBasisNote;

  /// onboard-birth.error.range: 지원 범위 밖 안내
  ///
  /// In ko, this message translates to:
  /// **'1900년 1월 31일부터 2099년 12월 31일 사이의 날짜만 계산할 수 있어요.'**
  String get onboardBirthErrorRange;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get onboardingNext;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get onboardingSave;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'양력'**
  String get calendarSolar;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'음력'**
  String get calendarLunar;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'윤달'**
  String get leapMonth;

  /// 임시. 호칭 입력칸의 접근성 이름(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'호칭'**
  String get onboardCallInputLabel;

  /// onboard-time.question.head: 태어난 시간을 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'몇 시에 태어났나요?'**
  String get onboardTimeQuestionHead;

  /// onboard-time.unknown.note: 3주로 계산한다는 안내
  ///
  /// In ko, this message translates to:
  /// **'시간을 모르면 태어난 시를 빼고 세 기둥으로 풀어요.'**
  String get onboardTimeUnknownNote;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'모름'**
  String get timeUnknownLabel;

  /// onboard-time.hour.confirm: 엔진이 계산한 시진과 벽시계 범위 확인 줄(예: 인시 03:30~05:30). 기기 지역이 한국일 때만 (D58) app이 getBirthHour 구조값(branch·start·end)을 ui 틀에 넣음(D68)
  ///
  /// In ko, this message translates to:
  /// **'{branch}시, {start}~{end}에 태어났어요.'**
  String onboardTimeHourConfirm(String branch, String start, String end);

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'자'**
  String get branchJa;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'축'**
  String get branchChuk;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'인'**
  String get branchIn;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'묘'**
  String get branchMyo;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'진'**
  String get branchJin;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'사'**
  String get branchSa;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'오'**
  String get branchO;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'미'**
  String get branchMi;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'신'**
  String get branchShin;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'유'**
  String get branchYu;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'술'**
  String get branchSul;

  /// 임시. 지지 이름(시진 확인 줄 틀의 {branch}, 시·hour·刻 없이)
  ///
  /// In ko, this message translates to:
  /// **'해'**
  String get branchHae;

  /// onboard-gender.question.head: 성별을 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'성별이 어떻게 되나요?'**
  String get onboardGenderQuestionHead;

  /// onboard-gender.why.body: 대운 방향 계산에 쓴다는 이유
  ///
  /// In ko, this message translates to:
  /// **'대운이 흐르는 방향을 정할 때만 써요.'**
  String get onboardGenderWhyBody;

  /// birthplace.question.head: 출생지를 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'어디에서 태어났나요?'**
  String get birthplaceQuestionHead;

  /// birthplace.why.body: 출생지가 필요한 이유
  ///
  /// In ko, this message translates to:
  /// **'태어난 곳의 시간대와 경도로 태어난 시를 정확히 맞춰요.'**
  String get birthplaceWhyBody;

  /// birthplace.search.hint: 검색칸 예시
  ///
  /// In ko, this message translates to:
  /// **'도시 이름'**
  String get birthplaceSearchHint;

  /// birthplace.empty.body: 결과가 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'찾는 도시가 없어요. 가까운 큰 도시로 찾아보세요.'**
  String get birthplaceEmptyBody;

  /// 임시. 도시 검색칸 이름(스크린리더, 슬롯 아님). 예시(birthplace.search.hint)와 같은 말이 되지 않게 목적을 말함
  ///
  /// In ko, this message translates to:
  /// **'출생 도시 검색'**
  String get birthplaceSearchLabel;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'남성'**
  String get genderMale;

  /// 임시. 온보딩 공용 문구(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'여성'**
  String get genderFemale;

  /// preview.cta.save: 저장하고 계속하기 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장하고 계속하기'**
  String get previewCtaSave;

  /// preview.cta.restart: 다시 입력 링크
  ///
  /// In ko, this message translates to:
  /// **'다시 입력하기'**
  String get previewCtaRestart;

  /// preview.share.login-notice: 로그인하면 공유할 수 있다는 안내 창
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 오늘 풀이를 공유할 수 있어요.'**
  String get previewShareLoginNotice;

  /// 임시. 날의 성격 이름(슬롯 아님, A20 ①). dayKind yongsin_day
  ///
  /// In ko, this message translates to:
  /// **'용신의 날'**
  String get dayKindYongsinDay;

  /// 임시. 날의 성격 이름(슬롯 아님, A20 ①). dayKind gwiin_day
  ///
  /// In ko, this message translates to:
  /// **'귀인의 날'**
  String get dayKindGwiinDay;

  /// 임시. 날의 성격 이름(슬롯 아님, A20 ①). dayKind gisin_day
  ///
  /// In ko, this message translates to:
  /// **'기신의 날'**
  String get dayKindGisinDay;

  /// 임시. 날의 성격 이름(슬롯 아님, A20 ①). dayKind ordinary_day
  ///
  /// In ko, this message translates to:
  /// **'평범한 날'**
  String get dayKindOrdinaryDay;

  /// 임시. 공유 버튼 글자·스크린리더 라벨(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'공유'**
  String get shareLabel;

  /// 임시. 확인 창의 닫기 버튼(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get actionClose;

  /// login.title.head: 로그인 제목
  ///
  /// In ko, this message translates to:
  /// **'로그인하고 풀이를 저장해요'**
  String get loginTitleHead;

  /// login.title.body: 저장하려면 로그인한다는 설명
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 다른 기기에서도 내 사주와 일기를 볼 수 있어요.'**
  String get loginTitleBody;

  /// login.discard.notice: 사주가 저장된 계정이면 미리보기 입력을 쓰지 않는다는 안내
  ///
  /// In ko, this message translates to:
  /// **'이미 사주를 저장한 계정이면 방금 입력한 정보 대신 저장된 정보를 써요.'**
  String get loginDiscardNotice;

  /// 임시. 카카오 로그인 버튼 글자(슬롯 아님). 카카오 로그인 디자인 가이드 Label의 완성형(ko "카카오 로그인", en "Login with Kakao"). 출처: assets/brand/README.md
  ///
  /// In ko, this message translates to:
  /// **'카카오 로그인'**
  String get loginKakaoLabel;

  /// 임시. Apple 로그인 버튼 글자(슬롯 아님). Sign in with Apple HIG의 언어별 공식 문구
  ///
  /// In ko, this message translates to:
  /// **'Apple로 로그인'**
  String get loginAppleLabel;

  /// 임시. 로그인 오류 상태: 카카오·iOS Apple 로그인 창을 닫음(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'로그인을 취소했어요.'**
  String get loginCancelled;

  /// 임시. 로그인 오류 상태: Android Apple 웹 로그인 복귀의 state가 맞지 않음(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'로그인을 확인하지 못했어요. 처음부터 다시 로그인해 주세요.'**
  String get appleWebErrorStateMismatch;

  /// 임시. 로그인 오류 상태: Android Apple 웹 로그인을 사용자가 취소함(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'Apple 로그인을 취소했어요.'**
  String get appleWebErrorCancelled;

  /// 임시. 로그인 오류 상태: Android Apple 웹 로그인 복귀의 그 밖 실패(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'Apple로 로그인하지 못했어요. 다시 시도해 주세요.'**
  String get appleWebErrorOther;

  /// 임시. 확인 창의 확인 버튼(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get actionConfirm;

  /// consent.title.head: 동의 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'약관에 동의해 주세요'**
  String get consentTitleHead;

  /// consent.cta.agree: 동의하고 계속 버튼
  ///
  /// In ko, this message translates to:
  /// **'동의하고 계속하기'**
  String get consentCtaAgree;

  /// 임시. 동의 항목의 약관 전문 보기 링크(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'보기'**
  String get consentView;

  /// notify-ask.question.head: 알림을 받을지 묻는 질문
  ///
  /// In ko, this message translates to:
  /// **'아침마다 오늘 풀이를 알려 드릴까요?'**
  String get notifyAskQuestionHead;

  /// notify-ask.why.body: 아침 알림이 주는 것
  ///
  /// In ko, this message translates to:
  /// **'알림에는 그날이 어떤 날인지와 총운 한 문장이 담겨요.'**
  String get notifyAskWhyBody;

  /// notify-ask.cta.skip: 건너뛰기
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get notifyAskCtaSkip;

  /// notify-ask.cta.allow: 알림 허락 버튼
  ///
  /// In ko, this message translates to:
  /// **'알림 받기'**
  String get notifyAskCtaAllow;

  /// account-delete.cta.delete: 계정 삭제 버튼
  ///
  /// In ko, this message translates to:
  /// **'계정 지우기'**
  String get accountDeleteCtaDelete;

  /// account-delete.data.body: 지워지는 데이터 안내
  ///
  /// In ko, this message translates to:
  /// **'계정을 지우면 사주 정보, 일기, 태그, 일정, 남은 광고 제거 기간이 모두 지워지고 되돌릴 수 없어요.'**
  String get accountDeleteDataBody;

  /// account-delete.delete.confirm: 최종 확인
  ///
  /// In ko, this message translates to:
  /// **'정말 지울까요? 지운 계정은 되돌릴 수 없어요.'**
  String get accountDeleteDeleteConfirm;

  /// account-delete.delete.confirm: 최종 확인
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get accountDeleteDeleteConfirmDelete;

  /// account-delete.delete.confirm: 최종 확인
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get accountDeleteDeleteConfirmCancel;

  /// account-delete.title.head: 계정 삭제 제목
  ///
  /// In ko, this message translates to:
  /// **'계정 삭제'**
  String get accountDeleteTitleHead;

  /// ad-free.legal.notice: 이용약관·개인정보처리방침 링크 안내
  ///
  /// In ko, this message translates to:
  /// **'구매 전에 이용약관과 개인정보 처리방침을 확인해 주세요.'**
  String get adFreeLegalNotice;

  /// ad-free.offer.head: 광고 제거권이 주는 것 한 줄(배너 제거, 근거·해석 열림, D60)
  ///
  /// In ko, this message translates to:
  /// **'한 달 동안 광고 없이, 근거와 해석까지 모두 열어 봐요.'**
  String get adFreeOfferHead;

  /// ad-free.offer.price: 가격과 기간(1개월, 자동 갱신 아님) 고지
  ///
  /// In ko, this message translates to:
  /// **'{price} · 1개월 · 자동 갱신 없음'**
  String adFreeOfferPrice(String price);

  /// ad-free.restore.cta: 구매 복원
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get adFreeRestoreCta;

  /// ad-free.status.remaining: 광고 제거 남은 기간 또는 만료일
  ///
  /// In ko, this message translates to:
  /// **'{date}까지 광고 없이 볼 수 있어요'**
  String adFreeStatusRemaining(String date);

  /// calc-basis.convention.body: 한국 기준 해석 안내
  ///
  /// In ko, this message translates to:
  /// **'명리 해석은 한국에서 널리 쓰는 기준 하나로 맞췄어요.'**
  String get calcBasisConventionBody;

  /// calc-basis.longitude.body: 동경 127.5° 기준 -30분 보정, 진태양시 미적용 안내
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 동경 127.5° 기준으로 30분을 빼서 계산해요. 진태양시는 쓰지 않아요. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String get calcBasisLongitudeBody;

  /// calc-basis.lunar.body: KASI 기준 한국 음력 안내
  ///
  /// In ko, this message translates to:
  /// **'음력은 한국천문연구원 기준의 한국 음력을 따라요.'**
  String get calcBasisLunarBody;

  /// calendar.legend.body: 점 색의 뜻
  ///
  /// In ko, this message translates to:
  /// **'잘 풀리는 날'**
  String get calendarLegendBodyGood;

  /// calendar.legend.body: 점 색의 뜻
  ///
  /// In ko, this message translates to:
  /// **'조심할 날'**
  String get calendarLegendBodyCaution;

  /// consent.required.label: 필수 동의 항목 이름
  ///
  /// In ko, this message translates to:
  /// **'(필수) 이용약관'**
  String get consentRequiredLabelTerms;

  /// consent.required.label: 필수 동의 항목 이름
  ///
  /// In ko, this message translates to:
  /// **'(필수) 개인정보 수집·이용'**
  String get consentRequiredLabelPrivacy;

  /// day-sheet.diary.open: 그날 일기 보기 링크
  ///
  /// In ko, this message translates to:
  /// **'이날 일기 보기'**
  String get daySheetDiaryOpen;

  /// day-sheet.diary.write-cta: 이날 일기 쓰기(지난 날·오늘이고 일기 없음)
  ///
  /// In ko, this message translates to:
  /// **'이날 일기 쓰기'**
  String get daySheetDiaryWriteCta;

  /// day-sheet.event.add: 일정 추가 버튼
  ///
  /// In ko, this message translates to:
  /// **'일정 추가'**
  String get daySheetEventAdd;

  /// day-sheet.event.empty: 일정이 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'이날은 일정이 없어요.'**
  String get daySheetEventEmpty;

  /// diary-edit.body.placeholder: 본문 입력칸 안내
  ///
  /// In ko, this message translates to:
  /// **'오늘 있었던 일을 적어 보세요'**
  String get diaryEditBodyPlaceholder;

  /// diary-edit.draft.status: 초안 저장 상태
  ///
  /// In ko, this message translates to:
  /// **'기기에 임시 저장됨'**
  String get diaryEditDraftStatusLocal;

  /// diary-edit.draft.status: 초안 저장 상태
  ///
  /// In ko, this message translates to:
  /// **'저장 중'**
  String get diaryEditDraftStatusSaving;

  /// diary-edit.draft.status: 초안 저장 상태
  ///
  /// In ko, this message translates to:
  /// **'저장됨'**
  String get diaryEditDraftStatusSaved;

  /// diary-edit.offline.notice: 연결되면 저장한다는 안내
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되면 저장할게요. 쓴 내용은 기기에 남아 있어요.'**
  String get diaryEditOfflineNotice;

  /// diary-edit.saved.tags: 저장 뒤 붙은 태그 알림
  ///
  /// In ko, this message translates to:
  /// **'일기에 태그가 붙었어요'**
  String get diaryEditSavedTags;

  /// diary-list.empty.body: 쓴 일기가 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'아직 쓴 일기가 없어요. 오늘 하루부터 적어 볼까요?'**
  String get diaryListEmptyBody;

  /// diary-list.pick-date.cta: 날짜 골라 쓰기 버튼
  ///
  /// In ko, this message translates to:
  /// **'날짜 골라 쓰기'**
  String get diaryListPickDateCta;

  /// diary-view.delete.confirm: 일기 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'이 일기를 지울까요? 지우면 되돌릴 수 없어요.'**
  String get diaryViewDeleteConfirm;

  /// diary-view.delete.confirm: 일기 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get diaryViewDeleteConfirmDelete;

  /// diary-view.delete.confirm: 일기 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get diaryViewDeleteConfirmCancel;

  /// event-edit.delete.confirm: 일정 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'이 일정을 지울까요?'**
  String get eventEditDeleteConfirm;

  /// event-edit.delete.confirm: 일정 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get eventEditDeleteConfirmDelete;

  /// event-edit.delete.confirm: 일정 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get eventEditDeleteConfirmCancel;

  /// event-edit.memo.hint: 메모 입력칸 예시
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get eventEditMemoHint;

  /// event-edit.title.hint: 제목 입력칸 예시
  ///
  /// In ko, this message translates to:
  /// **'일정 제목'**
  String get eventEditTitleHint;

  /// evidence-sheet.lock.pass: 광고 제거권으로도 열린다는 안내와 링크
  ///
  /// In ko, this message translates to:
  /// **'광고 제거 보기'**
  String get evidenceSheetLockPassLink;

  /// evidence-sheet.unlock.failed: 광고를 끝까지 봤는데 server 확인(SSV)이 오지 않을 때의 toast
  ///
  /// In ko, this message translates to:
  /// **'광고 확인이 늦어지고 있어요. 잠시 뒤에 다시 열어 주세요.'**
  String get evidenceSheetUnlockFailed;

  /// preview.share.login-notice: 로그인하면 공유할 수 있다는 안내 창
  ///
  /// In ko, this message translates to:
  /// **'로그인하기'**
  String get previewShareLoginNoticeConfirm;

  /// preview.share.login-notice: 로그인하면 공유할 수 있다는 안내 창
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get previewShareLoginNoticeCancel;

  /// profile-edit.recalc.confirm: 생일·시간·성별·출생지를 바꿔 저장할 때의 확인 창. 바뀌기 전 → 뒤 값과 영향(오늘·달력·나의 사주를 다시 계산하고, 이미 쓴 일기와 태그는 그때 기록 그대로 남음)
  ///
  /// In ko, this message translates to:
  /// **'정보를 바꿀까요?'**
  String get profileEditRecalcConfirmTitle;

  /// profile-edit.recalc.confirm: 생일·시간·성별·출생지를 바꿔 저장할 때의 확인 창. 바뀌기 전 → 뒤 값과 영향(오늘·달력·나의 사주를 다시 계산하고, 이미 쓴 일기와 태그는 그때 기록 그대로 남음)
  ///
  /// In ko, this message translates to:
  /// **'{before} → {after}\n오늘·달력·나의 사주를 다시 계산해요. 이미 쓴 일기와 태그는 그대로 남아요.'**
  String profileEditRecalcConfirmBody(String before, String after);

  /// profile-edit.recalc.confirm: 생일·시간·성별·출생지를 바꿔 저장할 때의 확인 창. 바뀌기 전 → 뒤 값과 영향(오늘·달력·나의 사주를 다시 계산하고, 이미 쓴 일기와 태그는 그때 기록 그대로 남음)
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get profileEditRecalcConfirmCancel;

  /// profile-edit.recalc.confirm: 생일·시간·성별·출생지를 바꿔 저장할 때의 확인 창. 바뀌기 전 → 뒤 값과 영향(오늘·달력·나의 사주를 다시 계산하고, 이미 쓴 일기와 태그는 그때 기록 그대로 남음)
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get profileEditRecalcConfirmSave;

  /// profile-edit.recalc.notice: 바꾸면 풀이를 다시 계산한다는 안내
  ///
  /// In ko, this message translates to:
  /// **'생일·시간·성별·출생지를 바꾸면 풀이를 다시 계산해요.'**
  String get profileEditRecalcNotice;

  /// saju-chart.time-unknown.notice: 시간 모름으로 시주가 빠졌다는 안내
  ///
  /// In ko, this message translates to:
  /// **'태어난 시간을 몰라 시주는 빼고 보여 드려요.'**
  String get sajuChartTimeUnknownNotice;

  /// settings.ad-free.label: 광고 제거 메뉴와 남은 기간 표시
  ///
  /// In ko, this message translates to:
  /// **'광고 제거'**
  String get settingsAdFreeLabel;

  /// settings.ad-free.label: 광고 제거 메뉴와 남은 기간 표시
  ///
  /// In ko, this message translates to:
  /// **'{date}까지'**
  String settingsAdFreeLabelActive(String date);

  /// settings.depth.desc: 기본 깊이 설명
  ///
  /// In ko, this message translates to:
  /// **'풀이를 처음에 어디까지 펼쳐 볼지 골라요.'**
  String get settingsDepthDesc;

  /// settings.language.birthplace-notice: 언어를 바꿀 때 출생지 입력 안내
  ///
  /// In ko, this message translates to:
  /// **'한국 밖에서 태어났다면 출생지를 입력해 주세요. 태어난 시를 더 정확히 맞출 수 있어요.'**
  String get settingsLanguageBirthplaceNotice;

  /// settings.language.birthplace-notice: 언어를 바꿀 때 출생지 입력 안내
  ///
  /// In ko, this message translates to:
  /// **'출생지 입력하기'**
  String get settingsLanguageBirthplaceNoticeCta;

  /// settings.logout.confirm: 로그아웃 확인
  ///
  /// In ko, this message translates to:
  /// **'로그아웃할까요?'**
  String get settingsLogoutConfirm;

  /// settings.logout.confirm: 로그아웃 확인
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get settingsLogoutConfirmLogout;

  /// settings.logout.confirm: 로그아웃 확인
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get settingsLogoutConfirmCancel;

  /// share-preview.cta.share: 공유 버튼
  ///
  /// In ko, this message translates to:
  /// **'공유하기'**
  String get sharePreviewCtaShare;

  /// share-preview.image.footer: 이미지 아래 앱 이름
  ///
  /// In ko, this message translates to:
  /// **'명리일기'**
  String get sharePreviewImageFooter;

  /// share-preview.image.tagline: 공유 이미지 태그라인
  ///
  /// In ko, this message translates to:
  /// **'내 사주로 푼 오늘, 명리일기'**
  String get sharePreviewImageTagline;

  /// share-preview.ratio.label: 공유 이미지 비율 이름(스토리 9:16·피드 4:5·정사각 1:1)
  ///
  /// In ko, this message translates to:
  /// **'스토리'**
  String get sharePreviewRatioLabelStory;

  /// share-preview.ratio.label: 공유 이미지 비율 이름(스토리 9:16·피드 4:5·정사각 1:1)
  ///
  /// In ko, this message translates to:
  /// **'피드'**
  String get sharePreviewRatioLabelFeed;

  /// share-preview.ratio.label: 공유 이미지 비율 이름(스토리 9:16·피드 4:5·정사각 1:1)
  ///
  /// In ko, this message translates to:
  /// **'정사각'**
  String get sharePreviewRatioLabelSquare;

  /// 임시. share-image 접근성 라벨(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'오늘 문장 이미지 미리보기'**
  String get shareImageSemantics;

  /// tag-diary.empty.body: 일기가 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'이 태그가 붙은 일기가 아직 없어요.'**
  String get tagDiaryEmptyBody;

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'오늘 일정 {count}개 · {title}'**
  String todayEventSummary(int count, String title);

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'진행 중'**
  String get todayEventSummaryOngoing;

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get todayEventSummaryNext;

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'오늘 일정이 모두 끝났어요'**
  String get todayEventSummaryDone;

  /// today.guide.cta: 일기 쓰기 또는 쓴 일기 보기 버튼
  ///
  /// In ko, this message translates to:
  /// **'일기 쓰기'**
  String get todayGuideCta;

  /// today.guide.cta: 일기 쓰기 또는 쓴 일기 보기 버튼
  ///
  /// In ko, this message translates to:
  /// **'쓴 일기 보기'**
  String get todayGuideCtaWritten;

  /// 임시. today.guide.question 카드 위 작은 머리글
  ///
  /// In ko, this message translates to:
  /// **'오늘의 질문'**
  String get todayGuideEyebrow;

  /// 임시. today.guide.cta 자리의 쓴 뒤 상태 알림
  ///
  /// In ko, this message translates to:
  /// **'오늘 일기 씀'**
  String get todayGuideWritten;

  /// 임시. 오늘 가이드 질문 카드 묶음의 접근성 라벨
  ///
  /// In ko, this message translates to:
  /// **'질문'**
  String get todayGuideLabel;

  /// today.reaction.label: 좋아요 반응 접근성 라벨
  ///
  /// In ko, this message translates to:
  /// **'좋아요 취소'**
  String get todayReactionLabelSelected;

  /// 깊이 단계 선택의 기본 단계 이름
  ///
  /// In ko, this message translates to:
  /// **'명리 풀이 보기'**
  String get depthDefaultLabel;

  /// 깊이 단계 근거 단계(셋째 단계)의 안내
  ///
  /// In ko, this message translates to:
  /// **'원리'**
  String get depthEvidence;

  /// 깊이 단계 풀이 단계(둘째 단계)의 안내
  ///
  /// In ko, this message translates to:
  /// **'풀이'**
  String get depthExplain;

  /// 깊이 단계 표면 단계(첫 단계)의 안내
  ///
  /// In ko, this message translates to:
  /// **'요약'**
  String get depthSurface;

  /// 임시. 행운 방향 칩 값 n(A27)
  ///
  /// In ko, this message translates to:
  /// **'북쪽'**
  String get directionN;

  /// 임시. 행운 방향 칩 값 ne(A27)
  ///
  /// In ko, this message translates to:
  /// **'북동쪽'**
  String get directionNe;

  /// 임시. 행운 방향 칩 값 e(A27)
  ///
  /// In ko, this message translates to:
  /// **'동쪽'**
  String get directionE;

  /// 임시. 행운 방향 칩 값 se(A27)
  ///
  /// In ko, this message translates to:
  /// **'남동쪽'**
  String get directionSe;

  /// 임시. 행운 방향 칩 값 s(A27)
  ///
  /// In ko, this message translates to:
  /// **'남쪽'**
  String get directionS;

  /// 임시. 행운 방향 칩 값 sw(A27)
  ///
  /// In ko, this message translates to:
  /// **'남서쪽'**
  String get directionSw;

  /// 임시. 행운 방향 칩 값 w(A27)
  ///
  /// In ko, this message translates to:
  /// **'서쪽'**
  String get directionW;

  /// 임시. 행운 방향 칩 값 nw(A27)
  ///
  /// In ko, this message translates to:
  /// **'북서쪽'**
  String get directionNw;

  /// 임시. today.fortune.head 끝의 근거 시트 링크(슬롯 아님)
  ///
  /// In ko, this message translates to:
  /// **'근거 보기'**
  String get depthLinkEvidence;

  /// 임시. 행운 색 칩의 접근성 항목 이름(lucky-card a11y 항목 이름 + 값)
  ///
  /// In ko, this message translates to:
  /// **'행운 색'**
  String get todayLuckyColorName;

  /// 임시. 행운 방향 칩의 접근성 항목 이름(lucky-card a11y 항목 이름 + 값)
  ///
  /// In ko, this message translates to:
  /// **'행운 방향'**
  String get todayLuckyDirectionName;

  /// 임시. 행운 숫자 칩의 접근성 항목 이름(lucky-card a11y 항목 이름 + 값)
  ///
  /// In ko, this message translates to:
  /// **'행운 숫자'**
  String get todayLuckyNumberName;

  /// 임시. 집중하기 좋은 시간 칩의 접근성 항목 이름(lucky-card a11y 항목 이름 + 값)
  ///
  /// In ko, this message translates to:
  /// **'집중하기 좋은 시간'**
  String get todayLuckyTimeName;
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
