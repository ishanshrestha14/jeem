import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the system alert sound when rest ends — no audio asset, no extra
/// package. Injectable for the same reason as [HapticsService]: so tests can
/// override [soundServiceProvider] with a recording fake instead of touching
/// a real platform channel. Whether this fires at all is gated by the
/// controller reading `soundEnabledSettingProvider`, not by this class — see
/// [HapticsService]'s doc comment for why.
class SoundService {
  const SoundService();

  Future<void> restComplete() => SystemSound.play(SystemSoundType.alert);
}

final soundServiceProvider = Provider<SoundService>(
  (ref) => const SoundService(),
);
