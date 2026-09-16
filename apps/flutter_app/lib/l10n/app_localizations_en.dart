// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get managerAuthorize => 'Authorize Folder';

  @override
  String get managerAuthorizationHint =>
      'Select this app’s folder inside Downloads. Other folders cannot be managed.';

  @override
  String get managerEmpty => 'This folder is empty';

  @override
  String get managerNewFolder => 'New Folder';

  @override
  String get managerSelect => 'Select';

  @override
  String get managerSelectAll => 'Select All';

  @override
  String get managerDone => 'Done';

  @override
  String get managerCancel => 'Cancel';

  @override
  String get managerCopy => 'Copy';

  @override
  String get managerMove => 'Move';

  @override
  String get managerRename => 'Rename';

  @override
  String get managerRenameExtensionTitle => 'Change the file extension?';

  @override
  String managerRenameExtensionMessage(String from, String to) {
    return 'Changing the extension from $from to $to may change how this file is classified (preview, extract, game data). Only continue if you meant to do that.';
  }

  @override
  String get managerRenameExtensionContinue => 'Continue';

  @override
  String get managerNoExtension => 'no extension';

  @override
  String get managerTrash => 'Move to Recently Deleted';

  @override
  String get managerRecentlyDeleted => 'Recently Deleted';

  @override
  String get managerTrashHint =>
      'These items still use storage. Nothing is deleted automatically.';

  @override
  String get managerTrashConfirm => 'Move selected items to Recently Deleted?';

  @override
  String get managerTrashExplanation =>
      'You can restore them later. Game history and private saves will be kept.';

  @override
  String get managerRestore => 'Restore';

  @override
  String get managerDeletePermanently => 'Delete Permanently';

  @override
  String get managerPermanentConfirm => 'Permanently delete this item?';

  @override
  String get managerPermanentExplanation =>
      'This cannot be undone. Private game saves are not included.';

  @override
  String get managerChooseDestination => 'Choose Destination';

  @override
  String get managerUseFolder => 'Use This Folder';

  @override
  String get managerName => 'Name';

  @override
  String get managerExtract => 'Extract';

  @override
  String get managerExtractTitle => 'Extract Archive';

  @override
  String get managerPassword => 'Password (if required)';

  @override
  String get managerEncoding => 'Legacy Filename Encoding';

  @override
  String get managerExtractHint =>
      'Extract to a new folder and keep the archive. Unicode names in the archive take priority.';

  @override
  String get managerWorking => 'Working…';

  @override
  String get managerCompleted => 'Completed';

  @override
  String get managerRetry => 'Try Again';

  @override
  String get managerErrorCancelled => 'Operation cancelled.';

  @override
  String get managerErrorBusy =>
      'Wait for the current file operation to finish.';

  @override
  String get managerErrorInvalidName =>
      'Use a valid name without path separators or reserved characters.';

  @override
  String get managerErrorOutsideRoot =>
      'Only this app’s dedicated Downloads folder can be managed.';

  @override
  String get managerErrorProtectedDirectory =>
      'This folder is reserved. Manage the items inside it instead.';

  @override
  String get managerErrorUnsupportedLink =>
      'Links and special files cannot be processed.';

  @override
  String get managerErrorNotFound =>
      'The file or destination folder no longer exists.';

  @override
  String get managerErrorConflict =>
      'An item with that name already exists. Nothing was overwritten.';

  @override
  String get managerErrorRecursiveTarget =>
      'An item cannot be placed inside itself.';

  @override
  String get managerErrorTrashCorrupt =>
      'This Recently Deleted record could not be read. No files were removed.';

  @override
  String get managerErrorPermissionDenied =>
      'Access is unavailable. Check folder authorization and permissions.';

  @override
  String get managerErrorNoSpace =>
      'Not enough storage. Free up space and try again.';

  @override
  String get managerErrorReadOnly => 'This location is read-only.';

  @override
  String get managerErrorPasswordRequired =>
      'This archive requires a password.';

  @override
  String get managerErrorWrongPassword =>
      'The password is incorrect, or the encrypted header is damaged.';

  @override
  String get managerErrorMissingVolume =>
      'A volume is missing. Keep all volumes together with their original numbering.';

  @override
  String get managerErrorUnsupportedFormat =>
      'This archive format is not supported or could not be recognized.';

  @override
  String get managerErrorUnsupportedMethod =>
      'This archive uses an unsupported compression method.';

  @override
  String get managerErrorCorruptArchive =>
      'The archive is incomplete or damaged. Check all volumes and the password.';

  @override
  String get managerErrorInvalidEncoding =>
      'The filename encoding could not be decoded. Choose another encoding and try again.';

  @override
  String get managerErrorUnsafeArchivePath =>
      'The archive contains unsafe paths. Extraction was stopped.';

  @override
  String get managerErrorArchiveLimit =>
      'The archive exceeds the file count or expanded size safety limit.';

  @override
  String get managerErrorGameRunning =>
      'Exit the game before changing its files.';

  @override
  String get managerErrorUnsupportedPlatform =>
      'Folder access is not available on this platform yet.';

  @override
  String get managerErrorFailed =>
      'The operation could not be completed. Check the affected items before trying again.';

  @override
  String managerItemsSelected(int count) {
    return '$count selected';
  }

  @override
  String get managerDetails => 'Details';

  @override
  String get managerDetailKind => 'Kind';

  @override
  String get managerDetailFolder => 'Folder';

  @override
  String get managerDetailFile => 'File';

  @override
  String get managerDetailArchive => 'Archive';

  @override
  String get managerDetailGame => 'Game';

  @override
  String get managerDetailImage => 'Image';

  @override
  String get managerDetailAudio => 'Audio';

  @override
  String get managerDetailVideo => 'Video';

  @override
  String get managerDetailText => 'Text';

  @override
  String get managerDetailGameData => 'Game data';

  @override
  String get managerTextEmpty => 'This file is empty.';

  @override
  String get managerTextTruncated => 'Showing the first 2 MB of this file.';

  @override
  String get managerPlay => 'Play';

  @override
  String get managerPause => 'Pause';

  @override
  String get managerPreview => 'Preview';

  @override
  String get managerMediaFailed => 'This file could not be opened.';

  @override
  String get managerDetailSize => 'Size';

  @override
  String managerDetailItems(int count) {
    return '$count items';
  }

  @override
  String get managerDetailModified => 'Modified';

  @override
  String get managerDetailLocation => 'Location';

  @override
  String get managerCalculating => 'Calculating…';

  @override
  String get managerEncodingUtf8 => 'UTF-8';

  @override
  String get managerEncodingGb18030 => 'GB18030';

  @override
  String get managerEncodingCp932 => 'Shift_JIS';

  @override
  String get appTitle => 'NextScene';

  @override
  String get settings => 'Settings';

  @override
  String get addGame => 'Add Game';

  @override
  String get refresh => 'Refresh';

  @override
  String get howToImport => 'How to Import';

  @override
  String get noGamesYet => 'No games added yet';

  @override
  String get noGamesHintDesktop =>
      'Click \"Add Game\" to select a game directory';

  @override
  String noGamesHintIos(String appName) {
    return 'Use the Files app to copy game folders to:\nOn My iPhone > $appName > Games\nThen tap \"Refresh\"';
  }

  @override
  String get importGames => 'Import Games';

  @override
  String get importGamesDesc =>
      'Please copy your game folders to this app\'s directory using the Files app:';

  @override
  String get importStep1 => '1. Open the \"Files\" app on your iPhone';

  @override
  String importStep2(String appName) {
    return '2. Go to: On My iPhone > $appName > Games';
  }

  @override
  String get importStep3 => '3. Copy your game folder into the Games directory';

  @override
  String get importStep4 =>
      '4. Come back and tap \"Refresh\" to detect new games';

  @override
  String get macosImportTip =>
      'Note: Please select the folder containing the XP3 file first before select the target XP3 file due to macOS sandbox restrictions';

  @override
  String get gamesDirectory => 'Games directory: Games/';

  @override
  String get gotIt => 'Got it';

  @override
  String get tabHome => 'Library';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabManage => 'Manage';

  @override
  String get tabStatistics => 'Stats';

  @override
  String get tabProfile => 'Me';

  @override
  String get search => 'Search';

  @override
  String get searchGamesHint => 'Search games';

  @override
  String get searchNoResults => 'No matching games';

  @override
  String get searchComingSoon => 'Search is coming soon';

  @override
  String get help => 'Help';

  @override
  String get profilePlayTimeTitle => 'Play Time';

  @override
  String get profileLifetime => 'All Time';

  @override
  String get profileLast7Days => 'Last 7 Days';

  @override
  String get profileTrackingHint => 'Your activity trend starts here';

  @override
  String get profileActiveDays => 'Active Days';

  @override
  String get profileGamesPlayed => 'Games Played';

  @override
  String get profileAverageSession => 'Avg. Session';

  @override
  String get profileTopGames => 'Most Played';

  @override
  String get profileStatistics => 'Play Statistics';

  @override
  String get profileViewStatistics => 'View Detailed Statistics';

  @override
  String get profileHonorTitle => 'Title';

  @override
  String get profileHonorNextUnlock => 'Next title';

  @override
  String get profileHonorNewcomer => 'New Arrival';

  @override
  String get profileHonorStoryTraveler => 'Story Traveler';

  @override
  String get profileHonorImmersedReader => 'Immersed Reader';

  @override
  String get profileHonorVeteran => 'Seasoned Player';

  @override
  String get profileHonorCollector => 'Game Collector';

  @override
  String get profileHonorCurator => 'Archive Curator';

  @override
  String profileHonorNext(String title) {
    return 'Next · $title';
  }

  @override
  String profileHonorRemainingBoth(String duration, int count) {
    return '$duration and $count more games to go';
  }

  @override
  String profileHonorRemainingTime(String duration) {
    return '$duration to go';
  }

  @override
  String profileHonorRemainingGames(int count) {
    return '$count more games to go';
  }

  @override
  String get profileHonorHighest => 'Top title reached';

  @override
  String get profileHonorCurrent => 'Current';

  @override
  String get profileHonorObtained => 'Earned';

  @override
  String get profileHonorLocked => 'Not earned';

  @override
  String get profileGameRecords => 'Games';

  @override
  String get profileLocalSummary => 'On This Device';

  @override
  String get profileLibraryCount => 'Library';

  @override
  String get profileRecentGame => 'Recently Played';

  @override
  String get profileNoHistory => 'No activity yet';

  @override
  String profilePlaySummary(String duration, int count) {
    return '$duration played · $count games';
  }

  @override
  String get playTimeLessThanMinute => 'Less than 1 min';

  @override
  String playTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String playTimeHours(int hours) {
    return '$hours hr';
  }

  @override
  String playTimeHoursMinutes(int hours, int minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String get helpIntro =>
      'This page covers importing games, where to store them, file management, and how play time is recorded.';

  @override
  String get helpSectionLibrary => 'Import and launch';

  @override
  String get helpSectionFiles => 'Files and metadata';

  @override
  String get helpSectionMore => 'Statistics and settings';

  @override
  String get helpFaqImportQ => 'Adding a game to the library';

  @override
  String get helpFaqImportA =>
      'On Library, tap Add Game and choose a complete game directory, or an XP3 / PFS pack. On HarmonyOS you can also place the directory in the app\'s public games path, then return to the home screen and pull down to refresh.';

  @override
  String get helpFaqOhosQ => 'Storage location on HarmonyOS';

  @override
  String helpFaqOhosA(String path) {
    return 'In the system Files app, copy the complete game directory to:\n$path\nThis app only reads and writes its own folder under Download.';
  }

  @override
  String get helpFaqIosQ => 'Copying a game on iPhone';

  @override
  String helpFaqIosA(String appName) {
    return 'Open Files, copy the game folder to On My iPhone > $appName > Games, then return here and tap Refresh.';
  }

  @override
  String get helpFaqLaunchQ => 'Tap and touch-and-hold';

  @override
  String get helpFaqLaunchA =>
      'Tap a card to open details, then launch from there. Touch and hold to launch, scrape the title and cover, rename, or remove the entry from the list without opening details.';

  @override
  String get helpFaqManageQ => 'What you can do on Manage';

  @override
  String get helpFaqManageA =>
      'Inside the authorised app folder you can copy, move, rename, extract archives, and view details. The root, games, and private save folders are protected and cannot be deleted like ordinary files.';

  @override
  String get helpFaqArchiveQ => 'Archives and split volumes';

  @override
  String get helpFaqArchiveA =>
      'zip, 7z and rar archives can be extracted on Manage. Keep split XP3 volumes in the same folder. Extraction and import do not rewrite game scripts.';

  @override
  String get helpFaqRemoveQ => 'Does removing a game delete the files?';

  @override
  String get helpFaqRemoveA =>
      'No. Removal only takes the entry off the list. The folder stays on disk. Delete files from Manage.';

  @override
  String get helpFaqMetadataQ => 'Filling in a title and cover';

  @override
  String get helpFaqMetadataA =>
      'After adding a game, or from the touch-and-hold menu, choose Scrape info and search VNDB by title. Only the display name and cover change.';

  @override
  String get helpFaqStatsQ => 'How play time is recorded';

  @override
  String get helpFaqStatsA =>
      'Time from launch to a normal exit is stored as one session and shown on Stats. If the process is force-stopped, that session may not be recorded.';

  @override
  String get helpFaqControlsQ => 'Playing without a keyboard or mouse';

  @override
  String get helpFaqControlsA =>
      'On-screen keys cover confirm, back, skip and direction. Use the layout shown during play.';

  @override
  String get helpFaqSettingsQ => 'Language and appearance';

  @override
  String get helpFaqSettingsA =>
      'Open Settings from Me to change the language, and to choose light, dark or system appearance. Some engine options take effect only after a restart.';

  @override
  String get helpFaqCompatQ => 'Which titles are supported';

  @override
  String get helpFaqCompatA =>
      'This app runs KiriKiri2 and Artemis titles. It is not an official release. A title may fail to start if assets are missing, an instruction is unimplemented, or the encryption is unsupported.';

  @override
  String get removeGame => 'Remove Game';

  @override
  String removeGameConfirm(String title) {
    return 'Remove \"$title\" from the list?\nThis will NOT delete the game files.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get renameGame => 'Rename Game';

  @override
  String get displayTitle => 'Display Title';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String gameAlreadyExists(String title) {
    return 'Game already exists: $title';
  }

  @override
  String get builtInReady => 'Built-in ✓';

  @override
  String get builtInNotReady => 'Built-in ✗';

  @override
  String get customNotSet => 'Custom (not set)';

  @override
  String get engineNotFoundBuiltIn =>
      'Built-in engine not found. Please use the build script to bundle the engine, or switch to Custom mode in Settings.';

  @override
  String get engineNotFoundCustom =>
      'Engine dylib not set. Please configure it in Settings first.';

  @override
  String lastPlayed(String time) {
    return 'Last played: $time';
  }

  @override
  String playDuration(String duration) {
    return 'Played $duration';
  }

  @override
  String get rename => 'Rename';

  @override
  String get setCover => 'Set Cover';

  @override
  String get coverFromGallery => 'Choose from Gallery';

  @override
  String get coverFromCamera => 'Take Photo';

  @override
  String get coverRemove => 'Remove Cover';

  @override
  String get settingsEngine => 'Engine';

  @override
  String get engineMode => 'Engine Mode';

  @override
  String get builtIn => 'Built-in';

  @override
  String get custom => 'Custom';

  @override
  String get builtInEngineAvailable => 'Built-in engine available';

  @override
  String get builtInEngineNotFound => 'Built-in engine not found';

  @override
  String get builtInEngineHint =>
      'Use the build script to compile and bundle the engine into the app.';

  @override
  String get engineDylibPath => 'Engine dylib path';

  @override
  String get notSetRequired => 'Not set (required)';

  @override
  String get clearPath => 'Clear path';

  @override
  String get browse => 'Browse...';

  @override
  String get selectEngineDylib => 'Select Engine dylib';

  @override
  String get settingsRendering => 'Rendering';

  @override
  String get renderPipeline => 'Render Pipeline';

  @override
  String get renderPipelineHint =>
      'Render pipeline and graphics backend take effect after restarting the app';

  @override
  String get restartRequiredTitle => 'Restart required';

  @override
  String get restartRequiredMessage =>
      'This change takes effect after the app restarts.';

  @override
  String get applyAndRestart => 'Apply and restart';

  @override
  String get restartPendingBanner =>
      'Saved changes are not in effect yet. Restart the app, or tap here to restart now.';

  @override
  String get restartNow => 'Restart app';

  @override
  String get opengl => 'OpenGL';

  @override
  String get software => 'Software';

  @override
  String get graphicsBackend => 'Graphics Backend';

  @override
  String get graphicsBackendHint =>
      'ANGLE translation layer backend (Android only). Requires restart.';

  @override
  String get opengles => 'OpenGL ES';

  @override
  String get vulkan => 'Vulkan';

  @override
  String get performanceOverlay => 'Performance Overlay';

  @override
  String get performanceOverlayDesc => 'Show FPS and graphics API info';

  @override
  String get fpsLimitEnabled => 'Frame Rate Limit';

  @override
  String get fpsLimitEnabledDesc =>
      'Limit engine rendering frequency to save power';

  @override
  String get fpsLimitOff => 'Off (VSync)';

  @override
  String get forceLandscape => 'Lock Landscape';

  @override
  String get forceLandscapeDesc =>
      'Force landscape orientation when running games (recommended for phones)';

  @override
  String get targetFrameRate => 'Target Frame Rate';

  @override
  String get targetFrameRateDesc =>
      'Maximum rendering frequency when limit is enabled';

  @override
  String fpsLabel(int fps) {
    return '$fps FPS';
  }

  @override
  String get settingsGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageJa => '日本語';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsAbout => 'About';

  @override
  String get version => 'Version';

  @override
  String get legal => 'Legal';

  @override
  String get legalTabOpenSource => 'Licenses';

  @override
  String get legalTabPrivacy => 'Privacy';

  @override
  String get legalTabDisclaimer => 'Disclaimer';

  @override
  String get legalOpenSourceTitle => 'Open-source licenses';

  @override
  String get legalPrivacyTitle => 'Privacy statement';

  @override
  String get legalDisclaimerTitle => 'Disclaimer';

  @override
  String legalUpdated(String date) {
    return 'Prepared by reference to the implementation dated $date.';
  }

  @override
  String get gameEngineError => 'Engine Error';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get hideDebug => 'Close Debug Log';

  @override
  String get showDebug => 'Open Debug Log';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get exitGame => 'Exit Game';

  @override
  String get discard => 'Discard';

  @override
  String get discardChangesMessage => 'Discard unsaved changes?';

  @override
  String get gameTypeXp3 => 'XP3 archive';

  @override
  String get gameTypeDirectory => 'Directory';

  @override
  String archiveNotExist(String path) {
    return 'Archive file does not exist: $path';
  }

  @override
  String gamePathNotExist(String path) {
    return 'Game path does not exist: $path';
  }

  @override
  String missingStartupScript(String path) {
    return 'Missing startup script in: $path\n(looked for startup.tjs and data/system/initialize.tjs)';
  }

  @override
  String gamePathCheckFailed(String error) {
    return 'Game path check failed: $error';
  }

  @override
  String get androidAllFilesAccess =>
      'All files access is required on Android. Please grant permission and open the game again.';

  @override
  String get noXp3InFolder =>
      'No XP3 archive or Artemis pack (.pfs) found in the selected folder.';

  @override
  String get gameTypeArtemis => 'Artemis pack (.pfs)';

  @override
  String gameEngine(String engine) {
    return 'Engine: $engine';
  }

  @override
  String missingArtemisPack(String path) {
    return 'No Artemis pack (.pfs) found in: $path';
  }

  @override
  String get rescanGamesDir => 'Rescan Directory';

  @override
  String rescanGamesDirDesc(String path) {
    return 'Find games dropped into $path or sent in with hdc (XP3 / Artemis .pfs)';
  }

  @override
  String get noGamesFoundInSandbox =>
      'No games found in the games folder or app sandbox.';

  @override
  String get allSandboxGamesRegistered =>
      'All games found are already in the library.';

  @override
  String get noNewGamesFound => 'No new games found.';

  @override
  String noGamesHintOhos(String path) {
    return 'Use the Files app to copy a game folder to:\n$path\nthen pull down to refresh';
  }

  @override
  String get settingsGames => 'Games';

  @override
  String get publicGamesDir => 'Games Folder';

  @override
  String publicGamesDirHint(String path) {
    return 'Copy a whole game folder into $path with the Files app, then pull down on the home page to refresh. Tap to copy the path.';
  }

  @override
  String get pullToRefresh => 'Pull to refresh';

  @override
  String get releaseToRefresh => 'Release to refresh';

  @override
  String get refreshing => 'Refreshing';

  @override
  String get refreshDone => 'Refreshed';

  @override
  String get screenOrientation => 'Screen Orientation';

  @override
  String get screenOrientationDesc =>
      'Orientation used while a game is running';

  @override
  String get orientationAuto => 'Follow system';

  @override
  String get orientationLandscape => 'Landscape';

  @override
  String get orientationPortrait => 'Portrait';

  @override
  String get rotateScreen => 'Rotate Screen';

  @override
  String get showVirtualControls => 'Show virtual controls';

  @override
  String get hideVirtualControls => 'Hide virtual controls';

  @override
  String get virtualTouchpad => 'Touchpad · tap to click';

  @override
  String get virtualMouseLeft => 'Left click';

  @override
  String get virtualMouseRight => 'Right click';

  @override
  String get virtualConfirm => 'Confirm (Enter)';

  @override
  String get virtualBack => 'Back (Esc)';

  @override
  String get virtualAdvance => 'Advance (Space)';

  @override
  String get virtualSkip => 'Hold to skip (Ctrl)';

  @override
  String get virtualUp => 'Up';

  @override
  String get virtualDown => 'Down';

  @override
  String get virtualLeft => 'Left';

  @override
  String get virtualRight => 'Right';

  @override
  String get gameStarting => 'Starting';

  @override
  String get gamePreparingEngine => 'Preparing engine';

  @override
  String get gameOpening => 'Opening game';

  @override
  String get gameLoadingResources => 'Loading resources';

  @override
  String get gameBootLogs => 'Details';

  @override
  String get gameHideBootLogs => 'Hide details';

  @override
  String get engineRestartRequired =>
      'The engine is already running another game. Restart the app to play a different one.';

  @override
  String gamesImported(int count) {
    return '$count games imported';
  }

  @override
  String get selectGameDirectory => 'Select Game Directory';

  @override
  String get selectGameArchive => 'Select Game Archive';

  @override
  String get addArchive => 'Add XP3';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get packXp3 => 'Pack as XP3';

  @override
  String get unpackXp3 => 'Unpack XP3';

  @override
  String get packingProgress => 'Packing...';

  @override
  String get unpackingProgress => 'Unpacking...';

  @override
  String get packComplete => 'Packed successfully';

  @override
  String get unpackComplete => 'Unpacked successfully';

  @override
  String xp3OperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get launchGame => 'Launch Game';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get gameFormat => 'Format';

  @override
  String get gamePath => 'Path';

  @override
  String get gameDescription => 'About';

  @override
  String get gameKeywords => 'Keywords';

  @override
  String get showMore => 'More';

  @override
  String get showLess => 'Less';

  @override
  String get scrapeMetadata => 'Scrape info';

  @override
  String get scrapeMetadataDialogTitle => 'Scrape info';

  @override
  String get scrapeMetadataSearchHint => 'Enter game name to search';

  @override
  String get scrapeMetadataSearch => 'Search';

  @override
  String get scrapeMetadataSelectTitle => 'Select matching game';

  @override
  String get scrapeMetadataNoResults =>
      'No matching games. Try another keyword.';

  @override
  String get scrapeMetadataConfirm => 'Confirm';

  @override
  String get scrapeMetadataSuccess => 'Name and cover updated.';

  @override
  String get scrapeMetadataCoverFailed =>
      'Name updated. Cover failed; you can set it manually.';

  @override
  String get scrapeMetadataEnterName => 'Please enter a game name.';

  @override
  String get scrapeMetadataSourceError =>
      'Source unavailable. Try again later.';

  @override
  String get scrapeMetadataSelectOne => 'Please select a game.';

  @override
  String get scrapeAfterAddPrompt =>
      'Scrape this game? Choose Yes to search and fill in name and cover.';

  @override
  String get scrapeAfterAddNo => 'No';

  @override
  String get scrapeAfterAddYes => 'Yes';
}
