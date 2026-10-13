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
}
