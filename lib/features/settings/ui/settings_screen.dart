import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';

/// App name shown in the About section. Matches `pubspec.yaml`'s `name`
/// entry (title-cased for display), not a widget/package identifier.
const String appDisplayName = 'GymFlow';

/// Matches the `version:` line in `pubspec.yaml`. There is no
/// `package_info_plus` dependency wired up in this project yet, so this is
/// a plain constant kept in sync by hand rather than read at runtime.
const String appVersion = '1.0.0';

/// Only an "About" section for now — the real settings (units, defaults,
/// backup/restore, etc.) are a later task. A tab must never lead to a
/// "coming soon" placeholder, so this renders honest, real content: what
/// the app is, its version, and the fact that everything is local-only.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('About', style: AppTheme.columnHeader.copyWith(color: muted)),
          const SizedBox(height: 12),
          Text(appDisplayName, style: AppTheme.exerciseName.copyWith(
            color: theme.colorScheme.onSurface,
          )),
          const SizedBox(height: 4),
          Text('Version $appVersion',
              style: AppTheme.body.copyWith(color: muted)),
          const SizedBox(height: 16),
          Divider(height: 1, color: theme.extension<SemanticColors>()!.line),
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
}
