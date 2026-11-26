import 'package:flutter/services.dart';

const _orientation = MethodChannel('erk.eco.wave/orientation');
Future<void>? _pending;

/// Keeps the app in landscape. Android system prompts (permission, Wi-Fi,
/// keyboard) can rotate the activity; the native side snaps it back.
Future<void> lockLandscape() {
  final pending = _pending;
  if (pending != null) return pending;
  final run = _lock();
  _pending = run;
  return run.whenComplete(() {
    if (identical(_pending, run)) _pending = null;
  });
}

Future<void> _lock() async {
  try {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _orientation.invokeMethod<void>('lock');
  } on MissingPluginException {
    // Desktop tests and platforms without the Android channel.
  } on PlatformException {
    // The activity is not attached yet.
  }
}
