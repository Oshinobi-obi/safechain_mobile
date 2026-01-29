import 'package:flutter/material.dart';
import 'package:safechain/services/notification_service.dart' as notification_service;
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<notification_service.Notification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndMarkNotifications();
  }

  Future<void> _loadAndMarkNotifications() async {
    final notifications = await notification_service.NotificationService.getNotifications();
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
    await notification_service.NotificationService.markAllAsRead();
  }

  IconData _getIconForType(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.device:
        return Icons.devices;
      case notification_service.NotificationType.announcement:
        return Icons.campaign;
      case notification_service.NotificationType.security:
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.device:
        return Colors.blue;
      case notification_service.NotificationType.announcement:
        return Colors.orange;
      case notification_service.NotificationType.security:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true), // Return true to signal a refresh
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF20C997)))
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('You have no notifications yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      shadowColor: Colors.black12,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForType(notification.type).withOpacity(0.1),
                          child: Icon(
                            _getIconForType(notification.type),
                            color: _getColorForType(notification.type),
                          ),
                        ),
                        title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(notification.message, style: const TextStyle(color: Colors.black87)),
                        trailing: Text(
                          timeago.format(notification.timestamp),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    );
                  },
                ),
    );
  }
}