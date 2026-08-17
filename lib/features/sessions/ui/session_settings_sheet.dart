import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/keep_screen_on_setting.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../providers/active_session_controller.dart';

/// Session settings sheet, opened from the active session screen's overflow
/// menu. Five switches (auto-focus next set / next exercise, both bound to
/// the session row; keep screen on, sound on rest complete, and haptics —
/// all device-wide preferences), a debounced multiline notes field, and a
/// read-only weight-unit row (PRD §9.6). The auto-focus switches persist
/// immediately through [ActiveSessionController]; this widget never touches
/// `SessionRepository` directly. "Keep screen on" persists through
/// [keepScreenOnSettingProvider] (`shared_preferences`-backed — see that
/// file for why this is device-wide rather than a session column) and is
/// read by `ActiveSessionScreen`/`WakelockService`, not by this sheet.
/// "Sound on rest complete" and "Haptics" follow the identical
/// `shared_preferences` pattern via [soundEnabledSettingProvider] and
/// [hapticsEnabledSettingProvider] (`session_feedback_settings.dart`) and
/// are read by [ActiveSessionController]'s rest-finish/set-complete side
/// effects (Task 18).
Future<void> showSessionSettingsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SessionSettingsSheetContent(),
  );
}

class _SessionSettingsSheetContent extends ConsumerStatefulWidget {
  const _SessionSettingsSheetContent();

  @override
  ConsumerState<_SessionSettingsSheetContent> createState() =>
      _SessionSettingsSheetContentState();
}

class _SessionSettingsSheetContentState
    extends ConsumerState<_SessionSettingsSheetContent> {
  final TextEditingController _notesController = TextEditingController();
  Timer? _debounce;
  bool _notesHydrated = false;

  // Cached in `initState` rather than read from `ref` inside `dispose` —
  // Riverpod's `ConsumerStatefulElement.unmount` calls `Element.unmount()`
  // (which marks the element defunct) *before* calling `State.dispose()`,
  // so `ref.read(...)` inside `dispose()` always throws `Cannot use "ref"
  // after the widget was disposed`. A plain Dart reference to the notifier,
  // captured while `ref` is still valid, sidesteps that entirely. This is
  // the same fix already applied to `TemplateEditorScreen`'s debounced
  // fields (Task 8) — see its `dispose()` for the identical reasoning.
  late final ActiveSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(activeSessionControllerProvider.notifier);
  }

  @override
  void dispose() {
    // Flush a pending debounced write rather than cancelling it outright —
    // cancelling on close would silently drop whatever the user just typed.
    // This exact bug (a dropped debounce on sheet close) was found and
    // fixed in Task 8; the fix here is to *always* write the current text
    // synchronously on dispose when a debounce was still pending, never to
    // just cancel the timer.
    if (_debounce != null && _debounce!.isActive) {
      _debounce!.cancel();
      _flushNotes();
    }
    _notesController.dispose();
    super.dispose();
  }

  void _flushNotes() {
    _controller.setSessionNotes(_notesController.text);
  }

  void _onNotesChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _flushNotes);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeSessionControllerProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();
    final session = state.session.session;

    // Hydrate the text controller once from the persisted value; later
    // rebuilds (e.g. from a switch toggle elsewhere in this same state)
    // must not stomp on whatever the user is mid-typing.
    if (!_notesHydrated) {
      _notesHydrated = true;
      _notesController.text = session.notes ?? '';
    }

    final colors = Theme.of(context).extension<SemanticColors>()!;
    final controller = _controller;
    final keepScreenOn = ref.watch(keepScreenOnSettingProvider).valueOrNull ?? false;
    final soundEnabled = ref.watch(soundEnabledSettingProvider).valueOrNull ?? true;
    final hapticsEnabled = ref.watch(hapticsEnabledSettingProvider).valueOrNull ?? true;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SESSION SETTINGS',
              style: AppTheme.columnHeader.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 4),
            _SettingsSwitch(
              switchKey: const Key('autoFocusNextSetSwitch'),
              label: 'Auto-focus next set',
              value: session.autoFocusNextSet,
              activeColor: colors.rest,
              onChanged: controller.setAutoFocusNextSet,
            ),
            Divider(height: 1, color: colors.line),
            _SettingsSwitch(
              switchKey: const Key('autoFocusNextExerciseSwitch'),
              label: 'Auto-focus next exercise',
              value: session.autoFocusNextExercise,
              activeColor: colors.rest,
              onChanged: controller.setAutoFocusNextExercise,
            ),
            Divider(height: 1, color: colors.line),
            _SettingsSwitch(
              switchKey: const Key('keepScreenOnSwitch'),
              label: 'Keep screen on',
              value: keepScreenOn,
              activeColor: colors.rest,
              onChanged: (v) =>
                  ref.read(keepScreenOnSettingProvider.notifier).setEnabled(v),
            ),
            Divider(height: 1, color: colors.line),
            _SettingsSwitch(
              switchKey: const Key('soundOnRestCompleteSwitch'),
              label: 'Sound on rest complete',
              value: soundEnabled,
              activeColor: colors.rest,
              onChanged: (v) =>
                  ref.read(soundEnabledSettingProvider.notifier).setEnabled(v),
            ),
            Divider(height: 1, color: colors.line),
            _SettingsSwitch(
              switchKey: const Key('hapticsSwitch'),
              label: 'Haptics',
              value: hapticsEnabled,
              activeColor: colors.rest,
              onChanged: (v) => ref
                  .read(hapticsEnabledSettingProvider.notifier)
                  .setEnabled(v),
            ),
            Divider(height: 1, color: colors.line),
            const SizedBox(height: 20),
            Text(
              'NOTES',
              style: AppTheme.columnHeader.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('sessionNotesField'),
              controller: _notesController,
              onChanged: _onNotesChanged,
              minLines: 3,
              maxLines: 6,
              style: AppTheme.body.copyWith(color: AppTheme.chalk),
              cursorColor: AppTheme.chalk,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Notes for this session',
                hintStyle: AppTheme.body.copyWith(color: colors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.line),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: colors.line),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Text(
                    'WEIGHT UNIT',
                    style: AppTheme.columnHeader.copyWith(color: colors.muted),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    session.weightUnit,
                    style: AppTheme.body.copyWith(color: AppTheme.chalk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline-bounded switch row — no card chrome, `rest` as the accent
/// (colour still means "live"), min 48dp touch target.
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.switchKey,
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final Key switchKey;
  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.body.copyWith(color: AppTheme.chalk),
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            activeThumbColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
