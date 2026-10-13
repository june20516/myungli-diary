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
}
