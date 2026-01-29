import 'package:flutter/material.dart';
import 'package:safechain/services/notification_service.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    // This is a placeholder. In a real app, you would fetch announcements from your server.
    // For now, we'll just add a notification to simulate a new announcement.
    await NotificationService.addNotification(
      'New Community Announcement',
      'There is a new community announcement available.',
      NotificationType.announcement,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F5F9),
        elevation: 0,
        scrolledUnderElevation: 0.0,
        title: const Text(
          'Announcement',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Community safety updates and advisories.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAnnouncementCard(
            context,
            name: 'Juan Dela Cruz',
            time: '10 hrs ago',
            postDate: 'Date Post: Enero 18, 2026',
            title: 'Sa Lahat ng Studyante ng BSIT',
            content:
                'Sa mga STUDYANTE aking PINAALAM sa INYO na ito ay isang HALIMBAWA lamang ng ANUNSYO para sa PAGPAPAKITA ng TAMANG FORMAT ng mga PAALALA at ABISO sa HINAHARAP.\n\nAng LAYUNIN po ng HALIMBAWANG ito ay upang IPAKITA sa INYO kung PAANO dapat ISULAT ang mga MAHALAGANG MENSAHE at INSTRUKSYON na DAPAT ninyong SUNDIN.\n\nMANGYARING HUWAG PANSININ ang nilalaman ng ANUNSYONG ito dahil ito ay HALIMBAWA lamang at WALANG AKTWAL na BISA o APLIKASYON sa KASALUKUYAN.\n\nKung mayroon kayong mga KATANUNGAN tungkol sa TUNAY na mga ANUNSYO, MAKIPAG-UGNAYAN po kayo sa inyong mga GURO o sa TANGGAPAN ng DEPARTAMENTO.\n\nInaasahan ko po ang inyong agarang tugon at pagsunod tungkol rito.\n\nMaraming salamat po!!!',
          ),
          const SizedBox(height: 16),
          _buildAnnouncementCard(
            context,
            name: 'Juan Dela Cruz',
            time: '10 hrs ago',
            title: "'Ada' now a tropical storm; Signal No. 1 up in areas across the country",
            content:
                'MANILA, Philippines — Tropical Storm Ada (International name: Nokoen) strengthened Thursday afternoon, January 15, as it moved closer to the Philippines, prompting PAGASA to raise lowest-level wind signals over parts of Luzon, Visayas and Mindanao.',
            image: 'images/typhoon.png',
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, {
    required String name,
    required String time,
    String? postDate,
    required String title,
    required String content,
    String? image,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF20C997),
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (postDate != null) ...[
              const SizedBox(height: 16),
              Text(
                postDate,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            if (image != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.asset(image),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
