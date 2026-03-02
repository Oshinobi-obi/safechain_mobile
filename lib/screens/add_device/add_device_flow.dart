import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:animations/animations.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:safechain/services/notification_service.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:safechain/screens/home/home_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:safechain/widgets/fade_page_route.dart';

const Color kPrimaryGreen = Color(0xFF20C997);
const Color kLightGreenBg = Color(0xFFE6F9F3);
const Color kBlueIconBg   = Color(0xFFD1E9FF);
const Color kPrimaryBlue  = Color(0xFF4B9EF8);

class AddDeviceFlow extends StatefulWidget {
  const AddDeviceFlow({super.key});

  @override
  State<AddDeviceFlow> createState() => _AddDeviceFlowState();
}

class _AddDeviceFlowState extends State<AddDeviceFlow> {
  int _currentIndex = 0;
  String? _scannedBtRemoteId;
  String _deviceName = 'Safechain001';

  @override
  void initState() {
    super.initState();
    // Removed the auto-Bluetooth check so the app always starts at the QR instructions
  }

  void _nextStep() => setState(() => _currentIndex++);
  void _goToStep(int step) => setState(() => _currentIndex = step);

  Future<void> _addDevice() async {
    final user = await SessionManager.getUser();

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add a device.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_scannedBtRemoteId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No device scanned. Please scan the QR code first.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final String btRemoteId = _scannedBtRemoteId!;

    try {
      final checkResponse = await http.get(
        Uri.parse('https://safechain.site/api/mobile/check_device.php?bt_remote_id=$btRemoteId&resident_id=${user.residentId}'),
      );

      if (checkResponse.statusCode == 200) {
        final checkBody = jsonDecode(checkResponse.body);

        if (checkBody['status'] == 'taken') {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(children: [Icon(Icons.link_off, color: Colors.red), SizedBox(width: 8), Text('Device Already Linked')]),
                content: const Text('This device is already linked to another account. Please use a different device or contact support.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: kPrimaryGreen)))],
              ),
            );
          }
          return;
        }

        if (checkBody['status'] == 'owned') {
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(children: [Icon(Icons.info_outline, color: kPrimaryGreen), SizedBox(width: 8), Text('Already Added')]),
                content: const Text('This device is already linked to your account. You can find it in your device list.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: kPrimaryGreen)))],
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Device check error: $e');
    }

    try {
      final response = await http.post(
        Uri.parse('https://safechain.site/api/mobile/add_device.php'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'resident_id': user.residentId,
          'name': _deviceName,
          'bt_remote_id': btRemoteId,
        }),
      );

      if (response.statusCode == 201) {
        await NotificationService.addNotification(
          'New Device Added',
          'Successfully added $_deviceName to your account.',
          NotificationType.device,
        );
      }
      _nextStep(); // Moves to TestingGatewayStep
    } catch (e) {
      _nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // 0. Start Here
      PairYourDeviceStep(
        onStart: () => _goToStep(1),
        onBack: () => Navigator.pop(context),
      ),
      // 1. Scan QR
      QRScanStep(
        onScanned: (btRemoteId) {
          setState(() => _scannedBtRemoteId = btRemoteId);
          _goToStep(2);
        },
        onCancel: () => _goToStep(0),
      ),
      // 2. Ask BT Permissions (If already on, user taps Enable to pass)
      EnableBluetoothStep(
        onEnable: () => _goToStep(3),
        onSkip: () => _goToStep(3),
      ),
      // 3. Local Verification (Now has Visual Feedback)
      ConnectingDeviceStep(
        btRemoteId: _scannedBtRemoteId,
        onSuccess: () => _goToStep(4),
        onError: () => _goToStep(8),
      ),
      // 4. Cloud Registration
      SetUpDeviceStep(
        btRemoteId: _scannedBtRemoteId,
        onAdd: _addDevice, // Internal API call moves index to 5
        onCancel: () => _goToStep(0),
        onNameChanged: (name) => setState(() => _deviceName = name),
      ),
      // 5. Gateway Test
      TestingGatewayStep(onSuccess: () => _goToStep(6), onError: () => _goToStep(8)),
      // 6. Success Summary
      AllSetStep(
        onTestGps: () => _goToStep(7),
        onGoToDeviceList: () => Navigator.pushReplacement(context, FadePageRoute(child: const HomeScreen())),
      ),
      // 7. Location Testing
      GpsTestingStep(btRemoteId: _scannedBtRemoteId, onBack: () => _goToStep(6)),
      // 8. Error Screen
      ConnectionUnsuccessfulStep(onTryAgain: () => _goToStep(1), onViewMap: () {}),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
            FadeThroughTransition(
              animation: primaryAnimation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            ),
        child: KeyedSubtree(key: ValueKey(_currentIndex), child: pages[_currentIndex]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// ENABLE BLUETOOTH STEP
// ─────────────────────────────────────────────────
class EnableBluetoothStep extends StatefulWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;
  const EnableBluetoothStep({super.key, required this.onEnable, required this.onSkip});

  @override
  State<EnableBluetoothStep> createState() => _EnableBluetoothStepState();
}

class _EnableBluetoothStepState extends State<EnableBluetoothStep> {
  bool _isRequesting = false;

  Future<void> _enableBluetooth() async {
    setState(() => _isRequesting = true);
    try {
      if (Platform.isAndroid) {
        final statuses = await [
          perm.Permission.bluetoothScan,
          perm.Permission.bluetoothConnect,
          perm.Permission.location,
        ].request();

        if (statuses.values.any((s) => s.isPermanentlyDenied)) {
          _showPermissionDialog();
          setState(() => _isRequesting = false);
          return;
        }

        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enable Bluetooth from your settings.')),
            );
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
        widget.onEnable();
      } else {
        final state = await FlutterBluePlus.adapterState.first;
        if (state == BluetoothAdapterState.on) {
          widget.onEnable();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bluetooth is not enabled yet.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Bluetooth and Location permissions are required to add a device. '
              'Please enable them in your settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              perm.openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: kPrimaryGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              SizedBox(height: 250, child: Center(child: RipplePulse(color: kPrimaryBlue, icon: Icons.bluetooth))),
              const SizedBox(height: 8),
              const Text('Enable Bluetooth', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'We need Bluetooth access to connect\nto your emergency device',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF4F4F4F), height: 1.6),
              ),
              const SizedBox(height: 8),
              const Text(
                'This allows your phone to communicate with the device',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _enableBluetooth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen, elevation: 4,
                    shadowColor: kPrimaryGreen.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: _isRequesting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Enable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 56,
                child: TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: const Text('Skip for Now', style: TextStyle(fontSize: 15, color: Color(0xFF505050), fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// PAIR YOUR DEVICE STEP
// ─────────────────────────────────────────────────
class PairYourDeviceStep extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onBack;
  const PairYourDeviceStep({super.key, required this.onStart, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: 100, height: 100,
                decoration: const BoxDecoration(color: kLightGreenBg, shape: BoxShape.circle),
                child: const Icon(Icons.qr_code_scanner, size: 50, color: kPrimaryGreen),
              ),
              const SizedBox(height: 24),
              const Text('Pair Your Device', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Follow the steps below then scan the QR code on your device',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 40),
              _buildInstructionCard(1, 'Power On Device', 'Hold power button for 3 seconds.', Icons.power_settings_new),
              const SizedBox(height: 16),
              _buildInstructionCard(2, 'Wait for LED', 'Device LED should start blinking.', Icons.flash_on),
              const SizedBox(height: 16),
              _buildInstructionCard(3, 'Scan QR Code', 'Point your camera at the QR code on the device.', Icons.qr_code),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Scan QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(int step, String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF20C997), Color(0xFF1CB586)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              ],
            ),
          ),
          Icon(icon, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// QR SCAN STEP
// ─────────────────────────────────────────────────
class QRScanStep extends StatefulWidget {
  final Function(String btRemoteId) onScanned;
  final VoidCallback onCancel;
  const QRScanStep({super.key, required this.onScanned, required this.onCancel});

  @override
  State<QRScanStep> createState() => _QRScanStepState();
}

class _QRScanStepState extends State<QRScanStep> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final _macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    if (!_macRegex.hasMatch(raw)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code. Please scan the QR code on your SafeChain device.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _scanned = true);
    _controller.stop();
    widget.onScanned(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _QROverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  ),
                  const Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: () {
                      setState(() => _torchOn = !_torchOn);
                      _controller.toggleTorch();
                    },
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: _torchOn ? Colors.yellow : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'Point the camera at the QR code\non your SafeChain device',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// QR OVERLAY — dark background + green scan box
// ─────────────────────────────────────────────────
class _QROverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const boxSize = 260.0;
    final top  = (size.height - boxSize) / 2 - 40;
    final left = (size.width  - boxSize) / 2;

    return Stack(
      children: [
        Container(color: Colors.black.withOpacity(0.55)),
        Positioned(
          top: top, left: left,
          child: Container(
            width: boxSize, height: boxSize,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimaryGreen, width: 3),
            ),
          ),
        ),
        ..._corners(top, left, boxSize),
      ],
    );
  }

  List<Widget> _corners(double top, double left, double size) {
    const len   = 24.0;
    const thick = 4.0;
    const r     = 16.0;

    Widget corner(double t, double l, bool flipH, bool flipV) {
      return Positioned(
        top: t, left: l,
        child: Transform.scale(
          scaleX: flipH ? -1 : 1,
          scaleY: flipV ? -1 : 1,
          child: CustomPaint(
            size: const Size(len, len),
            painter: _CornerPainter(color: kPrimaryGreen, thickness: thick, radius: r),
          ),
        ),
      );
    }

    return [
      corner(top - 2,               left - 2,               false, false),
      corner(top - 2,               left + size - len + 2,  true,  false),
      corner(top + size - len + 2,  left - 2,               false, true),
      corner(top + size - len + 2,  left + size - len + 2,  true,  true),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double radius;
  const _CornerPainter({required this.color, required this.thickness, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = ui.Path()
      ..moveTo(0, size.height)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ─────────────────────────────────────────────────
// SET UP DEVICE STEP
// ─────────────────────────────────────────────────
class SetUpDeviceStep extends StatelessWidget {
  final String? btRemoteId;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final Function(String) onNameChanged;

  const SetUpDeviceStep({
    super.key,
    required this.btRemoteId,
    required this.onAdd,
    required this.onCancel,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: onCancel),
        title: const Text('Set Up Device', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(color: kLightGreenBg, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: kPrimaryGreen, shape: BoxShape.circle),
                      child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('SafeChain Device Scanned ✅', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('ID: ${btRemoteId ?? "Unknown"}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text('Device Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: 'Safechain001',
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  hintText: 'e.g. My SafeChain Keychain',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9), elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryGreen, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Add Device', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// TESTING GATEWAY STEP
// ─────────────────────────────────────────────────
class TestingGatewayStep extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onError;
  const TestingGatewayStep({super.key, required this.onSuccess, required this.onError});

  @override
  State<TestingGatewayStep> createState() => _TestingGatewayStepState();
}

class _TestingGatewayStepState extends State<TestingGatewayStep> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), widget.onSuccess);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(height: 250, child: Center(child: RipplePulse(color: kPrimaryBlue, icon: Icons.router))),
          const Text('Testing Gateway Connection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Connecting to LoRa network...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// ALL SET STEP
// ─────────────────────────────────────────────────
class AllSetStep extends StatelessWidget {
  final VoidCallback onTestGps;
  final VoidCallback onGoToDeviceList;
  const AllSetStep({super.key, required this.onTestGps, required this.onGoToDeviceList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(height: 250, child: Center(child: RipplePulse(color: kPrimaryGreen, icon: Icons.check_rounded))),
              const SizedBox(height: 8),
              const Text('You\'re All Set! 🎉', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Your device is connected and ready', style: TextStyle(color: Colors.black87, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('You can now test GPS location tracking', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: onTestGps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Test GPS Tracking', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 56,
                child: TextButton(
                  onPressed: onGoToDeviceList,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF8F9FA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Go to device list', style: TextStyle(fontSize: 16, color: Colors.black54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// RIPPLE PULSE
// ─────────────────────────────────────────────────
class RipplePulse extends StatefulWidget {
  final Color color;
  final IconData icon;
  const RipplePulse({super.key, required this.color, required this.icon});

  @override
  State<RipplePulse> createState() => _RipplePulseState();
}

class _RipplePulseState extends State<RipplePulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _ringProgress(double offset) => (((_controller.value - offset) % 1.0) + 1.0) % 1.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildRing(_ringProgress(0.0)),
            _buildRing(_ringProgress(0.333)),
            _buildRing(_ringProgress(0.666)),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: widget.color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: widget.color.withOpacity(0.45), blurRadius: 24, spreadRadius: 4)],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 36),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRing(double progress) {
    return Container(
      width: 80 + (120 * progress),
      height: 80 + (120 * progress),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withOpacity((1.0 - progress) * 0.35),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// CONNECTION UNSUCCESSFUL STEP
// ─────────────────────────────────────────────────
class ConnectionUnsuccessfulStep extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onViewMap;
  const ConnectionUnsuccessfulStep({super.key, required this.onTryAgain, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            SizedBox(height: 250, child: Center(child: RipplePulse(color: const Color(0xFFFF5A5A), icon: Icons.signal_wifi_off_rounded))),
            const Text('Connection Unsuccessful', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Could not connect to the LoRa gateway. Please check your surroundings and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: onTryAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Try Again', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onViewMap,
              child: const Text('View Gateway Map', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// GPS TESTING STEP
// ─────────────────────────────────────────────────
class GpsTestingStep extends StatefulWidget {
  final String? btRemoteId;
  final VoidCallback onBack;
  const GpsTestingStep({super.key, required this.btRemoteId, required this.onBack});

  @override
  State<GpsTestingStep> createState() => _GpsTestingStepState();
}

class _GpsTestingStepState extends State<GpsTestingStep> {
  LatLng? _deviceLocation;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _scanSubscription;
  String _statusText = "Scanning for device...";

  final String _serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  final String _txCharUuid  = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  @override
  void initState() {
    super.initState();
    _findAndConnect();
  }

  Future<void> _findAndConnect() async {
    if (widget.btRemoteId == null) {
      if (mounted) setState(() => _statusText = "Error: No device ID");
      return;
    }
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (r.device.remoteId.toString() == widget.btRemoteId) {
            await FlutterBluePlus.stopScan();
            await _setupBleListener(r.device);
            break;
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = "Scan error: $e");
    }
  }

  Future<void> _setupBleListener(BluetoothDevice device) async {
    try {
      if (mounted) setState(() => _statusText = "Connecting...");
      await device.connect(timeout: const Duration(seconds: 10));
      if (mounted) setState(() => _statusText = "Discovering services...");

      final services = await device.discoverServices();
      final service = services.firstWhere(
            (s) => s.uuid.toString().toUpperCase() == _serviceUuid,
        orElse: () => throw Exception("SafeChain service not found"),
      );
      final characteristic = service.characteristics.firstWhere(
            (c) => c.uuid.toString().toUpperCase() == _txCharUuid,
        orElse: () => throw Exception("TX characteristic not found"),
      );

      if (!characteristic.isNotifying) await characteristic.setNotifyValue(true);
      if (mounted) setState(() => _statusText = "Waiting for GPS update...");

      _notifySubscription = characteristic.lastValueStream.listen((value) {
        try {
          final data = utf8.decode(value).trim();
          if (data.contains(',')) {
            final parts = data.split(',');
            if (parts.length == 2) {
              final lat = double.tryParse(parts[0]);
              final lon = double.tryParse(parts[1]);
              if (lat != null && lon != null && lat != 0.0) {
                if (mounted) setState(() {
                  _deviceLocation = LatLng(lat, lon);
                  _statusText = "Device Data Received";
                });
              }
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = "Connection Error: $e");
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('GPS Testing'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _deviceLocation ?? const LatLng(14.5995, 120.9842),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (_deviceLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _deviceLocation!, width: 80, height: 80,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.location_pin, color: kPrimaryGreen, size: 40),
                      ),
                      const Text("Device", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    ]),
                  ),
                ]),
            ],
          ),
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_deviceLocation == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: CircularProgressIndicator(color: kPrimaryGreen),
                    ),
                  Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (_deviceLocation != null) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _infoItem("LAT", _deviceLocation!.latitude.toStringAsFixed(6)),
                        _infoItem("LNG", _deviceLocation!.longitude.toStringAsFixed(6)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// CONNECTING DEVICE STEP (INDUSTRY STANDARD LOCAL VERIFICATION)
// ─────────────────────────────────────────────────
enum ConnectionPhase { connecting, success, error }

class ConnectingDeviceStep extends StatefulWidget {
  final String? btRemoteId;
  final VoidCallback onSuccess;
  final VoidCallback onError;

  const ConnectingDeviceStep({
    super.key,
    required this.btRemoteId,
    required this.onSuccess,
    required this.onError
  });

  @override
  State<ConnectingDeviceStep> createState() => _ConnectingDeviceStepState();
}

class _ConnectingDeviceStepState extends State<ConnectingDeviceStep> {
  ConnectionPhase _phase = ConnectionPhase.connecting;

  @override
  void initState() {
    super.initState();
    _verifyLocalConnection();
  }

  Future<void> _verifyLocalConnection() async {
    if (widget.btRemoteId == null) {
      if (mounted) widget.onError();
      return;
    }

    try {
      // 1. Attempt local connection
      final device = BluetoothDevice.fromId(widget.btRemoteId!);
      await device.connect(timeout: const Duration(seconds: 7));

      // 2. Disconnect to free up the radio
      await device.disconnect();

      // 3. Update UI to show Success to the user
      if (mounted) {
        setState(() => _phase = ConnectionPhase.success);

        // Wait 2 seconds so the user can read the success message
        await Future.delayed(const Duration(seconds: 2));

        // Move to Setup screen
        if (mounted) widget.onSuccess();
      }

    } catch (e) {
      // Failed to connect
      if (mounted) widget.onError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 250,
            child: Center(
              child: _phase == ConnectionPhase.connecting
                  ? const RipplePulse(color: kPrimaryBlue, icon: Icons.bluetooth_searching)
                  : const RipplePulse(color: kPrimaryGreen, icon: Icons.bluetooth_connected),
            ),
          ),
          Text(
              _phase == ConnectionPhase.connecting ? 'Verifying Device...' : 'Device Connected! ✅',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
                _phase == ConnectionPhase.connecting
                    ? 'Ensuring your SafeChain device is turned on and nearby.'
                    : 'Pairing successful. Moving to registration...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)
            ),
          ),
        ],
      ),
    );
  }
}