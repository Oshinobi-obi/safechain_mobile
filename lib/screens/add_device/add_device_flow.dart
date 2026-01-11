import 'package:flutter/material.dart';
import 'package:safechain/screens/home/home_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class AddDeviceFlow extends StatefulWidget {
  const AddDeviceFlow({super.key});

  @override
  State<AddDeviceFlow> createState() => _AddDeviceFlowState();
}

class _AddDeviceFlowState extends State<AddDeviceFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentStep = index),
        children: [
          EnableBluetoothStep(onEnable: _nextStep, onSkip: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()))),
          PairYourDeviceStep(onStart: _nextStep, onBack: () => _goToStep(0)),
          ScanningStep(onFound: _nextStep, onCancel: () => _goToStep(1), onNoDevice: () => _goToStep(8)),
          SetUpDeviceStep(onAdd: _nextStep, onCancel: () => _goToStep(1)),
          TestingGatewayStep(onSuccess: _nextStep, onError: () => _goToStep(9)),
          AllSetStep(
            onTestGps: () => _goToStep(6),
            onGoToDeviceList: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
          ),
          GpsTestingStep(onBack: () => _goToStep(5)),
          // Error Steps
          NoDeviceFoundStep(onTryAgain: () => _goToStep(2)),
          ConnectionUnsuccessfulStep(onTryAgain: () => _goToStep(4), onViewMap: () {}),
        ],
      ),
    );
  }
}

class EnableBluetoothStep extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;
  const EnableBluetoothStep({super.key, required this.onEnable, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFD1E9FF),
              child: Image.asset('images/bluetooth-icon.png', width: 60),
            ),
            const SizedBox(height: 40),
            const Text('Enable Bluetooth', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'We need Bluetooth access to connect to your emergency device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'This allows your phone to communicate with the device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onEnable,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Enable', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Skip for Now', style: TextStyle(fontSize: 18, color: Colors.grey)),
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
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: const Text('Add Device'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFE6F9F3),
                child: Image.asset('images/hotspot-icon.png', width: 50, color: const Color(0xFF20C997)),
              ),
              const SizedBox(height: 32),
              const Text('Pair Your Device', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Follow the steps to connect your keychain device', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              _buildStep(1, 'Power On Device', 'Hold power button for 3 seconds.', 'images/circle-power.png'),
              const SizedBox(height: 16),
              _buildStep(2, 'Wait for LED', 'Device LED should start blinking.', 'images/lightbulb-icon.png'),
              const SizedBox(height: 16),
              _buildStep(3, 'Start Pairing', 'You are good to go.', 'images/star-icon.png'),
              const Spacer(),
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20C997),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Start Pairing', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int num, String title, String sub, String iconPath) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF20C997),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(num.toString(), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          Image.asset(iconPath, width: 40, color: Colors.white),
        ],
      ),
    );
  }
}

class ScanningStep extends StatefulWidget {
  final VoidCallback onFound;
  final VoidCallback onCancel;
  final VoidCallback onNoDevice;
  const ScanningStep({super.key, required this.onFound, required this.onCancel, required this.onNoDevice});

  @override
  State<ScanningStep> createState() => _ScanningStepState();
}

class _ScanningStepState extends State<ScanningStep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    // Simulate finding a device
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() {}); // Show device found
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onCancel),
        title: const Text('Scanning'),
        centerTitle: true,
        actions: [TextButton(onPressed: widget.onCancel, child: const Text('CANCEL', style: TextStyle(color: Colors.grey)))],
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 100), // Increased top spacing
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Transform.scale(
                          scale: 1 + (_controller.value + i / 3) % 1 * 1.5,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF20C997).withOpacity(0.3 * (1 - (_controller.value + i / 3) % 1)),
                            ),
                          ),
                        ),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFE6F9F3),
                        child: Image.asset('images/hotspot-icon.png', width: 50, color: const Color(0xFF20C997)),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text('Searching for devices', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Please wait...', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 60),
              // Simulated found device
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: InkWell(
                  onTap: widget.onFound,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFE6F9F3), borderRadius: BorderRadius.circular(12)),
                          child: Image.asset('images/hotspot-icon.png', width: 24, color: const Color(0xFF20C997)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Safechain Device', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('ID: SC-KC-002', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFE6F9F3), borderRadius: BorderRadius.circular(20)),
                          child: const Text('Found', style: TextStyle(color: Color(0xFF20C997), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetUpDeviceStep extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onCancel;
  const SetUpDeviceStep({super.key, required this.onAdd, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onCancel),
        title: const Text('Set Up Device'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F9F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Image.asset('images/logo.png', height: 60),
                    const SizedBox(height: 24),
                    const Text('Safechain Device Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('ID: SC-KC-002', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text('Device Name', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Safechain001',
                  fillColor: const Color(0xFFF1F5F9),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20C997),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Add', style: TextStyle(fontSize: 18, color: Colors.white)),
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

class _TestingGatewayStepState extends State<TestingGatewayStep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    // Simulate gateway test
    Future.delayed(const Duration(seconds: 3), widget.onSuccess);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Transform.scale(
                        scale: 1 + (_controller.value + i / 3) % 1 * 1.5,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD1E9FF).withOpacity(0.3 * (1 - (_controller.value + i / 3) % 1)),
                          ),
                        ),
                      ),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFD1E9FF),
                      child: Image.asset('images/connection-icon.png', width: 50, color: const Color(0xFF007AFF)),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            const Text('Testing Gateway Connection', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFE6F9F3),
              child: Image.asset('images/hotspot-icon.png', width: 60, color: const Color(0xFF20C997)),
            ),
            const SizedBox(height: 40),
            const Text('You’re All Set!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Your device is connected and ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can now test GPS location tracking',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onTestGps,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Test GPS Tracking', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onGoToDeviceList,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Go to device list', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ],
        ),
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
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final location = Location();
    _currentLocation = await location.getLocation();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('GPS Testing'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation != null 
            ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
            : const LatLng(14.7120, 121.0387),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.safechain.app',
          ),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFFEBEE),
              child: Image.asset('images/hotspot-red.png', width: 60),
            ),
            const SizedBox(height: 40),
            const Text('No Device Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Turn on your device and make sure it’s nearby, then try scanning again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onTryAgain,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 18, color: Colors.white)),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFFFEBEE),
              child: Image.asset('images/connection-red.png', width: 60),
            ),
            const SizedBox(height: 40),
            const Text('Connection Unsuccessful', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Unable to connect to LoRa Gateway. Make sure your device is within range of a gateway and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onTryAgain,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Try Again', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onViewMap,
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('View Gateway Map', style: TextStyle(fontSize: 18, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
