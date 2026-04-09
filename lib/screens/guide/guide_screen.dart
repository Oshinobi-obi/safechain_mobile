import 'package:flutter/material.dart';
import 'package:safechain/widgets/profile_completion_banner.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            const ProfileCompletionBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'User Guide',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Learn how to use the safechain device',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3F3D56),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Start Guide',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Learn how to set up and use your device (3:45)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildGuideItem(
                      context,
                      'Emergency Buttons',
                      'images/warning-red.png',
                      [
                        'Press and hold the SOS button for 3 seconds to trigger an emergency alert.',
                        'A single press sends a ping notification to your registered contacts.',
                        'The LED will flash red when an alert is active.',
                        'To cancel a false alarm, press and hold the button again for 3 seconds.',
                      ],
                    ),
                    _buildGuideItem(
                      context,
                      'GPS Testing',
                      'images/gps-blue.png',
                      [
                      'Make sure the device is outdoors or near a window for best GPS accuracy.',
                      'Open the SafeChain app and tap "Test GPS" on your device card.',
                      'Wait up to 60 seconds for the first GPS fix — this is normal.',
                      'The blue dot on the map shows your device current location in real time.',
                      ],
                    ),
                    _buildGuideItem(
                      context,
                      'Battery & Charging',
                      'images/battery-green.png',
                      [
                        'Charge your device using the included micro-USB cable.',
                        'A full charge takes approximately 1.5 hours.',
                        'The battery indicator in the app shows remaining charge in real time.',
                        'You will receive a low battery notification when charge drops below 20%.',
                      ],
                    ),
                    _buildGuideItem(
                      context,
                      'Troubleshooting',
                      'images/wrench-orange.png',
                      [
                        'If the device does not connect, make sure Bluetooth is enabled on your phone.',
                        'Try moving your phone within 1 meter of the device during pairing.',
                        'If GPS is not updating, restart the device by holding the side button for 5 seconds.',
                        'For persistent issues, unlink the device from the app and re-register it.',
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Support Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20C997),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'images/headphone-icon.png',
                                width: 32,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 16),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need Help?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '24/7 support available for emergencies',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
                                  content: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Our support team is available 24/7 for emergencies.'),
                                      SizedBox(height: 16),
                                      Row(children: [Icon(Icons.email, color: Color(0xFF20C997), size: 18), SizedBox(width: 8), Text('support@safechain.site')]),
                                      SizedBox(height: 8),
                                      Row(children: [Icon(Icons.phone, color: Color(0xFF20C997), size: 18), SizedBox(width: 8), Text('+63 : 9')]),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Close', style: TextStyle(color: Color(0xFF20C997), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Contact Support',
                              style: TextStyle(
                                color: Color(0xFF20C997),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(BuildContext context, String title, String iconPath, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          child: ExpansionTile(
            leading: Image.asset(iconPath, width: 36),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF20C997), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item, style: const TextStyle(color: Colors.black87, height: 1.4)),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}