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
  String get evidenceSheetSectionPersonal => 'わたしの命式では';

  @override
  String get evidenceSheetLockHead => '根拠と解釈はロックされています';

  @override
  String get evidenceSheetLockReward => '広告を1本見ると、今日一日、根拠と解釈をすべて見られます。';

  @override
  String get evidenceSheetLockCta => '広告を見て開く';

  @override
  String get evidenceSheetLockPass => '広告除去パスがあれば、期間中ずっと開いています。';

  @override
  String get evidenceSheetLockUnavailable =>
      'いま見られる広告がありません。しばらくしてからもう一度お試しください。';

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
  String get todayReactionLabel => 'いいね';

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
  String get forceUpdateNoticeHead => '新しいバージョンにアップデートしてください';

  @override
  String get forceUpdateNoticeBody => '読み解きの計算方法が変わったため、このバージョンでは開けません。';

  @override
  String get forceUpdateCtaStore => 'アップデートする';

  @override
  String get welcomeConceptHead => '今日の日辰を、自分の命式に合わせて読み解きます';

  @override
  String get welcomeConceptBody => '読み解きに合わせた質問ひとつで、その日の日記を始めます。';

  @override
  String get welcomeCtaStart => 'はじめる';

  @override
  String get welcomeCtaSignin => 'アカウントをお持ちの方';

  @override
  String get onboardCallQuestionHead => '何とお呼びしましょうか?';

  @override
  String get onboardCallInputHint => '例:ゆき';

  @override
  String get onboardCallNoteBody => '本名でなくてもかまいません。あとで変えられます。';

  @override
  String get onboardBirthQuestionHead => 'いつ生まれましたか?';

  @override
  String get onboardBirthCalendarHint => '旧暦の誕生日なら旧暦を選び、閏月なら閏月にも印をつけてください。';

  @override
  String get onboardBirthBasisNote => '韓国で生まれたものとして計算します。';

  @override
  String get onboardBirthErrorRange => '1900年1月31日から2099年12月31日までの日付だけ計算できます。';

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

  @override
  String get onboardCallInputLabel => '呼び名';

  @override
  String get onboardTimeQuestionHead => '何時に生まれましたか?';

  @override
  String get onboardTimeUnknownNote => '時間がわからなければ、生まれた時刻を除いた三柱で読み解きます。';

  @override
  String get timeUnknownLabel => 'わからない';

  @override
  String onboardTimeHourConfirm(String branch, String start, String end) {
    return '$branchの刻、$start〜$endに生まれました。';
  }

  @override
  String get branchJa => '子';

  @override
  String get branchChuk => '丑';

  @override
  String get branchIn => '寅';

  @override
  String get branchMyo => '卯';

  @override
  String get branchJin => '辰';

  @override
  String get branchSa => '巳';

  @override
  String get branchO => '午';

  @override
  String get branchMi => '未';

  @override
  String get branchShin => '申';

  @override
  String get branchYu => '酉';

  @override
  String get branchSul => '戌';

  @override
  String get branchHae => '亥';

  @override
  String get onboardGenderQuestionHead => '性別を教えてください。';

  @override
  String get onboardGenderWhyBody => '大運の流れる向きを決めるときだけ使います。';

  @override
  String get birthplaceQuestionHead => 'どこで生まれましたか?';

  @override
  String get birthplaceWhyBody => '生まれた場所のタイムゾーンと経度で、生まれた時刻を正確に合わせます。';

  @override
  String get birthplaceSearchHint => '都市名';

  @override
  String get birthplaceEmptyBody => '該当する都市がありません。近くの大きな都市で探してみてください。';

  @override
  String get birthplaceSearchLabel => '出生都市の検索';

  @override
  String get genderMale => '男性';

  @override
  String get genderFemale => '女性';

  @override
  String get previewCtaSave => '保存して続ける';

  @override
  String get previewCtaRestart => '入力し直す';

  @override
  String get previewShareLoginNotice => 'ログインすると今日の読み解きを共有できます。';

  @override
  String get dayKindYongsinDay => '用神の日';

  @override
  String get dayKindGwiinDay => '貴人の日';

  @override
  String get dayKindGisinDay => '忌神の日';

  @override
  String get dayKindOrdinaryDay => '普通の日';

  @override
  String get shareLabel => '共有';

  @override
  String get actionClose => '閉じる';

  @override
  String get loginTitleHead => 'ログインして読み解きを保存しましょう';

  @override
  String get loginTitleBody => 'ログインすると、ほかの端末でも自分の命式と日記を見られます。';

  @override
  String get loginDiscardNotice =>
      'すでに命式を保存したアカウントなら、いま入力した情報ではなく保存済みの情報を使います。';

  @override
  String get loginKakaoLabel => 'カカオログイン';

  @override
  String get loginAppleLabel => 'Appleでサインイン';

  @override
  String get loginCancelled => 'ログインをキャンセルしました。';

  @override
  String get appleWebErrorStateMismatch =>
      'ログインを確認できませんでした。最初からもう一度ログインしてください。';

  @override
  String get appleWebErrorCancelled => 'Appleでのサインインをキャンセルしました。';

  @override
  String get appleWebErrorOther => 'Appleでサインインできませんでした。もう一度お試しください。';

  @override
  String get actionConfirm => 'OK';

  @override
  String get consentTitleHead => '規約に同意してください';

  @override
  String get consentCtaAgree => '同意して続ける';

  @override
  String get consentView => '見る';

  @override
  String get notifyAskQuestionHead => '毎朝、今日の読み解きをお知らせしましょうか?';

  @override
  String get notifyAskWhyBody => '通知には、その日がどんな日かと総運の一文が入ります。';

  @override
  String get notifyAskCtaSkip => 'あとで';

  @override
  String get notifyAskCtaAllow => '通知を受け取る';

  @override
  String get accountDeleteCtaDelete => 'アカウントを削除する';

  @override
  String get accountDeleteDataBody =>
      'アカウントを削除すると、命式の情報・日記・タグ・予定・広告除去の残り期間がすべて消え、元に戻せません。';

  @override
  String get accountDeleteDeleteConfirm => '本当に削除しますか?削除したアカウントは元に戻せません。';

  @override
  String get accountDeleteDeleteConfirmDelete => '削除';

  @override
  String get accountDeleteDeleteConfirmCancel => 'キャンセル';

  @override
  String get accountDeleteTitleHead => 'アカウント削除';

  @override
  String get adFreeLegalNotice => '購入前に利用規約とプライバシーポリシーをご確認ください。';

  @override
  String get adFreeOfferHead => '1か月間、広告なしで、根拠と解釈まですべて開いて見られます。';

  @override
  String adFreeOfferPrice(String price) {
    return '$price・1か月・自動更新なし';
  }

  @override
  String get adFreeRestoreCta => '購入を復元';

  @override
  String adFreeStatusRemaining(String date) {
    return '$dateまで広告なしで使えます';
  }

  @override
  String get calcBasisConventionBody => '読み解きは、韓国で広く使われている基準ひとつにそろえています。';

  @override
  String get calcBasisLongitudeBody =>
      '出生時刻は東経127.5°を基準に30分を引いて計算します。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';

  @override
  String get calcBasisLunarBody => '旧暦は、韓国天文研究院の基準による韓国の旧暦に従います。';

  @override
  String get calendarLegendBodyGood => 'うまく運ぶ日';

  @override
  String get calendarLegendBodyCaution => '気をつける日';

  @override
  String get consentRequiredLabelTerms => '(必須)利用規約';

  @override
  String get consentRequiredLabelPrivacy => '(必須)個人情報の収集・利用';

  @override
  String get daySheetDiaryOpen => 'この日の日記を見る';

  @override
  String get daySheetDiaryWriteCta => 'この日の日記を書く';

  @override
  String get daySheetEventAdd => '予定を追加';

  @override
  String get daySheetEventEmpty => 'この日の予定はありません。';

  @override
  String get diaryEditBodyPlaceholder => '今日あったことを書いてみましょう';

  @override
  String get diaryEditDraftStatusLocal => '端末に下書きを保存しました';

  @override
  String get diaryEditDraftStatusSaving => '保存中';

  @override
  String get diaryEditDraftStatusSaved => '保存済み';

  @override
  String get diaryEditOfflineNotice => 'インターネットにつながったら保存します。書いた内容は端末に残っています。';

  @override
  String get diaryEditSavedTags => '日記にタグが付きました';

  @override
  String get diaryListEmptyBody => 'まだ日記がありません。今日のことから書いてみませんか?';

  @override
  String get diaryListPickDateCta => '日付を選んで書く';

  @override
  String get diaryViewDeleteConfirm => 'この日記を削除しますか?削除すると元に戻せません。';

  @override
  String get diaryViewDeleteConfirmDelete => '削除';

  @override
  String get diaryViewDeleteConfirmCancel => 'キャンセル';

  @override
  String get eventEditDeleteConfirm => 'この予定を削除しますか?';

  @override
  String get eventEditDeleteConfirmDelete => '削除';

  @override
  String get eventEditDeleteConfirmCancel => 'キャンセル';

  @override
  String get eventEditMemoHint => 'メモ';

  @override
  String get eventEditTitleHint => '予定のタイトル';

  @override
  String get evidenceSheetLockPassLink => '広告除去を見る';

  @override
  String get evidenceSheetUnlockFailed => '広告の確認に時間がかかっています。しばらくしてから開き直してください。';

  @override
  String get previewShareLoginNoticeConfirm => 'ログインする';

  @override
  String get previewShareLoginNoticeCancel => '閉じる';

  @override
  String get profileEditRecalcConfirmTitle => '情報を変更しますか?';

  @override
  String profileEditRecalcConfirmBody(String before, String after) {
    return '$before → $after\n今日・カレンダー・わたしの命式を計算し直します。すでに書いた日記とタグはそのまま残ります。';
  }

  @override
  String get profileEditRecalcConfirmCancel => 'キャンセル';

  @override
  String get profileEditRecalcConfirmSave => '変更する';

  @override
  String get profileEditRecalcNotice => '誕生日・時間・性別・出生地を変えると、読み解きを計算し直します。';

  @override
  String get sajuChartTimeUnknownNotice => '生まれた時刻がわからないため、時柱を除いて表示しています。';

  @override
  String get settingsAdFreeLabel => '広告を消す';

  @override
  String settingsAdFreeLabelActive(String date) {
    return '$dateまで';
  }

  @override
  String get settingsDepthDesc => '読み解きを最初にどこまで広げて見るかを選びます。';

  @override
  String get settingsLanguageBirthplaceNotice =>
      '韓国以外で生まれた場合は、出生地を入力してください。生まれた時刻をより正確に合わせられます。';

  @override
  String get settingsLanguageBirthplaceNoticeCta => '出生地を入力する';

  @override
  String get settingsLogoutConfirm => 'ログアウトしますか?';

  @override
  String get settingsLogoutConfirmLogout => 'ログアウト';

  @override
  String get settingsLogoutConfirmCancel => 'キャンセル';

  @override
  String get sharePreviewCtaShare => '共有する';

  @override
  String get sharePreviewImageFooter => '命理日記';

  @override
  String get sharePreviewImageTagline => '自分の命式で読む今日、命理日記';

  @override
  String get sharePreviewRatioLabelStory => 'ストーリー';

  @override
  String get sharePreviewRatioLabelFeed => 'フィード';

  @override
  String get sharePreviewRatioLabelSquare => '正方形';

  @override
  String get tagDiaryEmptyBody => 'このタグが付いた日記はまだありません。';

  @override
  String todayEventSummary(int count, String title) {
    return '今日の予定 $count件・$title';
  }

  @override
  String get todayEventSummaryOngoing => '進行中';

  @override
  String get todayEventSummaryNext => '次';

  @override
  String get todayEventSummaryDone => '今日の予定はすべて終わりました';

  @override
  String get todayGuideCta => '日記を書く';

  @override
  String get todayGuideCtaWritten => '書いた日記を見る';

  @override
  String get todayReactionLabelSelected => 'いいねを取り消す';

  @override
  String get depthDefaultLabel => '命理の読み解き';

  @override
  String get depthEvidence => '原理';

  @override
  String get depthExplain => '読み解き';

  @override
  String get depthSurface => '要約';
}
