import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:safechain/services/notification_service.dart';
import 'package:safechain/services/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:safechain/screens/home/home_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:safechain/widgets/fade_page_route.dart';

const Color kPrimaryGreen = Color(0xFF20C997);
const Color kLightGreenBg = Color(0xFFE6F9F3);
const Color kBlueIconBg = Color(0xFFD1E9FF);
const Color kPrimaryBlue = Color(0xFF4B9EF8);

class AddDeviceFlow extends StatefulWidget {
  const AddDeviceFlow({super.key});

  @override
  State<AddDeviceFlow> createState() => _AddDeviceFlowState();
}

class _AddDeviceFlowState extends State<AddDeviceFlow> {
  final PageController _pageController = PageController();
  BluetoothDevice? _selectedDevice;
  String _deviceName = 'Safechain001';

  void _nextStep() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addDevice() async {
    final user = await SessionManager.getUser();
    if (user == null && _selectedDevice == null) {
      _nextStep();
      return;
    }

    if (user == null || _selectedDevice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add a device.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    const String apiUrl = 'https://safechain.site/api/mobile/add_device.php';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(<String, String>{
          'resident_id': user.residentId,
          'name': _deviceName,
          'bt_remote_id': _selectedDevice!.remoteId.toString(),
        }),
      );

      if (response.statusCode == 201) {
        await NotificationService.addNotification(
          'New Device Added',
          'Successfully added $_deviceName to your account.',
          NotificationType.device,
        );
        _nextStep();
      } else {
        _nextStep();
      }
    } catch (e) {
      _nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          EnableBluetoothStep(
              onEnable: _nextStep,
              onSkip: () => Navigator.pushReplacement(context, FadePageRoute(child: const HomeScreen()))),
          PairYourDeviceStep(onStart: _nextStep, onBack: () => Navigator.pop(context)),
          ScanningStep(
            onDeviceSelected: (device) {
              setState(() => _selectedDevice = device);
              _nextStep();
            },
            onCancel: () => _goToStep(1),
            onNoDevice: () => _goToStep(7),
          ),
          SetUpDeviceStep(
            device: _selectedDevice,
            onAdd: _addDevice,
            onCancel: () => _goToStep(1),
            onNameChanged: (name) => setState(() => _deviceName = name),
          ),
          TestingGatewayStep(onSuccess: _nextStep, onError: () => _goToStep(8)),
          AllSetStep(
            onTestGps: () => _goToStep(6),
            onGoToDeviceList: () => Navigator.pushReplacement(context, FadePageRoute(child: const HomeScreen())),
          ),
          GpsTestingStep(onBack: () => _goToStep(5)),
          NoDeviceFoundStep(onTryAgain: () => _goToStep(2)),
          ConnectionUnsuccessfulStep(onTryAgain: () => _goToStep(4), onViewMap: () {}),
        ],
      ),
    );
  }
}

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
        final Map<perm.Permission, perm.PermissionStatus> statuses;
        statuses = await [
          perm.Permission.bluetoothScan,
          perm.Permission.bluetoothConnect,
          perm.Permission.location,
        ].request();

        bool isScanGranted = statuses[perm.Permission.bluetoothScan]!.isGranted;
        bool isConnectGranted = statuses[perm.Permission.bluetoothConnect]!.isGranted;
        bool isLocationGranted = statuses[perm.Permission.location]!.isGranted;

        if (statuses.values.any((s) => s.isPermanentlyDenied)) {
          _showPermissionDialog();
          setState(() => _isRequesting = false);
          return;
        }
      }

      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
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
          'Bluetooth and Location permissions are required to add a device. Please enable them in your settings.',
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
            child: const Text('Open Settings', style: TextStyle(color: Color(0xFF20C997))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                color: Color(0xFFD1E9FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth, size: 80, color: Color(0xFF4B9EF8)),
            ),
            const SizedBox(height: 40),
            const Text('Enable Bluetooth',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)
            ),
            const SizedBox(height: 16),
            const Text(
              'We need Bluetooth access to connect to your emergency device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isRequesting ? null : _enableBluetooth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20C997),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isRequesting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enable', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: widget.onSkip,
                child: const Text('Skip for Now', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: kLightGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors, size: 50, color: kPrimaryGreen),
              ),
              const SizedBox(height: 24),
              const Text('Pair Your Device', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Follow the steps to connect your keychain device',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14)
              ),
              const SizedBox(height: 40),

              _buildInstructionCard(1, 'Power On Device', 'Hold power button for 3 seconds.', Icons.power_settings_new),
              const SizedBox(height: 16),
              _buildInstructionCard(2, 'Wait for LED', 'Device LED should start blinking.', Icons.flash_on),
              const SizedBox(height: 16),
              _buildInstructionCard(3, 'Start Pairing', 'You are good to go.', Icons.auto_awesome),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Start Pairing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
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
        color: kPrimaryGreen,
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5)
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

class ScanningStep extends StatefulWidget {
  final Function(BluetoothDevice) onDeviceSelected;
  final VoidCallback onCancel;
  final VoidCallback onNoDevice;
  const ScanningStep({super.key, required this.onDeviceSelected, required this.onCancel, required this.onNoDevice});

  @override
  State<ScanningStep> createState() => _ScanningStepState();
}

class _ScanningStepState extends State<ScanningStep> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    try {
      if(Platform.isAndroid || Platform.isIOS) {
        FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
        FlutterBluePlus.scanResults.listen((results) {
          if (mounted) setState(() => _scanResults = results);
        });
      }
    } catch(e) {
      // ignore
    }

    Future.delayed(const Duration(seconds: 10), () {
      if(mounted) setState(() => _isScanning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scanning', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(onPressed: widget.onCancel, child: const Text('CANCEL', style: TextStyle(color: Colors.grey)))
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: Center(
              child: RipplePulse(
                color: kPrimaryGreen,
                icon: Icons.sensors,
              ),
            ),
          ),
          const Text(
            'Searching for devices',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Please wait...', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          Expanded(
            child: _scanResults.isEmpty
                ? Container()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final device = _scanResults[index].device;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                      border: Border.all(color: Colors.grey.shade100)
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: kLightGreenBg, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.sensors, color: kPrimaryGreen),
                    ),
                    title: Text(device.platformName.isNotEmpty ? device.platformName : "Unknown Device",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("ID: ${device.remoteId}", style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: kLightGreenBg, borderRadius: BorderRadius.circular(20)),
                      child: const Text("Found", style: TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    onTap: () => widget.onDeviceSelected(device),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SetUpDeviceStep extends StatelessWidget {
  final BluetoothDevice? device;
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  final Function(String) onNameChanged;
  const SetUpDeviceStep({super.key, this.device, required this.onAdd, required this.onCancel, required this.onNameChanged});

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
              // The Green "Card" Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: kLightGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: kPrimaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.security, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('Safechain Device Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('ID: ${device?.remoteId ?? "SC-KC-002"}', style: const TextStyle(color: Colors.grey)),
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
                  fillColor: const Color(0xFFF1F5F9), // Light grey fill
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
              const Spacer(),

              // Bottom Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onCancel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          elevation: 0,
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
                          backgroundColor: kPrimaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

class TestingGatewayStep extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onError;
  const TestingGatewayStep({super.key, required this.onSuccess, required this.onError});

  @override
  State<TestingGatewayStep> createState() => _TestingGatewayStepState();
}

class _TestingGatewayStepState extends State<TestingGatewayStep> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), widget.onSuccess);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Blue Ripple Pulse
            RipplePulse(color: kPrimaryBlue, icon: Icons.router),
            const SizedBox(height: 40),
            const Text('Testing Gateway Connection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Connecting to LoRa network...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Green Pulse Static
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: kLightGreenBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: kLightGreenBg.withOpacity(0.5), // Slightly darker ring
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle_outline, color: kPrimaryGreen, size: 50),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text('You\'re All Set!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your device is connected and ready', style: TextStyle(color: Colors.black87)),
              const SizedBox(height: 4),
              const Text('You can now test GPS location tracking', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: onTestGps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Test GPS Tracking', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
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
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.5,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildCircle(180 * _controller.value, widget.color.withOpacity(0.15)),
            _buildCircle(130 * _controller.value, widget.color.withOpacity(0.25)),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)
                  ]
              ),
              child: Icon(widget.icon, color: Colors.white, size: 36),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class GpsTestingStep extends StatefulWidget {
  final VoidCallback onBack;
  const GpsTestingStep({super.key, required this.onBack});

  @override
  State<GpsTestingStep> createState() => _GpsTestingStepState();
}

class _GpsTestingStepState extends State<GpsTestingStep> {
  loc.LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final location = loc.Location();
    _currentLocation = await location.getLocation();
    if (mounted) setState(() {});
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
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation != null
              ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
              : const LatLng(14.7120, 121.0387),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.location_pin, color: kPrimaryGreen, size: 50),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class NoDeviceFoundStep extends StatelessWidget {
  final VoidCallback onTryAgain;
  const NoDeviceFoundStep({super.key, required this.onTryAgain});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('No Device Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onTryAgain,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionUnsuccessfulStep extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onViewMap;
  const ConnectionUnsuccessfulStep({super.key, required this.onTryAgain, required this.onViewMap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Connection Unsuccessful', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onTryAgain,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen),
              child: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: onViewMap,
              child: const Text('View Gateway Map', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}