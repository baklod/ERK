import 'package:controller/orientation_lock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

class EspWifiNetwork {
  const EspWifiNetwork({
    required this.ssid,
    required this.level,
    required this.secured,
    required this.likelyEsp,
  });

  final String ssid;
  final int level;
  final bool secured;
  final bool likelyEsp;
}

class WifiScanner {
  static final _espName = RegExp(r'esp|erk|eco|wave|boat', caseSensitive: false);
  static const _join = MethodChannel('erk.eco.wave/wifi');

  Future<List<EspWifiNetwork>> scan() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('Wi-Fi scanning runs on Android');
    }

    try {
      await <Permission>[
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
      ].request();
    } catch (_) {}
    await lockLandscape();

    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      throw StateError(_scanMessage(canScan));
    }

    await WiFiScan.instance.startScan();
    await Future<void>.delayed(const Duration(seconds: 2));

    final canRead = await WiFiScan.instance.canGetScannedResults();
    if (canRead != CanGetScannedResults.yes) {
      throw StateError('Wi-Fi results are not available. Turn location on and allow nearby Wi-Fi.');
    }

    final points = await WiFiScan.instance.getScannedResults();
    final byName = <String, EspWifiNetwork>{};
    for (final point in points) {
      final ssid = point.ssid.trim();
      if (ssid.isEmpty) continue;
      final network = EspWifiNetwork(
        ssid: ssid,
        level: point.level,
        secured: _secured(point.capabilities),
        likelyEsp: _espName.hasMatch(ssid),
      );
      final current = byName[ssid];
      if (current == null || network.level > current.level) {
        byName[ssid] = network;
      }
    }

    final networks = byName.values.toList()
      ..sort((a, b) {
        if (a.likelyEsp != b.likelyEsp) return a.likelyEsp ? -1 : 1;
        return b.level.compareTo(a.level);
      });
    return networks;
  }

  Future<void> join(EspWifiNetwork network, {String? password}) {
    return _join.invokeMethod<void>('connect', {
      'ssid': network.ssid,
      'password': password ?? '',
    });
  }

  bool _secured(String capabilities) {
    final caps = capabilities.toUpperCase();
    return caps.contains('WPA') ||
        caps.contains('WEP') ||
        caps.contains('SAE') ||
        caps.contains('PSK');
  }

  String _scanMessage(CanStartScan can) {
    return switch (can) {
      CanStartScan.notSupported => 'This device cannot scan Wi-Fi',
      CanStartScan.noLocationServiceDisabled => 'Turn on location so Android can scan Wi-Fi',
      CanStartScan.noLocationPermissionDenied => 'Allow location permission to scan Wi-Fi',
      CanStartScan.noLocationPermissionRequired => 'Location permission is required to scan Wi-Fi',
      CanStartScan.noLocationPermissionUpgradeAccuracy => 'Allow precise location to scan Wi-Fi',
      CanStartScan.failed => 'Wi-Fi scan failed',
      CanStartScan.yes => 'Ready',
    };
  }
}
