import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:safechain/services/ble_connection_service.dart';

const Color kPrimaryGreen = Color(0xFF20C997);

// ── Barangay Gulod fixed locations ────────────────────────────────
const LatLng kGulodHall = LatLng(14.714183, 121.039451);
const List<LatLng> kGulodBoundary = [
  LatLng(14.7185219, 121.0398006),
  LatLng(14.7186418, 121.0399609),
  LatLng(14.7187774, 121.0401694),
  LatLng(14.7189758, 121.0405221),
  LatLng(14.7190653, 121.0408212),
  LatLng(14.7190822, 121.0411203),
  LatLng(14.718745,  121.0415923),
  LatLng(14.7183403, 121.0420805),
  LatLng(14.7183454, 121.0423755),
  LatLng(14.718444,  121.0426384),
  LatLng(14.7187346, 121.0430944),
  LatLng(14.7187346, 121.0433358),
  LatLng(14.7185582, 121.0435289),
  LatLng(14.7180497, 121.0436161),
  LatLng(14.7172922, 121.0438213),
  LatLng(14.7164776, 121.0440399),
  LatLng(14.7161637, 121.0442457),
  LatLng(14.716012,  121.0443594),
  LatLng(14.7158706, 121.0443121),
  LatLng(14.7155696, 121.0435396),
  LatLng(14.7149989, 121.0428959),
  LatLng(14.7142725, 121.0430193),
  LatLng(14.7135461, 121.0432392),
  LatLng(14.7131752, 121.0430541),
  LatLng(14.712773,  121.0429334),
  LatLng(14.7123735, 121.043081),
  LatLng(14.7120518, 121.0433197),
  LatLng(14.712,     121.043545),
  LatLng(14.7120311, 121.0437488),
  LatLng(14.7125266, 121.0444033),
  LatLng(14.7129495, 121.0451275),
  LatLng(14.7129287, 121.0455942),
  LatLng(14.7127782, 121.0459429),
  LatLng(14.7123528, 121.0462755),
  LatLng(14.7119688, 121.0467154),
  LatLng(14.71145,   121.0471445),
  LatLng(14.7108792, 121.0466939),
  LatLng(14.7104123, 121.0460502),
  LatLng(14.709996,  121.0466173),
  LatLng(14.7092104, 121.0468214),
  LatLng(14.7090859, 121.0470574),
  LatLng(14.7053189, 121.0473471),
  LatLng(14.7046651, 121.0454374),
  LatLng(14.7053085, 121.0453945),
  LatLng(14.7052048, 121.0417896),
  LatLng(14.7068029, 121.0412531),
  LatLng(14.7078199, 121.0414033),
  LatLng(14.7083934, 121.0391347),
  LatLng(14.7093896, 121.0377614),
  LatLng(14.7096179, 121.0373752),
  LatLng(14.7094934, 121.0369889),
  LatLng(14.7093273, 121.0365383),
  LatLng(14.7096594, 121.0346286),
  LatLng(14.7098538, 121.0337481),
  LatLng(14.7103727, 121.0333619),
  LatLng(14.7103519, 121.0338983),
  LatLng(14.7105387, 121.0342309),
  LatLng(14.7109849, 121.0341987),
  LatLng(14.711566,  121.0335979),
  LatLng(14.7117528, 121.0336945),
  LatLng(14.712199,  121.0343275),
  LatLng(14.7127075, 121.0347566),
  LatLng(14.7130292, 121.0346708),
  LatLng(14.7131122, 121.0345098),
  LatLng(14.7134028, 121.0342202),
  LatLng(14.7138178, 121.0342202),
  LatLng(14.7144923, 121.0348424),
  LatLng(14.7147829, 121.0351107),
  LatLng(14.7147933, 121.0353467),
  LatLng(14.7145961, 121.0368165),
  LatLng(14.7152706, 121.0373744),
  LatLng(14.7158517, 121.0373744),
  LatLng(14.71663,   121.0387906),
  LatLng(14.7172215, 121.0387692),
  LatLng(14.7185219, 121.0398006),
];

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
  // ── BLE — handled by BleConnectionService singleton ──────────
  final _ble = BleConnectionService.instance;

  // ── Map ───────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  LatLng? _deviceLocation;
  LatLng? _userLocation;
  bool _didCenterOnDevice = false;

  // ── Compass ───────────────────────────────────────────────────
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _headingDeg = 0;

  // ── Status ────────────────────────────────────────────────────
  String _statusText = "Connecting to device...";

  @override
  void initState() {
    super.initState();
    _startCompass();
    _getUserLocation();
    _ble.onLocationUpdate = (location) {
      if (!mounted) return;
      setState(() {
        _deviceLocation = location;
        _statusText = "Live Tracking Active";
      });
      if (!_didCenterOnDevice) {
        _didCenterOnDevice = true;
        _mapController.move(location, 16.0);
      }
    };

    // ── Seed status from current service state ─────────────────────
    if (_ble.lastLocation != null) {
      _deviceLocation = _ble.lastLocation;
      _statusText = "Live Tracking Active";
    } else if (_ble.isRunning) {
      _statusText = "Waiting for GPS Signal...";
    }

    // Start BLE service — if already running, replays lastLocation via callback
    _ble.start(widget.deviceId, widget.deviceName);
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

  @override
  void dispose() {
    // Clear UI callback — service keeps running in background
    _ble.onLocationUpdate = null;
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
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
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

              // ── Barangay Gulod boundary ───────────────────────
              // Uses only PolygonLayer — no isDotted, works on all
              // flutter_map versions. Border is solid red, fill is
              // semi-transparent red.
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: kGulodBoundary,
                    color: const Color(0x22FF3B30),       // light red fill
                    borderColor: const Color(0xFFFF3B30), // solid red border
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),

              // ── Barangay Gulod Hall / Evacuation Center marker ──
              MarkerLayer(
                markers: [
                  Marker(
                    point: kGulodHall,
                    width: 160,
                    height: 90,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0057B8),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(blurRadius: 6, color: Colors.black38)
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0057B8),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(blurRadius: 4, color: Colors.black26)
                            ],
                          ),
                          child: const Text(
                            "Brgy. Gulod Hall\n& Evacuation Center",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Device pin with heading cone ─────────────────
              // Cone is drawn behind the icon — no separate blue dot.
              if (_deviceLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _deviceLocation!,
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Heading cone (same painter, green tint for device)
                          Transform.rotate(
                            angle: _headingDeg * math.pi / 180,
                            child: CustomPaint(
                              size: const Size(120, 120),
                              painter: _DeviceConePainter(),
                            ),
                          ),
                          // Custom device icon on top
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(blurRadius: 6, color: Colors.black26)
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: kPrimaryGreen,
                              size: 26,
                            ),
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
        Transform.rotate(
          angle: headingDeg * math.pi / 180,
          child: CustomPaint(
            size: const Size(120, 120),
            painter: _ConePainter(),
          ),
        ),
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

// Green cone for the device marker
class _DeviceConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const sweepAngle = 60.0 * math.pi / 180;
    const startAngle = -math.pi / 2 - sweepAngle / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          kPrimaryGreen.withOpacity(0.45),
          kPrimaryGreen.withOpacity(0.0),
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
  bool shouldRepaint(_DeviceConePainter oldDelegate) => false;
}

class _ConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const sweepAngle = 60.0 * math.pi / 180;
    const startAngle = -math.pi / 2 - sweepAngle / 2;

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