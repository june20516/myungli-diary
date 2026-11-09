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

  /// 오류 상태·토스트: 앱이 나눈 통신 오류 종류별 안내(연결 없음, 시간 초과, 4xx, 5xx, 그 밖, 준비 중)
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되어 있지 않아요. 연결을 확인해 주세요.'**
  String get errorOffline;

  /// 오류 상태·토스트: 앱이 나눈 통신 오류 종류별 안내(연결 없음, 시간 초과, 4xx, 5xx, 그 밖, 준비 중)
  ///
  /// In ko, this message translates to:
  /// **'응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.'**
  String get errorTimeout;

  /// 오류 상태·토스트: 앱이 나눈 통신 오류 종류별 안내(연결 없음, 시간 초과, 4xx, 5xx, 그 밖, 준비 중)
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 다시 시도해 주세요.'**
  String get errorClient;

  /// 오류 상태·토스트: 앱이 나눈 통신 오류 종류별 안내(연결 없음, 시간 초과, 4xx, 5xx, 그 밖, 준비 중)
  ///
  /// In ko, this message translates to:
  /// **'잠시 문제가 생겼어요. 조금 뒤에 다시 시도해 주세요.'**
  String get errorServer;

  /// 오류 상태·토스트: 앱이 나눈 통신 오류 종류별 안내(연결 없음, 시간 초과, 4xx, 5xx, 그 밖, 준비 중)
  ///
  /// In ko, this message translates to:
  /// **'문제가 생겼어요. 다시 시도해 주세요.'**
  String get errorUnexpected;

  /// 오류 상태·토스트: 앱이 나눈 통신 오류 종류별 안내(연결 없음, 시간 초과, 4xx, 5xx, 그 밖, 준비 중)
  ///
  /// In ko, this message translates to:
  /// **'아직 준비 중이에요.'**
  String get errorNotImplemented;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 다시 시도해 주세요.'**
  String get errorRequestMalformed;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'입력한 내용을 다시 확인해 주세요.'**
  String get errorRequestInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'로그인이 만료됐어요. 다시 로그인해 주세요.'**
  String get errorAuthTokenExpired;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'로그인 정보를 확인하지 못했어요. 다시 로그인해 주세요.'**
  String get errorAuthTokenInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'계정을 지키려고 로그아웃했어요. 다시 로그인해 주세요.'**
  String get errorAuthRefreshReused;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'로그인하지 못했어요. 다시 시도해 주세요.'**
  String get errorAuthProviderTokenInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'로그인 시간이 지났어요. 처음부터 다시 로그인해 주세요.'**
  String get errorAuthExchangeInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'앱을 확인하지 못했어요. 최신 버전으로 업데이트해 주세요.'**
  String get errorAppCheckInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'약관에 동의해야 계속할 수 있어요.'**
  String get errorConsentRequired;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'미리보기는 한 번만 볼 수 있어요. 로그인하면 이어서 읽을 수 있어요.'**
  String get errorPreviewUsed;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 앱을 업데이트해 주세요.'**
  String get errorRouteNotFound;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'일기를 찾지 못했어요.'**
  String get errorDiaryNotFound;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 앱을 업데이트해 주세요.'**
  String get errorMethodNotAllowed;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'먼저 태어난 날과 시간을 입력해 주세요.'**
  String get errorProfileRequired;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'그날에는 이미 일기가 있어요.'**
  String get errorDiaryDateTaken;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'아직 처리하고 있어요. 잠시 후 다시 확인해 주세요.'**
  String get errorIdempotencyInProgress;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'내용이 너무 길어요. 조금 줄여 주세요.'**
  String get errorRequestTooLarge;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 앱을 업데이트해 주세요.'**
  String get errorRequestUnsupportedMediaType;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'1900년 1월 31일부터 2099년 12월 31일까지의 날짜만 볼 수 있어요.'**
  String get errorDateOutOfRange;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'1900년 1월 31일부터 2099년 12월 31일 사이의 날짜만 계산할 수 있어요.'**
  String get errorBirthOutOfRange;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'달력에 없는 날짜예요.'**
  String get errorDateInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'입력한 내용을 다시 확인해 주세요.'**
  String get errorRequestInconsistent;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'입력한 태어난 날과 시간을 다시 확인해 주세요.'**
  String get errorBirthInvalid;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'아직 오지 않은 날의 일기는 쓸 수 없어요.'**
  String get errorDiaryFutureDate;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'불러 드릴 이름을 입력해 주세요.'**
  String get errorNameEmpty;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'이름이 너무 길어요. 조금 줄여 주세요.'**
  String get errorNameTooLong;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'이름에는 이모지를 쓸 수 없어요.'**
  String get errorNameEmoji;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'이름에 쓸 수 없는 글자가 있어요.'**
  String get errorNameControl;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'이름에는 괄호를 쓸 수 없어요.'**
  String get errorNameInvalidChar;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'요청을 처리하지 못했어요. 다시 시도해 주세요.'**
  String get errorIdempotencyMismatch;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'약관이 바뀌었어요. 다시 확인해 주세요.'**
  String get errorConsentVersionMismatch;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'요청이 너무 많아요. 잠시 후 다시 시도해 주세요.'**
  String get errorRateLimited;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'잠시 문제가 생겼어요. 조금 뒤에 다시 시도해 주세요.'**
  String get errorInternal;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'풀이를 계산하지 못했어요. 잠시 후 다시 시도해 주세요.'**
  String get errorEngineError;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'풀이를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.'**
  String get errorEngineUnavailable;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'지금은 로그인할 수 없어요. 잠시 후 다시 시도해 주세요.'**
  String get errorAuthProviderUnavailable;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'지금은 결제를 확인할 수 없어요. 잠시 후 다시 시도해 주세요.'**
  String get errorBillingProviderUnavailable;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'지금은 앱을 쓸 수 없어요. 잠시 후 다시 시도해 주세요.'**
  String get errorServiceUnavailable;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'풀이 계산이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.'**
  String get errorEngineTimeout;

  /// 앱 바·작업 전환기에 보이는 앱 이름
  ///
  /// In ko, this message translates to:
  /// **'명리일기'**
  String get appTitle;

  /// 오류 상태: 앱 시작 준비가 실패했을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'앱을 열지 못했어요. 앱을 완전히 닫았다가 다시 열어 주세요.'**
  String get bootstrapFailed;

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get actionRetry;

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'처리 중'**
  String get actionBusy;

  /// 오류 화면의 문의 번호 표시와 복사 뒤 토스트
  ///
  /// In ko, this message translates to:
  /// **'문의 번호 {traceId}'**
  String traceIdLabel(String traceId);

  /// 탭 바의 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get tabToday;

  /// 탭 바의 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'달력'**
  String get tabCalendar;

  /// 탭 바의 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'일기'**
  String get tabDiary;

  /// 탭 바의 탭 이름
  ///
  /// In ko, this message translates to:
  /// **'나'**
  String get tabMe;

  /// 앱 바 뒤로 버튼과 시트 바깥 덮개의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get appBarBack;

  /// 앱 바 뒤로 버튼과 시트 바깥 덮개의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get sheetDismiss;

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'광고'**
  String get adBannerLabel;

  /// 오프라인 안내 배너와 빈 상태 기본 문장
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되어 있지 않아 저장해 둔 내용을 보여 드려요.'**
  String get noticeOffline;

  /// 오프라인 안내 배너와 빈 상태 기본 문장
  ///
  /// In ko, this message translates to:
  /// **'아직 보여 드릴 내용이 없어요.'**
  String get emptyStateDefault;

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'불러오는 중'**
  String get skeletonLabel;

  /// 오류 화면의 문의 번호 표시와 복사 뒤 토스트
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

  /// saju-chart.yongsin.title: 원국 탭 섹션 제목(용신 판정 근거). 잠겼을 때 스크린리더 라벨(구역 이름 + 잠김)의 앞부분
  ///
  /// In ko, this message translates to:
  /// **'용신 판정 근거'**
  String get sajuChartYongsinTitle;

  /// today.reaction.label: 총운 섹션 제목 줄 오른쪽 좋아요 반응의 접근성 라벨
  ///
  /// In ko, this message translates to:
  /// **'좋아요'**
  String get todayReactionLabel;

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'{term} 뜻 보기'**
  String termTokenSemantics(String term);

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'{stepCount}단계 중 {step}단계'**
  String inputStepProgress(int step, int stepCount);

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
  ///
  /// In ko, this message translates to:
  /// **'지우기'**
  String get textFieldClear;

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'{max}자 중 {current}자'**
  String textFieldCounter(int current, int max);

  /// 날짜·시간 휠의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'연도'**
  String get datePickerYearLabel;

  /// 날짜·시간 휠의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get datePickerMonthLabel;

  /// 날짜·시간 휠의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get datePickerDayLabel;

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'{year}년'**
  String datePickerYearItem(int year);

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'{month}월'**
  String datePickerMonthItem(int month);

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'{day}일'**
  String datePickerDayItem(int day);

  /// 날짜·시간 휠의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'오전 또는 오후'**
  String get timePickerMeridiemLabel;

  /// 날짜·시간 휠의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'시'**
  String get timePickerHourLabel;

  /// 날짜·시간 휠의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'분'**
  String get timePickerMinuteLabel;

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'오전'**
  String get timePickerAm;

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'오후'**
  String get timePickerPm;

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'{hour}시'**
  String timePickerHourItem(int hour);

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'{minute}분'**
  String timePickerMinuteItem(String minute);

  /// 날짜·시간 휠 칸의 글자(연·월·일·시·분, 오전·오후, 윤달 월)
  ///
  /// In ko, this message translates to:
  /// **'윤{month}월'**
  String datePickerLeapMonthValue(int month);

  /// 생일 날짜 휠(date-picker birth)의 양력 확인 줄(solarConfirm, design V31, #313). 고른 음력 날짜를 양력으로 바꾼 날짜를 보입니다
  ///
  /// In ko, this message translates to:
  /// **'양력 {date}'**
  String datePickerSolarConfirm(String date);

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'결과 {count, plural, other{{count}개}}'**
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
  /// **'음력 생일이면 음력을 골라 주세요. 윤달이면 달 목록에 있는 윤달을 고르면 돼요.'**
  String get onboardBirthCalendarHint;

  /// onboard-birth.basis.note: 한국 출생 기준으로 계산한다는 안내
  ///
  /// In ko, this message translates to:
  /// **'한국에서 태어난 것을 기준으로 계산합니다.'**
  String get onboardBirthBasisNote;

  /// onboard-birth.error.range: 지원 범위 밖 안내
  ///
  /// In ko, this message translates to:
  /// **'1900년 1월 31일부터 2099년 12월 31일 사이의 날짜만 계산할 수 있어요.'**
  String get onboardBirthErrorRange;

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get onboardingNext;

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get onboardingSave;

  /// 출생 정보 입력의 선택지 이름(양력·음력, 시간 모름, 성별). 윤달은 월 휠에서 고릅니다(`datePickerLeapMonthValue`, V31). 사주 표 출생 정보 줄의 알약과 꼬리표도 같은 키를 씁니다(R30-13, design 5.0.0, 상한은 더 좁은 segmented 칸 기준 그대로)
  ///
  /// In ko, this message translates to:
  /// **'양력'**
  String get calendarSolar;

  /// 출생 정보 입력의 선택지 이름(양력·음력, 시간 모름, 성별). 윤달은 월 휠에서 고릅니다(`datePickerLeapMonthValue`, V31). 사주 표 출생 정보 줄의 알약과 꼬리표도 같은 키를 씁니다(R30-13, design 5.0.0, 상한은 더 좁은 segmented 칸 기준 그대로)
  ///
  /// In ko, this message translates to:
  /// **'음력'**
  String get calendarLunar;

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'불러 드릴 이름'**
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

  /// 출생 정보 입력의 선택지 이름(양력·음력, 시간 모름, 성별). 윤달은 월 휠에서 고릅니다(`datePickerLeapMonthValue`, V31). 사주 표 출생 정보 줄의 알약과 꼬리표도 같은 키를 씁니다(R30-13, design 5.0.0, 상한은 더 좁은 segmented 칸 기준 그대로)
  ///
  /// In ko, this message translates to:
  /// **'모름'**
  String get timeUnknownLabel;

  /// onboard-time.hour.confirm: 엔진이 계산한 시진과 벽시계 범위 확인 줄(예: 인시 03:30~05:30). 기기 지역이 한국일 때만 (D58) app이 getBirthHour 구조값(branch·start·end)을 ui 틀에 넣음(D68)
  ///
  /// In ko, this message translates to:
  /// **'{branch}시, {start}~{end}에 태어났어요.'**
  String onboardTimeHourConfirm(String branch, String start, String end);

  /// glossary.value_name: branch.ja
  ///
  /// In ko, this message translates to:
  /// **'자'**
  String get branchJa;

  /// glossary.value_name: branch.chuk
  ///
  /// In ko, this message translates to:
  /// **'축'**
  String get branchChuk;

  /// glossary.value_name: branch.in
  ///
  /// In ko, this message translates to:
  /// **'인'**
  String get branchIn;

  /// glossary.value_name: branch.myo
  ///
  /// In ko, this message translates to:
  /// **'묘'**
  String get branchMyo;

  /// glossary.value_name: branch.jin
  ///
  /// In ko, this message translates to:
  /// **'진'**
  String get branchJin;

  /// glossary.value_name: branch.sa
  ///
  /// In ko, this message translates to:
  /// **'사'**
  String get branchSa;

  /// glossary.value_name: branch.o
  ///
  /// In ko, this message translates to:
  /// **'오'**
  String get branchO;

  /// glossary.value_name: branch.mi
  ///
  /// In ko, this message translates to:
  /// **'미'**
  String get branchMi;

  /// glossary.value_name: branch.shin
  ///
  /// In ko, this message translates to:
  /// **'신'**
  String get branchShin;

  /// glossary.value_name: branch.yu
  ///
  /// In ko, this message translates to:
  /// **'유'**
  String get branchYu;

  /// glossary.value_name: branch.sul
  ///
  /// In ko, this message translates to:
  /// **'술'**
  String get branchSul;

  /// glossary.value_name: branch.hae
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

  /// 스크린리더가 읽는 컴포넌트 이름과 상태(처리 중, 광고, 불러오는 중, 용어 토큰, 진행 단계, 글자 수, 검색 결과 수, 입력칸 이름)
  ///
  /// In ko, this message translates to:
  /// **'태어난 도시 찾기'**
  String get birthplaceSearchLabel;

  /// 출생 정보 입력의 선택지 이름(양력·음력, 시간 모름, 성별). 윤달은 월 휠에서 고릅니다(`datePickerLeapMonthValue`, V31). 사주 표 출생 정보 줄의 알약과 꼬리표도 같은 키를 씁니다(R30-13, design 5.0.0, 상한은 더 좁은 segmented 칸 기준 그대로)
  ///
  /// In ko, this message translates to:
  /// **'남성'**
  String get genderMale;

  /// 출생 정보 입력의 선택지 이름(양력·음력, 시간 모름, 성별). 윤달은 월 휠에서 고릅니다(`datePickerLeapMonthValue`, V31). 사주 표 출생 정보 줄의 알약과 꼬리표도 같은 키를 씁니다(R30-13, design 5.0.0, 상한은 더 좁은 segmented 칸 기준 그대로)
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

  /// glossary.value_name: day_kind.yongsin_day
  ///
  /// In ko, this message translates to:
  /// **'용신의 날'**
  String get dayKindYongsinDay;

  /// glossary.value_name: day_kind.gwiin_day
  ///
  /// In ko, this message translates to:
  /// **'귀인의 날'**
  String get dayKindGwiinDay;

  /// glossary.value_name: day_kind.gisin_day
  ///
  /// In ko, this message translates to:
  /// **'기신의 날'**
  String get dayKindGisinDay;

  /// glossary.value_name: day_kind.ordinary_day
  ///
  /// In ko, this message translates to:
  /// **'평범한 날'**
  String get dayKindOrdinaryDay;

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
  ///
  /// In ko, this message translates to:
  /// **'공유'**
  String get shareLabel;

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get actionClose;

  /// login.title.head: 로그인 제목. 첫 화면 맞이 문구(경로와 상관없이 같음, D111)
  ///
  /// In ko, this message translates to:
  /// **'명리일기'**
  String get loginTitleHead;

  /// login.title.body: 로그인 설명. 첫 화면 맞이 문구로 경로와 상관없이 같음(D111, 검수 F-029, writing W56)
  ///
  /// In ko, this message translates to:
  /// **'로그인하시면 매일 내 사주에 맞춘 풀이를 드릴게요.'**
  String get loginTitleBody;

  /// login.discard.notice: 사주가 저장된 계정이면 미리보기 입력을 쓰지 않는다는 안내
  ///
  /// In ko, this message translates to:
  /// **'이미 사주를 저장한 계정이면 방금 입력한 정보 대신 저장된 정보를 써요.'**
  String get loginDiscardNotice;

  /// 소셜 로그인 버튼 글자. 제공자 가이드 문구를 그대로 씁니다(카카오 로그인 디자인 가이드, Sign in with Apple HIG, LINE Login button design guidelines, Sign in with Google branding guidelines)
  ///
  /// In ko, this message translates to:
  /// **'카카오 로그인'**
  String get loginKakaoLabel;

  /// 소셜 로그인 버튼 글자. 제공자 가이드 문구를 그대로 씁니다(카카오 로그인 디자인 가이드, Sign in with Apple HIG, LINE Login button design guidelines, Sign in with Google branding guidelines)
  ///
  /// In ko, this message translates to:
  /// **'Apple로 로그인'**
  String get loginAppleLabel;

  /// 로그인 화면 오류 상태: 로그인 창을 닫음, Android Apple 웹 로그인 복귀 실패
  ///
  /// In ko, this message translates to:
  /// **'로그인을 취소했어요.'**
  String get loginCancelled;

  /// 로그인 화면 오류 상태: 로그인 창을 닫음, Android Apple 웹 로그인 복귀 실패
  ///
  /// In ko, this message translates to:
  /// **'로그인을 확인하지 못했어요. 처음부터 다시 로그인해 주세요.'**
  String get appleWebErrorStateMismatch;

  /// 로그인 화면 오류 상태: 로그인 창을 닫음, Android Apple 웹 로그인 복귀 실패
  ///
  /// In ko, this message translates to:
  /// **'Apple 로그인을 취소했어요.'**
  String get appleWebErrorCancelled;

  /// 로그인 화면 오류 상태: 로그인 창을 닫음, Android Apple 웹 로그인 복귀 실패
  ///
  /// In ko, this message translates to:
  /// **'Apple로 로그인하지 못했어요. 다시 시도해 주세요.'**
  String get appleWebErrorOther;

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
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

  /// 여러 화면이 함께 쓰는 동작 버튼·링크 이름(다시 시도, 닫기, 확인, 다음, 저장, 공유, 약관 보기, 입력 지우기)
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

  /// account-delete.data.body: 지워지는 데이터 안내(바로 지워지고 되돌릴 수 없음, 법이나 부정 이용 방지를 위해 필요한 정보만 정해진 기간 따로 보관한다는 한 줄, D88 ③④)
  ///
  /// In ko, this message translates to:
  /// **'계정을 지우면 사주 정보, 일기, 태그, 일정, 구매한 상품의 남은 기간이 모두 지워지며 되돌릴 수 없습니다. 법이나 부정 이용 방지를 위해 필요한 정보만 정해진 기간 동안 따로 보관합니다.'**
  String get accountDeleteDataBody;

  /// account-delete.delete.confirm: 최종 확인
  ///
  /// In ko, this message translates to:
  /// **'정말 지울까요? 지운 계정은 되돌릴 수 없습니다.'**
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

  /// ad-free.offer.price: 가격(고정폭 숫자, D53). 기간과 자동 갱신 아님 고지는 offer.period
  ///
  /// In ko, this message translates to:
  /// **'{price}'**
  String adFreeOfferPrice(String price);

  /// ad-free.status.remaining: 광고 제거 남은 기간 또는 만료일
  ///
  /// In ko, this message translates to:
  /// **'{date}까지 광고 없이 볼 수 있어요'**
  String adFreeStatusRemaining(String date);

  /// calc-basis.convention.body: 한국에서 보편적으로 쓰는 해석 기준을 쓴다는 안내. 여러 유파 가운데 하나로서의 근거를 밝히고 우열은 말하지 않습니다(D28·D71)
  ///
  /// In ko, this message translates to:
  /// **'명리 해석은 한국에서 널리 쓰는 기준을 따릅니다. 여러 유파 가운데 하나로, 근거가 있는 기준이에요.'**
  String get calcBasisConventionBody;

  /// calc-basis.lunar.body: KASI 기준 한국 음력 안내
  ///
  /// In ko, this message translates to:
  /// **'음력은 한국천문연구원 기준의 한국 음력을 따릅니다.'**
  String get calcBasisLunarBody;

  /// calendar.legend.body: 범례 견본 셋의 이름: 아주 잘 풀리는 날(합한 점 3 이상), 잘 풀리는 날(2), 조심할 날. 무난한 날은 무색이라 범례 견본이 없음(DS1 관문 Q2 ①). 그날 시트 길흉판정 막대의 세 이름도 이 키
  ///
  /// In ko, this message translates to:
  /// **'잘 풀리는 날'**
  String get calendarLegendBodyGood;

  /// calendar.legend.body: 범례 견본 셋의 이름: 아주 잘 풀리는 날(합한 점 3 이상), 잘 풀리는 날(2), 조심할 날. 무난한 날은 무색이라 범례 견본이 없음(DS1 관문 Q2 ①). 그날 시트 길흉판정 막대의 세 이름도 이 키
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
  /// **'(필수) 개인정보 수집 및 이용'**
  String get consentRequiredLabelPrivacy;

  /// day-sheet.diary.open: 그날 일기 섹션 제목. 쓴 일기가 없어도 보이고, 0편이면 제목 아래 쓰기 버튼만(DS1 관문 Q5 ①). 쓴 일기는 아래에 diary-row로 작성 순
  ///
  /// In ko, this message translates to:
  /// **'일기'**
  String get daySheetDiaryOpen;

  /// day-sheet.diary.write-cta: 일기 쓰기 버튼 "<날짜> 일기 쓰기" 틀(매개변수 date, 예: 11월 9일 일기 쓰기). 지난 날과 오늘. 이미 쓴 날이면 한 편 더 쓰기, 10편을 채웠으면 누를 수 없고 더 쓸 수 없다는 문구(D83 ②)
  ///
  /// In ko, this message translates to:
  /// **'{date} 일기 쓰기'**
  String daySheetDiaryWriteCta(String date);

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

  /// diary-edit.draft.status: 임시 저장 상태. 상단 바 가운데에 작게, 쓰는 중에만(키보드 위는 비움)
  ///
  /// In ko, this message translates to:
  /// **'임시 저장'**
  String get diaryEditDraftStatusLocal;

  /// diary-edit.draft.status: 임시 저장 상태. 상단 바 가운데에 작게, 쓰는 중에만(키보드 위는 비움)
  ///
  /// In ko, this message translates to:
  /// **'저장 중'**
  String get diaryEditDraftStatusSaving;

  /// diary-edit.draft.status: 임시 저장 상태. 상단 바 가운데에 작게, 쓰는 중에만(키보드 위는 비움)
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

  /// diary-list.empty.body: 쓴 일기가 없을 때 안내. 아래에 같은 일기 쓰기 버튼을 가운데 둠
  ///
  /// In ko, this message translates to:
  /// **'아직 쓴 일기가 없어요. 오늘 하루부터 적어 볼까요?'**
  String get diaryListEmptyBody;

  /// diary-list.pick-date.cta: 일기 쓰기 버튼(가안 "일기 쓰기", 문구 writing). 쓰기 입구는 이것 하나이고 목록이 있으면 아래 고정, 빈 상태에서는 안내 아래 가운데. 누르면 날짜 고르기 시트(기본값 오늘)
  ///
  /// In ko, this message translates to:
  /// **'일기 쓰기'**
  String get diaryListPickDateCta;

  /// diary-view.delete.confirm: 일기 삭제 확인
  ///
  /// In ko, this message translates to:
  /// **'이 일기를 지울까요? 지우면 되돌릴 수 없습니다.'**
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
  /// **'{before} → {after}\n오늘, 달력, 나의 사주를 다시 계산해요. 이미 쓴 일기와 태그는 그대로 남아요.'**
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
  /// **'생일, 시간, 성별, 출생지를 바꾸면 풀이를 다시 계산합니다.'**
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
  /// **'오늘 일진을 내 사주에 맞춰 풀어 주는 일기'**
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

  /// 공유 미리보기 화면(share-preview): 이미지 미리보기와 비율 선택 묶음의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'오늘 문장 이미지 미리보기'**
  String get shareImageSemantics;

  /// 공유 미리보기 화면(share-preview): 이미지 미리보기와 비율 선택 묶음의 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'공유 이미지 비율'**
  String get sharePreviewRatioGroup;

  /// tag-diary.empty.body: 일기가 없을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'이 태그가 붙은 일기가 아직 없어요.'**
  String get tagDiaryEmptyBody;

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'오늘 일정 {count}개, {title}'**
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

  /// today.guide.cta: 일기 쓰기 버튼(언제나 새 일기. 오늘 이미 썼으면 한 편 더 쓰기, 10편을 채웠으면 누를 수 없고 더 쓸 수 없다는 문구, D83 ②)
  ///
  /// In ko, this message translates to:
  /// **'일기 쓰기'**
  String get todayGuideCta;

  /// today.guide.cta: 일기 쓰기 버튼(언제나 새 일기. 오늘 이미 썼으면 한 편 더 쓰기, 10편을 채웠으면 누를 수 없고 더 쓸 수 없다는 문구, D83 ②)
  ///
  /// In ko, this message translates to:
  /// **'새 일기 쓰기'**
  String get todayGuideCtaWritten;

  /// 가이드 질문 카드(guide-question-card) 위 작은 머리글(#153)
  ///
  /// In ko, this message translates to:
  /// **'오늘의 질문'**
  String get todayGuideEyebrow;

  /// 가이드 질문 카드(guide-question-card)의 스크린리더 문구: 카드 묶음 이름(a11y.label), 일기를 쓴 뒤 상태 알림(stateAnnounced)(#153)
  ///
  /// In ko, this message translates to:
  /// **'오늘 일기를 썼어요'**
  String get todayGuideWritten;

  /// 가이드 질문 카드(guide-question-card)의 스크린리더 문구: 카드 묶음 이름(a11y.label), 일기를 쓴 뒤 상태 알림(stateAnnounced)(#153)
  ///
  /// In ko, this message translates to:
  /// **'일기 질문'**
  String get todayGuideLabel;

  /// today.reaction.label: 총운 섹션 제목 줄 오른쪽 좋아요 반응의 접근성 라벨
  ///
  /// In ko, this message translates to:
  /// **'좋아요 취소'**
  String get todayReactionLabelSelected;

  /// 풀이 시트(sheet)의 접근성 라벨. 깊이 풀이 단계(explain)의 이름입니다(D79로 기본 깊이 설정이 빠져 segmented 칸에는 쓰지 않음)
  ///
  /// In ko, this message translates to:
  /// **'풀이'**
  String get depthExplain;

  /// 근거 아이콘(book-open-text)의 스크린리더 이름: 오늘 화면 문장 끝에서 근거 시트로 가는 아이콘(#153, DS1 V63, #807)
  ///
  /// In ko, this message translates to:
  /// **'{subject} 근거 보기'**
  String depthLinkEvidence(String subject);

  /// 오늘 화면(today): lucky-card 칩의 스크린리더 항목 이름(이름 다음에 값을 읽음)
  ///
  /// In ko, this message translates to:
  /// **'행운 색'**
  String get todayLuckyColorName;

  /// 오늘 화면(today): lucky-card 칩의 스크린리더 항목 이름(이름 다음에 값을 읽음)
  ///
  /// In ko, this message translates to:
  /// **'행운 방향'**
  String get todayLuckyDirectionName;

  /// 오늘 화면(today): lucky-card 칩의 스크린리더 항목 이름(이름 다음에 값을 읽음)
  ///
  /// In ko, this message translates to:
  /// **'행운 숫자'**
  String get todayLuckyNumberName;

  /// 오늘 화면(today): lucky-card 칩의 스크린리더 항목 이름(이름 다음에 값을 읽음)
  ///
  /// In ko, this message translates to:
  /// **'집중하기 좋은 시간'**
  String get todayLuckyTimeName;

  /// 근거 시트(sheet) 제목(#153)
  ///
  /// In ko, this message translates to:
  /// **'풀이의 근거'**
  String get evidenceSheetTitle;

  /// 달력 날짜 칸(day-cell): 스크린리더 조각
  ///
  /// In ko, this message translates to:
  /// **', '**
  String get a11yListSeparator;

  /// calendar.bar.title: app-bar 제목(화면 이름 "달력")
  ///
  /// In ko, this message translates to:
  /// **'달력'**
  String get calendarBarTitle;

  /// event-edit.bar.title: app-bar 제목(화면 이름 "일정 편집")
  ///
  /// In ko, this message translates to:
  /// **'일정'**
  String get eventEditBarTitle;

  /// 달력 한 달 보기(calendar-month): 이전 달·다음 달 버튼 이름
  ///
  /// In ko, this message translates to:
  /// **'이전 달'**
  String get calendarPrevMonth;

  /// 달력 한 달 보기(calendar-month): 이전 달·다음 달 버튼 이름
  ///
  /// In ko, this message translates to:
  /// **'다음 달'**
  String get calendarNextMonth;

  /// 달력 날짜 칸(day-cell): 스크린리더 조각
  ///
  /// In ko, this message translates to:
  /// **'음력 {month}월 {day}일'**
  String dayCellLunar(int month, int day);

  /// 달력 날짜 칸(day-cell): 스크린리더 조각
  ///
  /// In ko, this message translates to:
  /// **'윤달'**
  String get dayCellLeapMonth;

  /// 달력 날짜 칸(day-cell): 스크린리더 조각
  ///
  /// In ko, this message translates to:
  /// **'일정 {count, plural, other{{count}개}}'**
  String dayCellEventCount(int count);

  /// 달력 날짜 칸(day-cell): 스크린리더 조각
  ///
  /// In ko, this message translates to:
  /// **'일기 있음'**
  String get dayCellDiaryWritten;

  /// 달력 날짜 칸(day-cell): 스크린리더 조각
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get dayCellToday;

  /// 일정 줄(event-row): 더 있음·하루 종일 표시와 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'외 {count, plural, other{{count}개}}'**
  String eventRowMore(int count);

  /// 일정 줄(event-row): 더 있음·하루 종일 표시와 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'하루 종일'**
  String get eventRowAllDay;

  /// 일정 줄(event-row): 더 있음·하루 종일 표시와 스크린리더 이름
  ///
  /// In ko, this message translates to:
  /// **'{status} {time} {title}'**
  String eventRowLabel(String status, String time, String title);

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'다음 {time} {title}'**
  String todayEventSummaryNextAt(String time, String title);

  /// today.event.summary: 오늘 일정 개수와 첫 일정
  ///
  /// In ko, this message translates to:
  /// **'오늘 일정 {count, plural, other{{count}개}}가 모두 지났어요'**
  String todayEventSummaryAllPast(int count);

  /// 일정 편집 화면(event-edit): 하루 종일·시간 지정, 날짜·시간 이름. 저장·지우기 버튼과 오프라인·실패 안내는 IA 슬롯 `event-edit.*`(D77)
  ///
  /// In ko, this message translates to:
  /// **'하루 종일'**
  String get eventEditAllDay;

  /// 일정 편집 화면(event-edit): 하루 종일·시간 지정, 날짜·시간 이름. 저장·지우기 버튼과 오프라인·실패 안내는 IA 슬롯 `event-edit.*`(D77)
  ///
  /// In ko, this message translates to:
  /// **'시간 지정'**
  String get eventEditTimed;

  /// 일정 편집 화면(event-edit): 하루 종일·시간 지정, 날짜·시간 이름. 저장·지우기 버튼과 오프라인·실패 안내는 IA 슬롯 `event-edit.*`(D77)
  ///
  /// In ko, this message translates to:
  /// **'날짜'**
  String get eventEditDateLabel;

  /// 일정 편집 화면(event-edit): 하루 종일·시간 지정, 날짜·시간 이름. 저장·지우기 버튼과 오프라인·실패 안내는 IA 슬롯 `event-edit.*`(D77)
  ///
  /// In ko, this message translates to:
  /// **'시간'**
  String get eventEditTimeLabel;

  /// 일정 편집 화면(event-edit): 저장 버튼
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get eventEditSave;

  /// 일정 편집 화면(event-edit): 일정 지우기 버튼. 누르면 `event-edit.delete.confirm`을 엽니다
  ///
  /// In ko, this message translates to:
  /// **'일정 지우기'**
  String get eventEditDelete;

  /// 일정 편집 화면(event-edit): 연결이 없어 지금 저장할 수 없다는 안내
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되어 있지 않아 저장할 수 없어요.'**
  String get eventEditOfflineNotice;

  /// 일정 편집 화면(event-edit): 일정 저장에 실패했다는 안내
  ///
  /// In ko, this message translates to:
  /// **'일정을 저장하지 못했어요. 다시 시도해 주세요.'**
  String get eventEditSaveFailed;

  /// glossary.value_name: direction8.n
  ///
  /// In ko, this message translates to:
  /// **'북'**
  String get direction8N;

  /// glossary.value_name: direction8.ne
  ///
  /// In ko, this message translates to:
  /// **'북동'**
  String get direction8Ne;

  /// glossary.value_name: direction8.e
  ///
  /// In ko, this message translates to:
  /// **'동'**
  String get direction8E;

  /// glossary.value_name: direction8.se
  ///
  /// In ko, this message translates to:
  /// **'남동'**
  String get direction8Se;

  /// glossary.value_name: direction8.s
  ///
  /// In ko, this message translates to:
  /// **'남'**
  String get direction8S;

  /// glossary.value_name: direction8.sw
  ///
  /// In ko, this message translates to:
  /// **'남서'**
  String get direction8Sw;

  /// glossary.value_name: direction8.w
  ///
  /// In ko, this message translates to:
  /// **'서'**
  String get direction8W;

  /// glossary.value_name: direction8.nw
  ///
  /// In ko, this message translates to:
  /// **'북서'**
  String get direction8Nw;

  /// birthplace.standard.link: 계산 기준 화면으로 가는 링크 이름
  ///
  /// In ko, this message translates to:
  /// **'계산 기준 보기'**
  String get birthplaceStandardLink;

  /// birthplace.standard.note: 명리일기가 한국에서 표준으로 쓰는 기준으로 계산한다는 소개. 한국에서 보편적으로 쓰는 해석이고 여러 유파 가운데 하나로서 근거가 있다고 설명합니다. 다른 유파와 우열을 말하지 않습니다(D71)
  ///
  /// In ko, this message translates to:
  /// **'명리일기는 한국에서 널리 쓰는 기준으로 계산해요. 여러 유파 가운데 하나로, 근거가 있는 방식입니다.'**
  String get birthplaceStandardNote;

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 {longitude} 기준으로 {minutes}분을 빼서 계산합니다. 진태양시는 쓰지 않습니다. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String calcBasisLongitudeBodySubtract(String longitude, int minutes);

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 {longitude} 기준으로 {minutes}분을 더해서 계산합니다. 진태양시는 쓰지 않습니다. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String calcBasisLongitudeBodyAdd(String longitude, int minutes);

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 {longitude} 기준이라 따로 보정하지 않고 계산합니다. 진태양시는 쓰지 않습니다. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String calcBasisLongitudeBodyNone(String longitude);

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'동경 {degrees}°'**
  String calcBasisLongitudeBodyEast(String degrees);

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'서경 {degrees}°'**
  String calcBasisLongitudeBodyWest(String degrees);

  /// calc-basis.schools.body: 다른 유파·나라 관례와 다른 점: 지장간을 모두 표시, 자시 통합(D6). 다르게 나올 수 있는 이유로 설명합니다(D71)
  ///
  /// In ko, this message translates to:
  /// **'지장간은 하나만 고르지 않고 모두 보여 드려요. 자시에 태어났다면 자정 전이라도 다음 날로 계산합니다. 유파마다 처리가 달라서 다른 앱이나 책과 결과가 다를 수 있어요.'**
  String get calcBasisSchoolsBody;

  /// account-delete.bar.title: app-bar 제목(화면 이름 "계정 삭제")
  ///
  /// In ko, this message translates to:
  /// **'계정 삭제'**
  String get accountDeleteBarTitle;

  /// ad-free.bar.title: app-bar 제목(화면 이름 "광고 제거")
  ///
  /// In ko, this message translates to:
  /// **'광고 제거'**
  String get adFreeBarTitle;

  /// birthplace.bar.title: app-bar 제목(화면 이름 "출생지")
  ///
  /// In ko, this message translates to:
  /// **'출생지'**
  String get birthplaceBarTitle;

  /// calc-basis.bar.title: app-bar 제목(화면 이름 "계산 기준")
  ///
  /// In ko, this message translates to:
  /// **'계산 기준'**
  String get calcBasisBarTitle;

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 서머타임 {dstMinutes}분을 먼저 빼고, {longitude} 기준으로 {minutes}분을 더 빼서 계산합니다. 진태양시는 쓰지 않습니다. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String calcBasisLongitudeBodyDstSubtract(
    String longitude,
    int minutes,
    int dstMinutes,
  );

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 서머타임 {dstMinutes}분을 먼저 빼고, {longitude} 기준으로 {minutes}분을 더해서 계산합니다. 진태양시는 쓰지 않습니다. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String calcBasisLongitudeBodyDstAdd(
    String longitude,
    int minutes,
    int dstMinutes,
  );

  /// calc-basis.longitude.body: 출생 시간대의 기준 경도로 출생 시각을 보정한다는 안내. 기준 경도와 보정 분은 출생 시간대·도시에서 받습니다(한국 127.5° −30분, 일본 135° 보정 없음. D42·D71), 진태양시 미적용
  ///
  /// In ko, this message translates to:
  /// **'출생 시각은 서머타임 {dstMinutes}분만 빼고 계산합니다. {longitude} 기준이라 경도 보정은 따로 하지 않습니다. 진태양시는 쓰지 않습니다. 그래서 시가 바뀌는 경계 몇 분 안에 태어났다면 다른 만세력 앱과 시주가 다를 수 있어요.'**
  String calcBasisLongitudeBodyDstNone(String longitude, int dstMinutes);

  /// consent.bar.title: app-bar 제목(화면 이름 "약관 동의")
  ///
  /// In ko, this message translates to:
  /// **'약관 동의'**
  String get consentBarTitle;

  /// diary-edit.bar.title: app-bar 제목(화면 이름 "일기 쓰기")
  ///
  /// In ko, this message translates to:
  /// **'일기 쓰기'**
  String get diaryEditBarTitle;

  /// diary-list.bar.title: app-bar 제목(화면 이름 "일기 목록")
  ///
  /// In ko, this message translates to:
  /// **'일기'**
  String get diaryListBarTitle;

  /// diary-view.bar.title: app-bar 제목. 일기 날짜를 넣는 틀입니다(매개변수 date)
  ///
  /// In ko, this message translates to:
  /// **'{date}의 일기'**
  String diaryViewBarTitle(String date);

  /// legal.bar.title: app-bar 제목(화면 이름 "약관·정책")
  ///
  /// In ko, this message translates to:
  /// **'약관과 정책'**
  String get legalBarTitle;

  /// login.bar.title: app-bar 제목(화면 이름 "로그인")
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get loginBarTitle;

  /// my-saju.bar.title: app-bar 제목(화면 이름 "나의 사주")
  ///
  /// In ko, this message translates to:
  /// **'나의 사주'**
  String get mySajuBarTitle;

  /// notify-ask.bar.title: app-bar 제목(화면 이름 "알림 허락")
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get notifyAskBarTitle;

  /// onboard-birth.bar.title: app-bar 제목(화면 이름 "생일")
  ///
  /// In ko, this message translates to:
  /// **'생일'**
  String get onboardBirthBarTitle;

  /// onboard-call.bar.title: app-bar 제목(화면 이름 "호칭")
  ///
  /// In ko, this message translates to:
  /// **'호칭'**
  String get onboardCallBarTitle;

  /// onboard-gender.bar.title: app-bar 제목(화면 이름 "성별")
  ///
  /// In ko, this message translates to:
  /// **'성별'**
  String get onboardGenderBarTitle;

  /// onboard-time.bar.title: app-bar 제목(화면 이름 "태어난 시간")
  ///
  /// In ko, this message translates to:
  /// **'태어난 시간'**
  String get onboardTimeBarTitle;

  /// preview.bar.title: app-bar 제목(화면 이름 "첫 풀이")
  ///
  /// In ko, this message translates to:
  /// **'첫 풀이'**
  String get previewBarTitle;

  /// profile-edit.bar.title: app-bar 제목(화면 이름 "정보 수정")
  ///
  /// In ko, this message translates to:
  /// **'정보 수정'**
  String get profileEditBarTitle;

  /// saju-chart.bar.title: app-bar 제목(화면 이름 "사주 표")
  ///
  /// In ko, this message translates to:
  /// **'사주 표'**
  String get sajuChartBarTitle;

  /// settings.bar.title: app-bar 제목(화면 이름 "설정")
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsBarTitle;

  /// tag-diary.bar.title: app-bar 제목. 고른 태그 이름을 넣는 틀입니다(매개변수 tag)
  ///
  /// In ko, this message translates to:
  /// **'{tag} 태그'**
  String tagDiaryBarTitle(String tag);

  /// today.bar.title: app-bar 제목(화면 이름 "오늘")
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get todayBarTitle;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'반응을 남길 문장을 찾지 못했어요. 화면을 새로 고쳐 주세요.'**
  String get errorReactionNotFound;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'일정을 찾지 못했어요. 목록을 새로 고쳐 주세요.'**
  String get errorScheduleNotFound;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'한 번에 볼 수 있는 기간을 넘었어요. 기간을 줄여 주세요.'**
  String get errorRangeTooLong;

  /// 일기 쓰기 화면(diary-edit): 상단 바 오른쪽 저장 글자 버튼(app-bar textAction, DS1 V82, V94). 누르면 diary-view로 갑니다(#275)
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get diaryEditSave;

  /// 일기 보기 화면(diary-view) app-bar의 아이콘 버튼 접근성 라벨(#275, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'일기 고치기'**
  String get diaryViewEditAction;

  /// 일기 보기 화면(diary-view) app-bar의 아이콘 버튼 접근성 라벨(#275, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'일기 지우기'**
  String get diaryViewDeleteAction;

  /// 일기 보기 화면(diary-view): 일기를 지운 뒤 toast(#275)
  ///
  /// In ko, this message translates to:
  /// **'일기를 지웠어요.'**
  String get diaryViewDeleted;

  /// 일기 목록 화면(diary-list) 날짜 시트(date-picker calendar)의 아래 버튼. 누르면 그날 새 일기 diary-edit로 갑니다(#294, D83 ③)
  ///
  /// In ko, this message translates to:
  /// **'{date} 일기 쓰기'**
  String diaryListPickDateConfirm(String date);

  /// 달력 날짜 칸(day-cell) 음력 줄: 윤달 초하루 표지(#260, design V38). 평달 초하루 `M.1`·절기 이름·일(日)은 app이 숫자로 그립니다
  ///
  /// In ko, this message translates to:
  /// **'윤{month}.1'**
  String dayCellLeapNewMoon(int month);

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'출생지 도시를 찾지 못했어요. 도시를 다시 골라 주세요.'**
  String get errorCityNotFound;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'시간대를 확인하지 못했어요. 기기의 시간대 설정을 확인해 주세요.'**
  String get errorTimezoneInvalid;

  /// 설정 화면(settings): settings-row 줄 이름(알림 시각, 언어, 문의하기, 로그아웃)과 알림을 끈 값
  ///
  /// In ko, this message translates to:
  /// **'알림 시각'**
  String get settingsNotifyLabel;

  /// 설정 화면(settings): settings-row 줄 이름(알림 시각, 언어, 문의하기, 로그아웃)과 알림을 끈 값
  ///
  /// In ko, this message translates to:
  /// **'꺼짐'**
  String get settingsNotifyOff;

  /// 설정 화면(settings): settings-row 줄 이름(알림 시각, 언어, 문의하기, 로그아웃)과 알림을 끈 값
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsLanguageLabel;

  /// 설정 화면(settings): settings-row 줄 이름(알림 시각, 언어, 문의하기, 로그아웃)과 알림을 끈 값
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get settingsLogoutLabel;

  /// 정보 수정 화면(profile-edit): 출생지를 묻지 않았거나 건너뛰었을 때 출생지 줄의 값
  ///
  /// In ko, this message translates to:
  /// **'한국 기준'**
  String get profileEditBirthplaceKorea;

  /// 사주 표 화면(saju-chart): 위쪽 segmented 두 칸(원국표, 오행 분포, 용신 판정 근거 / 만세력 표, 대운, 세운)
  ///
  /// In ko, this message translates to:
  /// **'원국'**
  String get sajuChartTabNatal;

  /// 사주 표 화면(saju-chart): 위쪽 segmented 두 칸(원국표, 오행 분포, 용신 판정 근거 / 만세력 표, 대운, 세운)
  ///
  /// In ko, this message translates to:
  /// **'만세력과 대운'**
  String get sajuChartTabLuck;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'시주'**
  String get sajuPillarHour;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'일주'**
  String get sajuPillarDay;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'월주'**
  String get sajuPillarMonth;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'연주'**
  String get sajuPillarYear;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'지장간'**
  String get manseRowHiddenStems;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'12운성'**
  String get manseRowTwelveStages;

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'신살'**
  String get manseRowShinsal;

  /// saju-pillars, daeun-table: 칸 꼬리표(일간 칸의 나, 지금 대운, 올해 세운)
  ///
  /// In ko, this message translates to:
  /// **'나'**
  String get sajuTagMe;

  /// saju-pillars, daeun-table: 칸 꼬리표(일간 칸의 나, 지금 대운, 올해 세운)
  ///
  /// In ko, this message translates to:
  /// **'지금'**
  String get daeunTagNow;

  /// saju-pillars, daeun-table: 칸 꼬리표(일간 칸의 나, 지금 대운, 올해 세운)
  ///
  /// In ko, this message translates to:
  /// **'올해'**
  String get seunTagThisYear;

  /// saju-pillars, manse-table, daeun-table, ohaeng-bar: 스크린리더 표 이름과 항목
  ///
  /// In ko, this message translates to:
  /// **'대운 {age}세부터'**
  String daeunTableLabel(int age);

  /// saju-pillars, manse-table, daeun-table, ohaeng-bar: 스크린리더 표 이름과 항목
  ///
  /// In ko, this message translates to:
  /// **'{element} {weight}'**
  String ohaengBarItem(String element, String weight);

  /// saju-pillars, manse-table: 열 머리(시주, 일주, 월주, 연주), 행 머리(지장간, 12운성, 신살), 일주 천간 위 일간 라벨
  ///
  /// In ko, this message translates to:
  /// **'일간'**
  String get sajuPillarDayMaster;

  /// saju-pillars, manse-table, daeun-table, ohaeng-bar: 스크린리더 표 이름과 항목
  ///
  /// In ko, this message translates to:
  /// **'원국표'**
  String get sajuPillarsTableLabel;

  /// saju-pillars, manse-table, daeun-table, ohaeng-bar: 스크린리더 표 이름과 항목
  ///
  /// In ko, this message translates to:
  /// **'만세력 표'**
  String get manseTableLabel;

  /// 근거 시트(evidence-sheet): 사주 표 칸에서 열었는데 그 자리의 원국 개인 해석(personal.*)이 없을 때
  ///
  /// In ko, this message translates to:
  /// **'이 자리는 따로 풀이한 내용이 없어요.'**
  String get evidenceSheetPersonalEmpty;

  /// saju-pillars, manse-table, daeun-table, ohaeng-bar: 스크린리더 표 이름과 항목
  ///
  /// In ko, this message translates to:
  /// **'{year}년'**
  String luckYearLabel(int year);

  /// 약관과 정책 화면(legal): 문서 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'이용약관'**
  String get legalTermsLabel;

  /// 약관과 정책 화면(legal): 문서 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'개인정보 처리방침'**
  String get legalPrivacyLabel;

  /// 약관과 정책 화면(legal): 문서 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get legalLicensesLabel;

  /// account-merge.bar.title: app-bar 제목(화면 이름 "계정 합치기")
  ///
  /// In ko, this message translates to:
  /// **'계정 합치기'**
  String get accountMergeBarTitle;

  /// account-merge.choice.label: 프로필(사주 정보·호칭·설정)을 어느 계정 것으로 둘지 고르라는 안내. 남는 계정은 언제나 지금 계정
  ///
  /// In ko, this message translates to:
  /// **'어느 계정의 사주 정보를 쓸까요?'**
  String get accountMergeChoiceLabel;

  /// account-merge.cta.merge: 합치기 버튼
  ///
  /// In ko, this message translates to:
  /// **'계정 합치기'**
  String get accountMergeCtaMerge;

  /// account-merge.merge.confirm: 최종 확인(되돌릴 수 없음)
  ///
  /// In ko, this message translates to:
  /// **'두 계정을 합칠까요? 합친 뒤에는 되돌릴 수 없습니다.'**
  String get accountMergeMergeConfirm;

  /// account-merge.merge.confirm: 최종 확인(되돌릴 수 없음)
  ///
  /// In ko, this message translates to:
  /// **'합치기'**
  String get accountMergeMergeConfirmMerge;

  /// account-merge.merge.confirm: 최종 확인(되돌릴 수 없음)
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get accountMergeMergeConfirmCancel;

  /// account-merge.overlap.notice: 같은 날 일기가 겹쳐도 지우지 않고 모두 옮긴다는 안내(겹치는 날이 있을 때)
  ///
  /// In ko, this message translates to:
  /// **'같은 날 쓴 일기도 모두 이 계정으로 옮겨요.'**
  String get accountMergeOverlapNotice;

  /// account-merge.title.body: 합치면 무엇이 옮겨지고 무엇이 지워지는지 설명(합칠 계정의 기록과 구매는 이 계정으로, 프로필은 고른 쪽, 합칠 계정과 그 인증 수단은 지워짐, 용어는 D85 ①). 옮길 기록이 0건이어도 보임. 가져올 기록은 일기 편수·일정 개수(0이어도)와 광고 제거 남은 기간(남았을 때만)으로 보임
  ///
  /// In ko, this message translates to:
  /// **'가져올 계정의 기록은 모두 이 계정으로 옮겨요. 사주 정보, 호칭, 설정은 고른 쪽 것을 쓰고, 가져올 계정과 그 인증 수단은 지워집니다. 구매도 이 계정으로 옮겨요.'**
  String get accountMergeTitleBody;

  /// account-merge.title.head: 다른 계정의 기록을 이 계정으로 가져와 합친다는 제목
  ///
  /// In ko, this message translates to:
  /// **'다른 계정의 기록을 이 계정으로 가져올까요?'**
  String get accountMergeTitleHead;

  /// day-sheet.diary.write-cta: 일기 쓰기 버튼 "<날짜> 일기 쓰기" 틀(매개변수 date, 예: 11월 9일 일기 쓰기). 지난 날과 오늘. 이미 쓴 날이면 한 편 더 쓰기, 10편을 채웠으면 누를 수 없고 더 쓸 수 없다는 문구(D83 ②)
  ///
  /// In ko, this message translates to:
  /// **'{date} 새 일기 쓰기'**
  String daySheetDiaryWriteCtaWritten(String date);

  /// day-sheet.diary.write-cta: 일기 쓰기 버튼 "<날짜> 일기 쓰기" 틀(매개변수 date, 예: 11월 9일 일기 쓰기). 지난 날과 오늘. 이미 쓴 날이면 한 편 더 쓰기, 10편을 채웠으면 누를 수 없고 더 쓸 수 없다는 문구(D83 ②)
  ///
  /// In ko, this message translates to:
  /// **'이날은 충분히 썼어요'**
  String get daySheetDiaryWriteCtaFull;

  /// login-methods.bar.title: app-bar 제목(화면 이름 "로그인 수단")
  ///
  /// In ko, this message translates to:
  /// **'로그인 수단'**
  String get loginMethodsBarTitle;

  /// login-methods.error.body: 연결·떼기를 끝내지 못했을 때의 안내(인증 창을 닫음 포함)
  ///
  /// In ko, this message translates to:
  /// **'연결하지 못했어요. 다시 시도해 주세요.'**
  String get loginMethodsErrorBodyLink;

  /// login-methods.error.body: 연결·떼기를 끝내지 못했을 때의 안내(인증 창을 닫음 포함)
  ///
  /// In ko, this message translates to:
  /// **'연결을 끊지 못했어요. 다시 시도해 주세요.'**
  String get loginMethodsErrorBodyUnlink;

  /// login-methods.intro.body: 연결한 수단 어느 것으로 로그인해도 같은 계정이라는 설명
  ///
  /// In ko, this message translates to:
  /// **'여러 인증 수단을 연결해 두면 어느 것으로든 이 계정에 로그인할 수 있어요.'**
  String get loginMethodsIntroBody;

  /// login-methods.last.notice: 마지막 남은 수단은 뗄 수 없다는 안내
  ///
  /// In ko, this message translates to:
  /// **'인증 수단이 하나는 남아 있어야 해요.'**
  String get loginMethodsLastNotice;

  /// login-methods.unlink.confirm: 떼기 확인
  ///
  /// In ko, this message translates to:
  /// **'{provider} 연결을 끊을까요?'**
  String loginMethodsUnlinkConfirm(String provider);

  /// login-methods.unlink.confirm: 떼기 확인
  ///
  /// In ko, this message translates to:
  /// **'연결한 다른 인증 수단으로 계속 로그인할 수 있어요.'**
  String get loginMethodsUnlinkConfirmBody;

  /// login-methods.unlink.confirm: 떼기 확인
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기'**
  String get loginMethodsUnlinkConfirmUnlink;

  /// login-methods.unlink.confirm: 떼기 확인
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get loginMethodsUnlinkConfirmCancel;

  /// today.guide.cta: 일기 쓰기 버튼(언제나 새 일기. 오늘 이미 썼으면 한 편 더 쓰기, 10편을 채웠으면 누를 수 없고 더 쓸 수 없다는 문구, D83 ②)
  ///
  /// In ko, this message translates to:
  /// **'오늘은 충분히 썼어요'**
  String get todayGuideCtaFull;

  /// 계정 합치기 화면(account-merge) account-choice: 카드 알약(지금 계정 `Current`, 가져올 계정 `Other`)
  ///
  /// In ko, this message translates to:
  /// **'현재 계정'**
  String get accountChoiceCurrent;

  /// 계정 합치기 화면(account-merge) 오류 상태: 합치기 실패. 고른 계정을 둔 채 다시 누를 수 있게 dialog notice로 보입니다(design #441)
  ///
  /// In ko, this message translates to:
  /// **'계정을 합치지 못했어요. 두 계정 모두 그대로 있어요. 다시 시도해 주세요.'**
  String get accountMergeError;

  /// 계정 합치기 화면(account-merge) account-choice: 카드의 사주 요약 줄(design #441)
  ///
  /// In ko, this message translates to:
  /// **'{calendar} {date} {time}'**
  String accountChoiceSaju(String date, String calendar, String time);

  /// 계정 합치기 화면(account-merge) account-choice: 카드의 사주 요약 줄(design #441)
  ///
  /// In ko, this message translates to:
  /// **'{calendar} {date} 시각 모름'**
  String accountChoiceSajuNoTime(String date, String calendar);

  /// 계정 합치기 화면(account-merge) account-choice: 카드의 사주 요약 줄(design #441)
  ///
  /// In ko, this message translates to:
  /// **'사주 정보 없음'**
  String get accountChoiceSajuEmpty;

  /// 일기 목록 화면(diary-list) 날짜 시트(date-picker calendar)의 아래 버튼. 누르면 그날 새 일기 diary-edit로 갑니다(#294, D83 ③)
  ///
  /// In ko, this message translates to:
  /// **'이날은 충분히 썼어요'**
  String get diaryListPickDateConfirmFull;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'이날은 충분히 썼어요.'**
  String get errorDiaryDayFull;

  /// 로그인 수단 화면(login-methods) social-login-button connected 상태: 제공자 이름과 연결됨 표시, 떼기 스크린리더 힌트(design V39). 연결하지 않은 수단은 로그인 라벨(ui.login.provider)을 그대로 씁니다
  ///
  /// In ko, this message translates to:
  /// **'카카오'**
  String get loginProviderKakao;

  /// 로그인 수단 화면(login-methods) social-login-button connected 상태: 제공자 이름과 연결됨 표시, 떼기 스크린리더 힌트(design V39). 연결하지 않은 수단은 로그인 라벨(ui.login.provider)을 그대로 씁니다
  ///
  /// In ko, this message translates to:
  /// **'LINE'**
  String get loginProviderLine;

  /// 로그인 수단 화면(login-methods) social-login-button connected 상태: 제공자 이름과 연결됨 표시, 떼기 스크린리더 힌트(design V39). 연결하지 않은 수단은 로그인 라벨(ui.login.provider)을 그대로 씁니다
  ///
  /// In ko, this message translates to:
  /// **'Google'**
  String get loginProviderGoogle;

  /// 로그인 수단 화면(login-methods) social-login-button connected 상태: 제공자 이름과 연결됨 표시, 떼기 스크린리더 힌트(design V39). 연결하지 않은 수단은 로그인 라벨(ui.login.provider)을 그대로 씁니다
  ///
  /// In ko, this message translates to:
  /// **'Apple'**
  String get loginProviderApple;

  /// 로그인 수단 화면(login-methods) social-login-button connected 상태: 제공자 이름과 연결됨 표시, 떼기 스크린리더 힌트(design V39). 연결하지 않은 수단은 로그인 라벨(ui.login.provider)을 그대로 씁니다
  ///
  /// In ko, this message translates to:
  /// **'연결됨'**
  String get loginMethodsRowConnected;

  /// 로그인 수단 화면(login-methods) social-login-button connected 상태: 제공자 이름과 연결됨 표시, 떼기 스크린리더 힌트(design V39). 연결하지 않은 수단은 로그인 라벨(ui.login.provider)을 그대로 씁니다
  ///
  /// In ko, this message translates to:
  /// **'연결 끊기'**
  String get loginMethodsRowUnlink;

  /// 소셜 로그인 버튼 글자. 제공자 가이드 문구를 그대로 씁니다(카카오 로그인 디자인 가이드, Sign in with Apple HIG, LINE Login button design guidelines, Sign in with Google branding guidelines)
  ///
  /// In ko, this message translates to:
  /// **'LINE으로 로그인'**
  String get loginLineLabel;

  /// 소셜 로그인 버튼 글자. 제공자 가이드 문구를 그대로 씁니다(카카오 로그인 디자인 가이드, Sign in with Apple HIG, LINE Login button design guidelines, Sign in with Google branding guidelines)
  ///
  /// In ko, this message translates to:
  /// **'Google 계정으로 로그인'**
  String get loginGoogleLabel;

  /// 설정 화면(settings) settings-row: 로그인 수단 화면으로 가는 줄 이름
  ///
  /// In ko, this message translates to:
  /// **'로그인 수단'**
  String get settingsLoginMethodsLabel;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'연결된 인증 수단을 찾지 못했어요. 화면을 다시 열어 주세요.'**
  String get errorAuthIdentityNotFound;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'같은 인증 수단으로 연결한 다른 계정이 이미 있어요.'**
  String get errorAuthProviderTaken;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'다른 계정에 연결된 인증 수단이에요.'**
  String get errorAuthIdentityInUse;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'인증 수단이 하나는 남아 있어야 해요.'**
  String get errorAuthLastIdentity;

  /// account-merge.auth.body: 합칠 계정에 연결된 인증 수단으로 로그인하라는 안내
  ///
  /// In ko, this message translates to:
  /// **'기록을 가져올 계정을 인증해 주세요.'**
  String get accountMergeAuthBody;

  /// account-merge.not-other.body: 인증한 수단이 이 계정 것이면 합칠 계정의 인증 수단으로 다시 로그인하라는 안내, 어느 계정에도 연결돼 있지 않으면 합칠 계정이 없다는 안내(D85 ④)
  ///
  /// In ko, this message translates to:
  /// **'지금 계정의 인증 수단으로 로그인했어요. 가져올 계정의 인증 수단으로 다시 로그인해 주세요.'**
  String get accountMergeNotOtherBodySelf;

  /// account-merge.not-other.body: 인증한 수단이 이 계정 것이면 합칠 계정의 인증 수단으로 다시 로그인하라는 안내, 어느 계정에도 연결돼 있지 않으면 합칠 계정이 없다는 안내(D85 ④)
  ///
  /// In ko, this message translates to:
  /// **'이 인증 수단에 연결된 계정이 없어요.'**
  String get accountMergeNotOtherBodyNone;

  /// ad-free.history.cta: 구매 내역으로 가는 버튼(D88 ②)
  ///
  /// In ko, this message translates to:
  /// **'구매 내역'**
  String get adFreeHistoryCta;

  /// calc-basis.daeun.body: 대운수는 개월을 버려 센다는 안내(core C5, D86 ⑦). 다른 앱과의 차이는 말하지 않음
  ///
  /// In ko, this message translates to:
  /// **'대운수는 개월을 버리고 계산합니다.'**
  String get calcBasisDaeunBody;

  /// login-methods.in-use.body: 붙이려는 인증 수단이 다른 계정에 연결돼 있어 연결할 수 없다는 안내와, 그 계정에서 먼저 연결을 끊으라는 안내. 합치기 길은 같은 화면의 `merge.cta`가 맡음(D85 ③)
  ///
  /// In ko, this message translates to:
  /// **'이미 다른 계정에서 쓰는 인증 수단이에요. 그 계정에서 연결을 끊은 뒤 다시 연결해 주세요.'**
  String get loginMethodsInUseBody;

  /// login-methods.merge.cta: 계정 합치기로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'다른 계정의 기록 가져오기'**
  String get loginMethodsMergeCta;

  /// preview.restart.notice: 다시 입력할 때, 미리보기는 한 번이라 고친 정보로 이어 보려면 로그인을 권하는 안내. 막는다는 말보다 권하는 말(D86 ⑤)
  ///
  /// In ko, this message translates to:
  /// **'다시 입력한 정보로 풀이를 보려면 로그인해 보세요.'**
  String get previewRestartNotice;

  /// purchase-history.bar.title: app-bar 제목(화면 이름 "구매 내역")
  ///
  /// In ko, this message translates to:
  /// **'구매 내역'**
  String get purchaseHistoryBarTitle;

  /// purchase-history.empty.body: 구매가 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'구매 내역이 없어요.'**
  String get purchaseHistoryEmptyBody;

  /// purchase-history.missing.notice: 결제했는데 목록에 없으면 문의하라는 안내
  ///
  /// In ko, this message translates to:
  /// **'결제한 상품이 보이지 않으면 문의하기로 알려 주세요.'**
  String get purchaseHistoryMissingNotice;

  /// 계정 합치기 화면(account-merge) account-choice: 카드 알약(지금 계정 `Current`, 가져올 계정 `Other`)
  ///
  /// In ko, this message translates to:
  /// **'가져올 계정'**
  String get accountChoiceOther;

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'가져올 기록'**
  String get accountMergeSummaryHead;

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'일기'**
  String get accountMergeSummaryDiary;

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'일정'**
  String get accountMergeSummaryEvent;

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'광고 제거 남은 기간'**
  String get accountMergeSummaryAdFree;

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}편}}'**
  String accountMergeSummaryDiaryCount(int count);

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개}}'**
  String accountMergeSummaryEventCount(int count);

  /// 계정 합치기 화면(account-merge) 요약·고르기 단계: "가져올 기록" 상자의 머리, 줄 이름, 값(design #509)
  ///
  /// In ko, this message translates to:
  /// **'{days, plural, other{{days}일}}'**
  String accountMergeSummaryAdFreeDays(int days);

  /// 구매 내역 화면(purchase-history) purchase-row: 구매일과 사용 기간 줄
  ///
  /// In ko, this message translates to:
  /// **'{date} 구매'**
  String purchaseMetaPurchased(String date);

  /// 구매 내역 화면(purchase-history) purchase-row: 구매일과 사용 기간 줄
  ///
  /// In ko, this message translates to:
  /// **'{start}~{end}'**
  String purchaseMetaPeriod(String start, String end);

  /// 구매 내역 화면(purchase-history) purchase-row: 상품 이름. 상품 종류마다 키 하나이고 app이 상품 id를 이 키에 잇습니다(상품 id는 저장소에 두지 않음, server S89). 키가 없는 상품은 스토어의 현지화된 이름을 씁니다(D88 ②)
  ///
  /// In ko, this message translates to:
  /// **'광고 제거 1개월'**
  String get purchaseProductAdFreeMonth;

  /// 구매 내역 화면(purchase-history) purchase-row: 상태 낱말(기간권)
  ///
  /// In ko, this message translates to:
  /// **'사용 중'**
  String get purchaseStatusActive;

  /// 구매 내역 화면(purchase-history) purchase-row: 상태 낱말(기간권)
  ///
  /// In ko, this message translates to:
  /// **'사용 전'**
  String get purchaseStatusPending;

  /// 구매 내역 화면(purchase-history) purchase-row: 상태 낱말(기간권)
  ///
  /// In ko, this message translates to:
  /// **'만료'**
  String get purchaseStatusExpired;

  /// 구매 내역 화면(purchase-history) purchase-row: 상태 낱말(기간권)
  ///
  /// In ko, this message translates to:
  /// **'환불'**
  String get purchaseStatusRefunded;

  /// 오류 상태·토스트: server 오류 코드(`server/api/openapi.yaml`)별 안내. 키 이름은 app이 오류 코드에서 만든 이름입니다
  ///
  /// In ko, this message translates to:
  /// **'계정 합치기를 이어 가지 못했어요. 가져올 계정을 다시 인증해 주세요.'**
  String get errorMergeTokenInvalid;

  /// ad-free.buy.cta: 광고 제거권 구매를 시작하는 주 버튼(출구 system-purchase, #548)
  ///
  /// In ko, this message translates to:
  /// **'구매하기'**
  String get adFreeBuyCta;

  /// ad-free.offer.period: 기간(1개월)과 자동 갱신 아님 고지. 가격 아래 작은 글씨이고 구매 버튼보다 위(D53, design offer-card)
  ///
  /// In ko, this message translates to:
  /// **'1개월, 자동 결제 없음'**
  String get adFreeOfferPeriod;

  /// force-update.notice.body: 업데이트해야 하는 이유
  ///
  /// In ko, this message translates to:
  /// **'새 약관을 확인하려면 업데이트가 필요해요.'**
  String get forceUpdateNoticeBodyConsent;

  /// system-push.channel.morning: Android 알림 채널 이름(기기 설정 > 앱 > 알림의 채널 목록, 채널 id `morning`). 사용자가 아침 알림만 끌 때 읽는 짧은 이름이고 앱 언어를 따름. iOS에는 채널이 없어 보이지 않음
  ///
  /// In ko, this message translates to:
  /// **'오늘 풀이 알림'**
  String get systemPushChannelMorning;

  /// 계정 합치기 화면(account-merge) account-choice: 카드의 사주 요약 줄(design #441)
  ///
  /// In ko, this message translates to:
  /// **'{calendar} 윤달 {date} {time}'**
  String accountChoiceSajuLeap(String date, String calendar, String time);

  /// 계정 합치기 화면(account-merge) account-choice: 카드의 사주 요약 줄(design #441)
  ///
  /// In ko, this message translates to:
  /// **'{calendar} 윤달 {date} 시각 모름'**
  String accountChoiceSajuNoTimeLeap(String date, String calendar);

  /// iOS 앱 추적 투명성(ATT) 시스템 창의 본문. 제목과 버튼은 iOS가 정하고, UMP IDFA 안내 다음에 나옵니다
  ///
  /// In ko, this message translates to:
  /// **'허용하면 광고를 관심사에 맞춰 보여 드려요. 허용하지 않아도 앱은 똑같이 쓸 수 있어요.'**
  String get iosTrackingUsageDescription;

  /// contact.address.note: 메일로 직접 보낼 수 있는 주소 안내(보내기를 못 쓸 때, E14)
  ///
  /// In ko, this message translates to:
  /// **'보내기가 안 되면 이 주소로 메일을 보내 주세요.\n{email}'**
  String contactAddressNote(String email);

  /// contact.attached.notice: 함께 보내는 정보 고지(계정 id, 앱 버전, 기기 정보, 사용자가 고칠 수 없고 문의 처리에만 씀)
  ///
  /// In ko, this message translates to:
  /// **'계정 id, 앱 버전, 기기 정보(OS, 기종)를 함께 보냅니다. 문의 처리에만 활용됩니다.'**
  String get contactAttachedNotice;

  /// contact.bar.title: app-bar 제목(화면 이름 "문의하기")
  ///
  /// In ko, this message translates to:
  /// **'문의하기'**
  String get contactBarTitle;

  /// contact.email.field: 답장 받을 메일 주소 입력 칸 이름과 안내(필수)
  ///
  /// In ko, this message translates to:
  /// **'답장 받을 메일'**
  String get contactEmailFieldLabel;

  /// contact.email.field: 답장 받을 메일 주소 입력 칸 이름과 안내(필수)
  ///
  /// In ko, this message translates to:
  /// **'name@example.com'**
  String get contactEmailFieldHint;

  /// contact.intro.body: 무엇을 쓰면 되는지와 답은 메일로 온다는 안내
  ///
  /// In ko, this message translates to:
  /// **'궁금한 점이나 불편한 점을 적어 주세요. 답은 적어 주신 메일로 보내 드려요.'**
  String get contactIntroBody;

  /// contact.message.field: 문의 내용 입력 칸 이름과 안내
  ///
  /// In ko, this message translates to:
  /// **'문의 내용'**
  String get contactMessageFieldLabel;

  /// contact.message.field: 문의 내용 입력 칸 이름과 안내
  ///
  /// In ko, this message translates to:
  /// **'언제, 어느 화면에서 있었던 일인지 함께 적어 주세요'**
  String get contactMessageFieldHint;

  /// contact.send.cta: 보내기 버튼
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get contactSendCta;

  /// contact.sent.toast: 보낸 뒤 결과
  ///
  /// In ko, this message translates to:
  /// **'문의를 보냈어요.'**
  String get contactSentToast;

  /// 문의 화면(contact): 보내기 실패(error 상태)와 메일 주소 형식 오류(IA 밖, #752)
  ///
  /// In ko, this message translates to:
  /// **'문의를 보내지 못했어요. 잠시 뒤 다시 보내 주세요.'**
  String get contactSendFailed;

  /// 문의 화면(contact): 보내기 실패(error 상태)와 메일 주소 형식 오류(IA 밖, #752)
  ///
  /// In ko, this message translates to:
  /// **'메일 주소를 다시 확인해 주세요.'**
  String get contactEmailInvalid;

  /// 설정 화면(settings): settings-row 줄 이름(알림 시각, 언어, 문의하기, 로그아웃)과 알림을 끈 값
  ///
  /// In ko, this message translates to:
  /// **'문의하기'**
  String get settingsContactLabel;

  /// calendar.legend.body: 범례 견본 셋의 이름: 아주 잘 풀리는 날(합한 점 3 이상), 잘 풀리는 날(2), 조심할 날. 무난한 날은 무색이라 범례 견본이 없음(DS1 관문 Q2 ①). 그날 시트 길흉판정 막대의 세 이름도 이 키
  ///
  /// In ko, this message translates to:
  /// **'아주 잘 풀리는 날'**
  String get calendarLegendBodyVeryGood;

  /// calendar.legend.body: 범례 견본 셋의 이름: 아주 잘 풀리는 날(합한 점 3 이상), 잘 풀리는 날(2), 조심할 날. 무난한 날은 무색이라 범례 견본이 없음(DS1 관문 Q2 ①). 그날 시트 길흉판정 막대의 세 이름도 이 키
  ///
  /// In ko, this message translates to:
  /// **'무난한 날'**
  String get calendarLegendBodyNeutral;

  /// calendar.legend.rule-link: 범례 끝 입구 "길흉은 어떻게 정해지나요". 누르면 색 규칙 시트(DS1 관문 Q2 ②)
  ///
  /// In ko, this message translates to:
  /// **'길흉은 어떻게 정해지나요'**
  String get calendarLegendRuleLink;

  /// color-rule-sheet.rule.body: 설명 문장(사용자 문구 바탕, writing 확정): 그 날에 들어오는 기운을 합산해서 정해요. 예를 들어 용신의 날이라도 부딪히는 기운이 있으면 무난한 날이 될 수 있어요
  ///
  /// In ko, this message translates to:
  /// **'그 날에 들어오는 기운을 합산해서 정해요. 예를 들어 용신의 날이라도 부딪히는 기운이 있으면 무난한 날이 될 수 있어요.'**
  String get colorRuleSheetRuleBody;

  /// color-rule-sheet.sheet.title: 시트 제목(문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'길흉을 정하는 방법'**
  String get colorRuleSheetSheetTitle;

  /// day-sheet.date.lunar: 머리의 음력 날짜 틀(매개변수 lunarDate, 예: 음력 10월 1일)
  ///
  /// In ko, this message translates to:
  /// **'음력 {month}월 {day}일'**
  String daySheetDateLunar(int month, int day);

  /// day-sheet.date.lunar: 머리의 음력 날짜 틀(매개변수 lunarDate, 예: 음력 10월 1일)
  ///
  /// In ko, this message translates to:
  /// **'음력 윤{month}월 {day}일'**
  String daySheetDateLunarLeap(int month, int day);

  /// day-sheet.date.solar: 머리의 날짜와 요일 틀(매개변수 date, 예: 11월 9일 월요일)
  ///
  /// In ko, this message translates to:
  /// **'{date}'**
  String daySheetDateSolar(String date);

  /// day-sheet.verdict.item: 내역 한 줄 틀: 한자 아이콘 태그, 짧은 뜻, 점과 더함 또는 뺌(예: 用 용신의 날, 점 둘, 더함). 숫자 대신 점, 한 줄 요약 문장 없음
  ///
  /// In ko, this message translates to:
  /// **'좋은 쪽으로 {count}'**
  String daySheetVerdictItemPlus(int count);

  /// day-sheet.verdict.item: 내역 한 줄 틀: 한자 아이콘 태그, 짧은 뜻, 점과 더함 또는 뺌(예: 用 용신의 날, 점 둘, 더함). 숫자 대신 점, 한 줄 요약 문장 없음
  ///
  /// In ko, this message translates to:
  /// **'조심할 쪽으로 {count}'**
  String daySheetVerdictItemMinus(int count);

  /// day-sheet.verdict.title: 섹션 제목 "길흉판정"(확정). 아래에 조심할 날, 무난한 날, 잘 풀리는 날 위의 위치 막대와 내역. 아래 막대의 세 이름(조심할 날, 무난한 날, 잘 풀리는 날)은 `calendar.legend.body`와 같은 키(DS1 관문 Q3)
  ///
  /// In ko, this message translates to:
  /// **'길흉판정'**
  String get daySheetVerdictTitle;

  /// diary-edit.date.day: 큰 날짜 블록의 일 숫자 틀(매개변수 date)
  ///
  /// In ko, this message translates to:
  /// **'{date}'**
  String diaryEditDateDay(String date);

  /// diary-edit.date.iljin: 큰 날짜 블록의 일진 틀(매개변수 pillar), 일 숫자 아래
  ///
  /// In ko, this message translates to:
  /// **'{pillar}일'**
  String diaryEditDateIljin(String pillar);

  /// diary-edit.date.month: 큰 날짜 블록의 월과 요일 틀(매개변수 date), 일 숫자 옆
  ///
  /// In ko, this message translates to:
  /// **'{date}'**
  String diaryEditDateMonth(String date);

  /// diary-edit.length.count: 글자 수 틀(매개변수 count). 임시 저장 상태와 함께 상단 바 가운데에 작게, 쓰는 중에만
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}자}}'**
  String diaryEditLengthCount(int count);

  /// explain-sheet.tag.diary-link: 대표 태그 뜻 시트에만 두는 꺾쇠 링크: 그 태그가 붙은 내 일기 보기(매개변수 tag). 누르면 tag-diary, 일기가 없으면 tag-diary 빈 상태(V73, V81, 문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'{tag} 태그가 붙은 내 일기 보기'**
  String explainSheetTagDiaryLink(String tag);

  /// login.save.note: 첫 풀이(preview)를 거쳐 온 경우에만 보이는 덧붙임 문구: 지금 본 풀이를 계속 저장하려면 로그인한다는 안내. 거치지 않고 오면(이미 계정이 있어요 등) 보이지 않음(D111, 검수 F-029)
  ///
  /// In ko, this message translates to:
  /// **'로그인하시면 방금 본 풀이를 이어서 볼 수 있어요.'**
  String get loginSaveNote;

  /// my-saju.chart.link: 사주 원국 섹션의 "사주 표" 이동(오른쪽 꺾쇠). 누르면 사주 표
  ///
  /// In ko, this message translates to:
  /// **'사주 표'**
  String get mySajuChartLink;

  /// my-saju.chart.title: 섹션 제목 "사주 원국"(사용자가 정한 문구). 아래에 네 기둥(천간, 지지, 위아래 십성, 일간 표시)과 오행 분포
  ///
  /// In ko, this message translates to:
  /// **'사주 원국'**
  String get mySajuChartTitle;

  /// my-saju.flow.link: 올해와 지금 섹션의 "대운 전체" 이동(오른쪽 꺾쇠). 누르면 사주 표의 만세력과 대운 탭
  ///
  /// In ko, this message translates to:
  /// **'대운 전체'**
  String get mySajuFlowLink;

  /// my-saju.flow.title: 섹션 제목 "올해와 지금"(사용자가 정한 문구). 아래에 지금 대운과 올해 세운의 기둥과 십성 칩(누르면 용어 풀이). 흐름 설명 문장은 T1 뒤
  ///
  /// In ko, this message translates to:
  /// **'올해와 지금'**
  String get mySajuFlowTitle;

  /// my-saju.ilgan.title: 섹션 제목 "사주 성향 풀이"(사용자가 정한 문구)
  ///
  /// In ko, this message translates to:
  /// **'사주 성향 풀이'**
  String get mySajuIlganTitle;

  /// my-saju.record.few: 기록이 적을 때 명리일기 회고 자리의 안내
  ///
  /// In ko, this message translates to:
  /// **'일기가 몇 편 더 쌓이면 내 기록을 돌아볼 수 있어요.'**
  String get mySajuRecordFew;

  /// my-saju.record.title: 섹션 제목 "명리일기 회고"(사용자가 정한 문구). 아래에 기록 요약(server `getDiaryStats`, REST 1.9.0, S146: 쓴 편수, 날의 성격별로 일기가 있는 날짜 수, 대표 태그 기준 날짜 수가 많은 태그 최대 셋)
  ///
  /// In ko, this message translates to:
  /// **'명리일기 회고'**
  String get mySajuRecordTitle;

  /// my-saju.yongsin.title: 섹션 제목 "나를 돕는 기운"(사용자가 정한 문구). 아래에 용신, 행운 색, 용신 문장
  ///
  /// In ko, this message translates to:
  /// **'나를 돕는 기운'**
  String get mySajuYongsinTitle;

  /// notify-ask.time.note: 시각 고르기 아래 안내: 고른 시각부터 10분 안에 도착(D109, 문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'상황에 따라 알림이 최대 10분 지연될 수 있어요.'**
  String get notifyAskTimeNote;

  /// saju-chart.daeun.desc: 대운 섹션 제목 아래 한 줄 설명(늘 보임)
  ///
  /// In ko, this message translates to:
  /// **'10년마다 바뀌는 큰 흐름이에요.'**
  String get sajuChartDaeunDesc;

  /// saju-chart.daeun.title: 만세력과 대운 탭 섹션 제목 "대운"
  ///
  /// In ko, this message translates to:
  /// **'대운'**
  String get sajuChartDaeunTitle;

  /// saju-chart.head.title: 두 탭 공통 머리 "<호칭>님의 사주" 틀, 호칭 자리. 아래에 출생 정보 줄(달력 종류 꼬리표와 날짜, 시진 한자 태그와 시간, 성별 알약)
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님의 사주'**
  String sajuChartHeadTitle(String nickname);

  /// saju-chart.jijanggan.desc: 지장간 한 줄 설명. 띠 안에 두지 않고 띠 이름 용어 칩을 누르면 여는 설명 시트의 본문
  ///
  /// In ko, this message translates to:
  /// **'지지 속에 숨어 있는 천간이에요. 겉으로 보이지 않아도 그 자리의 기운을 구성해요.'**
  String get sajuChartJijangganDesc;

  /// saju-chart.manse.basis: 만세력과 대운 탭 위 "내 일간 <간>(<이름>) 기준" 틀(매개변수 stem)
  ///
  /// In ko, this message translates to:
  /// **'내 일간 {stem} 기준'**
  String sajuChartManseBasis(String stem);

  /// saju-chart.ohaeng.desc: 오행 분포 섹션 제목 아래 한 줄 설명(늘 보임)
  ///
  /// In ko, this message translates to:
  /// **'내 사주에 나무, 불, 흙, 쇠, 물 기운이 얼마나 있는지를 보여 줘요.'**
  String get sajuChartOhaengDesc;

  /// saju-chart.ohaeng.title: 원국 탭 섹션 제목 "오행 분포"
  ///
  /// In ko, this message translates to:
  /// **'오행 분포'**
  String get sajuChartOhaengTitle;

  /// saju-chart.pillars.desc: 사주 섹션 제목 아래 한 줄 설명(늘 보임)
  ///
  /// In ko, this message translates to:
  /// **'태어난 연, 월, 일, 시를 천간과 지지 한 쌍으로 나타낸 것이에요. 일간이 \'나\'예요.'**
  String get sajuChartPillarsDesc;

  /// saju-chart.pillars.title: 원국 탭 섹션 제목 "사주"("네 기둥" 아님)
  ///
  /// In ko, this message translates to:
  /// **'사주'**
  String get sajuChartPillarsTitle;

  /// saju-chart.seun.desc: 세운 섹션 제목 아래 한 줄 설명(늘 보임)
  ///
  /// In ko, this message translates to:
  /// **'해마다 들어오는 기운이에요.'**
  String get sajuChartSeunDesc;

  /// saju-chart.seun.title: 만세력과 대운 탭 섹션 제목 "세운"
  ///
  /// In ko, this message translates to:
  /// **'세운'**
  String get sajuChartSeunTitle;

  /// saju-chart.sinsal.desc: 신살 한 줄 설명. 띠 이름 용어 칩을 누르면 여는 설명 시트의 본문. 신살이 없는 자리는 비움 표시
  ///
  /// In ko, this message translates to:
  /// **'특정 글자의 조합으로 생기는 고유 성질이에요. 없는 경우도 있어요.'**
  String get sajuChartSinsalDesc;

  /// saju-chart.unseong.desc: 12운성 한 줄 설명. 띠 이름 용어 칩을 누르면 여는 설명 시트의 본문이고, 시트 안에 12단계 선형 띠와 내 네 자리(시, 일, 월, 연)
  ///
  /// In ko, this message translates to:
  /// **'일간의 기운이 그 자리에서 얼마나 힘을 쓰는지 열두 단계로 나타냅니다.'**
  String get sajuChartUnseongDesc;

  /// settings.notify-time.note: 알림 시각 고르기(시트) 안의 안내: 고른 시각부터 10분 안에 도착(D109, 문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'상황에 따라 알림이 최대 10분 지연될 수 있어요.'**
  String get settingsNotifyTimeNote;

  /// tag-sheet.diary.cta: 그 태그가 붙은 내 일기 보기 링크. 편수 없이 늘 보이고, 일기가 없으면 tag-diary 빈 상태가 맡음(V79, DS1 관문)
  ///
  /// In ko, this message translates to:
  /// **'{tag} 태그가 붙은 내 일기 보기'**
  String tagSheetDiaryCta(String tag);

  /// tag-sheet.sentences.empty: 이 기운으로 정해진 오늘 문장이 없을 때 안내(가안 "오늘은 이 기운으로 정해진 문장이 없어요", 문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'오늘은 이 기운으로 정해진 문장이 없어요.'**
  String get tagSheetSentencesEmpty;

  /// tag-sheet.sentences.title: 구역 제목 "이 기운에서 나온 오늘 문장". 아래 목록은 오늘 화면의 보조 문장(today.fortune.body), 오늘의 질문(today.guide.question)과 같은 문장
  ///
  /// In ko, this message translates to:
  /// **'이 기운에서 나온 오늘 문장'**
  String get tagSheetSentencesTitle;

  /// today.date.iljin: 날짜 머리의 일진 틀(매개변수 pillar, 예: 癸未(계미)일)
  ///
  /// In ko, this message translates to:
  /// **'{pillar}일'**
  String todayDateIljin(String pillar);

  /// today.date.lunar: 날짜 머리의 음력 날짜 틀(매개변수 lunarDate). 음력은 server 계약 추가
  ///
  /// In ko, this message translates to:
  /// **'음력 {month}월 {day}일'**
  String todayDateLunar(int month, int day);

  /// today.date.lunar: 날짜 머리의 음력 날짜 틀(매개변수 lunarDate). 음력은 server 계약 추가
  ///
  /// In ko, this message translates to:
  /// **'음력 윤{month}월 {day}일'**
  String todayDateLunarLeap(int month, int day);

  /// today.date.solar: 날짜 머리의 날짜와 요일 틀(매개변수 date, 예: 11월 5일 목요일)
  ///
  /// In ko, this message translates to:
  /// **'{date}'**
  String todayDateSolar(String date);

  /// today.event.title: 일정 섹션 제목 "일정". 일정이 있는 날만 섹션째 보임(그날 시트 `day-sheet.event.title`과 같은 키, 사용자 결정 2026-11-07, 문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'일정'**
  String get todayEventTitle;

  /// today.featured.empty: 대표 태그가 하나도 없는 날(합충, 십성 몰림, 신살이 없고 귀인의 날, 용신의 날도 아님, 표본 기준 약 7%) 사주 기운 섹션 제목 아래 한 줄 안내: 오늘은 두드러진 사주 기운이 없다는 사실(D112, 문구 writing)
  ///
  /// In ko, this message translates to:
  /// **'오늘은 두드러진 사주 기운이 없어요.'**
  String get todayFeaturedEmpty;

  /// today.featured.title: 섹션 제목 "사주 기운"(가안, 문구 writing). 아래에 대표 태그(최대 둘)를 한자 아이콘 태그로 두고, 누르면 사주 기운 시트. 대표 태그가 없는 날도 제목은 두고 아래에 `today.featured.empty` 한 줄(D112)
  ///
  /// In ko, this message translates to:
  /// **'사주 기운'**
  String get todayFeaturedTitle;

  /// today.fortune.title: 섹션 제목 "총운"(확정). 제목 줄 오른쪽에 좋아요
  ///
  /// In ko, this message translates to:
  /// **'총운'**
  String get todayFortuneTitle;

  /// today.guide.title: 섹션 제목 "오늘의 질문"(가안, 문구 writing). 아래에 오늘의 질문, 일기 쓰기, 오늘 쓴 일기
  ///
  /// In ko, this message translates to:
  /// **'오늘의 질문'**
  String get todayGuideTitle;

  /// today.lucky.title: 섹션 제목 "행운"(가안, 문구 writing). 아래에 색(색 견본), 방향(나침반), 숫자(#), 시간(시계) 칩
  ///
  /// In ko, this message translates to:
  /// **'행운'**
  String get todayLuckyTitle;

  /// 사주 표 머리 아래 출생 정보 줄(birth-info-row)의 시진 칸. 달력 종류는 `calendarSolar`·`calendarLunar`, 성별은 `genderMale`·`genderFemale`, 시간 모름은 `timeUnknownLabel`을 함께 씁니다(R30-13)
  ///
  /// In ko, this message translates to:
  /// **'{branch}시'**
  String birthInfoHour(String branch);

  /// 일기 쓰기 인용 질문 옆 질문 바꾸기 아이콘 버튼(arrows-clockwise)의 스크린리더 이름. 바꾼 뒤에는 새 질문을 읽습니다(DS1 V82, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'질문 바꾸기'**
  String get diaryEditQuestionSwap;

  /// text-field focused의 키보드 위 내리기 원형 버튼(keyboardDismiss, caret-down)의 스크린리더 이름. 입력칸에 초점이 있는 동안만 보입니다(DS1 V68, #807)
  ///
  /// In ko, this message translates to:
  /// **'키보드 내리기'**
  String get keyboardDismiss;

  /// 나 탭 명리일기 회고 카드의 낱말: 28px 숫자 옆 편수 단위, 날의 성격 막대 머리, 자주 붙은 태그 머리(DS1 V76, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{편}}'**
  String mySajuRecordCountUnit(int count);

  /// 나 탭 명리일기 회고 카드의 낱말: 28px 숫자 옆 편수 단위, 날의 성격 막대 머리, 자주 붙은 태그 머리(DS1 V76, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'쓴 날의 성격'**
  String get mySajuRecordDayKindHead;

  /// 나 탭 명리일기 회고 카드의 낱말: 28px 숫자 옆 편수 단위, 날의 성격 막대 머리, 자주 붙은 태그 머리(DS1 V76, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'자주 붙은 태그'**
  String get mySajuRecordTagHead;

  /// saju-pillars, manse-table, daeun-table, ohaeng-bar: 스크린리더 표 이름과 항목
  ///
  /// In ko, this message translates to:
  /// **'없음'**
  String get bandTableEmptyCell;

  /// 나 탭 대운, 세운 줄(luck-pillar compact)의 기간. 대운은 나이 범위와 연도 범위, 세운은 연도와 나이(DS1 V77, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'{startAge}~{endAge}세'**
  String luckDaeunAgeRange(int startAge, int endAge);

  /// 나 탭 대운, 세운 줄(luck-pillar compact)의 기간. 대운은 나이 범위와 연도 범위, 세운은 연도와 나이(DS1 V77, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'{startYear}~{endYear}년'**
  String luckDaeunYearRange(int startYear, int endYear);

  /// 나 탭 대운, 세운 줄(luck-pillar compact)의 기간. 대운은 나이 범위와 연도 범위, 세운은 연도와 나이(DS1 V77, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'{year}년'**
  String luckSeunYear(int year);

  /// 나 탭 대운, 세운 줄(luck-pillar compact)의 기간. 대운은 나이 범위와 연도 범위, 세운은 연도와 나이(DS1 V77, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'{age}세'**
  String luckSeunAge(int age);

  /// 12운성 설명 시트의 12단계 띠(stage-strip)에서 내 네 자리 위 원 18 안 기둥 한 글자(DS1 V91, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'시'**
  String get sajuStageMarkerHour;

  /// 12운성 설명 시트의 12단계 띠(stage-strip)에서 내 네 자리 위 원 18 안 기둥 한 글자(DS1 V91, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get sajuStageMarkerDay;

  /// 12운성 설명 시트의 12단계 띠(stage-strip)에서 내 네 자리 위 원 18 안 기둥 한 글자(DS1 V91, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get sajuStageMarkerMonth;

  /// 12운성 설명 시트의 12단계 띠(stage-strip)에서 내 네 자리 위 원 18 안 기둥 한 글자(DS1 V91, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'연'**
  String get sajuStageMarkerYear;

  /// 사주 기운 시트 문장 목록(tag-sentence-list) 줄 왼쪽 52px 이름 칸. 칸 안에서 줄바꿈합니다(DS1 V79, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'총운'**
  String get tagSheetSentenceKindFortune;

  /// 사주 기운 시트 문장 목록(tag-sentence-list) 줄 왼쪽 52px 이름 칸. 칸 안에서 줄바꿈합니다(DS1 V79, D77 ② IA 밖)
  ///
  /// In ko, this message translates to:
  /// **'오늘의 질문'**
  String get tagSheetSentenceKindGuide;
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
