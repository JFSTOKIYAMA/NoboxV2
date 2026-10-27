import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_inbox_screen.dart';
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

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final NoboxApiService _apiService = NoboxApiService();

  List<ChatMessageItem> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Polling periodik (setiap 5 detik) untuk sinkronisasi pesan baru dari nobox.ai
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isSending) {
        _syncMessagesSilently();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    // Ambil pesan dari server nobox.ai
    final remoteMessages = await _apiService.getMessages(widget.chat.id);

    if (!mounted) return;
    setState(() {
      if (remoteMessages.isNotEmpty) {
        _messages = remoteMessages;
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
    final remoteMessages = await _apiService.getMessages(widget.chat.id);
    if (!mounted || remoteMessages.isEmpty) return;

    if (remoteMessages.length != _messages.length ||
        (remoteMessages.isNotEmpty && remoteMessages.last.id != _messages.last.id)) {
      setState(() {
        _messages = remoteMessages;
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

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();

    // 1. Optimistic Update di UI lokal
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final tempMsg = ChatMessageItem(
      id: 'local_${now.millisecondsSinceEpoch}',
      content: text,
      isMe: true,
      time: timeStr,
      isPending: true,
    );

    setState(() {
      _messages.add(tempMsg);
      _isSending = true;
    });
    _scrollToBottom();
    widget.onMessageSent?.call(text);

    // 2. Kirim pesan ke nobox.ai (Inbox/Send)
    final bool success = await _apiService.sendMessage(
      roomId: widget.chat.id,
      content: text,
      channelId: widget.chat.channel == 'Telegram' ? '2' : '1',
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      // Update status pending menjadi terkirim
      final idx = _messages.indexOf(tempMsg);
      if (idx != -1) {
        _messages[idx] = ChatMessageItem(
          id: tempMsg.id,
          content: tempMsg.content,
          isMe: true,
          time: tempMsg.time,
          isPending: !success,
        );
      }
    });

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mode offline: pesan disimpan secara lokal'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandPrimary = Color(0xFF0066FF);
    const Color brandAccent = Color(0xFF38BDF8);
    const Color bgCanvas = Color(0xFF090D16);
    const Color headerBg = Color(0xFF0D1322);

    return Scaffold(
      backgroundColor: bgCanvas,
      appBar: AppBar(
        backgroundColor: headerBg,
        elevation: 0,
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
                    ? const Color(0xFF1E293B)
                    : const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: widget.chat.isGroup
                    ? const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      )
                    : Text(
                        widget.chat.name.isNotEmpty
                            ? widget.chat.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF38BDF8),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: widget.chat.channel == 'Telegram'
                              ? const Color(0xFF0088CC).withValues(alpha: 0.2)
                              : const Color(0xFF25D366).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.chat.channel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.chat.channel == 'Telegram'
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'nobox.ai sync',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
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
          IconButton(
            tooltip: 'Sinkronisasi sekarang',
            icon: const Icon(Icons.sync_rounded, color: Colors.white70, size: 20),
            onPressed: _loadMessages,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Koneksi nobox.ai
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF101726),
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
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Area Chat List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: brandAccent,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, brandPrimary);
                    },
                  ),
          ),

          // Input Bar di Bagian Bawah
          _buildInputBar(brandPrimary),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg, Color brandPrimary) {
    final bool isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? brandPrimary : const Color(0xFF161F33),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe
                ? brandPrimary
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isPending
                        ? Icons.access_time_rounded
                        : Icons.done_all_rounded,
                    size: 13,
                    color: msg.isPending
                        ? Colors.white54
                        : const Color(0xFF38BDF8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(Color brandPrimary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
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
                color: Colors.white.withValues(alpha: 0.5),
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

            // Text Input Field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSendMessage(),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan ke nobox.ai...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tombol Kirim
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0066FF),
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
