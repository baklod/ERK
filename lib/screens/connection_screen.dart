import 'package:controller/orientation_lock.dart';
import 'package:controller/screens/bluetooth_scan_screen.dart';
import 'package:controller/services/connection_manager.dart';
import 'package:controller/services/wifi_scanner.dart';
import 'package:controller/widgets/connection_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _manager = ConnectionManager.instance;
  final _scanner = WifiScanner();
  List<EspWifiNetwork> _networks = const [];
  bool _scanning = false;
  bool _espOnly = true;
  String? _joining;
  String? _wifiError;

  @override
  void initState() {
    super.initState();
    _scanWifi();
  }

  List<EspWifiNetwork> get _visible {
    if (!_espOnly) return _networks;
    final matches = _networks.where((network) => network.likelyEsp).toList();
    return matches.isEmpty ? _networks : matches;
  }

  Future<void> _scanWifi() async {
    setState(() {
      _scanning = true;
      _wifiError = null;
    });
    try {
      final networks = await _scanner.scan();
      if (!mounted) return;
      setState(() => _networks = networks);
    } catch (error) {
      if (!mounted) return;
      setState(() => _wifiError = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _join(EspWifiNetwork network) async {
    String? password;
    if (network.secured) {
      password = await _askPassword(network.ssid);
      await lockLandscape();
      if (password == null || !mounted) return;
    }
    setState(() => _joining = network.ssid);
    try {
      await _scanner.join(network, password: password);
      await _manager.connectWifi(
        host: '192.168.4.1',
        port: 81,
        name: network.ssid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PlatformException catch (error) {
      if (!mounted) return;
      _toast(error.message ?? 'Could not join ${network.ssid}');
    } catch (error) {
      if (!mounted) return;
      _toast('Wi-Fi connect failed: $error');
    } finally {
      await lockLandscape();
      if (mounted) setState(() => _joining = null);
    }
  }

  Future<String?> _askPassword(String ssid) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          backgroundColor: const Color(0xFF12243F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ssid, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Wi-Fi password'),
                  onTap: () {
                    lockLandscape();
                  },
                  onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3DDC97),
                        foregroundColor: const Color(0xFF071422),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(controller.text),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      controller.dispose();
      return lockLandscape();
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF071422),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: const Text(
              'ERK Eco Wave',
              style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
            actions: [
              if (_manager.isConnected)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF3DDC97)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to controller'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConnectionStatus(
                      status: _manager.status,
                      label: _manager.label,
                      kind: _manager.kind,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: _SectionTitle(
                                        icon: Icons.wifi_rounded,
                                        title: 'Wi-Fi',
                                        subtitle: 'ESP32 access points',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Scan again',
                                      color: const Color(0xFF3DDC97),
                                      onPressed: _scanning || _joining != null ? null : _scanWifi,
                                      icon: const Icon(Icons.refresh),
                                    ),
                                  ],
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  value: _espOnly,
                                  onChanged: (value) => setState(() => _espOnly = value),
                                  title: const Text('ESP32 networks'),
                                  activeThumbColor: const Color(0xFF3DDC97),
                                ),
                                if (_scanning) const LinearProgressIndicator(minHeight: 2),
                                if (_wifiError != null)
                                  Text(
                                    _wifiError!,
                                    style: const TextStyle(color: Color(0xFFFF8A80)),
                                  ),
                                const Divider(height: 1, color: Color(0xFF1E3A5F)),
                                Expanded(
                                  child: _visible.isEmpty
                                      ? Center(
                                          child: Text(
                                            _scanning ? 'Searching…' : 'No Wi-Fi networks found',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        )
                                      : ListView.separated(
                                          primary: false,
                                          padding: EdgeInsets.zero,
                                          physics: const ClampingScrollPhysics(),
                                          itemCount: _visible.length,
                                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                                          itemBuilder: (context, index) {
                                            final network = _visible[index];
                                            final joining = _joining == network.ssid;
                                            return Material(
                                              color: const Color(0xFF0E1C36),
                                              borderRadius: BorderRadius.circular(10),
                                              child: InkWell(
                                                onTap: _joining == null && !_manager.isBusy
                                                    ? () => _join(network)
                                                    : null,
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      joining
                                                          ? const SizedBox(
                                                              width: 22,
                                                              height: 22,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            )
                                                          : Icon(
                                                              network.secured ? Icons.wifi_lock : Icons.wifi,
                                                              color: network.likelyEsp
                                                                  ? const Color(0xFF3DDC97)
                                                                  : Colors.white70,
                                                            ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(network.ssid),
                                                            Text(
                                                              '${network.likelyEsp ? 'ESP32 · ' : ''}${network.level} dBm',
                                                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _SectionTitle(
                                  icon: Icons.bluetooth_rounded,
                                  title: 'Bluetooth',
                                  subtitle: 'Scan for a BLE UART module',
                                ),
                                const Spacer(),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF3DDC97),
                                    side: const BorderSide(color: Color(0xFF3DDC97)),
                                  ),
                                  onPressed: _manager.isBusy
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => const BluetoothScanScreen(),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.bluetooth_searching_rounded),
                                  label: const Text('Scan devices'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12243F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF16325A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF3DDC97)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(subtitle, style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      ],
    );
  }
}
