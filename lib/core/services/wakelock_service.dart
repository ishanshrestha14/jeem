import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Thin wrapper around `wakelock_plus`'s static API. Exists as an injectable
/// class (rather than the active session screen calling `WakelockPlus.*`
/// directly) so tests can override [wakelockServiceProvider] with a fake and
/// assert on calls — `flutter test` has no host implementation for the real
/// platform channel, and this project runs no Android/iOS build here to
/// exercise one.
class WakelockService {
  const WakelockService();

  Future<void> enable() => WakelockPlus.enable();
  Future<void> disable() => WakelockPlus.disable();
}

final wakelockServiceProvider = Provider<WakelockService>(
  (ref) => const WakelockService(),
);
