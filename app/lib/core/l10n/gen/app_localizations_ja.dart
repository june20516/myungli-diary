// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get errorOffline => 'インターネットに接続されていません。';

  @override
  String get errorTimeout => '応答に時間がかかっています。しばらくしてからもう一度お試しください。';

  @override
  String get errorClient => 'リクエストを処理できませんでした。';

  @override
  String get errorServer => 'サーバーで問題が発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get errorUnexpected => '予期しない問題が発生しました。';

  @override
  String get errorNotImplemented => 'まだ準備中です。';

  @override
  String get appTitle => '命理日記';

  @override
  String get bootstrapFailed => 'アプリを起動できませんでした。アプリを完全に終了してから、もう一度開いてください。';

  @override
  String get actionRetry => 'もう一度試す';

  @override
  String traceIdLabel(String traceId) {
    return 'お問い合わせ番号 $traceId';
  }

  @override
  String get tabToday => '今日';

  @override
  String get tabCalendar => 'カレンダー';

  @override
  String get tabDiary => '日記';

  @override
  String get tabMe => '私';

  @override
  String get appBarBack => '戻る';

  @override
  String get sheetDismiss => '閉じる';

  @override
  String get adBannerLabel => '広告';

  @override
  String get noticeOffline => 'インターネットに接続されていないため、保存済みの内容を表示しています。';

  @override
  String get emptyStateDefault => 'まだ表示できる内容がありません。';

  @override
  String get skeletonLabel => '読み込み中';

  @override
  String get traceIdCopied => 'お問い合わせ番号をコピーしました。';

  @override
  String get evidenceSheetSectionBasis => '判定の根拠';

  @override
  String get evidenceSheetSectionSource => '原典';

  @override
  String get evidenceSheetSectionPersonal => 'あなたの命式では';

  @override
  String get evidenceSheetLockHead => '根拠と解釈はロックされています';

  @override
  String get evidenceSheetLockReward => '広告を1本見ると、今日一日、根拠と解釈がすべて開きます。';

  @override
  String get evidenceSheetLockCta => '広告を見て開く';

  @override
  String get evidenceSheetLockPass => '広告削除パスがあればすぐに開きます ›';

  @override
  String get evidenceSheetLockUnavailable =>
      '今は表示できる広告がありません。しばらくしてからもう一度お試しください。';

  @override
  String get evidenceSheetA11yLocked => 'ロック中';

  @override
  String get evidenceSheetA11yChecking => '確認中';

  @override
  String get evidenceSheetA11yUnlocked => '根拠と解釈が開きました';

  @override
  String get sajuChartYongsinOpen => '開く';

  @override
  String get todayReactionLabel => 'この文に共感';

  @override
  String termTokenSemantics(String term) {
    return '$termの解説を見る';
  }
}
