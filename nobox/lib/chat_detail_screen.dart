import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_inbox_screen.dart';
import 'services/app_theme_controller.dart';
import 'services/nobox_api_service.dart';

/// Halaman percakapan aktif NoBox Chat yang terhubung dua arah dengan nobox.ai.
/// Pesan yang dikirim langsung di-forward ke nobox.ai (Inbox/Send).
class ChatDetailScreen extends StatefulWidget {
  final ChatConversation chat;
  final ValueChanged<String>? onMessageSent;

  const ChatDetailScreen({
    super.key,
    required this.chat,
    this.onMessageSent,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _OutgoingMessageTask {
  final String tempId;
  final String content;

  const _OutgoingMessageTask({
    required this.tempId,
    required this.content,
  });
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final NoboxApiService _apiService = NoboxApiService();

  // Cache pesan lokal per ruang obrolan agar saat refresh/navigasi pesan tidak terhapus
  static final Map<String, List<ChatMessageItem>> _pendingLocalMessagesByRoom = {};

  List<ChatMessageItem> _messages = [];
  bool _isLoading = true;
  final List<_OutgoingMessageTask> _outgoingQueue = [];
  bool _isProcessingQueue = false;
  Timer? _pollingTimer;
  Timer? _postSendSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Polling periodik (setiap 2 detik) agar pesan baru langsung masuk seketika
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (mounted && !_isProcessingQueue) {
        _syncMessagesSilently();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _postSendSyncTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Rekonsiliasi 1-to-1 antara pesan remote dari server dengan pesan lokal
  /// Menjamin:
  /// 1. Pesan kita TIDAK PERNAH DOUBLE (setiap pesan lokal yang sudah ada di remote digantikan secara mulus)
  /// 2. Pesan kita TIDAK PERNAH TERHAPUS (pesan lokal yang belum ada di server tetap dipertahankan di bawah)
  List<ChatMessageItem> _reconcileMessages(
    List<ChatMessageItem> remoteList,
    List<ChatMessageItem> currentList,
  ) {
    // 1. Kumpulkan semua pesan lokal yang masih pending atau berawalan local_
    final List<ChatMessageItem> candidateLocals = [
      ...currentList.where((m) => m.id.startsWith('local_') || m.isPending),
      ...?_pendingLocalMessagesByRoom[widget.chat.id],
    ];

    // Deduplikasi kandidat lokal berdasarkan ID
    final Map<String, ChatMessageItem> uniqueLocals = {};
    for (final loc in candidateLocals) {
      uniqueLocals[loc.id] = loc;
    }

    final List<ChatMessageItem> result = List<ChatMessageItem>.from(remoteList);
    final Set<int> matchedRemoteIndices = {};
    final List<ChatMessageItem> remainingLocals = [];

    for (final loc in uniqueLocals.values) {
      int matchedIndex = -1;
      // Cocokkan secara 1-to-1 dengan remote list yang belum ter-match
      for (int i = 0; i < result.length; i++) {
        if (matchedRemoteIndices.contains(i)) continue;
        final rem = result[i];
        if (rem.isMe && rem.content.trim() == loc.content.trim()) {
          matchedIndex = i;
          break;
        }
      }

      if (matchedIndex != -1) {
        matchedRemoteIndices.add(matchedIndex);
        // Pesan lokal ini telah resmi ada di server!
      } else {
        // Belum ada di server, pertahankan pesan lokal ini agar tidak terhapus
        remainingLocals.add(loc);
      }
    }

    // Perbarui cache statis room
    if (remainingLocals.isEmpty) {
      _pendingLocalMessagesByRoom.remove(widget.chat.id);
    } else {
      _pendingLocalMessagesByRoom[widget.chat.id] = List.from(remainingLocals);
    }

    // Tambahkan pesan lokal yang belum di-match ke bagian bawah daftar
    result.addAll(remainingLocals);
    return result;
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    // Ambil pesan dari server nobox.ai
    final remoteMessages = await _apiService.getMessages(
      widget.chat.id,
      extId: widget.chat.extId,
    );

    if (!mounted) return;
    setState(() {
      final combined = _reconcileMessages(remoteMessages, _messages);

      if (combined.isNotEmpty) {
        _messages = combined;
      } else {
        // Jika server baru/belum ada riwayat, tampilkan pesan pembuka
        _messages = [
          ChatMessageItem(
            id: 'init_1',
            content: widget.chat.lastMessage.isNotEmpty
                ? widget.chat.lastMessage
                : 'Halo, saya menghubungi melalui ${widget.chat.channel}',
            isMe: false,
            time: widget.chat.time,
          ),
        ];
      }
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _syncMessagesSilently() async {
    final remoteMessages = await _apiService.getMessages(
      widget.chat.id,
      extId: widget.chat.extId,
    );
    if (!mounted) return;

    final combined = _reconcileMessages(remoteMessages, _messages);
    if (combined.isEmpty) return;

    bool hasChanged = combined.length != _messages.length;
    if (!hasChanged) {
      for (int i = 0; i < combined.length; i++) {
        if (combined[i].id != _messages[i].id ||
            combined[i].content != _messages[i].content ||
            combined[i].isPending != _messages[i].isPending ||
            combined[i].isMe != _messages[i].isMe) {
          hasChanged = true;
          break;
        }
      }
    }

    if (hasChanged) {
      setState(() {
        _messages = combined;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();

    // Catat ke API service agar pesan yang baru dikirim dijamin isMe = true
    _apiService.recordSentMessage(text);

    // 1. Optimistic Update langsung di UI lokal agar pengguna langsung melihat pesan di sebelah KANAN
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final String tempId =
        'local_${now.millisecondsSinceEpoch}_${_messages.length}';
    final tempMsg = ChatMessageItem(
      id: tempId,
      content: text,
      isMe: true,
      time: timeStr,
      isPending: true,
    );

    setState(() {
      _messages.add(tempMsg);
      final list = _pendingLocalMessagesByRoom[widget.chat.id] ?? [];
      list.add(tempMsg);
      _pendingLocalMessagesByRoom[widget.chat.id] = list;
    });
    _scrollToBottom();
    widget.onMessageSent?.call(text);

    // 2. Masukkan ke antrean berurutan sehingga tidak ada pesan yang terlewat
    _outgoingQueue.add(_OutgoingMessageTask(tempId: tempId, content: text));
    _processOutgoingQueue();
  }

  Future<void> _processOutgoingQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_outgoingQueue.isNotEmpty) {
      final task = _outgoingQueue.removeAt(0);

      final String safeExt = (widget.chat.extId ?? '').length > 4
          ? '${widget.chat.extId!.substring(0, 2)}***${widget.chat.extId!.substring(widget.chat.extId!.length - 2)}'
          : (widget.chat.extId != null && widget.chat.extId!.isNotEmpty ? '***' : '(empty)');
      debugPrint(
        'ChatDetail: Pre-send check -> RoomId: ${widget.chat.id}, '
        'Channel: ${widget.chat.channel}, '
        'AccountId: ${widget.chat.accountId != null && widget.chat.accountId!.isNotEmpty}, '
        'ExtId: $safeExt, '
        'LinkId: ${widget.chat.linkId}, '
        'IsGroup: ${widget.chat.isGroup}',
      );

      final bool success = await _apiService.sendMessage(
        roomId: widget.chat.id,
        content: task.content,
        channelId: widget.chat.channel == 'Telegram' ? '2' : '1',
        accountId: widget.chat.accountId,
        extId: widget.chat.extId,
        linkId: widget.chat.linkId,
        isGroup: widget.chat.isGroup,
        groupId: widget.chat.groupId,
      );

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == task.tempId);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(isPending: !success);
          }
          final roomList = _pendingLocalMessagesByRoom[widget.chat.id];
          if (roomList != null) {
            final roomIdx = roomList.indexWhere((m) => m.id == task.tempId);
            if (roomIdx != -1) {
              roomList[roomIdx] = roomList[roomIdx].copyWith(isPending: !success);
            }
          }
        });
      }

      if (!success && mounted) {
        final String errText =
            _apiService.lastError ?? 'Gagal mengirim pesan ke nobox.ai';
        if (!errText.toLowerCase().contains('too many requests')) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                errText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }

      // Jeda minimal antar pengiriman pesan berturut-turut agar aman dari rate limit server
      if (_outgoingQueue.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }

    _isProcessingQueue = false;

    if (mounted) {
      _postSendSyncTimer?.cancel();
      _postSendSyncTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && !_isProcessingQueue) {
          _syncMessagesSilently();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        final bool isDark = AppThemeController.instance.isDarkMode;
        final Color waBg =
            isDark ? const Color(0xFF0B141A) : const Color(0xFFF8FAFC);
        final Color waHeaderBg =
            isDark ? const Color(0xFF1F2C34) : Colors.white;
        final Color headerTitleColor =
            isDark ? Colors.white : const Color(0xFF111B21);
        final Color headerSubColor =
            isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF667781);
        final Color statusBannerBg =
            isDark ? const Color(0xFF111B21) : const Color(0xFFECFDF5);
        final Color statusBannerText =
            isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF047857);
        const Color waAccent = Color(0xFF00A884);

        return Scaffold(
          backgroundColor: waBg,
          appBar: AppBar(
            backgroundColor: waHeaderBg,
            elevation: isDark ? 0 : 0.5,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : const Color(0xFF111B21),
            ),
            leadingWidth: 40,
            titleSpacing: 0,
            title: Row(
              children: [
                // Mini Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.chat.isGroup
                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                        : (isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                            : const Color(0xFFE0F2FE)),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : (widget.chat.isGroup ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD)),
                    ),
                  ),
                  child: Center(
                    child: widget.chat.isGroup
                        ? Icon(
                            Icons.groups_rounded,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            size: 20,
                          )
                        : Text(
                            widget.chat.name.isNotEmpty
                                ? widget.chat.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nama & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: headerTitleColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: widget.chat.channel == 'Telegram'
                                  ? const Color(0xFF0088CC).withValues(alpha: 0.15)
                                  : const Color(0xFF25D366).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.chat.channel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.chat.channel == 'Telegram'
                                    ? const Color(0xFF0088CC)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'nobox.ai sync',
                            style: TextStyle(
                              fontSize: 11,
                              color: headerSubColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Tombol Gelap / Terang (Icon sesuai tema aktif)
              IconButton(
                tooltip: isDark ? 'Mode Gelap aktif (Ketuk untuk Mode Terang)' : 'Mode Terang aktif (Ketuk untuk Mode Gelap)',
                icon: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                  size: 20,
                ),
                onPressed: () {
                  AppThemeController.instance.toggleTheme();
                },
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              // Banner Status Koneksi nobox.ai
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: statusBannerBg,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _apiService.isLoggedIn
                          ? 'Terhubung ke nobox.ai (Real-time)'
                          : 'Terhubung ke nobox.ai (Akun Tamu/Lokal)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusBannerText,
                      ),
                    ),
                  ],
                ),
              ),

              // Area Chat List (WhatsApp Style)
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: waAccent,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg, isDark);
                        },
                      ),
              ),

              // Input Bar di Bagian Bawah
              _buildInputBar(waAccent, isDark),
            ],
          ),
        );
      },
    );
  }

  /// Bubble Obrolan WhatsApp:
  /// - Pesan kita (isMe = true): KANAN, background #005C4B (Dark) / #D9FDD3 (Light), centang status di pojok kanan bawah
  /// - Pesan orang lain (isMe = false): KIRI, background #202C33 (Dark) / #FFFFFF (Light), nama pengirim jika ada
  Widget _buildMessageBubble(ChatMessageItem msg, bool isDark) {
    final bool isMe = msg.isMe;

    final Color bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    final Color textColor =
        isDark ? const Color(0xFFE9EDEF) : const Color(0xFF0F172A);

    final Color timeColor = isMe
        ? (isDark
            ? Colors.white.withValues(alpha: 0.65)
            : const Color(0xFF64748B))
        : (isDark
            ? const Color(0xFF8696A0)
            : const Color(0xFF64748B));

    final Color bubbleBorder = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : (isMe ? const Color(0xFFC8E6C9) : const Color(0xFFE2E8F0));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 56 : 8,
          right: isMe ? 8 : 56,
          bottom: 4,
          top: 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
          border: Border.all(
            color: bubbleBorder,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nama pengirim (untuk chat masuk dari lawan bicara / grup)
            if (!isMe && msg.senderName != null && msg.senderName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  msg.senderName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0088CC),
                  ),
                ),
              ),

            // Konten Teks Pesan
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 14.2,
                height: 1.35,
                color: textColor,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 3),

            // Waktu dan Status Centang WhatsApp (Rata Kanan di Pojok Bawah)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  msg.time,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    color: timeColor,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isPending
                        ? Icons.access_time_rounded
                        : Icons.done_all_rounded,
                    size: 14,
                    color: msg.isPending
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : const Color(0xFF94A3B8))
                        : const Color(0xFF53BDEB), // Centang biru khas WhatsApp
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Input Bar Gaya WhatsApp (Pill Container & Tombol Bulat)
  Widget _buildInputBar(Color brandAccent, bool isDark) {
    final Color barBg =
        isDark ? const Color(0xFF111B21) : Colors.white;
    final Color pillBg =
        isDark ? const Color(0xFF202C33) : const Color(0xFFF1F5F9);
    final Color textColor =
        isDark ? const Color(0xFFE9EDEF) : const Color(0xFF0F172A);
    final Color pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tombol Lampiran
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : const Color(0xFF64748B),
                size: 24,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lampiran file/gambar siap dikirim ke nobox.ai'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            // Text Input Pill Field (WhatsApp Style)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: pillBorder,
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF8696A0) : const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tombol Kirim Bulat WhatsApp Style
            Container(
              decoration: BoxDecoration(
                color: brandAccent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _handleSendMessage,
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
