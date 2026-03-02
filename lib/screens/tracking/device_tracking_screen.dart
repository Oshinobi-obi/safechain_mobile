import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const Color kPrimaryGreen = Color(0xFF20C997);

class DeviceTrackingScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const DeviceTrackingScreen({
    super.key,
    required this.deviceId,
    required this.deviceName
  });

  @override
  State<DeviceTrackingScreen> createState() => _DeviceTrackingScreenState();
}

class _DeviceTrackingScreenState extends State<DeviceTrackingScreen> {
  BluetoothDevice? _device;
  LatLng? _currentLocation;
  String _statusText = "Connecting to device...";
  StreamSubscription? _notifySubscription;
  StreamSubscription? _stateSubscription;

  final String _serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  final String _txCharacteristicUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  @override
  void initState() {
    super.initState();
    _connectAndListen();
  }

  Future<void> _connectAndListen() async {
    try {
      _device = BluetoothDevice.fromId(widget.deviceId);

      // ── Step 1: Check Bluetooth is on ──────────────────────────────────
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        if (mounted) setState(() => _statusText = "Bluetooth is turned off. Please enable it.");
        return;
      }

      // ── Step 2: Connect ────────────────────────────────────────────────
      if (mounted) setState(() => _statusText = "Connecting...");
      try {
        await _device!.connect(timeout: const Duration(seconds: 15));
      } on FlutterBluePlusException catch (e) {
        if (mounted) {
          if (e.code == FbpErrorCode.timeout.index) {
            setState(() => _statusText = "Device not found. Make sure it is powered on and nearby.");
          } else {
            setState(() => _statusText = "Could not connect. Try moving closer to the device.");
          }
        }
        return;
      }

      // ── Step 3: Watch for disconnection ───────────────────────────────
      _stateSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (mounted) setState(() => _statusText = "Device disconnected. It may be out of range.");
        }
      });

      // ── Step 4: Discover services ─────────────────────────────────────
      if (mounted) setState(() => _statusText = "Discovering Services...");
      List<BluetoothService> services;
      try {
        services = await _device!.discoverServices();
      } catch (e) {
        if (mounted) setState(() => _statusText = "Failed to read device services. Try again.");
        return;
      }

      // ── Step 5: Find SafeChain service ───────────────────────────────
      BluetoothService service;
      try {
        service = services.firstWhere(
              (s) => s.uuid.toString().toUpperCase() == _serviceUuid,
        );
      } catch (_) {
        if (mounted) setState(() => _statusText = "Not a SafeChain device. Wrong device connected.");
        return;
      }

      // ── Step 6: Find GPS characteristic ──────────────────────────────
      BluetoothCharacteristic characteristic;
      try {
        characteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == _txCharacteristicUuid,
        );
      } catch (_) {
        if (mounted) setState(() => _statusText = "GPS channel not found on this device.");
        return;
      }

      // ── Step 7: Subscribe to GPS data ────────────────────────────────
      if (!characteristic.isNotifying) {
        await characteristic.setNotifyValue(true);
      }
      if (mounted) setState(() => _statusText = "Waiting for GPS Signal...");

      _notifySubscription = characteristic.lastValueStream.listen((value) {
        _parseGpsData(value);
      });

    } catch (e) {
      // Fallback for any unexpected error — shows the actual error message
      if (mounted) setState(() => _statusText = "Unexpected error: ${e.toString().replaceAll('Exception: ', '')}");
      debugPrint("Tracking Error: $e");
    }
  }

  void _parseGpsData(List<int> value) {
    try {
      String data = utf8.decode(value).trim();

      if (data.contains(',')) {
        List<String> parts = data.split(',');
        if (parts.length == 2) {
          double? lat = double.tryParse(parts[0]);
          double? lon = double.tryParse(parts[1]);

          if (lat != null && lon != null && lat != 0.0) {
            if (mounted) {
              setState(() {
                _currentLocation = LatLng(lat, lon);
                _statusText = "Live Tracking Active";
              });
            }
          }
        }
      }
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _notifySubscription?.cancel();
    _stateSubscription?.cancel();
    //_device?.disconnect();
    // remains active in the background for the Home Screen to use.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.deviceName, style: const TextStyle(color: Colors.black, fontSize: 16)),
            Text(_statusText, style: const TextStyle(color: kPrimaryGreen, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(14.5995, 120.9842),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.safechain.safechain',
                maxZoom: 20,
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black26)]
                              ),
                              child: const Icon(Icons.my_location, color: kPrimaryGreen, size: 30)
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                            child: const Text("Device", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          Positioned(
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("STATUS", style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryGreen)),
                    ],
                  ),
                  if (_currentLocation == null)
                    const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryGreen)
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("GPS Coordinates", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                      ],
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}