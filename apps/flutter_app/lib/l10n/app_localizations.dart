import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('zh'),
  ];

  /// No description provided for @managerAuthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize Folder'**
  String get managerAuthorize;

  /// No description provided for @managerAuthorizationHint.
  ///
  /// In en, this message translates to:
  /// **'Select this app’s folder inside Downloads. Other folders cannot be managed.'**
  String get managerAuthorizationHint;

  /// No description provided for @managerEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get managerEmpty;

  /// No description provided for @managerNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get managerNewFolder;

  /// No description provided for @managerSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get managerSelect;

  /// No description provided for @managerSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get managerSelectAll;

  /// No description provided for @managerDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get managerDone;

  /// No description provided for @managerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get managerCancel;

  /// No description provided for @managerCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get managerCopy;

  /// No description provided for @managerMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get managerMove;

  /// No description provided for @managerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get managerRename;

  /// No description provided for @managerRenameExtensionTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the file extension?'**
  String get managerRenameExtensionTitle;

  /// No description provided for @managerRenameExtensionMessage.
  ///
  /// In en, this message translates to:
  /// **'Changing the extension from {from} to {to} may change how this file is classified (preview, extract, game data). Only continue if you meant to do that.'**
  String managerRenameExtensionMessage(String from, String to);

  /// No description provided for @managerRenameExtensionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get managerRenameExtensionContinue;

  /// No description provided for @managerNoExtension.
  ///
  /// In en, this message translates to:
  /// **'no extension'**
  String get managerNoExtension;

  /// No description provided for @managerTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to Recently Deleted'**
  String get managerTrash;

  /// No description provided for @managerRecentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recently Deleted'**
  String get managerRecentlyDeleted;

  /// No description provided for @managerTrashHint.
  ///
  /// In en, this message translates to:
  /// **'These items still use storage. Nothing is deleted automatically.'**
  String get managerTrashHint;

  /// No description provided for @managerTrashConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move selected items to Recently Deleted?'**
  String get managerTrashConfirm;

  /// No description provided for @managerTrashExplanation.
  ///
  /// In en, this message translates to:
  /// **'You can restore them later. Game history and private saves will be kept.'**
  String get managerTrashExplanation;

  /// No description provided for @managerRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get managerRestore;

  /// No description provided for @managerDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get managerDeletePermanently;

  /// No description provided for @managerPermanentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this item?'**
  String get managerPermanentConfirm;

  /// No description provided for @managerPermanentExplanation.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Private game saves are not included.'**
  String get managerPermanentExplanation;

  /// No description provided for @managerChooseDestination.
  ///
  /// In en, this message translates to:
  /// **'Choose Destination'**
  String get managerChooseDestination;

  /// No description provided for @managerUseFolder.
  ///
  /// In en, this message translates to:
  /// **'Use This Folder'**
  String get managerUseFolder;

  /// No description provided for @managerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get managerName;

  /// No description provided for @managerExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get managerExtract;

  /// No description provided for @managerExtractTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract Archive'**
  String get managerExtractTitle;

  /// No description provided for @managerPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (if required)'**
  String get managerPassword;

  /// No description provided for @managerEncoding.
  ///
  /// In en, this message translates to:
  /// **'Legacy Filename Encoding'**
  String get managerEncoding;

  /// No description provided for @managerExtractHint.
  ///
  /// In en, this message translates to:
  /// **'Extract to a new folder and keep the archive. Unicode names in the archive take priority.'**
  String get managerExtractHint;

  /// No description provided for @managerWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get managerWorking;

  /// No description provided for @managerCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get managerCompleted;

  /// No description provided for @managerRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get managerRetry;

  /// No description provided for @managerErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled.'**
  String get managerErrorCancelled;

  /// No description provided for @managerErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current file operation to finish.'**
  String get managerErrorBusy;

  /// No description provided for @managerErrorInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Use a valid name without path separators or reserved characters.'**
  String get managerErrorInvalidName;

  /// No description provided for @managerErrorOutsideRoot.
  ///
  /// In en, this message translates to:
  /// **'Only this app’s dedicated Downloads folder can be managed.'**
  String get managerErrorOutsideRoot;

  /// No description provided for @managerErrorProtectedDirectory.
  ///
  /// In en, this message translates to:
  /// **'This folder is reserved. Manage the items inside it instead.'**
  String get managerErrorProtectedDirectory;

  /// No description provided for @managerErrorUnsupportedLink.
  ///
  /// In en, this message translates to:
  /// **'Links and special files cannot be processed.'**
  String get managerErrorUnsupportedLink;

  /// No description provided for @managerErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The file or destination folder no longer exists.'**
  String get managerErrorNotFound;

  /// No description provided for @managerErrorConflict.
  ///
  /// In en, this message translates to:
  /// **'An item with that name already exists. Nothing was overwritten.'**
  String get managerErrorConflict;

  /// No description provided for @managerErrorRecursiveTarget.
  ///
  /// In en, this message translates to:
  /// **'An item cannot be placed inside itself.'**
  String get managerErrorRecursiveTarget;

  /// No description provided for @managerErrorTrashCorrupt.
  ///
  /// In en, this message translates to:
  /// **'This Recently Deleted record could not be read. No files were removed.'**
  String get managerErrorTrashCorrupt;

  /// No description provided for @managerErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access is unavailable. Check folder authorization and permissions.'**
  String get managerErrorPermissionDenied;

  /// No description provided for @managerErrorNoSpace.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage. Free up space and try again.'**
  String get managerErrorNoSpace;

  /// No description provided for @managerErrorReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This location is read-only.'**
  String get managerErrorReadOnly;

  /// No description provided for @managerErrorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'This archive requires a password.'**
  String get managerErrorPasswordRequired;

  /// No description provided for @managerErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect, or the encrypted header is damaged.'**
  String get managerErrorWrongPassword;

  /// No description provided for @managerErrorMissingVolume.
  ///
  /// In en, this message translates to:
  /// **'A volume is missing. Keep all volumes together with their original numbering.'**
  String get managerErrorMissingVolume;

  /// No description provided for @managerErrorUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'This archive format is not supported or could not be recognized.'**
  String get managerErrorUnsupportedFormat;

  /// No description provided for @managerErrorUnsupportedMethod.
  ///
  /// In en, this message translates to:
  /// **'This archive uses an unsupported compression method.'**
  String get managerErrorUnsupportedMethod;

  /// No description provided for @managerErrorCorruptArchive.
  ///
  /// In en, this message translates to:
  /// **'The archive is incomplete or damaged. Check all volumes and the password.'**
  String get managerErrorCorruptArchive;

  /// No description provided for @managerErrorInvalidEncoding.
  ///
  /// In en, this message translates to:
  /// **'The filename encoding could not be decoded. Choose another encoding and try again.'**
  String get managerErrorInvalidEncoding;

  /// No description provided for @managerErrorUnsafeArchivePath.
  ///
  /// In en, this message translates to:
  /// **'The archive contains unsafe paths. Extraction was stopped.'**
  String get managerErrorUnsafeArchivePath;

  /// No description provided for @managerErrorArchiveLimit.
  ///
  /// In en, this message translates to:
  /// **'The archive exceeds the file count or expanded size safety limit.'**
  String get managerErrorArchiveLimit;

  /// No description provided for @managerErrorGameRunning.
  ///
  /// In en, this message translates to:
  /// **'Exit the game before changing its files.'**
  String get managerErrorGameRunning;

  /// No description provided for @managerErrorUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Folder access is not available on this platform yet.'**
  String get managerErrorUnsupportedPlatform;

  /// No description provided for @managerErrorFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed. Check the affected items before trying again.'**
  String get managerErrorFailed;

  /// No description provided for @managerItemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String managerItemsSelected(int count);

  /// No description provided for @managerDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get managerDetails;

  /// No description provided for @managerDetailKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get managerDetailKind;

  /// No description provided for @managerDetailFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get managerDetailFolder;

  /// No description provided for @managerDetailFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get managerDetailFile;

  /// No description provided for @managerDetailArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get managerDetailArchive;

  /// No description provided for @managerDetailGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get managerDetailGame;

  /// No description provided for @managerDetailImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get managerDetailImage;

  /// No description provided for @managerDetailAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get managerDetailAudio;

  /// No description provided for @managerDetailVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get managerDetailVideo;

  /// No description provided for @managerDetailText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get managerDetailText;

  /// No description provided for @managerDetailGameData.
  ///
  /// In en, this message translates to:
  /// **'Game data'**
  String get managerDetailGameData;

  /// No description provided for @managerTextEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file is empty.'**
  String get managerTextEmpty;

  /// No description provided for @managerTextTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 2 MB of this file.'**
  String get managerTextTruncated;

  /// No description provided for @managerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get managerPlay;

  /// No description provided for @managerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get managerPause;

  /// No description provided for @managerPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get managerPreview;

  /// No description provided for @managerMediaFailed.
  ///
  /// In en, this message translates to:
  /// **'This file could not be opened.'**
  String get managerMediaFailed;

  /// No description provided for @managerDetailSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get managerDetailSize;

  /// No description provided for @managerDetailItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String managerDetailItems(int count);

  /// No description provided for @managerDetailModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get managerDetailModified;

  /// No description provided for @managerDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get managerDetailLocation;

  /// No description provided for @managerCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get managerCalculating;

  /// No description provided for @managerEncodingUtf8.
  ///
  /// In en, this message translates to:
  /// **'UTF-8'**
  String get managerEncodingUtf8;

  /// No description provided for @managerEncodingGb18030.
  ///
  /// In en, this message translates to:
  /// **'GB18030'**
  String get managerEncodingGb18030;

  /// No description provided for @managerEncodingCp932.
  ///
  /// In en, this message translates to:
  /// **'Shift_JIS'**
  String get managerEncodingCp932;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NextScene'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addGame.
  ///
  /// In en, this message translates to:
  /// **'Add Game'**
  String get addGame;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @howToImport.
  ///
  /// In en, this message translates to:
  /// **'How to Import'**
  String get howToImport;

  /// No description provided for @noGamesYet.
  ///
  /// In en, this message translates to:
  /// **'No games added yet'**
  String get noGamesYet;

  /// No description provided for @noGamesHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click \"Add Game\" to select a game directory'**
  String get noGamesHintDesktop;

  /// No description provided for @noGamesHintIos.
  ///
  /// In en, this message translates to:
  /// **'Use the Files app to copy game folders to:\nOn My iPhone > {appName} > Games\nThen tap \"Refresh\"'**
  String noGamesHintIos(String appName);

  /// No description provided for @importGames.
  ///
  /// In en, this message translates to:
  /// **'Import Games'**
  String get importGames;

  /// No description provided for @importGamesDesc.
  ///
  /// In en, this message translates to:
  /// **'Please copy your game folders to this app\'s directory using the Files app:'**
  String get importGamesDesc;

  /// No description provided for @importStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Open the \"Files\" app on your iPhone'**
  String get importStep1;

  /// No description provided for @importStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Go to: On My iPhone > {appName} > Games'**
  String importStep2(String appName);

  /// No description provided for @importStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Copy your game folder into the Games directory'**
  String get importStep3;

  /// No description provided for @importStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Come back and tap \"Refresh\" to detect new games'**
  String get importStep4;

  /// No description provided for @macosImportTip.
  ///
  /// In en, this message translates to:
  /// **'Note: Please select the folder containing the XP3 file first before select the target XP3 file due to macOS sandbox restrictions'**
  String get macosImportTip;

  /// No description provided for @gamesDirectory.
  ///
  /// In en, this message translates to:
  /// **'Games directory: Games/'**
  String get gamesDirectory;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabHome;

  /// No description provided for @tabExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// No description provided for @tabManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get tabManage;

  /// No description provided for @tabStatistics.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get tabStatistics;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabProfile;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchGamesHint.
  ///
  /// In en, this message translates to:
  /// **'Search games'**
  String get searchGamesHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching games'**
  String get searchNoResults;

  /// No description provided for @searchComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Search is coming soon'**
  String get searchComingSoon;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @profilePlayTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Play Time'**
  String get profilePlayTimeTitle;

  /// No description provided for @profileLifetime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get profileLifetime;

  /// No description provided for @profileLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get profileLast7Days;

  /// No description provided for @profileTrackingHint.
  ///
  /// In en, this message translates to:
  /// **'Your activity trend starts here'**
  String get profileTrackingHint;

  /// No description provided for @profileActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active Days'**
  String get profileActiveDays;

  /// No description provided for @profileGamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games Played'**
  String get profileGamesPlayed;

  /// No description provided for @profileAverageSession.
  ///
  /// In en, this message translates to:
  /// **'Avg. Session'**
  String get profileAverageSession;

  /// No description provided for @profileTopGames.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get profileTopGames;

  /// No description provided for @profileStatistics.
  ///
  /// In en, this message translates to:
  /// **'Play Statistics'**
  String get profileStatistics;

  /// No description provided for @profileViewStatistics.
  ///
  /// In en, this message translates to:
  /// **'View Detailed Statistics'**
  String get profileViewStatistics;

  /// No description provided for @profileHonorTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get profileHonorTitle;

  /// No description provided for @profileHonorNextUnlock.
  ///
  /// In en, this message translates to:
  /// **'Next title'**
  String get profileHonorNextUnlock;

  /// No description provided for @profileHonorNewcomer.
  ///
  /// In en, this message translates to:
  /// **'New Arrival'**
  String get profileHonorNewcomer;

  /// No description provided for @profileHonorStoryTraveler.
  ///
  /// In en, this message translates to:
  /// **'Story Traveler'**
  String get profileHonorStoryTraveler;

  /// No description provided for @profileHonorImmersedReader.
  ///
  /// In en, this message translates to:
  /// **'Immersed Reader'**
  String get profileHonorImmersedReader;

  /// No description provided for @profileHonorVeteran.
  ///
  /// In en, this message translates to:
  /// **'Seasoned Player'**
  String get profileHonorVeteran;

  /// No description provided for @profileHonorCollector.
  ///
  /// In en, this message translates to:
  /// **'Game Collector'**
  String get profileHonorCollector;

  /// No description provided for @profileHonorCurator.
  ///
  /// In en, this message translates to:
  /// **'Archive Curator'**
  String get profileHonorCurator;

  /// No description provided for @profileHonorNext.
  ///
  /// In en, this message translates to:
  /// **'Next · {title}'**
  String profileHonorNext(String title);

  /// No description provided for @profileHonorRemainingBoth.
  ///
  /// In en, this message translates to:
  /// **'{duration} and {count} more games to go'**
  String profileHonorRemainingBoth(String duration, int count);

  /// No description provided for @profileHonorRemainingTime.
  ///
  /// In en, this message translates to:
  /// **'{duration} to go'**
  String profileHonorRemainingTime(String duration);

  /// No description provided for @profileHonorRemainingGames.
  ///
  /// In en, this message translates to:
  /// **'{count} more games to go'**
  String profileHonorRemainingGames(int count);

  /// No description provided for @profileHonorHighest.
  ///
  /// In en, this message translates to:
  /// **'Top title reached'**
  String get profileHonorHighest;

  /// No description provided for @profileHonorCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get profileHonorCurrent;

  /// No description provided for @profileHonorObtained.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get profileHonorObtained;

  /// No description provided for @profileHonorLocked.
  ///
  /// In en, this message translates to:
  /// **'Not earned'**
  String get profileHonorLocked;

  /// No description provided for @profileGameRecords.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get profileGameRecords;

  /// No description provided for @profileLocalSummary.
  ///
  /// In en, this message translates to:
  /// **'On This Device'**
  String get profileLocalSummary;

  /// No description provided for @profileLibraryCount.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get profileLibraryCount;

  /// No description provided for @profileRecentGame.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get profileRecentGame;

  /// No description provided for @profileNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get profileNoHistory;

  /// No description provided for @profilePlaySummary.
  ///
  /// In en, this message translates to:
  /// **'{duration} played · {count} games'**
  String profilePlaySummary(String duration, int count);

  /// No description provided for @playTimeLessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 min'**
  String get playTimeLessThanMinute;

  /// No description provided for @playTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String playTimeMinutes(int minutes);

  /// No description provided for @playTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr'**
  String playTimeHours(int hours);

  /// No description provided for @playTimeHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String playTimeHoursMinutes(int hours, int minutes);

  /// No description provided for @helpIntro.
  ///
  /// In en, this message translates to:
  /// **'This page covers importing games, where to store them, file management, and how play time is recorded.'**
  String get helpIntro;

  /// No description provided for @helpSectionLibrary.
  ///
  /// In en, this message translates to:
  /// **'Import and launch'**
  String get helpSectionLibrary;

  /// No description provided for @helpSectionFiles.
  ///
  /// In en, this message translates to:
  /// **'Files and metadata'**
  String get helpSectionFiles;

  /// No description provided for @helpSectionMore.
  ///
  /// In en, this message translates to:
  /// **'Statistics and settings'**
  String get helpSectionMore;

  /// No description provided for @helpFaqImportQ.
  ///
  /// In en, this message translates to:
  /// **'Adding a game to the library'**
  String get helpFaqImportQ;

  /// No description provided for @helpFaqImportA.
  ///
  /// In en, this message translates to:
  /// **'On Library, tap Add Game and choose a complete game directory, or an XP3 / PFS pack. On HarmonyOS you can also place the directory in the app\'s public games path, then return to the home screen and pull down to refresh.'**
  String get helpFaqImportA;

  /// No description provided for @helpFaqOhosQ.
  ///
  /// In en, this message translates to:
  /// **'Storage location on HarmonyOS'**
  String get helpFaqOhosQ;

  /// No description provided for @helpFaqOhosA.
  ///
  /// In en, this message translates to:
  /// **'In the system Files app, copy the complete game directory to:\n{path}\nThis app only reads and writes its own folder under Download.'**
  String helpFaqOhosA(String path);

  /// No description provided for @helpFaqIosQ.
  ///
  /// In en, this message translates to:
  /// **'Copying a game on iPhone'**
  String get helpFaqIosQ;

  /// No description provided for @helpFaqIosA.
  ///
  /// In en, this message translates to:
  /// **'Open Files, copy the game folder to On My iPhone > {appName} > Games, then return here and tap Refresh.'**
  String helpFaqIosA(String appName);

  /// No description provided for @helpFaqLaunchQ.
  ///
  /// In en, this message translates to:
  /// **'Tap and touch-and-hold'**
  String get helpFaqLaunchQ;

  /// No description provided for @helpFaqLaunchA.
  ///
  /// In en, this message translates to:
  /// **'Tap a card to open details, then launch from there. Touch and hold to launch, scrape the title and cover, rename, or remove the entry from the list without opening details.'**
  String get helpFaqLaunchA;

  /// No description provided for @helpFaqManageQ.
  ///
  /// In en, this message translates to:
  /// **'What you can do on Manage'**
  String get helpFaqManageQ;

  /// No description provided for @helpFaqManageA.
  ///
  /// In en, this message translates to:
  /// **'Inside the authorised app folder you can copy, move, rename, extract archives, and view details. The root, games, and private save folders are protected and cannot be deleted like ordinary files.'**
  String get helpFaqManageA;

  /// No description provided for @helpFaqArchiveQ.
  ///
  /// In en, this message translates to:
  /// **'Archives and split volumes'**
  String get helpFaqArchiveQ;

  /// No description provided for @helpFaqArchiveA.
  ///
  /// In en, this message translates to:
  /// **'zip, 7z and rar archives can be extracted on Manage. Keep split XP3 volumes in the same folder. Extraction and import do not rewrite game scripts.'**
  String get helpFaqArchiveA;

  /// No description provided for @helpFaqRemoveQ.
  ///
  /// In en, this message translates to:
  /// **'Does removing a game delete the files?'**
  String get helpFaqRemoveQ;

  /// No description provided for @helpFaqRemoveA.
  ///
  /// In en, this message translates to:
  /// **'No. Removal only takes the entry off the list. The folder stays on disk. Delete files from Manage.'**
  String get helpFaqRemoveA;

  /// No description provided for @helpFaqMetadataQ.
  ///
  /// In en, this message translates to:
  /// **'Filling in a title and cover'**
  String get helpFaqMetadataQ;

  /// No description provided for @helpFaqMetadataA.
  ///
  /// In en, this message translates to:
  /// **'After adding a game, or from the touch-and-hold menu, choose Scrape info and search VNDB by title. Only the display name and cover change.'**
  String get helpFaqMetadataA;

  /// No description provided for @helpFaqStatsQ.
  ///
  /// In en, this message translates to:
  /// **'How play time is recorded'**
  String get helpFaqStatsQ;

  /// No description provided for @helpFaqStatsA.
  ///
  /// In en, this message translates to:
  /// **'Time from launch to a normal exit is stored as one session and shown on Stats. If the process is force-stopped, that session may not be recorded.'**
  String get helpFaqStatsA;

  /// No description provided for @helpFaqControlsQ.
  ///
  /// In en, this message translates to:
  /// **'Playing without a keyboard or mouse'**
  String get helpFaqControlsQ;

  /// No description provided for @helpFaqControlsA.
  ///
  /// In en, this message translates to:
  /// **'On-screen keys cover confirm, back, skip and direction. Use the layout shown during play.'**
  String get helpFaqControlsA;

  /// No description provided for @helpFaqSettingsQ.
  ///
  /// In en, this message translates to:
  /// **'Language and appearance'**
  String get helpFaqSettingsQ;

  /// No description provided for @helpFaqSettingsA.
  ///
  /// In en, this message translates to:
  /// **'Open Settings from Me to change the language, and to choose light, dark or system appearance. Some engine options take effect only after a restart.'**
  String get helpFaqSettingsA;

  /// No description provided for @helpFaqCompatQ.
  ///
  /// In en, this message translates to:
  /// **'Which titles are supported'**
  String get helpFaqCompatQ;

  /// No description provided for @helpFaqCompatA.
  ///
  /// In en, this message translates to:
  /// **'This app runs KiriKiri2 and Artemis titles. It is not an official release. A title may fail to start if assets are missing, an instruction is unimplemented, or the encryption is unsupported.'**
  String get helpFaqCompatA;

  /// No description provided for @removeGame.
  ///
  /// In en, this message translates to:
  /// **'Remove Game'**
  String get removeGame;

  /// No description provided for @removeGameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from the list?\nThis will NOT delete the game files.'**
  String removeGameConfirm(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @renameGame.
  ///
  /// In en, this message translates to:
  /// **'Rename Game'**
  String get renameGame;

  /// No description provided for @displayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Title'**
  String get displayTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @gameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Game already exists: {title}'**
  String gameAlreadyExists(String title);

  /// No description provided for @builtInReady.
  ///
  /// In en, this message translates to:
  /// **'Built-in ✓'**
  String get builtInReady;

  /// No description provided for @builtInNotReady.
  ///
  /// In en, this message translates to:
  /// **'Built-in ✗'**
  String get builtInNotReady;

  /// No description provided for @customNotSet.
  ///
  /// In en, this message translates to:
  /// **'Custom (not set)'**
  String get customNotSet;

  /// No description provided for @engineNotFoundBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in engine not found. Please use the build script to bundle the engine, or switch to Custom mode in Settings.'**
  String get engineNotFoundBuiltIn;

  /// No description provided for @engineNotFoundCustom.
  ///
  /// In en, this message translates to:
  /// **'Engine dylib not set. Please configure it in Settings first.'**
  String get engineNotFoundCustom;

  /// No description provided for @lastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played: {time}'**
  String lastPlayed(String time);

  /// No description provided for @playDuration.
  ///
  /// In en, this message translates to:
  /// **'Played {duration}'**
  String playDuration(String duration);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @setCover.
  ///
  /// In en, this message translates to:
  /// **'Set Cover'**
  String get setCover;

  /// No description provided for @coverFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get coverFromGallery;

  /// No description provided for @coverFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get coverFromCamera;

  /// No description provided for @coverRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get coverRemove;

  /// No description provided for @settingsEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get settingsEngine;

  /// No description provided for @engineMode.
  ///
  /// In en, this message translates to:
  /// **'Engine Mode'**
  String get engineMode;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @builtInEngineAvailable.
  ///
  /// In en, this message translates to:
  /// **'Built-in engine available'**
  String get builtInEngineAvailable;

  /// No description provided for @builtInEngineNotFound.
  ///
  /// In en, this message translates to:
  /// **'Built-in engine not found'**
  String get builtInEngineNotFound;

  /// No description provided for @builtInEngineHint.
  ///
  /// In en, this message translates to:
  /// **'Use the build script to compile and bundle the engine into the app.'**
  String get builtInEngineHint;

  /// No description provided for @engineDylibPath.
  ///
  /// In en, this message translates to:
  /// **'Engine dylib path'**
  String get engineDylibPath;

  /// No description provided for @notSetRequired.
  ///
  /// In en, this message translates to:
  /// **'Not set (required)'**
  String get notSetRequired;

  /// No description provided for @clearPath.
  ///
  /// In en, this message translates to:
  /// **'Clear path'**
  String get clearPath;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse...'**
  String get browse;

  /// No description provided for @selectEngineDylib.
  ///
  /// In en, this message translates to:
  /// **'Select Engine dylib'**
  String get selectEngineDylib;

  /// No description provided for @settingsRendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering'**
  String get settingsRendering;

  /// No description provided for @renderPipeline.
  ///
  /// In en, this message translates to:
  /// **'Render Pipeline'**
  String get renderPipeline;

  /// No description provided for @renderPipelineHint.
  ///
  /// In en, this message translates to:
  /// **'Render pipeline and graphics backend take effect after restarting the app'**
  String get renderPipelineHint;

  /// No description provided for @restartRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get restartRequiredTitle;

  /// No description provided for @restartRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This change takes effect after the app restarts.'**
  String get restartRequiredMessage;

  /// No description provided for @applyAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Apply and restart'**
  String get applyAndRestart;

  /// No description provided for @restartPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'Saved changes are not in effect yet. Restart the app, or tap here to restart now.'**
  String get restartPendingBanner;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart app'**
  String get restartNow;

  /// No description provided for @opengl.
  ///
  /// In en, this message translates to:
  /// **'OpenGL'**
  String get opengl;

  /// No description provided for @software.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get software;

  /// No description provided for @graphicsBackend.
  ///
  /// In en, this message translates to:
  /// **'Graphics Backend'**
  String get graphicsBackend;

  /// No description provided for @graphicsBackendHint.
  ///
  /// In en, this message translates to:
  /// **'ANGLE translation layer backend (Android only). Requires restart.'**
  String get graphicsBackendHint;

  /// No description provided for @opengles.
  ///
  /// In en, this message translates to:
  /// **'OpenGL ES'**
  String get opengles;

  /// No description provided for @vulkan.
  ///
  /// In en, this message translates to:
  /// **'Vulkan'**
  String get vulkan;

  /// No description provided for @performanceOverlay.
  ///
  /// In en, this message translates to:
  /// **'Performance Overlay'**
  String get performanceOverlay;

  /// No description provided for @performanceOverlayDesc.
  ///
  /// In en, this message translates to:
  /// **'Show FPS and graphics API info'**
  String get performanceOverlayDesc;

  /// No description provided for @fpsLimitEnabled.
  ///
  /// In en, this message translates to:
  /// **'Frame Rate Limit'**
  String get fpsLimitEnabled;

  /// No description provided for @fpsLimitEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Limit engine rendering frequency to save power'**
  String get fpsLimitEnabledDesc;

  /// No description provided for @fpsLimitOff.
  ///
  /// In en, this message translates to:
  /// **'Off (VSync)'**
  String get fpsLimitOff;

  /// No description provided for @forceLandscape.
  ///
  /// In en, this message translates to:
  /// **'Lock Landscape'**
  String get forceLandscape;

  /// No description provided for @forceLandscapeDesc.
  ///
  /// In en, this message translates to:
  /// **'Force landscape orientation when running games (recommended for phones)'**
  String get forceLandscapeDesc;

  /// No description provided for @targetFrameRate.
  ///
  /// In en, this message translates to:
  /// **'Target Frame Rate'**
  String get targetFrameRate;

  /// No description provided for @targetFrameRateDesc.
  ///
  /// In en, this message translates to:
  /// **'Maximum rendering frequency when limit is enabled'**
  String get targetFrameRateDesc;

  /// No description provided for @fpsLabel.
  ///
  /// In en, this message translates to:
  /// **'{fps} FPS'**
  String fpsLabel(int fps);

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageJa.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJa;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @legalTabOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get legalTabOpenSource;

  /// No description provided for @legalTabPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get legalTabPrivacy;

  /// No description provided for @legalTabDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get legalTabDisclaimer;

  /// No description provided for @legalOpenSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get legalOpenSourceTitle;

  /// No description provided for @legalPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy statement'**
  String get legalPrivacyTitle;

  /// No description provided for @legalDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get legalDisclaimerTitle;

  /// No description provided for @legalUpdated.
  ///
  /// In en, this message translates to:
  /// **'Prepared by reference to the implementation dated {date}.'**
  String legalUpdated(String date);

  /// No description provided for @gameEngineError.
  ///
  /// In en, this message translates to:
  /// **'Engine Error'**
  String get gameEngineError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @hideDebug.
  ///
  /// In en, this message translates to:
  /// **'Close Debug Log'**
  String get hideDebug;

  /// No description provided for @showDebug.
  ///
  /// In en, this message translates to:
  /// **'Open Debug Log'**
  String get showDebug;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @exitGame.
  ///
  /// In en, this message translates to:
  /// **'Exit Game'**
  String get exitGame;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardChangesMessage;

  /// No description provided for @gameTypeXp3.
  ///
  /// In en, this message translates to:
  /// **'XP3 archive'**
  String get gameTypeXp3;

  /// No description provided for @gameTypeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get gameTypeDirectory;

  /// No description provided for @archiveNotExist.
  ///
  /// In en, this message translates to:
  /// **'Archive file does not exist: {path}'**
  String archiveNotExist(String path);

  /// No description provided for @gamePathNotExist.
  ///
  /// In en, this message translates to:
  /// **'Game path does not exist: {path}'**
  String gamePathNotExist(String path);

  /// No description provided for @missingStartupScript.
  ///
  /// In en, this message translates to:
  /// **'Missing startup script in: {path}\n(looked for startup.tjs and data/system/initialize.tjs)'**
  String missingStartupScript(String path);

  /// No description provided for @gamePathCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Game path check failed: {error}'**
  String gamePathCheckFailed(String error);

  /// No description provided for @androidAllFilesAccess.
  ///
  /// In en, this message translates to:
  /// **'All files access is required on Android. Please grant permission and open the game again.'**
  String get androidAllFilesAccess;

  /// No description provided for @noXp3InFolder.
  ///
  /// In en, this message translates to:
  /// **'No XP3 archive or Artemis pack (.pfs) found in the selected folder.'**
  String get noXp3InFolder;

  /// No description provided for @gameTypeArtemis.
  ///
  /// In en, this message translates to:
  /// **'Artemis pack (.pfs)'**
  String get gameTypeArtemis;

  /// No description provided for @gameEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine: {engine}'**
  String gameEngine(String engine);

  /// No description provided for @missingArtemisPack.
  ///
  /// In en, this message translates to:
  /// **'No Artemis pack (.pfs) found in: {path}'**
  String missingArtemisPack(String path);

  /// No description provided for @rescanGamesDir.
  ///
  /// In en, this message translates to:
  /// **'Rescan Directory'**
  String get rescanGamesDir;

  /// No description provided for @rescanGamesDirDesc.
  ///
  /// In en, this message translates to:
  /// **'Find games dropped into {path} or sent in with hdc (XP3 / Artemis .pfs)'**
  String rescanGamesDirDesc(String path);

  /// No description provided for @noGamesFoundInSandbox.
  ///
  /// In en, this message translates to:
  /// **'No games found in the games folder or app sandbox.'**
  String get noGamesFoundInSandbox;

  /// No description provided for @allSandboxGamesRegistered.
  ///
  /// In en, this message translates to:
  /// **'All games found are already in the library.'**
  String get allSandboxGamesRegistered;

  /// No description provided for @noNewGamesFound.
  ///
  /// In en, this message translates to:
  /// **'No new games found.'**
  String get noNewGamesFound;

  /// No description provided for @noGamesHintOhos.
  ///
  /// In en, this message translates to:
  /// **'Use the Files app to copy a game folder to:\n{path}\nthen pull down to refresh'**
  String noGamesHintOhos(String path);

  /// No description provided for @settingsGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get settingsGames;

  /// No description provided for @publicGamesDir.
  ///
  /// In en, this message translates to:
  /// **'Games Folder'**
  String get publicGamesDir;

  /// No description provided for @publicGamesDirHint.
  ///
  /// In en, this message translates to:
  /// **'Copy a whole game folder into {path} with the Files app, then pull down on the home page to refresh. Tap to copy the path.'**
  String publicGamesDirHint(String path);

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// No description provided for @releaseToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Release to refresh'**
  String get releaseToRefresh;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing'**
  String get refreshing;

  /// No description provided for @refreshDone.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get refreshDone;

  /// No description provided for @screenOrientation.
  ///
  /// In en, this message translates to:
  /// **'Screen Orientation'**
  String get screenOrientation;

  /// No description provided for @screenOrientationDesc.
  ///
  /// In en, this message translates to:
  /// **'Orientation used while a game is running'**
  String get screenOrientationDesc;

  /// No description provided for @orientationAuto.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get orientationAuto;

  /// No description provided for @orientationLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get orientationLandscape;

  /// No description provided for @orientationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get orientationPortrait;

  /// No description provided for @rotateScreen.
  ///
  /// In en, this message translates to:
  /// **'Rotate Screen'**
  String get rotateScreen;

  /// No description provided for @showVirtualControls.
  ///
  /// In en, this message translates to:
  /// **'Show virtual controls'**
  String get showVirtualControls;

  /// No description provided for @hideVirtualControls.
  ///
  /// In en, this message translates to:
  /// **'Hide virtual controls'**
  String get hideVirtualControls;

  /// No description provided for @virtualTouchpad.
  ///
  /// In en, this message translates to:
  /// **'Touchpad · tap to click'**
  String get virtualTouchpad;

  /// No description provided for @virtualMouseLeft.
  ///
  /// In en, this message translates to:
  /// **'Left click'**
  String get virtualMouseLeft;

  /// No description provided for @virtualMouseRight.
  ///
  /// In en, this message translates to:
  /// **'Right click'**
  String get virtualMouseRight;

  /// No description provided for @virtualConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm (Enter)'**
  String get virtualConfirm;

  /// No description provided for @virtualBack.
  ///
  /// In en, this message translates to:
  /// **'Back (Esc)'**
  String get virtualBack;

  /// No description provided for @virtualAdvance.
  ///
  /// In en, this message translates to:
  /// **'Advance (Space)'**
  String get virtualAdvance;

  /// No description provided for @virtualSkip.
  ///
  /// In en, this message translates to:
  /// **'Hold to skip (Ctrl)'**
  String get virtualSkip;

  /// No description provided for @virtualUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get virtualUp;

  /// No description provided for @virtualDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get virtualDown;

  /// No description provided for @virtualLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get virtualLeft;

  /// No description provided for @virtualRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get virtualRight;

  /// No description provided for @gameStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get gameStarting;

  /// No description provided for @gamePreparingEngine.
  ///
  /// In en, this message translates to:
  /// **'Preparing engine'**
  String get gamePreparingEngine;

  /// No description provided for @gameOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening game'**
  String get gameOpening;

  /// No description provided for @gameLoadingResources.
  ///
  /// In en, this message translates to:
  /// **'Loading resources'**
  String get gameLoadingResources;

  /// No description provided for @gameBootLogs.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get gameBootLogs;

  /// No description provided for @gameHideBootLogs.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get gameHideBootLogs;

  /// No description provided for @engineRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'The engine is already running another game. Restart the app to play a different one.'**
  String get engineRestartRequired;

  /// No description provided for @gamesImported.
  ///
  /// In en, this message translates to:
  /// **'{count} games imported'**
  String gamesImported(int count);

  /// No description provided for @selectGameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Game Directory'**
  String get selectGameDirectory;

  /// No description provided for @selectGameArchive.
  ///
  /// In en, this message translates to:
  /// **'Select Game Archive'**
  String get selectGameArchive;

  /// No description provided for @addArchive.
  ///
  /// In en, this message translates to:
  /// **'Add XP3'**
  String get addArchive;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @packXp3.
  ///
  /// In en, this message translates to:
  /// **'Pack as XP3'**
  String get packXp3;

  /// No description provided for @unpackXp3.
  ///
  /// In en, this message translates to:
  /// **'Unpack XP3'**
  String get unpackXp3;

  /// No description provided for @packingProgress.
  ///
  /// In en, this message translates to:
  /// **'Packing...'**
  String get packingProgress;

  /// No description provided for @unpackingProgress.
  ///
  /// In en, this message translates to:
  /// **'Unpacking...'**
  String get unpackingProgress;

  /// No description provided for @packComplete.
  ///
  /// In en, this message translates to:
  /// **'Packed successfully'**
  String get packComplete;

  /// No description provided for @unpackComplete.
  ///
  /// In en, this message translates to:
  /// **'Unpacked successfully'**
  String get unpackComplete;

  /// No description provided for @xp3OperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String xp3OperationFailed(String error);

  /// No description provided for @launchGame.
  ///
  /// In en, this message translates to:
  /// **'Launch Game'**
  String get launchGame;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @gameFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get gameFormat;

  /// No description provided for @gamePath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get gamePath;

  /// No description provided for @gameDescription.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get gameDescription;

  /// No description provided for @gameKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get gameKeywords;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get showLess;

  /// No description provided for @scrapeMetadata.
  ///
  /// In en, this message translates to:
  /// **'Scrape info'**
  String get scrapeMetadata;

  /// No description provided for @scrapeMetadataDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Scrape info'**
  String get scrapeMetadataDialogTitle;

  /// No description provided for @scrapeMetadataSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter game name to search'**
  String get scrapeMetadataSearchHint;

  /// No description provided for @scrapeMetadataSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get scrapeMetadataSearch;

  /// No description provided for @scrapeMetadataSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select matching game'**
  String get scrapeMetadataSelectTitle;

  /// No description provided for @scrapeMetadataNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching games. Try another keyword.'**
  String get scrapeMetadataNoResults;

  /// No description provided for @scrapeMetadataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get scrapeMetadataConfirm;

  /// No description provided for @scrapeMetadataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Name and cover updated.'**
  String get scrapeMetadataSuccess;

  /// No description provided for @scrapeMetadataCoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Name updated. Cover failed; you can set it manually.'**
  String get scrapeMetadataCoverFailed;

  /// No description provided for @scrapeMetadataEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a game name.'**
  String get scrapeMetadataEnterName;

  /// No description provided for @scrapeMetadataSourceError.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable. Try again later.'**
  String get scrapeMetadataSourceError;

  /// No description provided for @scrapeMetadataSelectOne.
  ///
  /// In en, this message translates to:
  /// **'Please select a game.'**
  String get scrapeMetadataSelectOne;

  /// No description provided for @scrapeAfterAddPrompt.
  ///
  /// In en, this message translates to:
  /// **'Scrape this game? Choose Yes to search and fill in name and cover.'**
  String get scrapeAfterAddPrompt;

  /// No description provided for @scrapeAfterAddNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get scrapeAfterAddNo;

  /// No description provided for @scrapeAfterAddYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get scrapeAfterAddYes;
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
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

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
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
