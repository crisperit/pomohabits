import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Resolves the device IANA timezone identifier (e.g. `Europe/Warsaw`).
///
/// Falls back to `'UTC'` on [PlatformException] so unit tests (which lack a
/// platform channel) can override this provider without hitting the plugin.
/// Also falls back on [MissingPluginException]: in `flutter test` environments
/// the native plugin is not registered at all, so the channel throws
/// MissingPluginException rather than PlatformException.
final localTimezoneProvider = FutureProvider<String>((ref) async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  } on PlatformException {
    return 'UTC';
  } on MissingPluginException {
    return 'UTC';
  }
});
