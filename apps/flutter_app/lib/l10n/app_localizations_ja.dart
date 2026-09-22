// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get managerAuthorize => 'フォルダへのアクセスを許可';

  @override
  String managerAndroidAuthorizationHint(String appId) {
    return 'システムのフォルダー選択画面で Download/$appId/ を開き、「このフォルダを使用」を押してください。ゲームはその中の games フォルダーに置いてください。';
  }

  @override
  String get managerAuthorizationHint =>
      'ダウンロード内の本アプリ専用フォルダを選択してください。他のフォルダは管理できません。';

  @override
  String get managerEmpty => 'このフォルダは空です';

  @override
  String get managerNewFolder => '新規フォルダ';

  @override
  String get managerSelect => '選択';

  @override
  String get managerSelectAll => 'すべて選択';

  @override
  String get managerDone => '完了';

  @override
  String get managerCancel => 'キャンセル';

  @override
  String get managerCopy => 'コピー';

  @override
  String get managerMove => '移動';

  @override
  String get managerRename => '名前を変更';

  @override
  String get managerRenameExtensionTitle => '拡張子を変更しますか？';

  @override
  String managerRenameExtensionMessage(String from, String to) {
    return '拡張子を $from から $to に変えると、ファイルの種類（プレビュー・展開・ゲームデータなど）が変わる場合があります。意図した操作のときだけ続けてください。';
  }

  @override
  String get managerRenameExtensionContinue => '続ける';

  @override
  String get managerNoExtension => '拡張子なし';

  @override
  String get managerTrash => '最近削除した項目に移動';

  @override
  String get managerRecentlyDeleted => '最近削除した項目';

  @override
  String get managerTrashHint => 'これらの項目は引き続き容量を使用します。自動削除は行いません。';

  @override
  String get managerTrashConfirm => '選択した項目を最近削除した項目に移動しますか？';

  @override
  String get managerTrashExplanation => '後から復元できます。プレイ履歴とアプリ内のセーブデータは保持されます。';

  @override
  String get managerRestore => '復元';

  @override
  String get managerDeletePermanently => '完全に削除';

  @override
  String get managerPermanentConfirm => 'この項目を完全に削除しますか？';

  @override
  String get managerPermanentExplanation => 'この操作は取り消せません。アプリ内のセーブデータは削除しません。';

  @override
  String get managerChooseDestination => '移動先を選択';

  @override
  String get managerUseFolder => 'このフォルダを使用';

  @override
  String get managerName => '名前';

  @override
  String get managerExtract => '展開';

  @override
  String get managerExtractTitle => 'アーカイブを展開';

  @override
  String get managerPassword => 'パスワード（必要な場合）';

  @override
  String get managerEncoding => '従来形式のファイル名の文字コード';

  @override
  String get managerExtractHint =>
      '新しいフォルダに展開し、元のアーカイブを保持します。アーカイブ内の Unicode 情報を優先します。';

  @override
  String get managerWorking => '処理中…';

  @override
  String get managerCompleted => '完了しました';

  @override
  String get managerRetry => '再試行';

  @override
  String get managerErrorCancelled => '操作をキャンセルしました。';

  @override
  String get managerErrorBusy => '現在のファイル操作が完了するまでお待ちください。';

  @override
  String get managerErrorInvalidName => 'パス区切りや予約文字を含まない有効な名前を指定してください。';

  @override
  String get managerErrorOutsideRoot => 'ダウンロード内の本アプリ専用フォルダのみ管理できます。';

  @override
  String get managerErrorProtectedDirectory =>
      'このフォルダは予約されています。フォルダ内の項目を操作してください。';

  @override
  String get managerErrorUnsupportedLink => 'リンクや特殊ファイルには対応していません。';

  @override
  String get managerErrorNotFound => 'ファイルまたは保存先のフォルダが見つかりません。';

  @override
  String get managerErrorConflict => '同名の項目が存在します。上書きはしていません。';

  @override
  String get managerErrorRecursiveTarget => '項目をその項目自身や子フォルダ内に配置することはできません。';

  @override
  String get managerErrorTrashCorrupt => '最近削除した項目の記録を読み込めません。ファイルは削除していません。';

  @override
  String get managerErrorPermissionDenied =>
      'アクセスできません。フォルダの許可と読み書き権限を確認してください。';

  @override
  String get managerErrorNoSpace => '空き容量が不足しています。容量を確保してから再試行してください。';

  @override
  String get managerErrorReadOnly => 'この場所は読み取り専用です。';

  @override
  String get managerErrorPasswordRequired => 'このアーカイブにはパスワードが必要です。';

  @override
  String get managerErrorWrongPassword => 'パスワードが正しくないか、暗号化ヘッダーが破損しています。';

  @override
  String get managerErrorMissingVolume =>
      '分割ファイルが不足しています。元の連番を保ち、すべて同じフォルダに置いてください。';

  @override
  String get managerErrorUnsupportedFormat => 'このアーカイブ形式には対応していないか、形式を認識できません。';

  @override
  String get managerErrorUnsupportedMethod => 'このアーカイブの圧縮方式には対応していません。';

  @override
  String get managerErrorCorruptArchive =>
      'アーカイブが不完全または破損しています。分割ファイルとパスワードを確認してください。';

  @override
  String get managerErrorInvalidEncoding =>
      'ファイル名を読み取れません。文字コードを変更して再試行してください。';

  @override
  String get managerErrorUnsafeArchivePath => 'アーカイブに危険なパスが含まれているため、展開を停止しました。';

  @override
  String get managerErrorArchiveLimit => 'ファイル数または展開後のサイズが安全上の上限を超えています。';

  @override
  String get managerErrorGameRunning => 'ゲームを終了してからファイルを変更してください。';

  @override
  String get managerErrorUnsupportedPlatform =>
      'このプラットフォームでは、このフォルダへのアクセスはまだ利用できません。';

  @override
  String get managerErrorFailed => '操作を完了できませんでした。対象の項目を確認してから再試行してください。';

  @override
  String managerItemsSelected(int count) {
    return '$count 件を選択中';
  }

  @override
  String get managerDetails => '詳細';

  @override
  String get managerDetailKind => '種類';

  @override
  String get managerDetailFolder => 'フォルダ';

  @override
  String get managerDetailFile => 'ファイル';

  @override
  String get managerDetailArchive => 'アーカイブ';

  @override
  String get managerDetailGame => 'ゲーム';

  @override
  String get managerDetailImage => '画像';

  @override
  String get managerDetailAudio => '音声';

  @override
  String get managerDetailVideo => '動画';

  @override
  String get managerDetailText => 'テキスト';

  @override
  String get managerDetailGameData => 'ゲームデータ';

  @override
  String get managerTextEmpty => 'このファイルは空です。';

  @override
  String get managerTextTruncated => 'このファイルの先頭 2 MB のみ表示しています。';

  @override
  String get managerPlay => '再生';

  @override
  String get managerPause => '一時停止';

  @override
  String get managerPreview => 'プレビュー';

  @override
  String get managerMediaFailed => 'このファイルを開けませんでした。';

  @override
  String get managerDetailSize => 'サイズ';

  @override
  String managerDetailItems(int count) {
    return '$count 項目';
  }

  @override
  String get managerDetailModified => '変更日時';

  @override
  String get managerDetailLocation => '場所';

  @override
  String get managerCalculating => '計算中…';

  @override
  String get managerEncodingUtf8 => 'UTF-8';

  @override
  String get managerEncodingGb18030 => 'GB18030';

  @override
  String get managerEncodingCp932 => 'Shift_JIS';

  @override
  String get appTitle => 'NextScene';

  @override
  String get settings => '設定';

  @override
  String get addGame => 'ゲームを追加';

  @override
  String get refresh => '更新';

  @override
  String get howToImport => 'インポート方法';

  @override
  String get noGamesYet => 'ゲームがまだ追加されていません';

  @override
  String get noGamesHintDesktop => '「ゲームを追加」をクリックしてゲームディレクトリを選択してください';

  @override
  String noGamesHintIos(String appName) {
    return '「ファイル」アプリでゲームフォルダをコピーしてください：\niPhone内 > $appName > Games\nその後「更新」をタップ';
  }

  @override
  String get importGames => 'ゲームをインポート';

  @override
  String get importGamesDesc =>
      '「ファイル」アプリを使用して、ゲームフォルダをこのアプリのディレクトリにコピーしてください：';

  @override
  String get importStep1 => '1. iPhoneの「ファイル」アプリを開く';

  @override
  String importStep2(String appName) {
    return '2. iPhone内 > $appName > Games に移動';
  }

  @override
  String get importStep3 => '3. ゲームフォルダをGamesディレクトリにコピー';

  @override
  String get importStep4 => '4. アプリに戻り「更新」をタップして新しいゲームを検出';

  @override
  String get macosImportTip =>
      '注意：macOS サンドボックス制限のため、まず XP3 ファイルを含むフォルダを選択し、その後対象の XP3 ファイルを選択してください';

  @override
  String get gamesDirectory => 'ゲームディレクトリ：Games/';

  @override
  String get gotIt => '了解';

  @override
  String get tabHome => 'ライブラリ';

  @override
  String get tabExplore => '見つける';

  @override
  String get tabManage => '管理';

  @override
  String get tabStatistics => '統計';

  @override
  String get tabProfile => 'マイページ';

  @override
  String get search => '検索';

  @override
  String get searchGamesHint => 'ゲームを検索';

  @override
  String get searchNoResults => '一致するゲームがありません';

  @override
  String get searchComingSoon => '検索機能は準備中です';

  @override
  String get help => 'ヘルプ';

  @override
  String get profilePlayTimeTitle => 'プレイ時間';

  @override
  String get profileLifetime => '累計プレイ';

  @override
  String get profileLast7Days => '直近7日間';

  @override
  String get profileTrackingHint => 'プレイ傾向はこれから記録されます';

  @override
  String get profileActiveDays => 'プレイ日数';

  @override
  String get profileGamesPlayed => 'プレイしたゲーム';

  @override
  String get profileAverageSession => '平均プレイ時間';

  @override
  String get profileTopGames => 'よく遊ぶゲーム';

  @override
  String get profileStatistics => 'プレイ統計';

  @override
  String get profileViewStatistics => '詳しい統計を見る';

  @override
  String get profileHonorTitle => '称号';

  @override
  String get profileHonorNextUnlock => '次の称号';

  @override
  String get profileHonorNewcomer => 'はじめの一歩';

  @override
  String get profileHonorStoryTraveler => '物語の旅人';

  @override
  String get profileHonorImmersedReader => '没入する読者';

  @override
  String get profileHonorVeteran => 'ベテランプレイヤー';

  @override
  String get profileHonorCollector => 'ゲームコレクター';

  @override
  String get profileHonorCurator => '物語の蒐集家';

  @override
  String profileHonorNext(String title) {
    return '次 · $title';
  }

  @override
  String profileHonorRemainingBoth(String duration, int count) {
    return 'あと$durationと$count本';
  }

  @override
  String profileHonorRemainingTime(String duration) {
    return 'あと$duration';
  }

  @override
  String profileHonorRemainingGames(int count) {
    return 'あと$count本';
  }

  @override
  String get profileHonorHighest => '最高ランクです';

  @override
  String get profileHonorCurrent => '現在';

  @override
  String get profileHonorObtained => '獲得済み';

  @override
  String get profileHonorLocked => '未獲得';

  @override
  String get profileGameRecords => 'ゲーム記録';

  @override
  String get profileLocalSummary => 'このデバイス';

  @override
  String get profileLibraryCount => 'ライブラリ';

  @override
  String get profileRecentGame => '最近プレイしたゲーム';

  @override
  String get profileNoHistory => '記録はありません';

  @override
  String profilePlaySummary(String duration, int count) {
    return 'プレイ時間 $duration · $count本';
  }

  @override
  String get playTimeLessThanMinute => '1分未満';

  @override
  String playTimeMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String playTimeHours(int hours) {
    return '$hours時間';
  }

  @override
  String playTimeHoursMinutes(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String get helpIntro => 'ゲームの取り込み、保存場所、ファイル管理、プレイ時間の記録について説明します。';

  @override
  String get helpSectionLibrary => '取り込みと起動';

  @override
  String get helpSectionFiles => 'ファイルと資料';

  @override
  String get helpSectionMore => '統計と設定';

  @override
  String get helpFaqImportQ => 'ゲームをライブラリへ追加する方法';

  @override
  String get helpFaqImportA =>
      '「ライブラリ」の「ゲームを追加」から、ゲームフォルダ全体、または XP3 / PFS パックを選びます。HarmonyOS では、公開のゲーム用フォルダに置いてからホームを下に引いて更新することもできます。';

  @override
  String get helpFaqOhosQ => 'HarmonyOS における保存場所';

  @override
  String helpFaqOhosA(String path) {
    return 'システムの「ファイル」で、ゲームフォルダ全体を次の場所へコピーしてください。\n$path\nこのアプリが読み書きするのは、Download 配下の専用フォルダだけです。';
  }

  @override
  String get helpFaqIosQ => 'iPhone でのコピー手順';

  @override
  String helpFaqIosA(String appName) {
    return '「ファイル」アプリで、ゲームフォルダを「iPhone内 > $appName > Games」へコピーし、アプリに戻って更新します。';
  }

  @override
  String get helpFaqLaunchQ => 'タップと長押しの違い';

  @override
  String get helpFaqLaunchA =>
      'カードをタップすると詳細が開き、そこから起動できます。長押しすると、詳細を開かずに起動、情報取得、名前の変更、リストからの削除ができます。';

  @override
  String get helpFaqManageQ => '「管理」で行える操作';

  @override
  String get helpFaqManageA =>
      '許可済みのアプリフォルダ内で、コピー、移動、名前の変更、展開、詳細表示ができます。ルート、games、非公開のセーブフォルダは保護されており、通常のファイルのように削除できません。';

  @override
  String get helpFaqArchiveQ => '圧縮ファイルと分割ファイル';

  @override
  String get helpFaqArchiveA =>
      '「管理」では zip、7z、rar を展開できます。分割された XP3 は同じフォルダに置いてください。展開や取り込みでゲームスクリプトは書き換えません。';

  @override
  String get helpFaqRemoveQ => 'ライブラリから外すとファイルも消えますか';

  @override
  String get helpFaqRemoveA =>
      '消えません。リストの項目だけが除かれ、フォルダは残ります。ファイルを消すときは「管理」から操作してください。';

  @override
  String get helpFaqMetadataQ => '題名とカバーの取得';

  @override
  String get helpFaqMetadataA =>
      '追加のあと、または長押しメニューの「情報を取得」から、作品名で VNDB を検索します。変わるのは表示名とカバーだけです。';

  @override
  String get helpFaqStatsQ => 'プレイ時間の記録方法';

  @override
  String get helpFaqStatsA =>
      '起動から通常終了までを1回として「統計」に残します。システムから強制終了すると、その回は残らないことがあります。';

  @override
  String get helpFaqControlsQ => 'キーボードやマウスがないとき';

  @override
  String get helpFaqControlsA =>
      'プレイ中は、決定、戻る、スキップ、方向の仮想キーを使います。配置はその場の表示に従ってください。';

  @override
  String get helpFaqSettingsQ => '言語と外観の変更';

  @override
  String get helpFaqSettingsA =>
      '「マイページ」から「設定」を開き、言語を変え、ライト、ダーク、システム外観を選びます。エンジン関連の一部は再起動後に有効になります。';

  @override
  String get helpFaqCompatQ => '対象となる作品';

  @override
  String get helpFaqCompatA =>
      'KiriKiri2 と Artemis の作品向けです。公式の配布ではありません。資源が足りない、未実装の命令がある、または未対応の暗号化がある場合、起動しないことがあります。';

  @override
  String get removeGame => 'ゲームを削除';

  @override
  String removeGameConfirm(String title) {
    return 'リストから「$title」を削除しますか？\nゲームファイルは削除されません。';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get remove => '削除';

  @override
  String get renameGame => 'ゲーム名を変更';

  @override
  String get displayTitle => '表示名';

  @override
  String get save => '保存';

  @override
  String get done => '完了';

  @override
  String gameAlreadyExists(String title) {
    return 'ゲームは既に存在します：$title';
  }

  @override
  String get builtInReady => '内蔵 ✓';

  @override
  String get builtInNotReady => '内蔵 ✗';

  @override
  String get customNotSet => 'カスタム（未設定）';

  @override
  String get engineNotFoundBuiltIn =>
      '内蔵エンジンが見つかりません。ビルドスクリプトでエンジンをバンドルするか、設定でカスタムモードに切り替えてください。';

  @override
  String get engineNotFoundCustom => 'エンジンdylibが設定されていません。先に設定で構成してください。';

  @override
  String lastPlayed(String time) {
    return '最終プレイ：$time';
  }

  @override
  String playDuration(String duration) {
    return 'プレイ時間 $duration';
  }

  @override
  String get rename => '名前変更';

  @override
  String get setCover => 'カバーを設定';

  @override
  String get coverFromGallery => 'ギャラリーから選択';

  @override
  String get coverFromCamera => '写真を撮る';

  @override
  String get coverRemove => 'カバーを削除';

  @override
  String get settingsEngine => 'エンジン';

  @override
  String get engineMode => 'エンジンモード';

  @override
  String get builtIn => '内蔵';

  @override
  String get custom => 'カスタム';

  @override
  String get builtInEngineAvailable => '内蔵エンジン利用可能';

  @override
  String get builtInEngineNotFound => '内蔵エンジンが見つかりません';

  @override
  String get builtInEngineHint => 'ビルドスクリプトを使用してエンジンをコンパイルし、アプリにバンドルしてください。';

  @override
  String get engineDylibPath => 'エンジンdylibパス';

  @override
  String get notSetRequired => '未設定（必須）';

  @override
  String get clearPath => 'パスをクリア';

  @override
  String get browse => '参照...';

  @override
  String get selectEngineDylib => 'エンジンdylibを選択';

  @override
  String get settingsRendering => 'レンダリング';

  @override
  String get renderPipeline => 'レンダリングパイプライン';

  @override
  String get renderPipelineHint => 'レンダリングパイプラインとグラフィックスバックエンドはアプリ再起動後に有効になります';

  @override
  String get restartRequiredTitle => '再起動が必要です';

  @override
  String get restartRequiredMessage => 'この変更はアプリを再起動すると有効になります。';

  @override
  String get applyAndRestart => '変更して再起動';

  @override
  String get restartPendingBanner =>
      '保存した変更はまだ有効になっていません。アプリを再起動するか、ここから手動で再起動してください。';

  @override
  String get restartNow => 'アプリを再起動';

  @override
  String get opengl => 'OpenGL';

  @override
  String get software => 'ソフトウェア';

  @override
  String get graphicsBackend => 'グラフィックスバックエンド';

  @override
  String get graphicsBackendHint => 'ANGLE翻訳レイヤーバックエンド（Androidのみ）。再起動が必要です。';

  @override
  String get opengles => 'OpenGL ES';

  @override
  String get vulkan => 'Vulkan';

  @override
  String get performanceOverlay => 'パフォーマンスオーバーレイ';

  @override
  String get performanceOverlayDesc => 'FPSとグラフィックAPI情報を表示';

  @override
  String get fpsLimitEnabled => 'フレームレート制限';

  @override
  String get fpsLimitEnabledDesc => 'エンジンの描画頻度を制限して省電力';

  @override
  String get fpsLimitOff => 'オフ（VSync）';

  @override
  String get forceLandscape => '横画面ロック';

  @override
  String get forceLandscapeDesc => 'ゲーム実行時に横向き表示を強制します（スマートフォン推奨）';

  @override
  String get targetFrameRate => '目標フレームレート';

  @override
  String get targetFrameRateDesc => '制限有効時の最大描画頻度';

  @override
  String fpsLabel(int fps) {
    return '$fps FPS';
  }

  @override
  String get settingsGeneral => '一般';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageJa => '日本語';

  @override
  String get themeMode => 'テーマ';

  @override
  String get themeSystem => 'システムに従う';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeLight => 'ライト';

  @override
  String get settingsAbout => 'バージョン情報';

  @override
  String get version => 'バージョン';

  @override
  String get legal => '法的情報';

  @override
  String get legalTabOpenSource => 'ライセンス';

  @override
  String get legalTabPrivacy => 'プライバシー';

  @override
  String get legalTabDisclaimer => '免責';

  @override
  String get legalOpenSourceTitle => 'オープンソースライセンス';

  @override
  String get legalPrivacyTitle => 'プライバシーに関する説明';

  @override
  String get legalDisclaimerTitle => '免責事項';

  @override
  String legalUpdated(String date) {
    return '本声明は $date 時点の実装に基づき作成しています。';
  }

  @override
  String get gameEngineError => 'エンジンエラー';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get back => '戻る';

  @override
  String get retry => '再試行';

  @override
  String get hideDebug => 'デバッグログを閉じる';

  @override
  String get showDebug => 'デバッグログを開く';

  @override
  String get pause => '一時停止';

  @override
  String get resume => '再開';

  @override
  String get exitGame => 'ゲームを終了';

  @override
  String get discard => '破棄';

  @override
  String get discardChangesMessage => '未保存の変更を破棄しますか？';

  @override
  String get gameTypeXp3 => 'XP3 アーカイブ';

  @override
  String get gameTypeDirectory => 'フォルダ';

  @override
  String archiveNotExist(String path) {
    return 'アーカイブが存在しません: $path';
  }

  @override
  String gamePathNotExist(String path) {
    return 'ゲームパスが存在しません: $path';
  }

  @override
  String missingStartupScript(String path) {
    return '起動スクリプトが見つかりません: $path\n（startup.tjs と data/system/initialize.tjs を確認済み）';
  }

  @override
  String gamePathCheckFailed(String error) {
    return 'ゲームパスの確認に失敗しました: $error';
  }

  @override
  String get androidDirectoryAccess =>
      'ゲームフォルダーへのアクセスがありません。Download/com.nextscene.app を選び直してから開いてください。';

  @override
  String get noXp3InFolder => '選択したフォルダに XP3 アーカイブも Artemis パック（.pfs）も見つかりません。';

  @override
  String get gameTypeArtemis => 'Artemis パック（.pfs）';

  @override
  String gameEngine(String engine) {
    return 'エンジン: $engine';
  }

  @override
  String missingArtemisPack(String path) {
    return 'Artemis パック（.pfs）が見つかりません: $path';
  }

  @override
  String get rescanGamesDir => 'ディレクトリを再スキャン';

  @override
  String rescanGamesDirDesc(String path) {
    return '$path に置いた、または hdc で転送したゲームを検索（XP3 / Artemis .pfs）';
  }

  @override
  String get noGamesFoundInSandbox => 'ゲームフォルダとアプリサンドボックスにゲームが見つかりません。';

  @override
  String get allSandboxGamesRegistered => '見つかったゲームはすべてライブラリに登録済みです。';

  @override
  String get noNewGamesFound => '新しいゲームは見つかりませんでした。';

  @override
  String noGamesHintOhos(String path) {
    return '「ファイル」アプリでゲームフォルダを次の場所にコピー：\n$path\nその後、下に引いて更新';
  }

  @override
  String get settingsGames => 'ゲーム';

  @override
  String get publicGamesDir => 'ゲーム保存フォルダ';

  @override
  String publicGamesDirHint(String path) {
    return '「ファイル」アプリでゲームフォルダごと $path にコピーし、ホーム画面で下に引いて更新すると認識されます。タップでパスをコピー。';
  }

  @override
  String get pullToRefresh => '引っ張って更新';

  @override
  String get releaseToRefresh => '離して更新';

  @override
  String get refreshing => '更新中';

  @override
  String get refreshDone => '更新完了';

  @override
  String get screenOrientation => '画面の向き';

  @override
  String get screenOrientationDesc => 'ゲーム実行中に使用する画面の向き';

  @override
  String get orientationAuto => 'システムに従う';

  @override
  String get orientationLandscape => '横向き';

  @override
  String get orientationPortrait => '縦向き';

  @override
  String get rotateScreen => '画面を回転';

  @override
  String get showVirtualControls => 'バーチャル操作を表示';

  @override
  String get hideVirtualControls => 'バーチャル操作を隠す';

  @override
  String get virtualTouchpad => 'タッチパッド・タップでクリック';

  @override
  String get virtualMouseLeft => '左クリック';

  @override
  String get virtualMouseRight => '右クリック';

  @override
  String get virtualConfirm => '決定（Enter）';

  @override
  String get virtualBack => '戻る（Esc）';

  @override
  String get virtualAdvance => '進む（Space）';

  @override
  String get virtualSkip => '長押しでスキップ（Ctrl）';

  @override
  String get virtualUp => '上';

  @override
  String get virtualDown => '下';

  @override
  String get virtualLeft => '左';

  @override
  String get virtualRight => '右';

  @override
  String get gameStarting => '起動中';

  @override
  String get gamePreparingEngine => 'エンジンを準備';

  @override
  String get gameOpening => 'ゲームを開く';

  @override
  String get gameLoadingResources => 'リソースを読み込み';

  @override
  String get gameBootLogs => '詳細ログ';

  @override
  String get gameHideBootLogs => 'ログを閉じる';

  @override
  String get engineRestartRequired =>
      'エンジンはこのセッションで別のゲームを実行中です。変更するにはアプリを再起動してください。';

  @override
  String gamesImported(int count) {
    return '$count 件のゲームをインポートしました';
  }

  @override
  String get selectGameDirectory => 'ゲームディレクトリを選択';

  @override
  String get selectGameArchive => 'ゲームアーカイブを選択';

  @override
  String get addArchive => 'XP3 追加';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int count) {
    return '$count分前';
  }

  @override
  String hoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String daysAgo(int count) {
    return '$count日前';
  }

  @override
  String get packXp3 => 'XP3にパック';

  @override
  String get unpackXp3 => 'XP3を展開';

  @override
  String get packingProgress => 'パック中...';

  @override
  String get unpackingProgress => '展開中...';

  @override
  String get packComplete => 'パック完了';

  @override
  String get unpackComplete => '展開完了';

  @override
  String xp3OperationFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get launchGame => 'ゲームを開始';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get gameFormat => 'フォーマット';

  @override
  String get gamePath => 'パス';

  @override
  String get gameDescription => 'あらすじ';

  @override
  String get gameKeywords => 'キーワード';

  @override
  String get showMore => 'もっと見る';

  @override
  String get showLess => '閉じる';

  @override
  String get scrapeMetadata => '情報を取得';

  @override
  String get scrapeMetadataDialogTitle => '情報を取得';

  @override
  String get scrapeMetadataSearchHint => 'ゲーム名を入力して検索';

  @override
  String get scrapeMetadataSearch => '検索';

  @override
  String get scrapeMetadataSelectTitle => '一致する作品を選択';

  @override
  String get scrapeMetadataNoResults => '一致する作品がありません。別のキーワードをお試しください。';

  @override
  String get scrapeMetadataConfirm => '確定';

  @override
  String get scrapeMetadataSuccess => '名前とカバーを更新しました。';

  @override
  String get scrapeMetadataCoverFailed => '名前を更新しました。カバーの取得に失敗しました。手動で設定できます。';

  @override
  String get scrapeMetadataEnterName => 'ゲーム名を入力してください。';

  @override
  String get scrapeMetadataSourceError => 'データソースが利用できません。しばらくしてから再試行してください。';

  @override
  String get scrapeMetadataSelectOne => '作品を選択してください。';

  @override
  String get scrapeAfterAddPrompt => 'このゲームの情報を取得しますか？「はい」で検索して名前とカバーを設定します。';

  @override
  String get scrapeAfterAddNo => 'いいえ';

  @override
  String get scrapeAfterAddYes => 'はい';
}
