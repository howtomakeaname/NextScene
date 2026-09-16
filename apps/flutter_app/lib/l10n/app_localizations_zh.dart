// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get managerAuthorize => '授权文件夹';

  @override
  String get managerAuthorizationHint => '请选择下载目录下的应用专属文件夹，其他目录不在管理范围内。';

  @override
  String get managerEmpty => '此文件夹为空';

  @override
  String get managerNewFolder => '新建文件夹';

  @override
  String get managerSelect => '选择';

  @override
  String get managerSelectAll => '全选';

  @override
  String get managerDone => '完成';

  @override
  String get managerCancel => '取消';

  @override
  String get managerCopy => '复制';

  @override
  String get managerMove => '移动';

  @override
  String get managerRename => '重命名';

  @override
  String get managerRenameExtensionTitle => '要更改扩展名吗？';

  @override
  String managerRenameExtensionMessage(String from, String to) {
    return '把扩展名从 $from 改成 $to 可能会改变这个文件的类型（预览、解压、游戏数据等）。请确认这是你想做的。';
  }

  @override
  String get managerRenameExtensionContinue => '继续';

  @override
  String get managerNoExtension => '无扩展名';

  @override
  String get managerTrash => '移到最近删除';

  @override
  String get managerRecentlyDeleted => '最近删除';

  @override
  String get managerTrashHint => '这些项目仍占用存储空间，不会自动清空。';

  @override
  String get managerTrashConfirm => '将所选项目移到最近删除？';

  @override
  String get managerTrashExplanation => '之后可以恢复。游玩记录和应用私有存档会保留。';

  @override
  String get managerRestore => '恢复';

  @override
  String get managerDeletePermanently => '永久删除';

  @override
  String get managerPermanentConfirm => '永久删除此项目？';

  @override
  String get managerPermanentExplanation => '此操作无法撤销，不会删除应用私有存档。';

  @override
  String get managerChooseDestination => '选择目标文件夹';

  @override
  String get managerUseFolder => '选择此文件夹';

  @override
  String get managerName => '名称';

  @override
  String get managerExtract => '解压缩';

  @override
  String get managerExtractTitle => '解压压缩包';

  @override
  String get managerPassword => '密码（如有）';

  @override
  String get managerEncoding => '旧格式文件名编码';

  @override
  String get managerExtractHint => '解压到新文件夹并保留压缩包。优先使用包内的 Unicode 文件名信息。';

  @override
  String get managerWorking => '正在处理…';

  @override
  String get managerCompleted => '已完成';

  @override
  String get managerRetry => '重试';

  @override
  String get managerErrorCancelled => '操作已取消。';

  @override
  String get managerErrorBusy => '请等待当前文件操作完成。';

  @override
  String get managerErrorInvalidName => '名称无效，请去掉路径分隔符或保留字符。';

  @override
  String get managerErrorOutsideRoot => '只能管理下载目录下的应用专属文件夹。';

  @override
  String get managerErrorProtectedDirectory => '这是固定目录，请操作其中的文件。';

  @override
  String get managerErrorUnsupportedLink => '暂不支持操作链接或特殊文件。';

  @override
  String get managerErrorNotFound => '文件或目标文件夹已不存在。';

  @override
  String get managerErrorConflict => '已有同名项目，未覆盖任何文件。';

  @override
  String get managerErrorRecursiveTarget => '不能放到自身或自己的子目录中。';

  @override
  String get managerErrorTrashCorrupt => '无法读取这条最近删除记录，未删除文件。';

  @override
  String get managerErrorPermissionDenied => '无法访问，请检查文件夹授权和读写权限。';

  @override
  String get managerErrorNoSpace => '存储空间不足，请释放空间后重试。';

  @override
  String get managerErrorReadOnly => '此位置为只读，无法修改。';

  @override
  String get managerErrorPasswordRequired => '此压缩包需要密码。';

  @override
  String get managerErrorWrongPassword => '密码不正确，或加密文件头已损坏。';

  @override
  String get managerErrorMissingVolume => '缺少分卷，请将所有分卷放在一起并保留原有编号。';

  @override
  String get managerErrorUnsupportedFormat => '暂不支持此压缩格式，或无法识别压缩包。';

  @override
  String get managerErrorUnsupportedMethod => '此压缩包使用了暂不支持的压缩方法。';

  @override
  String get managerErrorCorruptArchive => '压缩包不完整或已损坏，请检查分卷及密码。';

  @override
  String get managerErrorInvalidEncoding => '无法解码文件名，请切换编码后重试。';

  @override
  String get managerErrorUnsafeArchivePath => '压缩包包含不安全的路径，已停止解压。';

  @override
  String get managerErrorArchiveLimit => '压缩包的文件数或解压后大小超过安全限制。';

  @override
  String get managerErrorGameRunning => '请先退出游戏，再修改游戏文件。';

  @override
  String get managerErrorUnsupportedPlatform => '当前平台暂未提供此文件夹的访问能力。';

  @override
  String get managerErrorFailed => '操作未完成，请检查相关项目后重试。';

  @override
  String managerItemsSelected(int count) {
    return '已选择 $count 项';
  }

  @override
  String get managerDetails => '详情';

  @override
  String get managerDetailKind => '类型';

  @override
  String get managerDetailFolder => '文件夹';

  @override
  String get managerDetailFile => '文件';

  @override
  String get managerDetailArchive => '压缩包';

  @override
  String get managerDetailGame => '游戏';

  @override
  String get managerDetailImage => '图片';

  @override
  String get managerDetailAudio => '音频';

  @override
  String get managerDetailVideo => '视频';

  @override
  String get managerDetailText => '文本';

  @override
  String get managerDetailGameData => '游戏数据';

  @override
  String get managerTextEmpty => '这个文件是空的。';

  @override
  String get managerTextTruncated => '仅显示此文件的前 2 MB。';

  @override
  String get managerPlay => '播放';

  @override
  String get managerPause => '暂停';

  @override
  String get managerPreview => '预览';

  @override
  String get managerMediaFailed => '无法打开此文件。';

  @override
  String get managerDetailSize => '大小';

  @override
  String managerDetailItems(int count) {
    return '$count 项';
  }

  @override
  String get managerDetailModified => '修改时间';

  @override
  String get managerDetailLocation => '位置';

  @override
  String get managerCalculating => '正在计算…';

  @override
  String get managerEncodingUtf8 => 'UTF-8';

  @override
  String get managerEncodingGb18030 => 'GB18030';

  @override
  String get managerEncodingCp932 => 'Shift_JIS';

  @override
  String get appTitle => '下一幕';

  @override
  String get settings => '设置';

  @override
  String get addGame => '添加游戏';

  @override
  String get refresh => '刷新';

  @override
  String get howToImport => '导入指南';

  @override
  String get noGamesYet => '尚未添加任何游戏';

  @override
  String get noGamesHintDesktop => '点击「添加游戏」选择游戏目录';

  @override
  String noGamesHintIos(String appName) {
    return '使用「文件」App 将游戏文件夹复制到：\n我的 iPhone > $appName > Games\n然后点击「刷新」';
  }

  @override
  String get importGames => '导入游戏';

  @override
  String get importGamesDesc => '请使用「文件」App 将游戏文件夹复制到本应用的目录：';

  @override
  String get importStep1 => '1. 打开 iPhone 上的「文件」App';

  @override
  String importStep2(String appName) {
    return '2. 前往：我的 iPhone > $appName > Games';
  }

  @override
  String get importStep3 => '3. 将游戏文件夹复制到 Games 目录';

  @override
  String get importStep4 => '4. 返回本应用，点击「刷新」检测新游戏';

  @override
  String get macosImportTip =>
      '注意：由于 macOS 沙盒限制，请先选择 XP3 文件所在的文件夹后再选择目标 XP3 文件';

  @override
  String get gamesDirectory => '游戏目录：Games/';

  @override
  String get gotIt => '知道了';

  @override
  String get tabHome => '库';

  @override
  String get tabExplore => '探索';

  @override
  String get tabManage => '管理';

  @override
  String get tabStatistics => '统计';

  @override
  String get tabProfile => '我的';

  @override
  String get search => '搜索';

  @override
  String get searchGamesHint => '搜索游戏';

  @override
  String get searchNoResults => '没有找到匹配的游戏';

  @override
  String get searchComingSoon => '搜索功能正在准备中';

  @override
  String get help => '帮助';

  @override
  String get profilePlayTimeTitle => '游玩时间';

  @override
  String get profileLifetime => '累计游玩';

  @override
  String get profileLast7Days => '近 7 天';

  @override
  String get profileTrackingHint => '游玩趋势将从现在开始记录';

  @override
  String get profileActiveDays => '活跃天数';

  @override
  String get profileGamesPlayed => '玩过的游戏';

  @override
  String get profileAverageSession => '单次平均';

  @override
  String get profileTopGames => '常玩游戏';

  @override
  String get profileStatistics => '游玩统计';

  @override
  String get profileViewStatistics => '查看详细统计';

  @override
  String get profileHonorTitle => '称号';

  @override
  String get profileHonorNextUnlock => '下个称号';

  @override
  String get profileHonorNewcomer => '初来乍到';

  @override
  String get profileHonorStoryTraveler => '剧情旅人';

  @override
  String get profileHonorImmersedReader => '沉浸读者';

  @override
  String get profileHonorVeteran => '资深玩家';

  @override
  String get profileHonorCollector => '游戏藏家';

  @override
  String get profileHonorCurator => '典藏家';

  @override
  String profileHonorNext(String title) {
    return '下一档 · $title';
  }

  @override
  String profileHonorRemainingBoth(String duration, int count) {
    return '还差 $duration和 $count 款游戏';
  }

  @override
  String profileHonorRemainingTime(String duration) {
    return '还差 $duration';
  }

  @override
  String profileHonorRemainingGames(int count) {
    return '还差 $count 款游戏';
  }

  @override
  String get profileHonorHighest => '已经到最高档';

  @override
  String get profileHonorCurrent => '当前';

  @override
  String get profileHonorObtained => '已获得';

  @override
  String get profileHonorLocked => '未获得';

  @override
  String get profileGameRecords => '游戏记录';

  @override
  String get profileLocalSummary => '本机摘要';

  @override
  String get profileLibraryCount => '游戏库';

  @override
  String get profileRecentGame => '最近游玩';

  @override
  String get profileNoHistory => '暂无记录';

  @override
  String profilePlaySummary(String duration, int count) {
    return '已玩 $duration · $count 个游戏';
  }

  @override
  String get playTimeLessThanMinute => '不足 1 分钟';

  @override
  String playTimeMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String playTimeHours(int hours) {
    return '$hours 小时';
  }

  @override
  String playTimeHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String get helpIntro => '本页说明游戏的导入、存放位置、文件管理，以及游玩时间的统计方式。';

  @override
  String get helpSectionLibrary => '导入与启动';

  @override
  String get helpSectionFiles => '文件与资料';

  @override
  String get helpSectionMore => '统计与设置';

  @override
  String get helpFaqImportQ => '如何将游戏加入游戏库';

  @override
  String get helpFaqImportA =>
      '在「库」中点击「添加游戏」，选择完整游戏目录，或 XP3 / PFS 封包。HarmonyOS 也可以先将目录放到本应用的公共游戏路径，返回首页后下拉刷新。';

  @override
  String get helpFaqOhosQ => 'HarmonyOS 下应存放于何处';

  @override
  String helpFaqOhosA(String path) {
    return '请使用系统「文件管理」，将完整游戏目录复制到：\n$path\n本应用只会读写 Download 下属于自己的目录。';
  }

  @override
  String get helpFaqIosQ => '如何在 iPhone 上拷贝游戏';

  @override
  String helpFaqIosA(String appName) {
    return '打开「文件」App，将游戏文件夹复制到「我的 iPhone > $appName > Games」，再返回本应用刷新。';
  }

  @override
  String get helpFaqLaunchQ => '轻触与长按有何区别';

  @override
  String get helpFaqLaunchA =>
      '轻触卡片会打开详情，再从详情启动。长按可以直接启动、刮削名称与封面、重命名，或从列表中移除，不必先进入详情。';

  @override
  String get helpFaqManageQ => '「管理」页可以做什么';

  @override
  String get helpFaqManageA =>
      '在已授权的应用目录内，可以复制、移动、重命名、解压和查看详情。根目录、games 和私有存档目录受保护，不能按普通文件删除。';

  @override
  String get helpFaqArchiveQ => '压缩包与分卷如何处理';

  @override
  String get helpFaqArchiveA =>
      '「管理」页可以解压 zip、7z、rar。分卷 XP3 请放在同一目录。解压和导入都不会改写游戏脚本。';

  @override
  String get helpFaqRemoveQ => '从游戏库移除是否删除文件';

  @override
  String get helpFaqRemoveA => '不会。移除只会去掉列表中的条目，磁盘上的目录仍在。删除文件请到「管理」中操作。';

  @override
  String get helpFaqMetadataQ => '如何取得封面与名称';

  @override
  String get helpFaqMetadataA =>
      '添加游戏后，或从长按菜单选择「刮削信息」，按作品名检索 VNDB。只会更改显示名称和封面。';

  @override
  String get helpFaqStatsQ => '游玩时间如何记录';

  @override
  String get helpFaqStatsA => '从启动到正常退出记为一次时长，显示在「统计」。若进程被系统强制结束，该次可能不会被记录。';

  @override
  String get helpFaqControlsQ => '无键盘或鼠标时如何操作';

  @override
  String get helpFaqControlsA => '游玩时会提供虚拟按键，包括确认、返回、快进和方向。具体键位以当时屏幕上的控件为准。';

  @override
  String get helpFaqSettingsQ => '如何更改语言与外观';

  @override
  String get helpFaqSettingsA =>
      '从「我的」进入「设置」，可以更改语言，并在浅色、深色和跟随系统之间选择。部分引擎选项需要重启后才会生效。';

  @override
  String get helpFaqCompatQ => '支持哪些游戏';

  @override
  String get helpFaqCompatA =>
      '面向 KiriKiri2 与 Artemis 作品，不是官方发行版本。资源缺失、指令未实现，或所用加密不受支持时，可能无法启动。';

  @override
  String get removeGame => '移除游戏';

  @override
  String removeGameConfirm(String title) {
    return '从列表中移除「$title」？\n这不会删除游戏文件。';
  }

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get renameGame => '重命名游戏';

  @override
  String get displayTitle => '显示名称';

  @override
  String get save => '保存';

  @override
  String get done => '完成';

  @override
  String gameAlreadyExists(String title) {
    return '游戏已存在：$title';
  }

  @override
  String get builtInReady => '内置 ✓';

  @override
  String get builtInNotReady => '内置 ✗';

  @override
  String get customNotSet => '自定义（未设置）';

  @override
  String get engineNotFoundBuiltIn => '未找到内置引擎。请使用构建脚本将引擎打包到应用中，或在设置中切换到自定义模式。';

  @override
  String get engineNotFoundCustom => '引擎 dylib 未设置。请先在设置中进行配置。';

  @override
  String lastPlayed(String time) {
    return '上次游玩：$time';
  }

  @override
  String playDuration(String duration) {
    return '已玩 $duration';
  }

  @override
  String get rename => '重命名';

  @override
  String get setCover => '设置封面';

  @override
  String get coverFromGallery => '从相册选择';

  @override
  String get coverFromCamera => '拍照';

  @override
  String get coverRemove => '移除封面';

  @override
  String get settingsEngine => '引擎';

  @override
  String get engineMode => '引擎模式';

  @override
  String get builtIn => '内置';

  @override
  String get custom => '自定义';

  @override
  String get builtInEngineAvailable => '内置引擎可用';

  @override
  String get builtInEngineNotFound => '未找到内置引擎';

  @override
  String get builtInEngineHint => '请使用构建脚本编译并将引擎打包到应用中。';

  @override
  String get engineDylibPath => '引擎 dylib 路径';

  @override
  String get notSetRequired => '未设置（必填）';

  @override
  String get clearPath => '清除路径';

  @override
  String get browse => '浏览...';

  @override
  String get selectEngineDylib => '选择引擎 dylib';

  @override
  String get settingsRendering => '渲染';

  @override
  String get renderPipeline => '渲染管线';

  @override
  String get renderPipelineHint => '渲染管线与图形后端需重启应用后生效';

  @override
  String get restartRequiredTitle => '需要重启应用';

  @override
  String get restartRequiredMessage => '这项改动需要重启应用后才会生效。';

  @override
  String get applyAndRestart => '改动并重启应用';

  @override
  String get restartPendingBanner => '已保存的改动尚未生效。请重启应用，或点这里手动重启。';

  @override
  String get restartNow => '重启应用';

  @override
  String get opengl => 'OpenGL';

  @override
  String get software => '软件渲染';

  @override
  String get graphicsBackend => '图形后端';

  @override
  String get graphicsBackendHint => 'ANGLE 翻译层后端（仅 Android）。需重启生效。';

  @override
  String get opengles => 'OpenGL ES';

  @override
  String get vulkan => 'Vulkan';

  @override
  String get performanceOverlay => '性能监控';

  @override
  String get performanceOverlayDesc => '显示帧率和图形 API 信息';

  @override
  String get fpsLimitEnabled => '帧率限制';

  @override
  String get fpsLimitEnabledDesc => '限制引擎渲染频率以节省功耗';

  @override
  String get fpsLimitOff => '关闭（垂直同步）';

  @override
  String get forceLandscape => '锁定横屏';

  @override
  String get forceLandscapeDesc => '游戏运行时强制横屏显示（手机推荐开启）';

  @override
  String get targetFrameRate => '目标帧率';

  @override
  String get targetFrameRateDesc => '启用限制时的最大渲染频率';

  @override
  String fpsLabel(int fps) {
    return '$fps FPS';
  }

  @override
  String get settingsGeneral => '通用';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageJa => '日本語';

  @override
  String get themeMode => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get settingsAbout => '关于';

  @override
  String get version => '版本';

  @override
  String get legal => '法律信息';

  @override
  String get legalTabOpenSource => '开源协议';

  @override
  String get legalTabPrivacy => '隐私声明';

  @override
  String get legalTabDisclaimer => '免责声明';

  @override
  String get legalOpenSourceTitle => '开源协议声明';

  @override
  String get legalPrivacyTitle => '隐私声明';

  @override
  String get legalDisclaimerTitle => '免责声明';

  @override
  String legalUpdated(String date) {
    return '本声明依据 $date 之程序实现整理。';
  }

  @override
  String get gameEngineError => '引擎错误';

  @override
  String get unknownError => '未知错误';

  @override
  String get back => '返回';

  @override
  String get retry => '重试';

  @override
  String get hideDebug => '关闭调试日志';

  @override
  String get showDebug => '打开调试日志';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续';

  @override
  String get exitGame => '退出游戏';

  @override
  String get discard => '放弃';

  @override
  String get discardChangesMessage => '放弃未保存的修改？';

  @override
  String get gameTypeXp3 => 'XP3 归档';

  @override
  String get gameTypeDirectory => '文件夹';

  @override
  String archiveNotExist(String path) {
    return '归档文件不存在：$path';
  }

  @override
  String gamePathNotExist(String path) {
    return '游戏路径不存在：$path';
  }

  @override
  String missingStartupScript(String path) {
    return '未找到启动脚本：$path\n（已查找 startup.tjs 与 data/system/initialize.tjs）';
  }

  @override
  String gamePathCheckFailed(String error) {
    return '游戏路径检查失败：$error';
  }

  @override
  String get androidAllFilesAccess => 'Android 上需要“所有文件”访问权限。请授予权限后重新打开游戏。';

  @override
  String get noXp3InFolder => '所选文件夹里没有找到 XP3 归档或 Artemis 封包（.pfs）。';

  @override
  String get gameTypeArtemis => 'Artemis 封包（.pfs）';

  @override
  String gameEngine(String engine) {
    return '引擎：$engine';
  }

  @override
  String missingArtemisPack(String path) {
    return '未找到 Artemis 封包（.pfs）：$path';
  }

  @override
  String get rescanGamesDir => '重新扫描目录';

  @override
  String rescanGamesDirDesc(String path) {
    return '查找放入 $path 或经 hdc 送入的游戏（XP3 / Artemis .pfs）';
  }

  @override
  String get noGamesFoundInSandbox => '游戏目录和应用沙箱中都没有找到游戏。';

  @override
  String get allSandboxGamesRegistered => '找到的游戏都已在库中。';

  @override
  String get noNewGamesFound => '没有发现新游戏。';

  @override
  String noGamesHintOhos(String path) {
    return '用「文件管理」把游戏文件夹复制到：\n$path\n然后下拉刷新';
  }

  @override
  String get settingsGames => '游戏';

  @override
  String get publicGamesDir => '游戏存放目录';

  @override
  String publicGamesDirHint(String path) {
    return '用「文件管理」把整个游戏文件夹复制到 $path，回到首页下拉刷新即可识别。点按可复制路径。';
  }

  @override
  String get pullToRefresh => '下拉刷新';

  @override
  String get releaseToRefresh => '释放刷新';

  @override
  String get refreshing => '正在刷新';

  @override
  String get refreshDone => '刷新成功';

  @override
  String get screenOrientation => '屏幕方向';

  @override
  String get screenOrientationDesc => '游戏运行时使用的屏幕方向';

  @override
  String get orientationAuto => '跟随系统';

  @override
  String get orientationLandscape => '横屏';

  @override
  String get orientationPortrait => '竖屏';

  @override
  String get rotateScreen => '旋转屏幕';

  @override
  String get showVirtualControls => '显示虚拟操控';

  @override
  String get hideVirtualControls => '隐藏虚拟操控';

  @override
  String get virtualTouchpad => '（触控板）轻点单击';

  @override
  String get virtualMouseLeft => '左键';

  @override
  String get virtualMouseRight => '右键';

  @override
  String get virtualConfirm => '确认（Enter）';

  @override
  String get virtualBack => '返回（Esc）';

  @override
  String get virtualAdvance => '推进（Space）';

  @override
  String get virtualSkip => '按住快进（Ctrl）';

  @override
  String get virtualUp => '上';

  @override
  String get virtualDown => '下';

  @override
  String get virtualLeft => '左';

  @override
  String get virtualRight => '右';

  @override
  String get gameStarting => '正在启动';

  @override
  String get gamePreparingEngine => '准备引擎';

  @override
  String get gameOpening => '打开游戏';

  @override
  String get gameLoadingResources => '载入资源';

  @override
  String get gameBootLogs => '详细日志';

  @override
  String get gameHideBootLogs => '收起日志';

  @override
  String get engineRestartRequired => '引擎已在本会话中运行另一游戏，如需切换新游戏请重启应用。';

  @override
  String gamesImported(int count) {
    return '已导入 $count 个游戏';
  }

  @override
  String get selectGameDirectory => '选择游戏目录';

  @override
  String get selectGameArchive => '选择游戏归档';

  @override
  String get addArchive => '添加 XP3';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get packXp3 => '打包为 XP3';

  @override
  String get unpackXp3 => '解包 XP3';

  @override
  String get packingProgress => '正在打包...';

  @override
  String get unpackingProgress => '正在解包...';

  @override
  String get packComplete => '打包完成';

  @override
  String get unpackComplete => '解包完成';

  @override
  String xp3OperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get launchGame => '启动游戏';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get gameFormat => '格式';

  @override
  String get gamePath => '路径';

  @override
  String get gameDescription => '简介';

  @override
  String get gameKeywords => '关键词';

  @override
  String get showMore => '展开';

  @override
  String get showLess => '收起';

  @override
  String get scrapeMetadata => '刮削信息';

  @override
  String get scrapeMetadataDialogTitle => '刮削信息';

  @override
  String get scrapeMetadataSearchHint => '输入游戏名称搜索';

  @override
  String get scrapeMetadataSearch => '搜索';

  @override
  String get scrapeMetadataSelectTitle => '选择匹配作品';

  @override
  String get scrapeMetadataNoResults => '未找到匹配作品，请尝试其他关键词。';

  @override
  String get scrapeMetadataConfirm => '确认';

  @override
  String get scrapeMetadataSuccess => '已更新名称与封面。';

  @override
  String get scrapeMetadataCoverFailed => '名称已更新，封面获取失败可手动设置。';

  @override
  String get scrapeMetadataEnterName => '请输入游戏名称。';

  @override
  String get scrapeMetadataSourceError => '数据源暂时不可用，请稍后重试。';

  @override
  String get scrapeMetadataSelectOne => '请选择一项作品。';

  @override
  String get scrapeAfterAddPrompt => '是否刮削该游戏？选择「是」将搜索并填写名称与封面。';

  @override
  String get scrapeAfterAddNo => '否';

  @override
  String get scrapeAfterAddYes => '是';
}
