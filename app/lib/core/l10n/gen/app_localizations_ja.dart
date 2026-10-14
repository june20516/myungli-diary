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
  String get errorRequestMalformed => 'リクエストを処理できませんでした。';

  @override
  String get errorRequestInvalid => '入力内容をもう一度ご確認ください。';

  @override
  String get errorAuthTokenExpired => 'ログインの有効期限が切れました。もう一度ログインしてください。';

  @override
  String get errorAuthTokenInvalid => 'もう一度ログインしてください。';

  @override
  String get errorAuthRefreshReused => 'セキュリティのためログアウトしました。もう一度ログインしてください。';

  @override
  String get errorAuthProviderTokenInvalid => 'ログインできませんでした。もう一度お試しください。';

  @override
  String get errorAuthExchangeInvalid => 'ログインの時間が過ぎました。最初からもう一度ログインしてください。';

  @override
  String get errorAppCheckInvalid => 'アプリを確認できませんでした。最新バージョンにアップデートしてください。';

  @override
  String get errorConsentRequired => '利用規約への同意が必要です。';

  @override
  String get errorPreviewUsed => 'プレビューは一度だけ見られます。ログインすると続けて見られます。';

  @override
  String get errorRouteNotFound => 'リクエストを処理できませんでした。アプリをアップデートしてください。';

  @override
  String get errorDiaryNotFound => '日記が見つかりませんでした。';

  @override
  String get errorMethodNotAllowed => 'リクエストを処理できませんでした。アプリをアップデートしてください。';

  @override
  String get errorProfileRequired => '先に生年月日時を入力してください。';

  @override
  String get errorDiaryDateTaken => 'その日にはすでに日記があります。';

  @override
  String get errorIdempotencyInProgress => '処理中です。しばらくしてからもう一度ご確認ください。';

  @override
  String get errorRequestTooLarge => '内容が長すぎます。';

  @override
  String get errorRequestUnsupportedMediaType =>
      'リクエストを処理できませんでした。アプリをアップデートしてください。';

  @override
  String get errorDateOutOfRange => '1900年1月31日から2099年12月31日までの日付のみ対応しています。';

  @override
  String get errorBirthOutOfRange => '1900年1月31日から2099年12月31日までの生年月日を入力してください。';

  @override
  String get errorDateInvalid => 'カレンダーに存在しない日付です。';

  @override
  String get errorRequestInconsistent => '入力内容をもう一度ご確認ください。';

  @override
  String get errorBirthInvalid => '入力した生年月日時をもう一度ご確認ください。';

  @override
  String get errorDiaryFutureDate => '今日より後の日記は書けません。';

  @override
  String get errorNameEmpty => '呼び名を入力してください。';

  @override
  String get errorNameTooLong => '呼び名が長すぎます。';

  @override
  String get errorNameEmoji => '呼び名に絵文字は使えません。';

  @override
  String get errorNameControl => '呼び名に使えない文字が含まれています。';

  @override
  String get errorNameInvalidChar => '呼び名に括弧は使えません。';

  @override
  String get errorIdempotencyMismatch => 'リクエストを処理できませんでした。もう一度お試しください。';

  @override
  String get errorConsentVersionMismatch => '利用規約が変更されました。もう一度ご確認ください。';

  @override
  String get errorRateLimited => 'リクエストが多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get errorInternal => 'サーバーで問題が発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get errorEngineError => '鑑定を計算できませんでした。';

  @override
  String get errorEngineUnavailable => '鑑定を読み込めませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get errorAuthProviderUnavailable => '現在ログインできません。しばらくしてからもう一度お試しください。';

  @override
  String get errorBillingProviderUnavailable =>
      '現在購入を確認できません。しばらくしてからもう一度お試しください。';

  @override
  String get errorServiceUnavailable => '一時的にサービスを利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get errorEngineTimeout => '鑑定の計算に時間がかかっています。しばらくしてからもう一度お試しください。';

  @override
  String get appTitle => '命理日記';

  @override
  String get bootstrapFailed => 'アプリを起動できませんでした。アプリを完全に終了してから、もう一度開いてください。';

  @override
  String get actionRetry => 'もう一度試す';

  @override
  String get actionBusy => '処理中';

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
  String get sajuChartYongsinTitle => '用神の判定根拠';

  @override
  String get todayReactionLabel => 'この文に共感';

  @override
  String termTokenSemantics(String term) {
    return '$termの解説を見る';
  }

  @override
  String inputStepProgress(int step, int stepCount) {
    return '$stepCountステップ中$stepステップ目';
  }

  @override
  String get textFieldClear => '消去';

  @override
  String textFieldCounter(int current, int max) {
    return '文字数 $current/$max';
  }

  @override
  String get datePickerYearLabel => '年';

  @override
  String get datePickerMonthLabel => '月';

  @override
  String get datePickerDayLabel => '日';

  @override
  String datePickerYearItem(int year) {
    return '$year年';
  }

  @override
  String datePickerMonthItem(int month) {
    return '$month月';
  }

  @override
  String datePickerDayItem(int day) {
    return '$day日';
  }

  @override
  String get timePickerMeridiemLabel => '午前・午後';

  @override
  String get timePickerHourLabel => '時';

  @override
  String get timePickerMinuteLabel => '分';

  @override
  String get timePickerAm => '午前';

  @override
  String get timePickerPm => '午後';

  @override
  String timePickerHourItem(int hour) {
    return '$hour時';
  }

  @override
  String timePickerMinuteItem(String minute) {
    return '$minute分';
  }

  @override
  String datePickerLeapMonthValue(int month) {
    return '閏$month月';
  }

  @override
  String citySearchResults(int count) {
    return '結果$count件';
  }

  @override
  String get forceUpdateNoticeHead => '新しいバージョンが必要です';

  @override
  String get forceUpdateNoticeBody => '引き続きご利用いただくには、最新バージョンに更新してください。';

  @override
  String get forceUpdateCtaStore => 'ストアで更新';

  @override
  String get welcomeConceptHead => '今日の自分を読み解く';

  @override
  String get welcomeConceptBody => '生年月日時から読み解いた一日を言葉で受け取り、日記と一緒に記録します。';

  @override
  String get welcomeCtaStart => 'はじめる';

  @override
  String get welcomeCtaSignin => 'すでにアカウントをお持ちの方';

  @override
  String get onboardCallQuestionHead => '何とお呼びしましょうか？';

  @override
  String get onboardCallInputHint => '例：ほし';

  @override
  String get onboardCallNoteBody => '本名でなくても大丈夫です。';

  @override
  String get onboardBirthQuestionHead => 'いつお生まれですか？';

  @override
  String get onboardBirthCalendarHint => '旧暦の場合は旧暦を選び、閏月ならチェックしてください。';

  @override
  String get onboardBirthBasisNote => '韓国生まれとして計算します。';

  @override
  String get onboardBirthErrorRange => '1900年1月31日から2099年12月31日まで計算できます。';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingSave => '保存';

  @override
  String get calendarSolar => '新暦';

  @override
  String get calendarLunar => '旧暦';

  @override
  String get leapMonth => '閏月';
}
