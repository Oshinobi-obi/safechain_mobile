import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safechain/services/notification_service.dart' as notification_service;
import 'package:timeago/timeago.dart' as timeago;

const Color kPrimaryGreen = Color(0xFF20C997);

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<notification_service.Notification> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<int>? _streamSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-render instantly when another part of the app adds a notification
    _streamSub = notification_service.NotificationService.countStream.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await notification_service.NotificationService.getNotifications();
    if (mounted) setState(() { _notifications = list; _isLoading = false; });
  }

  // ── Mark all as read ────────────────────────────────────────────
  Future<void> _markAllRead() async {
    await notification_service.NotificationService.markAllAsRead();
    // No need to call _load() — the stream listener above handles it
  }

  // ── Clear all with confirmation ─────────────────────────────────
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications'),
        content: const Text('This will permanently delete all notifications. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await notification_service.NotificationService.clearAll();
    }
  }

  // ── Delete single notification ──────────────────────────────────
  Future<void> _deleteOne(String id) async {
    await notification_service.NotificationService.deleteOne(id);
  }

  IconData _iconFor(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.device:       return Icons.devices_rounded;
      case notification_service.NotificationType.announcement: return Icons.campaign_rounded;
      case notification_service.NotificationType.security:     return Icons.security_rounded;
      default:                                                  return Icons.notifications_rounded;
    }
  }

  Color _colorFor(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.device:       return kPrimaryGreen;
      case notification_service.NotificationType.announcement: return Colors.orange;
      case notification_service.NotificationType.security:     return Colors.red;
      default:                                                  return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: const TextStyle(color: kPrimaryGreen, fontSize: 11),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // ── ✓✓ Mark all as read ──
          if (unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all_rounded, color: kPrimaryGreen),
              onPressed: _markAllRead,
            ),
          // ── 🗑 Clear all ──
          if (_notifications.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
          : _notifications.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final n = _notifications[index];
          return _buildCard(n);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No notifications yet.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(notification_service.Notification n) {
    final color = _colorFor(n.type);
    final icon  = _iconFor(n.type);
    final isUnread = !n.isRead;

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteOne(n.id),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: isUnread
              ? Border.all(color: color.withOpacity(0.25), width: 1.5)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: isUnread
              ? [BoxShadow(color: color.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Theme(
            data: Theme.of(context).copyWith(
              // Remove the default grey pointy highlight on ListTile tap
              splashColor: color.withOpacity(0.08),
              highlightColor: Colors.transparent,
            ),
            child: ListTile(
              onTap: () async {
                if (isUnread) {
                  await notification_service.NotificationService.markAsRead(n.id);
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  // Unread dot
                  if (isUnread)
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                n.title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(n.message, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(n.timestamp),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
              trailing: isUnread
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('New', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              )
                  : null,
            ),
          ),  // Theme
        ),  // ClipRRect
      ),
    );
  }
}