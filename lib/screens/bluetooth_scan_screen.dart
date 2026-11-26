import 'dart:async';

import 'package:controller/services/bluetooth_service.dart';
import 'package:controller/services/connection_manager.dart';
import 'package:flutter/material.dart';

class BluetoothScanScreen extends StatefulWidget {
  const BluetoothScanScreen({super.key});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  final _manager = ConnectionManager.instance;
  StreamSubscription<List<BoatScanDevice>>? _resultsSub;
  StreamSubscription<bool>? _scanningSub;
  List<BoatScanDevice> _devices = const [];
  bool _scanning = false;
  String? _connectingId;
  String? _error;
  bool _hideUnnamed = true;

  @override
  void initState() {
    super.initState();
    _resultsSub = _manager.bluetooth.scanResults.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    _scanningSub = _manager.bluetooth.scanning.listen((scanning) {
      if (mounted) setState(() => _scanning = scanning);
    });
    _startScan();
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    unawaited(_manager.bluetooth.stopScan());
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _error = null;
      _devices = const [];
    });
    try {
      await _manager.bluetooth.startScan();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _connect(BoatScanDevice device) async {
    setState(() => _connectingId = device.id);
    try {
      await _manager.bluetooth.stopScan();
      await _manager.connectBluetooth(device);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectingId = null;
        _error = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth connect failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _hideUnnamed
        ? _devices.where((device) => !device.name.startsWith('Unknown')).toList()
        : _devices;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ERK Eco Wave',
          style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            color: const Color(0xFF3DDC97),
            tooltip: 'Scan again',
            onPressed: _scanning || _connectingId != null ? null : _startScan,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_scanning) const LinearProgressIndicator(minHeight: 2),
          SwitchListTile(
            value: _hideUnnamed,
            onChanged: (value) => setState(() => _hideUnnamed = value),
            title: const Text('Hide unnamed devices'),
            activeThumbColor: const Color(0xFF3DDC97),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
            ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? 'Scanning for the boat…' : 'No devices found',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = visible[index];
                      final connecting = _connectingId == device.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF1E3A5F)),
                        ),
                        tileColor: const Color(0xFF12243F),
                        leading: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF16325A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: connecting
                                ? const CircularProgressIndicator(strokeWidth: 2)
                                : const Icon(
                                    Icons.directions_boat,
                                    color: Color(0xFF3DDC97),
                                  ),
                          ),
                        ),
                        title: Text(device.name),
                        subtitle: Text('${device.id}  ·  ${device.rssi} dBm'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _connectingId == null ? () => _connect(device) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
