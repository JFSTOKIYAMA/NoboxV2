import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_detail_screen.dart';
import 'login_screen.dart';
import 'new_conversation_dialog.dart';
import 'services/app_theme_controller.dart';
import 'services/nobox_api_service.dart';

/// Model untuk item percakapan NoBox Chat
class ChatConversation {
  final String id;
  final String name;
  final String? subtitle;
  final String lastMessage;
  final String time;
  final String channel; // 'Telegram' atau 'WhatsApp'
  final String assignedTo;
  final int unreadCount;
  final String status; // 'Assigned', 'Unassigned', 'Resolved'
  final bool isGroup;
  final String? avatarUrl;
  final bool isSpecialMessage; // e.g. Unsupported message or sticker
  final String? extId;
  final String? accountId;
  final String? groupId;
  final String? linkId;

  const ChatConversation({
    required this.id,
    required this.name,
    this.subtitle,
    required this.lastMessage,
    required this.time,
    required this.channel,
    required this.assignedTo,
    this.unreadCount = 0,
    required this.status,
    this.isGroup = false,
    this.avatarUrl,
    this.isSpecialMessage = false,
    this.extId,
    this.accountId,
    this.groupId,
    this.linkId,
  });
}

/// Halaman NoBox Chat dengan sinkronisasi dua arah ke nobox.ai:
/// Modern, minimalis, kontras tinggi, hierarki tipografi tegas,
/// auto-sync percakapan, dan pengiriman pesan langsung ke backend nobox.ai.
class ChatInboxScreen extends StatefulWidget {
  final VoidCallback? onBackToLoading;
  final List<ChatConversation> initialConversations;

  const ChatInboxScreen({
    super.key,
    this.onBackToLoading,
    this.initialConversations = const [],
  });

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final NoboxApiService _apiService = NoboxApiService();

  int _selectedTabIndex = 0;
  final List<String> _tabs = const ['All', 'Unassigned', 'Assigned', 'Resolved'];
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  late List<ChatConversation> _conversations =
      List<ChatConversation>.from(widget.initialConversations);

  Timer? _syncTimer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initAndSync();

    // Auto-sync berkala cepat setiap 2.5 detik jika terhubung ke server nobox.ai
    _syncTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted && _apiService.isLoggedIn && !_isSyncing) {
        _syncFromNoboxAi();
      }
    });
  }

  Future<void> _initAndSync() async {
    await _apiService.init();
    if (mounted && _apiService.isLoggedIn) {
      await _syncFromNoboxAi();
    }
  }

  Future<void> _syncFromNoboxAi() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final remoteChats = await _apiService.getConversations();
    if (mounted) {
      setState(() {
        if (remoteChats.isNotEmpty) {
          _conversations = remoteChats;
        }
        _isSyncing = false;
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ChatConversation> get _filteredConversations {
    return _conversations.where((chat) {
      // 1. Filter Tab
      final String currentTab = _tabs[_selectedTabIndex];
      if (currentTab != 'All' && chat.status != currentTab) {
        return false;
      }

      // 2. Filter Search
      if (_searchQuery.trim().isNotEmpty) {
        final String query = _searchQuery.toLowerCase();
        final bool matchName = chat.name.toLowerCase().contains(query);
        final bool matchSub = chat.subtitle?.toLowerCase().contains(query) ?? false;
        final bool matchMsg = chat.lastMessage.toLowerCase().contains(query);
        return matchName || matchSub || matchMsg;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        final bool isDark = AppThemeController.instance.isDarkMode;
        const Color brandPrimary = Color(0xFF0066FF);
        final Color brandAccent =
            isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        final Color bgCanvas =
            isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
        final Color surfaceCard =
            isDark ? const Color(0xFF111726) : Colors.white;
        final Color headerBg =
            isDark ? const Color(0xFF0D1322) : Colors.white;
        final Color borderColor =
            isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0);
        final Color tabContainerBg =
            isDark ? const Color(0xFF0D1322) : Colors.white;
        final Color dividerColor =
            isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);

        return Scaffold(
          backgroundColor: bgCanvas,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(68),
            child: Container(
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(
                  bottom: BorderSide(
                    color: borderColor,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _isSearchOpen
                      ? _buildSearchBar(isDark)
                      : _buildNormalAppBar(brandAccent, isDark),
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // 1. Modern Segmented Tab Bar (Pill selector)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                color: tabContainerBg,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(_tabs.length, (index) {
                      final String tab = _tabs[index];
                      final bool isSelected = _selectedTabIndex == index;
                      final int count = _getTabCount(tab);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandPrimary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? brandPrimary
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tab,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.65)
                                            : const Color(0xFF64748B)),
                                  ),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.1)
                                              : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.8)
                                                : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // 2. Chat Conversation List dengan Pull-to-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _syncFromNoboxAi,
                  color: brandAccent,
                  backgroundColor: surfaceCard,
                  child: _filteredConversations.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filteredConversations.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            thickness: 0.6,
                            indent: 78,
                            endIndent: 16,
                            color: dividerColor,
                          ),
                          itemBuilder: (context, index) {
                            final ChatConversation chat =
                                _filteredConversations[index];
                            return _buildChatRow(
                              chat,
                              surfaceCard,
                              brandPrimary,
                              isDark,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),

          // 3. Floating Action Button (New Chat)
          floatingActionButton: FloatingActionButton(
            onPressed: _showNewChatModal,
            backgroundColor: brandPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  int _getTabCount(String tab) {
    if (tab == 'All') return _conversations.length;
    return _conversations.where((c) => c.status == tab).length;
  }

  Widget _buildNormalAppBar(Color brandAccent, bool isDark) {
    return Row(
      children: [
        // Logo Nobox Icon Container
        Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Image.asset(
            'assets/images/logo_transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => Icon(
              Icons.view_in_ar_rounded,
              color: brandAccent,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Title and Live Sync Status
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'NoBox',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: brandAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: _showNoboxAiConnectDialog,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _apiService.isLoggedIn
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _apiService.isLoggedIn
                          ? 'nobox.ai aktif (${_conversations.length} chat)'
                          : 'Hubungkan nobox.ai',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action Icons
        if (_isSyncing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: brandAccent,
              ),
            ),
          ),
        IconButton(
          tooltip: 'Cari percakapan',
          icon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _isSearchOpen = true;
            });
          },
        ),
        IconButton(
          tooltip: 'Filter saluran',
          icon: Icon(
            Icons.tune_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            size: 22,
          ),
          onPressed: () {
            _showFilterBottomSheet(context);
          },
        ),
        // Menu Titik Tiga (Pergantian Gelap/Terang & Logout)
        PopupMenuButton<String>(
          tooltip: 'Menu lainnya',
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            size: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          color: isDark ? const Color(0xFF111726) : Colors.white,
          elevation: 6,
          onSelected: (value) {
            if (value == 'theme') {
              AppThemeController.instance.toggleTheme();
            } else if (value == 'logout') {
              _handleLogout();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'theme',
              child: Row(
                children: [
                  Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isDark ? 'Mode Terang' : 'Mode Gelap',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Keluar Akun',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    final bool isDark = AppThemeController.instance.isDarkMode;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111726) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Keluar Akun',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun nobox.ai?',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await _apiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: LoginScreen(
              destination: ChatInboxScreen(
                onBackToLoading: widget.onBackToLoading,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSearchBar(bool isDark) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () {
            setState(() {
              _isSearchOpen = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Cari nama, pesan, atau institusi...',
              hintStyle: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : const Color(0xFF94A3B8),
                fontSize: 13.5,
              ),
              border: InputBorder.none,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.clear_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 18,
            ),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
      ],
    );
  }

  Widget _buildChatRow(
    ChatConversation chat,
    Color surfaceCard,
    Color brandPrimary,
    bool isDark,
  ) {
    return InkWell(
      onTap: () async {
        // Navigasi langsung ke ruang chat dua arah dengan nobox.ai
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatDetailScreen(
              chat: chat,
              onMessageSent: (sentText) {
                setState(() {
                  final idx =
                      _conversations.indexWhere((c) => c.id == chat.id);
                  if (idx != -1) {
                    final old = _conversations[idx];
                    _conversations[idx] = ChatConversation(
                      id: old.id,
                      name: old.name,
                      subtitle: old.subtitle,
                      lastMessage: sentText,
                      time: 'Baru saja',
                      channel: old.channel,
                      assignedTo: old.assignedTo,
                      status: old.status,
                      isGroup: old.isGroup,
                      extId: old.extId,
                      accountId: old.accountId,
                      groupId: old.groupId,
                      linkId: old.linkId,
                    );
                  }
                });
              },
            ),
          ),
        );
        if (mounted && _apiService.isLoggedIn) {
          await _syncFromNoboxAi();
        }
      },
      splashColor: brandPrimary.withValues(alpha: 0.08),
      highlightColor: brandPrimary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Avatar dengan badge icon channel
            _buildAvatar(chat, isDark),

            const SizedBox(width: 14),

            // Informasi Utama (Nama, Subtitle, Pesan Terakhir)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Nama Kontak
                      Expanded(
                        child: Text(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Timestamp
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 11,
                          color: chat.unreadCount > 0
                              ? const Color(0xFF0066FF)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : const Color(0xFF94A3B8)),
                          fontWeight: chat.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  // Subtitle / Institusi
                  if (chat.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      chat.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Pesan Terakhir & Status Badges
                  Row(
                    children: [
                      // Last Message preview
                      Expanded(
                        child: Row(
                          children: [
                            if (chat.isSpecialMessage &&
                                chat.lastMessage.contains('Sticker')) ...[
                              const Icon(
                                Icons.wb_sunny_rounded,
                                size: 13,
                                color: Color(0xFFFBBF24),
                              ),
                              const SizedBox(width: 4),
                            ] else if (chat.isSpecialMessage &&
                                chat.lastMessage.contains('Unsupported')) ...[
                              const Icon(
                                Icons.block_rounded,
                                size: 13,
                                color: Color(0xFFF87171),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: chat.lastMessage.contains('Unsupported')
                                      ? const Color(0xFFF87171)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : const Color(0xFF475569)),
                                  fontWeight: chat.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Channel & Assignee info pill
                      _buildAssigneeBadge(chat),

                      const SizedBox(width: 8),

                      // Unread count badge
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: brandPrimary.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatConversation chat, bool isDark) {
    final Color avatarBg = chat.isGroup
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
        : (isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
            : const Color(0xFFE0F2FE));
    final Color avatarBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : (chat.isGroup ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD));
    final Color textColor = isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0284C7);
    final Color groupIconColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color badgeBorderColor = isDark
        ? const Color(0xFF090D16)
        : Colors.white;

    return Stack(
      children: [
        // Lingkaran Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarBg,
            border: Border.all(
              color: avatarBorder,
              width: 1.2,
            ),
          ),
          child: Center(
            child: chat.isGroup
                ? Icon(
                    Icons.groups_rounded,
                    color: groupIconColor,
                    size: 24,
                  )
                : Text(
                    chat.name.isNotEmpty
                        ? chat.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
          ),
        ),

        // Channel Mini Badge (Telegram / WhatsApp)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: badgeBorderColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: chat.channel == 'Telegram'
                    ? const Color(0xFF0088CC)
                    : const Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              child: Icon(
                chat.channel == 'Telegram'
                    ? Icons.send_rounded
                    : Icons.chat_rounded,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeBadge(ChatConversation chat) {
    Color statusColor;
    if (chat.status == 'Assigned') {
      statusColor = const Color(0xFF38BDF8);
    } else if (chat.status == 'Unassigned') {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 11,
            color: statusColor,
          ),
          const SizedBox(width: 3),
          Text(
            chat.assignedTo,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final bool isSearchActive = _searchQuery.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Icon(
                  isSearchActive
                      ? Icons.search_off_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 30,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isSearchActive
                  ? 'Percakapan Tidak Ditemukan'
                  : 'Belum Ada Percakapan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearchActive
                  ? 'Coba gunakan kata kunci pencarian yang berbeda'
                  : 'Pesan dari saluran Telegram & WhatsApp yang terhubung ke nobox.ai akan muncul di sini secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            if (!_apiService.isLoggedIn)
              OutlinedButton.icon(
                onPressed: _showNoboxAiConnectDialog,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Hubungkan Akun nobox.ai'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0066FF),
                  side: const BorderSide(color: Color(0xFF0066FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final bool isDark = AppThemeController.instance.isDarkMode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F1523) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color handleColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(0xFFCBD5E1);

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Filter Saluran & Akun',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.all_inclusive_rounded,
                  color: isDark ? Colors.white : const Color(0xFF0066FF),
                ),
                title: Text(
                  'Semua Saluran',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: Color(0xFF0088CC)),
                title: Text(
                  'Telegram (Awas)',
                  style: TextStyle(color: textColor),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                title: Text(
                  'WhatsApp (Fawwas)',
                  style: TextStyle(color: textColor),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNoboxAiConnectDialog() {
    final bool isDark = AppThemeController.instance.isDarkMode;
    final userController =
        TextEditingController(text: _apiService.currentUsername ?? '');
    final passController = TextEditingController();
    bool isConnecting = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final Color dialogBg =
                isDark ? const Color(0xFF111726) : Colors.white;
            final Color titleColor =
                isDark ? Colors.white : const Color(0xFF0F172A);
            final Color descColor = isDark
                ? Colors.white.withValues(alpha: 0.6)
                : const Color(0xFF64748B);
            final Color inputBg =
                isDark ? const Color(0xFF161F33) : const Color(0xFFF8FAFC);
            final Color inputBorder = isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0);
            final Color inputTextColor =
                isDark ? Colors.white : const Color(0xFF0F172A);
            final Color inputLabelColor =
                isDark ? Colors.white70 : const Color(0xFF64748B);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0066FF)),
                  const SizedBox(width: 8),
                  Text(
                    'Koneksi nobox.ai',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _apiService.isLoggedIn
                        ? 'Akun aktif: ${_apiService.currentUsername}\nServer: id.nobox.ai'
                        : 'Masukkan kredensial akun nobox.ai untuk sinkronisasi otomatis.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: descColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_apiService.isLoggedIn) ...[
                    TextField(
                      controller: userController,
                      style: TextStyle(color: inputTextColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Username / Email',
                        labelStyle: TextStyle(color: inputLabelColor),
                        filled: true,
                        fillColor: inputBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passController,
                      obscureText: true,
                      style: TextStyle(color: inputTextColor, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: inputLabelColor),
                        filled: true,
                        fillColor: inputBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (_apiService.isLoggedIn)
                  TextButton(
                    onPressed: () async {
                      await _apiService.logout();
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder<void>(
                          transitionDuration: const Duration(milliseconds: 400),
                          pageBuilder: (_, animation, secondaryAnimation) =>
                              FadeTransition(
                            opacity: animation,
                            child: LoginScreen(
                              destination: ChatInboxScreen(
                                onBackToLoading: widget.onBackToLoading,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Putuskan Sesi', style: TextStyle(color: Color(0xFFF87171))),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (!_apiService.isLoggedIn)
                  FilledButton(
                    onPressed: isConnecting
                        ? null
                        : () async {
                            final u = userController.text.trim();
                            final p = passController.text.trim();
                            if (u.isEmpty || p.isEmpty) return;

                            setDialogState(() => isConnecting = true);

                            final ok = await _apiService.login(u, p);
                            setDialogState(() => isConnecting = false);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (ok && mounted) {
                              await _syncFromNoboxAi();
                            }
                          },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
                    child: isConnecting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Hubungkan'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showNewChatModal() async {
    final ChatConversation? created = await showDialog<ChatConversation>(
      context: context,
      builder: (ctx) => NewConversationDialog(
        onCreated: (newChat) {
          setState(() {
            _conversations.insert(0, newChat);
          });
        },
      ),
    );

    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Percakapan dengan ${created.name} berhasil dibuat'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
