// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get errorOffline => 'インターネットに接続されていません。接続を確認してください。';

  @override
  String get errorTimeout => '応答に時間がかかっています。しばらくしてからもう一度お試しください。';

  @override
  String get errorClient => '処理できませんでした。もう一度お試しください。';

  @override
  String get errorServer => 'こちらで問題が起きました。しばらくしてからもう一度お試しください。';

  @override
  String get errorUnexpected => '問題が起きました。もう一度お試しください。';

  @override
  String get errorNotImplemented => 'まだ準備中です。';

  @override
  String get errorRequestMalformed => '処理できませんでした。もう一度お試しください。';

  @override
  String get errorRequestInvalid => '入力内容をもう一度確認してください。';

  @override
  String get errorAuthTokenExpired => 'ログインの有効期限が切れました。もう一度ログインしてください。';

  @override
  String get errorAuthTokenInvalid => 'ログイン情報を確認できませんでした。もう一度ログインしてください。';

  @override
  String get errorAuthRefreshReused => '安全のためログアウトしました。もう一度ログインしてください。';

  @override
  String get errorAuthProviderTokenInvalid => 'ログインできませんでした。もう一度お試しください。';

  @override
  String get errorAuthExchangeInvalid => 'ログインの時間が過ぎました。最初からもう一度ログインしてください。';

  @override
  String get errorAppCheckInvalid => 'アプリを確認できませんでした。最新版にアップデートしてください。';

  @override
  String get errorConsentRequired => '続けるには利用規約への同意が必要です。';

  @override
  String get errorPreviewUsed => 'プレビューは一度だけ見られます。ログインすると続きを読めます。';

  @override
  String get errorRouteNotFound => '処理できませんでした。アプリをアップデートしてください。';

  @override
  String get errorDiaryNotFound => '日記が見つかりませんでした。';

  @override
  String get errorMethodNotAllowed => '処理できませんでした。アプリをアップデートしてください。';

  @override
  String get errorProfileRequired => '先に生まれた日と時間を入力してください。';

  @override
  String get errorDiaryDateTaken => 'その日にはすでに日記があります。';

  @override
  String get errorIdempotencyInProgress => 'まだ処理しています。しばらくしてからもう一度確認してください。';

  @override
  String get errorRequestTooLarge => '内容が長すぎます。少し短くしてください。';

  @override
  String get errorRequestUnsupportedMediaType => '処理できませんでした。アプリをアップデートしてください。';

  @override
  String get errorDateOutOfRange => '1900年1月31日〜2099年12月31日の日付だけ見られます。';

  @override
  String get errorBirthOutOfRange => '1900年1月31日〜2099年12月31日の日付だけ計算できます。';

  @override
  String get errorDateInvalid => 'カレンダーにない日付です。';

  @override
  String get errorRequestInconsistent => '入力内容をもう一度確認してください。';

  @override
  String get errorBirthInvalid => '入力した生まれた日と時間をもう一度確認してください。';

  @override
  String get errorDiaryFutureDate => '明日以降の日記は書けません。';

  @override
  String get errorNameEmpty => '呼び名を入力してください。';

  @override
  String get errorNameTooLong => '呼び名が長すぎます。少し短くしてください。';

  @override
  String get errorNameEmoji => '呼び名に絵文字は使えません。';

  @override
  String get errorNameControl => '呼び名に使えない文字が入っています。';

  @override
  String get errorNameInvalidChar => '呼び名に括弧は使えません。';

  @override
  String get errorIdempotencyMismatch => '処理できませんでした。もう一度お試しください。';

  @override
  String get errorConsentVersionMismatch => '利用規約が変わりました。もう一度確認してください。';

  @override
  String get errorRateLimited => 'リクエストが多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get errorInternal => 'こちらで問題が起きました。しばらくしてからもう一度お試しください。';

  @override
  String get errorEngineError => '読み解きを計算できませんでした。時間をおいてお試しください。';

  @override
  String get errorEngineUnavailable => '読み解きを読み込めませんでした。時間をおいてお試しください。';

  @override
  String get errorAuthProviderUnavailable => '今はログインできません。しばらくしてからもう一度お試しください。';

  @override
  String get errorBillingProviderUnavailable =>
      '今は購入を確認できません。しばらくしてからもう一度お試しください。';

  @override
  String get errorServiceUnavailable => '今はアプリを使えません。しばらくしてからもう一度お試しください。';

  @override
  String get errorEngineTimeout => '読み解きの計算に時間がかかっています。後でお試しください。';

  @override
  String get appTitle => '命理日記';

  @override
  String get bootstrapFailed => 'アプリを開けませんでした。アプリを完全に閉じてから、もう一度開いてください。';

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
  String get tabMe => 'マイページ';

  @override
  String get appBarBack => '戻る';

  @override
  String get sheetDismiss => '閉じる';

  @override
  String get adBannerLabel => '広告';

  @override
  String get noticeOffline => 'オフラインのため、保存してある内容を表示しています。';

  @override
  String get emptyStateDefault => 'まだ表示する内容がありません。';

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
    return '$termの意味を見る';
  }

  @override
  String inputStepProgress(int step, int stepCount) {
    return '$stepCountステップ中$stepステップ目';
  }

  @override
  String get textFieldClear => '消去';

  @override
  String textFieldCounter(int current, int max) {
    return '$max文字中$current文字';
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
  String datePickerSolarConfirm(String date) {
    return '新暦 $date';
  }

  @override
  String citySearchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '結果$count件',
    );
    return '$_temp0';
  }

  @override
  String get forceUpdateNoticeHead => '新しいバージョンにアップデートしてください';

  @override
  String get forceUpdateNoticeBody => '読み解きの計算方法が変わったため、このバージョンでは開けません。';

  @override
  String get forceUpdateCtaStore => 'アップデートする';

  @override
  String get welcomeConceptHead => '今日の干支を、自分の命式に合わせて読み解きます';

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
  String get birthplaceSearchLabel => '生まれた都市を探す';

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
  String get loginKakaoLabel => 'Login with Kakao';

  @override
  String get loginAppleLabel => 'Appleでサインイン';

  @override
  String get loginCancelled => 'ログインをキャンセルしました。';

  @override
  String get appleWebErrorStateMismatch => 'ログインを確認できませんでした。最初からやり直してください。';

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
  String get calcBasisConventionBody =>
      '読み解きは、韓国で広く使われている基準に従います。いくつかある流派のひとつとして、根拠のある基準です。';

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
  String get evidenceSheetUnlockFailed => '広告の確認に時間がかかっています。少し待って開き直してください。';

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
  String get shareImageSemantics => '今日の一文の画像プレビュー';

  @override
  String get sharePreviewRatioGroup => '共有画像の比率';

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
  String get todayGuideEyebrow => '今日の質問';

  @override
  String get todayGuideWritten => '今日の日記を書きました';

  @override
  String get todayGuideLabel => '日記の質問';

  @override
  String get todayReactionLabelSelected => 'いいねを取り消す';

  @override
  String get depthExplain => '読み解き';

  @override
  String get depthLinkEvidence => '根拠を見る';

  @override
  String get todayLuckyColorName => 'ラッキーカラー';

  @override
  String get todayLuckyDirectionName => 'ラッキー方位';

  @override
  String get todayLuckyNumberName => 'ラッキーナンバー';

  @override
  String get todayLuckyTimeName => '集中しやすい時間';

  @override
  String get evidenceSheetTitle => '今日の読み解きの根拠';

  @override
  String get a11yListSeparator => '、';

  @override
  String get calendarBarTitle => 'カレンダー';

  @override
  String get eventEditBarTitle => '予定';

  @override
  String get calendarPrevMonth => '前の月';

  @override
  String get calendarNextMonth => '次の月';

  @override
  String dayCellLunar(int month, int day) {
    return '旧暦$month月$day日';
  }

  @override
  String get dayCellLeapMonth => '閏月';

  @override
  String dayCellEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return '予定$_temp0';
  }

  @override
  String get dayCellDiaryWritten => '日記あり';

  @override
  String get dayCellToday => '今日';

  @override
  String eventRowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return 'ほか$_temp0';
  }

  @override
  String get eventRowAllDay => '終日';

  @override
  String eventRowLabel(String status, String time, String title) {
    return '$status $time $title';
  }

  @override
  String todayEventSummaryNextAt(String time, String title) {
    return '次は$time $title';
  }

  @override
  String todayEventSummaryAllPast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return '今日の予定$_temp0はすべて終わりました';
  }

  @override
  String get eventEditAllDay => '終日';

  @override
  String get eventEditTimed => '時間指定';

  @override
  String get eventEditDateLabel => '日付';

  @override
  String get eventEditTimeLabel => '時間';

  @override
  String get eventEditSave => '保存';

  @override
  String get eventEditDelete => '予定を削除';

  @override
  String get eventEditOfflineNotice => 'インターネットに接続されていないため、保存できません。';

  @override
  String get eventEditSaveFailed => '予定を保存できませんでした。もう一度お試しください。';

  @override
  String get direction8N => '北';

  @override
  String get direction8Ne => '北東';

  @override
  String get direction8E => '東';

  @override
  String get direction8Se => '南東';

  @override
  String get direction8S => '南';

  @override
  String get direction8Sw => '南西';

  @override
  String get direction8W => '西';

  @override
  String get direction8Nw => '北西';

  @override
  String get birthplaceStandardLink => '計算の基準を見る';

  @override
  String get birthplaceStandardNote =>
      '命理日記は、韓国で広く使われている基準で計算します。いくつかある流派のひとつとして、根拠のある方法です。';

  @override
  String calcBasisLongitudeBodySubtract(String longitude, int minutes) {
    return '出生時刻は$longitudeを基準に$minutes分を引いて計算します。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';
  }

  @override
  String calcBasisLongitudeBodyAdd(String longitude, int minutes) {
    return '出生時刻は$longitudeを基準に$minutes分を足して計算します。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';
  }

  @override
  String calcBasisLongitudeBodyNone(String longitude) {
    return '出生時刻は$longitudeを基準に、補正せずに計算します。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';
  }

  @override
  String calcBasisLongitudeBodyEast(String degrees) {
    return '東経$degrees°';
  }

  @override
  String calcBasisLongitudeBodyWest(String degrees) {
    return '西経$degrees°';
  }

  @override
  String get calcBasisSchoolsBody =>
      '蔵干はひとつに絞らず、すべて表示します。子の刻に生まれた場合は、午前0時より前でも翌日として計算します。流派によって扱いが異なるため、ほかのアプリや本と結果が異なることがあります。';

  @override
  String get accountDeleteBarTitle => 'アカウント削除';

  @override
  String get adFreeBarTitle => '広告を消す';

  @override
  String get birthplaceBarTitle => '出生地';

  @override
  String get calcBasisBarTitle => '計算の基準';

  @override
  String calcBasisLongitudeBodyDstSubtract(
    String longitude,
    int minutes,
    int dstMinutes,
  ) {
    return '出生時刻は、サマータイムの$dstMinutes分を先に引き、$longitudeを基準にさらに$minutes分を引いて計算します。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';
  }

  @override
  String calcBasisLongitudeBodyDstAdd(
    String longitude,
    int minutes,
    int dstMinutes,
  ) {
    return '出生時刻は、サマータイムの$dstMinutes分を先に引き、$longitudeを基準に$minutes分を足して計算します。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';
  }

  @override
  String calcBasisLongitudeBodyDstNone(String longitude, int dstMinutes) {
    return '出生時刻は、サマータイムの$dstMinutes分だけを引いて計算します。$longitudeが基準のため、経度の補正はしません。真太陽時は使いません。そのため、時の境目の数分以内に生まれた場合は、ほかの万歳暦アプリと時柱が異なることがあります。';
  }

  @override
  String get consentBarTitle => '規約への同意';

  @override
  String get diaryEditBarTitle => '日記を書く';

  @override
  String get diaryListBarTitle => '日記';

  @override
  String diaryViewBarTitle(String date) {
    return '$dateの日記';
  }

  @override
  String get legalBarTitle => '規約とポリシー';

  @override
  String get loginBarTitle => 'ログイン';

  @override
  String get mySajuBarTitle => '私の命式';

  @override
  String get notifyAskBarTitle => '通知';

  @override
  String get onboardBirthBarTitle => '誕生日';

  @override
  String get onboardCallBarTitle => '呼び名';

  @override
  String get onboardGenderBarTitle => '性別';

  @override
  String get onboardTimeBarTitle => '生まれた時刻';

  @override
  String get previewBarTitle => '最初の読み解き';

  @override
  String get profileEditBarTitle => '情報の変更';

  @override
  String get sajuChartBarTitle => '命式表';

  @override
  String get settingsBarTitle => '設定';

  @override
  String tagDiaryBarTitle(String tag) {
    return 'タグ:$tag';
  }

  @override
  String get todayBarTitle => '今日';

  @override
  String get errorReactionNotFound => '反応する文が見つかりませんでした。画面を更新してください。';

  @override
  String get errorScheduleNotFound => '予定が見つかりませんでした。一覧を更新してください。';

  @override
  String get errorRangeTooLong => '一度に見られる期間を超えています。期間を短くしてください。';

  @override
  String get diaryEditSave => '保存';

  @override
  String get diaryViewEditAction => '日記を編集';

  @override
  String get diaryViewDeleteAction => '日記を削除';

  @override
  String get diaryViewDeleted => '日記を削除しました。';

  @override
  String diaryListPickDateConfirm(String date) {
    return '$dateの日記';
  }

  @override
  String tagChipLabel(String tag) {
    return '#$tag';
  }

  @override
  String get tagChipPolarityGood => '良い流れ';

  @override
  String get tagChipPolarityBad => '気をつけたい流れ';

  @override
  String get tagChipPolarityNeutral => '穏やかな流れ';

  @override
  String dayCellLeapNewMoon(int month) {
    return '閏$month.1';
  }

  @override
  String get errorCityNotFound => '出生地の都市が見つかりませんでした。都市を選び直してください。';

  @override
  String get errorTimezoneInvalid => 'タイムゾーンを確認できませんでした。端末の設定を確認してください。';
}
