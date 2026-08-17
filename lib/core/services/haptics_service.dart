import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around `HapticFeedback`'s static API — same shape as
/// [WakelockService]: an injectable class so tests can override
/// [hapticsServiceProvider] with a fake and assert on calls, rather than
/// exercising a real platform channel `flutter test` has no host
/// implementation for.
///
/// Deliberately does NOT read the haptics-enabled setting itself. Whether a
/// given call happens at all is a decision [ActiveSessionController] makes
/// (reading `hapticsEnabledSettingProvider`) before calling in — mirroring
/// how every other session preference (auto-focus, keep-screen-on) is
/// enforced by the controller rather than by the service it drives. That
/// keeps this class a dumb platform wrapper and keeps "honours the toggle"
/// testable at the controller boundary with a plain recording fake, instead
/// of duplicating the on/off logic inside the fake itself.
class HapticsService {
  const HapticsService();

  Future<void> setCompleted() => HapticFeedback.mediumImpact();
  Future<void> restFinished() => HapticFeedback.heavyImpact();
}

final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => const HapticsService(),
);
