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

  /// 임시. 앱 이름(작업 전환기 등에 보임)
  ///
  /// In ko, this message translates to:
  /// **'명리일기'**
  String get appTitle;

  /// 임시. 오류 뒤 다시 시도 버튼 문구
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get actionRetry;

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
