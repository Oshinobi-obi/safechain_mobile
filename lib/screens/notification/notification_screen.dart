import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // ── Multi-select state ──────────────────────────────────────────
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
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

  // ── Enter / exit selection mode ─────────────────────────────────
  void _enterSelectMode(String firstId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelecting = true;
      _selectedIds.clear();
      _selectedIds.add(firstId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelecting = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() => _selectedIds.addAll(_notifications.map((n) => n.id)));
  }

  // ── Delete selected ─────────────────────────────────────────────
  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Notifications'),
        content: Text('Delete $count selected notification${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selectedIds.toList()) {
        await notification_service.NotificationService.deleteOne(id);
      }
      _exitSelectMode();
    }
  }

  // ── Mark all as read ────────────────────────────────────────────
  Future<void> _markAllRead() async {
    await notification_service.NotificationService.markAllAsRead();
  }

  // ── Clear all ───────────────────────────────────────────────────
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Notifications'),
        content: const Text('This will permanently delete all notifications. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await notification_service.NotificationService.clearAll();
      _exitSelectMode();
    }
  }

  // ── Delete single (swipe) ───────────────────────────────────────
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
    final allSelected = _selectedIds.length == _notifications.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _isSelecting
          ? _buildSelectionAppBar(allSelected)
          : _buildNormalAppBar(unreadCount),
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
      // ── Delete button shown when items are selected ──
      bottomNavigationBar: _isSelecting && _selectedIds.isNotEmpty
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: ElevatedButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            label: Text(
              'Delete ${_selectedIds.length} selected',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      )
          : null,
    );
  }

  // ── Normal app bar ──────────────────────────────────────────────
  AppBar _buildNormalAppBar(int unreadCount) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context, true),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Notifications', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          if (unreadCount > 0)
            Text('$unreadCount unread', style: const TextStyle(color: kPrimaryGreen, fontSize: 11)),
        ],
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 1,
      actions: [
        if (unreadCount > 0)
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all_rounded, color: kPrimaryGreen),
            onPressed: _markAllRead,
          ),
        if (_notifications.isNotEmpty)
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: _clearAll,
          ),
      ],
    );
  }

  // ── Selection mode app bar ──────────────────────────────────────
  AppBar _buildSelectionAppBar(bool allSelected) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: _exitSelectMode,
      ),
      title: Text(
        '${_selectedIds.length} selected',
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 1,
      actions: [
        // Select all / deselect all toggle
        TextButton(
          onPressed: allSelected ? _exitSelectMode : _selectAll,
          child: Text(
            allSelected ? 'Deselect All' : 'Select All',
            style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No notifications yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCard(notification_service.Notification n) {
    final color      = _colorFor(n.type);
    final icon       = _iconFor(n.type);
    final isUnread   = !n.isRead;
    final isSelected = _selectedIds.contains(n.id);

    return Dismissible(
      key: Key(n.id),
      // Disable swipe-to-dismiss while in selection mode
      direction: _isSelecting ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: (_) => _deleteOne(n.id),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      child: GestureDetector(
        // Long press → enter selection mode
        onLongPress: _isSelecting ? null : () => _enterSelectMode(n.id),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? kPrimaryGreen.withOpacity(0.08)
                : isUnread ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: kPrimaryGreen, width: 1.5)
                : isUnread
                ? Border.all(color: color.withOpacity(0.25), width: 1.5)
                : Border.all(color: Colors.grey.shade100),
            boxShadow: isUnread && !isSelected
                ? [BoxShadow(color: color.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              child: ListTile(
                onTap: () async {
                  if (_isSelecting) {
                    // In selection mode — toggle select
                    _toggleSelect(n.id);
                  } else {
                    // Normal mode — mark as read
                    if (isUnread) {
                      await notification_service.NotificationService.markAsRead(n.id);
                    }
                  }
                },
                onLongPress: _isSelecting ? null : () => _enterSelectMode(n.id),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: _isSelecting
                // Show checkbox in selection mode
                    ? AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? kPrimaryGreen : Colors.grey.shade200,
                    border: Border.all(
                      color: isSelected ? kPrimaryGreen : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                )
                // Normal icon with unread dot
                    : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(icon, color: color, size: 22),
                    ),
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
                    Text(timeago.format(n.timestamp), style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
                trailing: _isSelecting
                    ? null
                    : isUnread
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
            ),
          ),
        ),
      ),
    );
  }
}