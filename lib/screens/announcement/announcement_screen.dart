import 'dart:async';
import 'dart:convert';
import 'package:safechain/widgets/profile_completion_banner.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/services/session_manager.dart';
import 'package:timeago/timeago.dart' as timeago;

const Color kPrimaryGreen = Color(0xFF20C997);
const String _baseUrl = 'https://safechain.site';

// ── Models ───────────────────────────────────────────────────────
class Announcement {
  final int id;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final List<AnnouncementMedia> media;
  int viewCount;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
    required this.media,
    required this.viewCount,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final mediaList = (json['media'] as List? ?? [])
        .map((m) => AnnouncementMedia.fromJson(m))
        .toList();
    return Announcement(
      id:         json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title:      json['title']       ?? '',
      content:    json['content']     ?? '',
      authorName: json['author_name'] ?? 'Admin',
      createdAt:  DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      media:      mediaList,
      viewCount:  json['view_count'] is int
          ? json['view_count']
          : int.tryParse(json['view_count'].toString()) ?? 0,
    );
  }
}

class AnnouncementMedia {
  final String type;
  final String src;
  AnnouncementMedia({required this.type, required this.src});
  factory AnnouncementMedia.fromJson(Map<String, dynamic> json) =>
      AnnouncementMedia(type: json['type'] ?? 'image', src: json['src'] ?? '');
  String get fullUrl => '$_baseUrl/${src.startsWith('/') ? src.substring(1) : src}';
}

// ── Screen ───────────────────────────────────────────────────────
class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});
  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  List<Announcement> _announcements = [];
  bool _isLoading    = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page       = 1;
  int _totalPages = 1;

  final ScrollController _scrollController = ScrollController();
  final Set<int> _viewedIds = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
    _scrollController.addListener(_onScroll);
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchAnnouncements(silent: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _page < _totalPages) {
        _fetchAnnouncements(loadMore: true);
      }
    }
  }

  Future<void> _fetchAnnouncements({bool loadMore = false, bool refresh = false, bool silent = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else if (!silent) {
      setState(() { _page = 1; _isLoading = true; _error = null; });
    } else {
      // Silent refresh — reset page without showing spinner
      _page = 1;
    }

    final fetchPage = loadMore ? _page + 1 : 1;

    try {
      final uri = Uri.parse('$_baseUrl/api/announcements/get.php?page=$fetchPage&limit=10');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final fetched = (body['announcements'] as List)
              .map((a) => Announcement.fromJson(a))
              .toList();
          final pagination = body['pagination'];

          setState(() {
            if (loadMore) {
              _announcements.addAll(fetched);
              _page = fetchPage;
            } else {
              _announcements = fetched;
              _page = 1;
            }
            _totalPages    = pagination['total_pages'] ?? 1;
            _isLoading     = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _error         = body['message'] ?? 'Failed to load.';
            _isLoading     = false;
            _isLoadingMore = false;
          });
        }
      } else {
        setState(() {
          _error         = 'Server error (${response.statusCode}).';
          _isLoading     = false;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      setState(() {
        _error         = 'Could not connect. Check your internet.';
        _isLoading     = false;
        _isLoadingMore = false;
      });
    }
  }


  // ── Called by card when user expands — records view ──────────
  Future<void> _recordView(Announcement a) async {
    // Skip if already recorded this session
    if (_viewedIds.contains(a.id)) return;
    _viewedIds.add(a.id);

    final user = await SessionManager.getUser();
    if (user == null) {
      return;
    }


    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/announcements/record_view.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'announcement_id': a.id,
          'user_id': user.residentId,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          if (mounted) setState(() => a.viewCount = body['view_count']);
        }
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner sits above everything — shows only when profile is incomplete
            const ProfileCompletionBanner(),
            // Title section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Announcements',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Community safety updates and advisories.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
                  : _error != null
                  ? _buildError()
                  : _announcements.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                color: kPrimaryGreen,
                onRefresh: () => _fetchAnnouncements(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _announcements.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _announcements.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
                      );
                    }
                    // Record view as soon as card is visible on screen
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _recordView(_announcements[index]);
                    });
                    return _AnnouncementCard(
                      announcement: _announcements[index],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchAnnouncements,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('No announcements yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
      ],
    ),
  );
}

// ── Card ─────────────────────────────────────────────────────────
class _AnnouncementCard extends StatefulWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _expanded = false;
  static const int _previewLines = 3;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Author row ──────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kPrimaryGreen.withOpacity(0.15),
                  radius: 22,
                  child: Text(
                    a.authorName.isNotEmpty ? a.authorName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(a.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(Icons.star_rounded, size: 11, color: Colors.grey.shade500),
                                const SizedBox(width: 3),
                                Text('Admin', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // ── Time + view count ──
                      Row(
                        children: [
                          Text(timeago.format(a.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          const SizedBox(width: 12),
                          Icon(Icons.remove_red_eye_outlined, size: 13, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text('${a.viewCount}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Title ───────────────────────────────────────────
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            // ── Content (collapsed / expanded) ──────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Text(
                a.content,
                maxLines: _previewLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.55),
              ),
              secondChild: Text(
                a.content,
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.55),
              ),
            ),

            // ── Expand / Collapse arrow ──────────────────────────
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _toggle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: kPrimaryGreen, size: 26),
                  ),
                ],
              ),
            ),

            // ── Media (only shown when expanded) ────────────────
            if (_expanded && a.media.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...a.media.map((m) => _buildMedia(m)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(AnnouncementMedia m) {
    if (m.type == 'image') {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            m.fullUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : Container(
              height: 180,
              color: Colors.grey.shade100,
              child: const Center(child: CircularProgressIndicator(color: kPrimaryGreen)),
            ),
            errorBuilder: (ctx, _, __) => Container(
              height: 120,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade300, size: 40)),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 100,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Text('Media attachment', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}