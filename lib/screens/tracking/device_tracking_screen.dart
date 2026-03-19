import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

const Color kPrimaryGreen = Color(0xFF20C997);

class DeviceTrackingScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const DeviceTrackingScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceTrackingScreen> createState() => _DeviceTrackingScreenState();
}

class _DeviceTrackingScreenState extends State<DeviceTrackingScreen> {
  // ── BLE ──────────────────────────────────────────────────────
  BluetoothDevice? _device;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _stateSubscription;

  final String _serviceUuid       = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  final String _txCharacteristicUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  // ── Map ───────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  LatLng? _deviceLocation;
  LatLng? _userLocation;
  bool _didCenterOnDevice = false; // only auto-center on first GPS fix

  // ── Compass ───────────────────────────────────────────────────
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _headingDeg = 0;

  // ── Status ────────────────────────────────────────────────────
  String _statusText = "Connecting to device...";

  @override
  void initState() {
    super.initState();
    _connectAndListen();
    _startCompass();
    _getUserLocation();
  }

  // ── Compass ───────────────────────────────────────────────────
  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _headingDeg = event.heading!);
      }
    });
  }

  // ── User location ─────────────────────────────────────────────
  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  // ── Go to my location ─────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    await _getUserLocation();
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16.0);
    }
  }

  // ── Go to device ──────────────────────────────────────────────
  void _goToDevice() {
    if (_deviceLocation != null) {
      _mapController.move(_deviceLocation!, 16.0);
    }
  }

  // ── BLE connection ────────────────────────────────────────────
  Future<void> _connectAndListen() async {
    try {
      _device = BluetoothDevice.fromId(widget.deviceId);

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        if (mounted) setState(() => _statusText = "Bluetooth is turned off. Please enable it.");
        return;
      }

      if (mounted) setState(() => _statusText = "Connecting...");
      try {
        await _device!.connect(timeout: const Duration(seconds: 15));
      } on FlutterBluePlusException catch (e) {
        if (mounted) {
          setState(() => _statusText = e.code == FbpErrorCode.timeout.index
              ? "Device not found. Make sure it is powered on and nearby."
              : "Could not connect. Try moving closer to the device.");
        }
        return;
      }

      _stateSubscription = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && mounted) {
          setState(() => _statusText = "Device disconnected. It may be out of range.");
        }
      });

      if (mounted) setState(() => _statusText = "Discovering Services...");
      List<BluetoothService> services;
      try {
        services = await _device!.discoverServices();
      } catch (e) {
        if (mounted) setState(() => _statusText = "Failed to read device services. Try again.");
        return;
      }

      BluetoothService service;
      try {
        service = services.firstWhere(
              (s) => s.uuid.toString().toUpperCase() == _serviceUuid,
        );
      } catch (_) {
        if (mounted) setState(() => _statusText = "Not a SafeChain device. Wrong device connected.");
        return;
      }

      BluetoothCharacteristic characteristic;
      try {
        characteristic = service.characteristics.firstWhere(
              (c) => c.uuid.toString().toUpperCase() == _txCharacteristicUuid,
        );
      } catch (_) {
        if (mounted) setState(() => _statusText = "GPS channel not found on this device.");
        return;
      }

      if (!characteristic.isNotifying) {
        await characteristic.setNotifyValue(true);
      }
      if (mounted) setState(() => _statusText = "Waiting for GPS Signal...");

      _notifySubscription = characteristic.lastValueStream.listen(_parseGpsData);
    } catch (e) {
      if (mounted) {
        setState(() => _statusText =
        "Unexpected error: ${e.toString().replaceAll('Exception: ', '')}");
      }
    }
  }

  void _parseGpsData(List<int> value) {
    try {
      final data = utf8.decode(value).trim();
      if (data.contains(',')) {
        final parts = data.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0]);
          final lon = double.tryParse(parts[1]);
          if (lat != null && lon != null && lat != 0.0) {
            if (mounted) {
              setState(() {
                _deviceLocation = LatLng(lat, lon);
                _statusText = "Live Tracking Active";
              });
              // Auto-pan ONLY on the very first GPS fix
              if (!_didCenterOnDevice) {
                _didCenterOnDevice = true;
                _mapController.move(_deviceLocation!, 16.0);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _notifySubscription?.cancel();
    _stateSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.deviceName,
                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_statusText,
                style: const TextStyle(color: kPrimaryGreen, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _deviceLocation ?? const LatLng(14.5995, 120.9842),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.safechain.safechain',
                maxZoom: 20,
              ),

              // ── User location + heading cone ─────────────────
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 120,
                      height: 120,
                      child: _UserLocationMarker(headingDeg: _headingDeg),
                    ),
                  ],
                ),

              // ── Device pin ───────────────────────────────────
              if (_deviceLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _deviceLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(blurRadius: 5, color: Colors.black26)
                              ],
                            ),
                            child: const Icon(Icons.my_location,
                                color: kPrimaryGreen, size: 30),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text("Device",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── FAB — Go to device pin ────────────────────────
          Positioned(
            right: 16,
            bottom: 110 + MediaQuery.of(context).padding.bottom,
            child: FloatingActionButton.small(
              heroTag: 'go_device',
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _goToDevice,
              tooltip: 'Go to device',
              child: const Icon(Icons.gps_fixed, color: kPrimaryGreen),
            ),
          ),

          // ── Status card ───────────────────────────────────────
          Positioned(
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("STATUS",
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_statusText,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kPrimaryGreen)),
                    ],
                  ),
                  if (_deviceLocation == null)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kPrimaryGreen),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${_deviceLocation!.latitude.toStringAsFixed(5)}, "
                              "${_deviceLocation!.longitude.toStringAsFixed(5)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text("GPS Coordinates",
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 10)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// User location marker with heading cone
// ─────────────────────────────────────────────────────────────────
class _UserLocationMarker extends StatelessWidget {
  final double headingDeg;
  const _UserLocationMarker({required this.headingDeg});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Heading cone (fan / sector)
        Transform.rotate(
          angle: headingDeg * math.pi / 180,
          child: CustomPaint(
            size: const Size(120, 120),
            painter: _ConePainter(),
          ),
        ),
        // Blue dot
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF2979FF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Cone sweep: 60° arc pointing upward (north = 0° before rotation)
    const sweepAngle = 60.0 * math.pi / 180;
    const startAngle = -math.pi / 2 - sweepAngle / 2; // centered on "up"

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2979FF).withOpacity(0.45),
          const Color(0xFF2979FF).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConePainter oldDelegate) => false;
}