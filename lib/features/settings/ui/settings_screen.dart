import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/backup_service.dart';
import '../../../core/services/keep_screen_on_setting.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/numeric_field.dart';
import '../../exercises/providers/exercise_providers.dart';
import '../../history/providers/history_providers.dart';
import '../../sessions/providers/active_session_controller.dart';
import '../../templates/providers/template_providers.dart';
import '../providers/settings_providers.dart';

/// App name shown in the About section. Matches `pubspec.yaml`'s `name`
/// entry (title-cased for display), not a widget/package identifier.
const String appDisplayName = 'GymFlow';

/// Matches the `version:` line in `pubspec.yaml`. There is no
/// `package_info_plus` dependency wired up in this project yet, so this is
/// a plain constant kept in sync by hand rather than read at runtime.
const String appVersion = '1.0.0';

/// The Profile tab's screen (PRD §9.9): default weight unit and rest,
/// sound/haptics/keep-screen-on (the three existing device-wide switches,
/// read straight off their own established providers — see
/// `session_settings_sheet.dart` for the identical pattern), notification
/// permission, JSON export/import, and About.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.extension<SemanticColors>()!;
    final settings = ref.watch(settingsProvider);
    final soundEnabled = ref.watch(soundEnabledSettingProvider).valueOrNull ?? true;
    final hapticsEnabled =
        ref.watch(hapticsEnabledSettingProvider).valueOrNull ?? true;
    final keepScreenOn =
        ref.watch(keepScreenOnSettingProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('DEFAULTS', style: AppTheme.columnHeader.copyWith(color: colors.muted)),
          const SizedBox(height: 12),
          Text('Weight unit', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Changing this affects only sessions started afterwards — '
            'existing sessions keep their snapshot.',
            style: AppTheme.body.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'kg', label: Text('kg')),
              ButtonSegment(value: 'lb', label: Text('lb')),
            ],
            selected: {settings.weightUnit},
            onSelectionChanged: (selection) => ref
                .read(settingsProvider.notifier)
                .setWeightUnit(selection.first),
          ),
          const SizedBox(height: 20),
          NumericField(
            label: 'Default rest for new template exercises',
            value: settings.defaultRestSeconds,
            min: 0,
            max: 3600,
            suffix: 's',
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setDefaultRestSeconds((value ?? 90).toInt()),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.line),
          const SizedBox(height: 16),
          SwitchListTile(
            key: const Key('soundOnRestCompleteSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound on rest complete'),
            value: soundEnabled,
            onChanged: (v) =>
                ref.read(soundEnabledSettingProvider.notifier).setEnabled(v),
          ),
          SwitchListTile(
            key: const Key('hapticsSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptics'),
            value: hapticsEnabled,
            onChanged: (v) =>
                ref.read(hapticsEnabledSettingProvider.notifier).setEnabled(v),
          ),
          SwitchListTile(
            key: const Key('keepScreenOnSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Keep screen on during a session'),
            value: keepScreenOn,
            onChanged: (v) =>
                ref.read(keepScreenOnSettingProvider.notifier).setEnabled(v),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.line),
          const SizedBox(height: 16),
          const _NotificationPermissionTile(),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.line),
          const SizedBox(height: 16),
          Text('DATA', style: AppTheme.columnHeader.copyWith(color: colors.muted)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export data'),
            subtitle: const Text(
              'Saves every exercise, template and session to a JSON file. '
              'Exercise images are not included — an import on another '
              'device shows a placeholder for each one.',
            ),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import data'),
            subtitle: const Text('Replaces everything on this device.'),
            onTap: () => _importData(context, ref),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.line),
          const SizedBox(height: 16),
          Text('ABOUT', style: AppTheme.columnHeader.copyWith(color: colors.muted)),
          const SizedBox(height: 12),
          Text(appDisplayName, style: AppTheme.exerciseName.copyWith(
            color: theme.colorScheme.onSurface,
          )),
          const SizedBox(height: 4),
          Text('Version $appVersion',
              style: AppTheme.body.copyWith(color: colors.muted)),
          const SizedBox(height: 16),
          Text(
            'All data is stored on this device. GymFlow does not send your '
            'workouts anywhere.',
            style: AppTheme.body.copyWith(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(backupServiceProvider).exportToFile();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = files.isEmpty ? null : files.single.path;
    if (path == null) return;
    if (!context.mounted) return;

    final confirmed = await confirmDestructive(
      context,
      title: 'Import data',
      message:
          'This replaces all workouts, exercises and history on this device.',
      confirmLabel: 'Import',
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      // ignore: avoid_slow_async_io
      final json = await XFile(path).readAsString();
      await ref.read(backupServiceProvider).importJson(json);

      // Provider invalidation after a replace-all import: most of the
      // screens in this app already watch live drift streams
      // (`watchAll`/`watchSummaries`/`tableUpdates`), which re-emit on their
      // own the moment the import's transaction commits, so they need no
      // help here. The exceptions are providers that read the database
      // once and cache the result rather than staying subscribed —
      // `activeSessionControllerProvider` in particular resolves
      // `watchActiveSession().first` inside `build()` and then drives its
      // own state from mutator methods, so a raw import (which bypasses
      // every mutator) leaves it stale unless explicitly invalidated. The
      // other four are invalidated too, defensively, since "did the import
      // actually take" is exactly the moment a user is watching for a
      // stale screen.
      ref.invalidate(activeSessionControllerProvider);
      ref.invalidate(exerciseListProvider);
      ref.invalidate(filteredExercisesProvider);
      ref.invalidate(templateSummariesProvider);
      ref.invalidate(historyProvider);

      messenger.showSnackBar(const SnackBar(content: Text('Import complete')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

class _NotificationPermissionTile extends ConsumerStatefulWidget {
  const _NotificationPermissionTile();

  @override
  ConsumerState<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends ConsumerState<_NotificationPermissionTile> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Guarded like every other platform-channel call in this app
  // (`ActiveSessionController._safe`): `flutter_local_notifications` throws
  // on a host with no plugin registered (including this project's widget
  // tests, which don't call `NotificationService.init()`), and that must
  // degrade to "unknown/not granted" rather than crash the settings screen.
  Future<void> _refresh() async {
    bool granted;
    try {
      granted = await ref.read(notificationServiceProvider).hasPermission();
    } catch (_) {
      granted = false;
    }
    if (mounted) setState(() => _granted = granted);
  }

  Future<void> _requestOrOpenSettings() async {
    if (_granted == true) return;
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (_) {
      // Swallowed — see [_refresh].
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notifications_outlined),
      title: const Text('Notification permission'),
      subtitle: Text(granted == null
          ? 'Checking…'
          : (granted ? 'Granted' : 'Not granted')),
      trailing: granted == true
          ? null
          : TextButton(
              onPressed: _requestOrOpenSettings,
              child: const Text('Request'),
            ),
    );
  }
}
