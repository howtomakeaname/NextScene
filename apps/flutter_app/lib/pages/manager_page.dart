import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../l10n/file_manager_localizations.dart';
import '../services/file_manager_controller.dart';
import '../services/local_file_service.dart';
import '../services/manager_file_kind.dart';
import '../ui/ui.dart';
import 'manager_media_page.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key, required this.controller, this.active = true});

  final FileManagerController controller;

  /// Whether this tab is the visible one. The page lives in an IndexedStack,
  /// so it must only claim the system back gesture while it is on screen.
  final bool active;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  FileManagerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
    if (controller.grant == null && !controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.grant == null && !controller.loading) {
          controller.load();
        }
      });
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    final error = controller.lastError;
    if (error != null) {
      controller.lastError = null;
      // Codes only; the message never carries paths, passwords or the
      // native exception text.
      UiToast.show(
        context,
        message: l10n.fileOperationError(error.code),
        type: UiToastType.error,
      );
      return;
    }
    if (controller.notice == ManagerNotice.completed) {
      controller.notice = null;
      UiToast.show(
        context,
        message: l10n.managerCompleted,
        type: UiToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final handlesBack = widget.active && controller.canGoBack;
    return PopScope(
      canPop: !handlesBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.goBack();
      },
      child: ColoredBox(
        color: colors.background,
        child: _buildPage(context, l10n, colors, bottom),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    AppLocalizations l10n,
    UiColors colors,
    double bottom,
  ) {
    return Column(
      children: [
        UiTabHeader.labeled(
          title: controller.selecting
              ? l10n.managerItemsSelected(controller.selected.length)
              : l10n.tabManage,
          trailing: controller.grant == null
              ? null
              : UiGlassToolbar(
                  children: [
                    UiGlassIconButton(
                      icon: controller.selecting
                          ? LucideIcons.check
                          : LucideIcons.listChecks,
                      semanticLabel: controller.selecting
                          ? l10n.managerDone
                          : l10n.managerSelect,
                      contained: false,
                      onPressed: () =>
                          controller.toggleSelecting(!controller.selecting),
                    ),
                    Builder(
                      builder: (buttonContext) => UiGlassIconButton(
                        icon: LucideIcons.ellipsis,
                        semanticLabel: l10n.tabManage,
                        contained: false,
                        onPressed: () => _showMenu(buttonContext, l10n),
                      ),
                    ),
                  ],
                ),
        ),
        if (controller.grant != null) _buildBreadcrumb(l10n),
        if (controller.task != null) _buildProgress(l10n),
        Expanded(child: _buildBody(l10n)),
        if (controller.selecting && controller.selected.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 12),
            child: UiGlassToolbar(
              variant: UiGlassVariant.regular,
              children: [
                UiGlassIconButton(
                  icon: LucideIcons.copy,
                  semanticLabel: l10n.managerCopy,
                  contained: false,
                  onPressed: () => _pickDestination(copy: true),
                ),
                UiGlassIconButton(
                  icon: LucideIcons.folderInput,
                  semanticLabel: l10n.managerMove,
                  contained: false,
                  onPressed: () => _pickDestination(copy: false),
                ),
                UiGlassIconButton(
                  icon: LucideIcons.trash2,
                  semanticLabel: l10n.managerTrash,
                  contained: false,
                  foregroundColor: colors.danger,
                  onPressed: () => _confirmTrash(l10n),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBreadcrumb(AppLocalizations l10n) {
    final labels = controller.breadcrumbLabels();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: UiBreadcrumb(
        items: [
          for (var i = 0; i < labels.length; i++)
            UiBreadcrumbItem(
              label: i == 0 ? controller.grant!.displayRoot : labels[i],
              onTap: () => controller.openBreadcrumb(i),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(AppLocalizations l10n) {
    final task = controller.task!;
    // A nested tar layer adds bytes after the outer total was reported.
    final value = task.total <= 0
        ? null
        : (task.completed / task.total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.currentName.isEmpty
                      ? l10n.managerWorking
                      : task.currentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiType.caption,
                ),
              ),
              if (task.bytesPerSecond case final speed?) ...[
                const SizedBox(width: 8),
                Text(
                  formatTransferSpeed(speed),
                  style: context.uiType.caption.copyWith(
                    color: context.uiColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: UiProgress(value: value)),
              const SizedBox(width: 8),
              UiButton(
                label: l10n.managerCancel,
                variant: UiButtonVariant.ghost,
                size: UiButtonSize.small,
                onPressed: controller.cancelTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (controller.loading) {
      return const Center(child: UiLoader());
    }
    if (controller.grant == null) {
      if (!controller.isSupported) {
        return UiEmpty(
          icon: LucideIcons.folderLock,
          title: l10n.tabManage,
          description: l10n.managerErrorUnsupportedPlatform,
        );
      }
      return UiEmpty(
        icon: LucideIcons.folderLock,
        title: l10n.tabManage,
        description: controller.storage.usesAndroidDocumentTree
            ? l10n.managerAndroidAuthorizationHint(controller.storage.appId)
            : l10n.managerAuthorizationHint,
        actionLabel: l10n.managerAuthorize,
        onAction: controller.authorize,
      );
    }
    return UiPullRefresh(
      pullingText: l10n.pullToRefresh,
      readyText: l10n.releaseToRefresh,
      refreshingText: l10n.refreshing,
      doneText: l10n.refreshDone,
      onRefresh: controller.reload,
      child: controller.entries.isEmpty
          ? _buildEmptyFolder(l10n)
          : _buildListing(l10n),
    );
  }

  /// The empty state has nothing to scroll, so it is given the viewport
  /// height inside a list; otherwise there is no gesture to pull on.
  Widget _buildEmptyFolder(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: UiEmpty(
              icon: LucideIcons.folder,
              title: l10n.managerEmpty,
              actionLabel: l10n.managerNewFolder,
              onAction: () => _createFolder(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListing(AppLocalizations l10n) {
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        bottom: MediaQuery.paddingOf(context).bottom + 88,
      ),
      itemCount: controller.entries.length,
      itemBuilder: (context, index) {
        final entry = controller.entries[index];
        final selected = controller.selected.contains(entry.path);
        final mutable = controller.canMutate(entry.path);
        final kind = ManagerFileKind.of(entry);
        return Builder(
          builder: (tileContext) => UiListTile(
            title: entry.name,
            subtitle: entry.isDirectory ? null : _sizeLabel(entry.stat.size),
            icon: kind.icon,
            iconColor: kind == ManagerFileKind.game
                ? context.uiColors.brand
                : null,
            trailing: controller.selecting && mutable
                ? Icon(
                    selected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: selected
                        ? context.uiColors.brand
                        : context.uiColors.textTertiary,
                  )
                : null,
            onTap: () {
              if (controller.selecting && mutable) {
                controller.toggle(entry.path);
              } else if (entry.isDirectory) {
                controller.open(entry.path);
              } else if (kind.canOpen) {
                _openMedia(entry, kind);
              } else {
                _showDetails(entry, l10n);
              }
            },
            onLongPress: () => _showItemMenu(tileContext, entry, l10n),
          ),
        );
      },
    );
  }

  String _sizeLabel(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }

  Future<void> _openMedia(LocalFileEntry entry, ManagerFileKind kind) {
    return ManagerMediaPage.open(
      context,
      path: entry.path,
      kind: kind,
      fileSystem: controller.files?.io,
    );
  }

  Future<void> _showDetails(LocalFileEntry entry, AppLocalizations l10n) {
    return UiBottomSheet.show<void>(
      context,
      title: entry.name,
      child: _DetailsSheet(
        entry: entry,
        controller: controller,
        sizeLabel: _sizeLabel,
      ),
    );
  }

  Future<void> _showMenu(BuildContext buttonContext, AppLocalizations l10n) {
    return UiPopupMenu.show<void>(
      context,
      anchor: UiPopupMenu.rectOf(buttonContext),
      items: [
        UiMenuItem(
          label: l10n.managerNewFolder,
          icon: LucideIcons.folderPlus,
          onSelected: () => _createFolder(l10n),
        ),
        UiMenuItem(
          label: l10n.managerSelectAll,
          icon: LucideIcons.listChecks,
          onSelected: () {
            controller.toggleSelecting(true);
            controller.selectAll();
          },
        ),
        UiMenuItem(
          label: l10n.managerRecentlyDeleted,
          icon: LucideIcons.trash2,
          onSelected: () => _showTrash(l10n),
        ),
      ],
    );
  }

  Future<void> _showItemMenu(
    BuildContext tileContext,
    LocalFileEntry entry,
    AppLocalizations l10n,
  ) {
    // The games container has no rename/move/trash; offering them only to
    // answer with protected_directory would be noise. Details always apply.
    final mutable = controller.canMutate(entry.path);
    final kind = ManagerFileKind.of(entry);
    return UiPopupMenu.show<void>(
      context,
      anchor: UiPopupMenu.rectOf(tileContext),
      items: [
        if (kind.canOpen)
          UiMenuItem(
            label:
                kind == ManagerFileKind.audio || kind == ManagerFileKind.video
                ? l10n.managerPlay
                : l10n.managerPreview,
            icon: switch (kind) {
              ManagerFileKind.image => LucideIcons.image,
              ManagerFileKind.text => LucideIcons.fileText,
              _ => LucideIcons.play,
            },
            onSelected: () => _openMedia(entry, kind),
          ),
        UiMenuItem(
          label: l10n.managerDetails,
          icon: LucideIcons.info,
          onSelected: () => _showDetails(entry, l10n),
        ),
        if (mutable) ...[
          UiMenuItem(
            label: l10n.managerRename,
            icon: LucideIcons.pencil,
            onSelected: () => _rename(entry, l10n),
          ),
          UiMenuItem(
            label: l10n.managerCopy,
            icon: LucideIcons.copy,
            onSelected: () {
              controller
                ..toggleSelecting(true)
                ..selected.add(entry.path);
              _pickDestination(copy: true);
            },
          ),
          UiMenuItem(
            label: l10n.managerMove,
            icon: LucideIcons.folderInput,
            onSelected: () {
              controller
                ..toggleSelecting(true)
                ..selected.add(entry.path);
              _pickDestination(copy: false);
            },
          ),
          if (controller.looksLikeArchive(entry.name))
            UiMenuItem(
              label: l10n.managerExtract,
              icon: LucideIcons.packageOpen,
              onSelected: () => _extract(entry, l10n),
            ),
          UiMenuItem(
            label: l10n.managerTrash,
            icon: LucideIcons.trash2,
            isDestructive: true,
            onSelected: () {
              controller
                ..toggleSelecting(true)
                ..selected.add(entry.path);
              _confirmTrash(l10n);
            },
          ),
        ],
      ],
    );
  }

  Future<void> _createFolder(AppLocalizations l10n) async {
    final name = await _promptName(l10n, l10n.managerNewFolder);
    if (name == null) return;
    await controller.createFolder(name);
  }

  Future<void> _rename(LocalFileEntry entry, AppLocalizations l10n) async {
    final name = await _promptName(
      l10n,
      l10n.managerRename,
      initial: entry.name,
    );
    if (name == null || name == entry.name) return;
    if (!entry.isDirectory &&
        ManagerFileKind.extensionChanged(entry.name, name)) {
      if (!mounted) return;
      // Let the name dialog finish leaving so its field is not rebuilt
      // against a disposed controller when this alert lands.
      await Future<void>.delayed(UiSprings.dismissDuration);
      if (!mounted) return;
      final confirmed = await UiDialog.show<bool>(
        context,
        title: l10n.managerRenameExtensionTitle,
        message: l10n.managerRenameExtensionMessage(
          _extensionLabel(entry.name, l10n),
          _extensionLabel(name, l10n),
        ),
        actions: [
          UiDialogAction(label: l10n.managerCancel, returnValue: false),
          UiDialogAction(
            label: l10n.managerRenameExtensionContinue,
            isDefault: true,
            returnValue: true,
          ),
        ],
      );
      if (confirmed != true) return;
    }
    await controller.rename(entry.path, name);
  }

  String _extensionLabel(String name, AppLocalizations l10n) {
    final ext = ManagerFileKind.extensionOf(name);
    return ext.isEmpty ? l10n.managerNoExtension : '.$ext';
  }

  Future<String?> _promptName(
    AppLocalizations l10n,
    String title, {
    String? initial,
  }) async {
    final input = TextEditingController(text: initial);
    final result = await UiDialog.show<String>(
      context,
      title: title,
      content: UiInput(
        controller: input,
        label: l10n.managerName,
        autofocus: true,
      ),
      actions: [
        UiDialogAction(label: l10n.managerCancel),
        UiDialogAction(
          label: l10n.managerDone,
          isDefault: true,
          // UiDialog pushes on the root navigator; pop the same one.
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(input.text.trim()),
        ),
      ],
    );
    // The dialog is still reversing; disposing now would rebuild its
    // TextField against a dead controller.
    Future<void>.delayed(UiSprings.dismissDuration, input.dispose);
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _confirmTrash(AppLocalizations l10n) async {
    final confirmed = await UiDialog.show<bool>(
      context,
      title: l10n.managerTrash,
      message: '${l10n.managerTrashConfirm}\n${l10n.managerTrashExplanation}',
      actions: [
        UiDialogAction(label: l10n.managerCancel, returnValue: false),
        UiDialogAction(
          label: l10n.managerTrash,
          isDestructive: true,
          returnValue: true,
        ),
      ],
    );
    if (confirmed == true) await controller.trashSelected();
  }

  Future<void> _showTrash(AppLocalizations l10n) async {
    await controller.refresh();
    if (!mounted) return;
    await UiBottomSheet.show<void>(
      context,
      title: l10n.managerRecentlyDeleted,
      child: controller.trash.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.managerTrashHint, style: context.uiType.body),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.managerTrashHint,
                    style: context.uiType.caption,
                  ),
                ),
                for (final item in controller.trash)
                  UiListTile(
                    title: p.basename(item.originalPath),
                    subtitle: _deletedAtLabel(item),
                    icon: LucideIcons.trash2,
                    onTap: () => _trashActions(item, l10n),
                  ),
              ],
            ),
    );
  }

  String _deletedAtLabel(DeletedFile item) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).add_Hm().format(item.deletedAt.toLocal());
  }

  Future<void> _trashActions(DeletedFile item, AppLocalizations l10n) async {
    final restore = await UiDialog.show<bool>(
      context,
      title: p.basename(item.originalPath),
      actions: [
        UiDialogAction(label: l10n.managerCancel),
        UiDialogAction(label: l10n.managerRestore, returnValue: true),
        UiDialogAction(
          label: l10n.managerDeletePermanently,
          isDestructive: true,
          returnValue: false,
        ),
      ],
    );
    if (!mounted) return;
    if (restore == true) {
      await controller.restore(item);
    } else if (restore == false) {
      final confirmed = await UiDialog.show<bool>(
        context,
        title: l10n.managerDeletePermanently,
        message:
            '${l10n.managerPermanentConfirm}\n${l10n.managerPermanentExplanation}',
        actions: [
          UiDialogAction(label: l10n.managerCancel, returnValue: false),
          UiDialogAction(
            label: l10n.managerDeletePermanently,
            isDestructive: true,
            returnValue: true,
          ),
        ],
      );
      if (confirmed == true) await controller.permanentlyDelete(item);
    }
  }

  Future<void> _pickDestination({required bool copy}) async {
    final l10n = AppLocalizations.of(context)!;
    final service = controller.files;
    if (service == null) return;
    var cursor = controller.currentPath;
    final destination = await UiBottomSheet.show<String>(
      context,
      title: l10n.managerChooseDestination,
      child: _DestinationBrowser(
        service: service,
        initialPath: cursor,
        useLabel: l10n.managerUseFolder,
        onUse: (path) => Navigator.of(context).pop(path),
      ),
    );
    if (destination == null) return;
    if (copy) {
      await controller.copyTo(destination);
    } else {
      await controller.moveTo(destination);
    }
  }

  Future<void> _extract(LocalFileEntry entry, AppLocalizations l10n) async {
    var codepage = 65001;
    final password = TextEditingController();
    final confirmed = await UiDialog.show<bool>(
      context,
      title: l10n.managerExtractTitle,
      content: StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.managerExtractHint, style: context.uiType.caption),
            const SizedBox(height: 12),
            UiInput(
              controller: password,
              label: l10n.managerPassword,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            UiDropdown<int>(
              label: l10n.managerEncoding,
              value: codepage,
              items: [
                UiDropdownItem(value: 65001, label: l10n.managerEncodingUtf8),
                UiDropdownItem(
                  value: 54936,
                  label: l10n.managerEncodingGb18030,
                ),
                UiDropdownItem(value: 932, label: l10n.managerEncodingCp932),
              ],
              onChanged: (value) => setDialogState(() => codepage = value),
            ),
          ],
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.managerCancel, returnValue: false),
        UiDialogAction(
          label: l10n.managerExtract,
          isDefault: true,
          returnValue: true,
        ),
      ],
    );
    final secret = password.text;
    password.clear();
    password.dispose();
    if (confirmed != true) return;
    await controller.extract(
      entry.path,
      password: secret.isEmpty ? null : secret,
      legacyCodepage: codepage,
    );
  }
}

class _DestinationBrowser extends StatefulWidget {
  const _DestinationBrowser({
    required this.service,
    required this.initialPath,
    required this.useLabel,
    required this.onUse,
  });

  final LocalFileService service;
  final String initialPath;
  final String useLabel;
  final ValueChanged<String> onUse;

  @override
  State<_DestinationBrowser> createState() => _DestinationBrowserState();
}

class _DestinationBrowserState extends State<_DestinationBrowser> {
  late String _path;
  List<LocalFileEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.service.list(_path);
    if (!mounted) return;
    setState(() {
      _entries = entries.where((entry) => entry.isDirectory).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiListTile(
          title: p.basename(_path).isEmpty
              ? widget.service.rootPath
              : p.basename(_path),
          icon: LucideIcons.folder,
        ),
        if (!p.equals(_path, widget.service.rootPath))
          UiListTile(
            title: '..',
            icon: LucideIcons.cornerLeftUp,
            onTap: () {
              _path = p.dirname(_path);
              _load();
            },
          ),
        for (final entry in _entries)
          UiListTile(
            title: entry.name,
            icon: CupertinoIcons.folder,
            showChevron: true,
            onTap: () {
              _path = entry.path;
              _load();
            },
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: UiButton(
            label: widget.useLabel,
            fullWidth: true,
            onPressed: () => widget.onUse(_path),
          ),
        ),
      ],
    );
  }
}

/// Kind, size, modified time and location of one entry. Folder totals are
/// walked after the sheet opens so a multi-gigabyte game does not delay it;
/// the walk is cancelled if the sheet is dismissed first.
class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({
    required this.entry,
    required this.controller,
    required this.sizeLabel,
  });

  final LocalFileEntry entry;
  final FileManagerController controller;
  final String Function(int bytes) sizeLabel;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  final _task = FileTask();
  DirectorySummary? _summary;
  FileOperationException? _error;

  @override
  void initState() {
    super.initState();
    if (widget.entry.isDirectory) _summarize();
  }

  @override
  void dispose() {
    _task.cancelled = true;
    super.dispose();
  }

  Future<void> _summarize() async {
    try {
      final summary = await widget.controller.summarize(
        widget.entry.path,
        _task,
      );
      if (mounted) setState(() => _summary = summary);
    } on FileOperationException catch (error) {
      if (error.code == FileErrorCode.cancelled) return;
      if (mounted) setState(() => _error = error);
    } catch (error) {
      if (mounted) setState(() => _error = FileOperationException.from(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entry = widget.entry;
    final locale = Localizations.localeOf(context).toString();
    final modified = DateFormat.yMd(
      locale,
    ).add_Hm().format(entry.stat.modified.toLocal());

    final kind = ManagerFileKind.of(entry).label(l10n);

    final String size;
    if (!entry.isDirectory) {
      size = widget.sizeLabel(entry.stat.size);
    } else if (_summary case final summary?) {
      size =
          '${widget.sizeLabel(summary.bytes)} · '
          '${l10n.managerDetailItems(summary.items)}';
    } else if (_error case final error?) {
      size = l10n.fileOperationError(error.code);
    } else {
      size = l10n.managerCalculating;
    }

    // Sit on the sheet itself. Another grouped card here is a panel inside
    // a panel; location is stacked so a long path can wrap.
    return Column(
      key: const Key('manager-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailRow(label: l10n.managerDetailKind, value: kind),
        _DetailRow(label: l10n.managerDetailSize, value: size),
        _DetailRow(label: l10n.managerDetailModified, value: modified),
        _DetailRow(
          label: l10n.managerDetailLocation,
          value: widget.controller.locationOf(entry.path),
          stacked: true,
          divider: false,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.stacked = false,
    this.divider = true,
  });

  final String label;
  final String value;
  final bool stacked;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final type = context.uiType;
    final labelStyle = type.subheadline.copyWith(color: colors.textSecondary);
    final valueStyle = type.body.copyWith(color: colors.textPrimary);
    final content = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 4),
              Text(value, style: valueStyle),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(width: UiSpacing.lg),
              Expanded(
                child: Text(value, style: valueStyle, textAlign: TextAlign.end),
              ),
            ],
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: colors.separator, width: 0.5))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UiSpacing.md),
        child: content,
      ),
    );
  }
}
