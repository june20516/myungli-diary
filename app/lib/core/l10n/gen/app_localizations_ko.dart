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
  String get appTitle => '명리일기';

  @override
  String get actionRetry => '다시 시도';

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
  String get todayReactionLabel => '이 문장 좋아요';

  @override
  String termTokenSemantics(String term) {
    return '$term 풀이 보기';
  }
}
