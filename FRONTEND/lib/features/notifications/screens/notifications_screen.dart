import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';

class NotificationModel {
  NotificationModel({
    required this.id,
    required this.body,
    this.title,
    this.templateCode,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String body;
  final String? title;
  final String? templateCode;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isUnread => readAt == null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      title: json['title']?.toString(),
      templateCode: json['template_code']?.toString(),
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<NotificationModel> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().get('/notifications/');
      final list = data['results'] is List ? data['results'] as List : const [];
      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (!n.isUnread) return;
    try {
      await context.read<ApiClient>().post('/notifications/${n.id}/mark-read/');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: WantiColors.teal,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.paddingOf(context).top + 8,
                  24,
                  8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    Text(
                      'Notificaciones',
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: WantiColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: WantiColors.teal)),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, style: const TextStyle(color: WantiColors.error)),
                ),
              )
            else if (_items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Sin notificaciones por ahora.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final n = _items[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: InkWell(
                        onTap: () => _markRead(n),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.isUnread
                                ? WantiColors.surfaceTeal
                                : WantiColors.canvas,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WantiColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((n.title ?? '').isNotEmpty)
                                Text(
                                  n.title!,
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              Text(
                                n.body,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: WantiColors.inkMuted,
                                  height: 1.35,
                                ),
                              ),
                              if (n.createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    relativeDaysAgo(n.createdAt),
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: WantiColors.inkFaint,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
