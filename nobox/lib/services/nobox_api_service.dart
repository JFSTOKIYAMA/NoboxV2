import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../chat_inbox_screen.dart';

/// Model item pesan untuk ruang obrolan NoBox Chat
class ChatMessageItem {
  final String id;
  final String content;
  final bool isMe;
  final String time;
  final bool isPending;
  final String? senderName;

  const ChatMessageItem({
    required this.id,
    required this.content,
    required this.isMe,
    required this.time,
    this.isPending = false,
    this.senderName,
  });
}

/// Service komunikasi dengan server nobox.ai (REST API)
/// Mendukung sinkronisasi dua arah:
/// 1. Mengambil percakapan dan pesan dari nobox.ai
/// 2. Mengirim pesan dari NoBox Chat langsung masuk ke nobox.ai (Telegram / WhatsApp)
class NoboxApiService {
  static final NoboxApiService _instance = NoboxApiService._internal();
  factory NoboxApiService() => _instance;
  NoboxApiService._internal();

  static const String baseUrl = 'https://id.nobox.ai/';
  static const String _tokenPrefKey = 'auth_token';
  static const String _usernamePrefKey = 'last_username';
  static const String _tenantIdPrefKey = 'tenant_id';

  String? _token;
  String? _tenantId;
  String? _currentUsername;
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn && _token != null && _token!.isNotEmpty;
  String? get currentUsername => _currentUsername;

  /// Inisialisasi token dari penyimpanan lokal
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenPrefKey);
      _currentUsername = prefs.getString(_usernamePrefKey);
      _tenantId = prefs.getString(_tenantIdPrefKey);
      if (_token != null && _token!.isNotEmpty) {
        _isLoggedIn = true;
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error initializing: $e');
    }
  }

  /// Autentikasi ke nobox.ai menggunakan username & password
  Future<bool> login(String username, String password) async {
    try {
      final Uri uri = Uri.parse('${baseUrl}AccountAPI/GenerateToken');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'userName': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map && data['token'] != null) {
          _token = data['token'].toString();
          _currentUsername = username;
          _isLoggedIn = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenPrefKey, _token!);
          await prefs.setString(_usernamePrefKey, username);

          // Ambil tenant dan akun setelah login
          await fetchAccounts();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('NoboxApiService: Login error: $e');
      return false;
    }
  }

  /// Logout dan hapus sesi token
  Future<void> logout() async {
    _token = null;
    _currentUsername = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefKey);
  }

  /// Set token secara manual jika sudah didapatkan dari sesi aktif
  Future<void> setSessionToken(String token, {String? username}) async {
    _token = token;
    _currentUsername = username ?? 'Agent';
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefKey, token);
    if (username != null) {
      await prefs.setString(_usernamePrefKey, username);
    }
    await fetchAccounts();
  }

  /// Mengambil daftar akun & tenant ID
  Future<void> fetchAccounts() async {
    if (!isLoggedIn) return;
    try {
      final Uri uri = Uri.parse('${baseUrl}Services/Nobox/Account/List');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map && data['Entities'] is List) {
          final List<dynamic> entities = data['Entities'] as List<dynamic>;
          if (entities.isNotEmpty) {
            final firstAccount = entities.first;
            if (firstAccount is Map && firstAccount['TenantId'] != null) {
              _tenantId = firstAccount['TenantId'].toString();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_tenantIdPrefKey, _tenantId!);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NoboxApiService: fetchAccounts error: $e');
    }
  }

  /// 1. Mengambil daftar percakapan dari nobox.ai (Chatrooms/List)
  Future<List<ChatConversation>> getConversations({String? filterStatus}) async {
    if (!isLoggedIn) {
      return [];
    }

    try {
      final Uri uri = Uri.parse('${baseUrl}Services/Chat/Chatrooms/List');
      final Map<String, dynamic> payload = {
        'Take': 50,
        'Skip': 0,
        'Sort': ['Up DESC'],
      };

      if (filterStatus != null && filterStatus != 'All') {
        int st = 1;
        if (filterStatus == 'Assigned') st = 2;
        if (filterStatus == 'Resolved') st = 3;
        payload['EqualityFilter'] = {'St': st};
      }

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> items = [];
        if (data is List) {
          items = data;
        } else if (data is Map) {
          final dynamic raw = data['Entities'] ?? data['Values'] ?? data['data'];
          if (raw is List) {
            items = raw;
          }
        }

        return items.map((json) {
          if (json is! Map) return null;
          final map = Map<String, dynamic>.from(json);

          // ID
          final String id = map['Id']?.toString() ?? '';

          // Name
          final String name = (map['CtNm'] ??
                  map['ContactName'] ??
                  map['Ct'] ??
                  map['Name'] ??
                  map['Title'] ??
                  'Tanpa Nama')
              .toString();

          // Subtitle / Group / Funnel
          final String? subtitle =
              map['FnNm']?.toString() ?? map['GroupNm']?.toString();

          // Last message
          String lastMsg = (map['LastMsg'] ?? map['Category'] ?? '').toString();
          if (lastMsg.isEmpty || lastMsg == 'null') {
            lastMsg = 'Percakapan kosong';
          }

          // Format waktu
          final String rawTime = (map['Up'] ?? map['In'] ?? '').toString();
          final String time = _formatTimestamp(rawTime);

          // Channel (Telegram / WhatsApp)
          final String chNm = (map['ChNm'] ?? map['Channel'] ?? '').toString();
          final String chId = map['ChId']?.toString() ?? '1';
          final String channel = (chId == '2' || chNm.toLowerCase().contains('telegram'))
              ? 'Telegram'
              : 'WhatsApp';

          // Assigned Agent
          final String assignedTo =
              (map['UsrNm'] ?? map['AgentName'] ?? 'Belum Ditugaskan').toString();

          // Status
          final dynamic stVal = map['St'];
          String status = 'Unassigned';
          if (stVal == 2 || stVal == '2' || stVal == 'Assigned') {
            status = 'Assigned';
          } else if (stVal == 3 || stVal == '3' || stVal == 'Resolved') {
            status = 'Resolved';
          }

          // Unread Count
          final int unreadCount =
              int.tryParse(map['Uc']?.toString() ?? '0') ?? 0;

          // Group flag
          final dynamic grpId = map['GrpId'] ?? map['GroupId'];
          final bool isGroup = (grpId != null && grpId.toString() != '0') ||
              name.toLowerCase().contains('grup') ||
              name.toLowerCase().contains('group');

          return ChatConversation(
            id: id,
            name: name,
            subtitle: subtitle,
            lastMessage: lastMsg,
            time: time,
            channel: channel,
            assignedTo: assignedTo,
            unreadCount: unreadCount,
            status: status,
            isGroup: isGroup,
          );
        }).whereType<ChatConversation>().toList();
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error fetching conversations: $e');
    }
    return [];
  }

  /// 2. Mengambil riwayat pesan di suatu room dari nobox.ai (ChatMessages/List)
  Future<List<ChatMessageItem>> getMessages(String roomId) async {
    if (!isLoggedIn) {
      return [];
    }

    try {
      final Uri uri = Uri.parse('${baseUrl}Services/Chat/ChatMessages/List');
      final int? numericRoomId = int.tryParse(roomId.replaceAll(RegExp(r'[^0-9]'), ''));

      final payload = {
        'Take': 40,
        'Skip': 0,
        'Sort': ['In ASC'],
        'EqualityFilter': {'RoomId': numericRoomId ?? roomId},
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> items = [];
        if (data is List) {
          items = data;
        } else if (data is Map) {
          final dynamic raw = data['Entities'] ?? data['Values'] ?? data['data'];
          if (raw is List) {
            items = raw;
          }
        }

        return items.map((json) {
          if (json is! Map) return null;
          final map = Map<String, dynamic>.from(json);

          final String msgId = map['Id']?.toString() ?? '';
          final String body = (map['Body'] ?? map['Msg'] ?? '').toString();
          final String sdr = (map['SdrMsg'] ?? map['Sdr'] ?? '').toString().toLowerCase();
          final bool isMe = sdr == 'me' || map['IsMe'] == true || map['IsMeLast'] == true;
          final String rawTime = (map['In'] ?? map['Up'] ?? '').toString();

          return ChatMessageItem(
            id: msgId,
            content: body,
            isMe: isMe,
            time: _formatTimeOnly(rawTime),
            senderName: map['SenderName']?.toString(),
          );
        }).whereType<ChatMessageItem>().toList();
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error fetching messages: $e');
    }
    return [];
  }

  /// 3. Mengirim pesan dari NoBox Chat ke nobox.ai (Inbox/Send)
  /// Pesan yang dikirim di sini otomatis masuk ke nobox.ai dan diteruskan ke customer
  Future<bool> sendMessage({
    required String roomId,
    required String content,
    String channelId = '1',
    String? accountId,
  }) async {
    if (!isLoggedIn) {
      return false;
    }

    try {
      final String cleanRoomId = roomId.replaceAll(RegExp(r'[^0-9\-]'), '');
      final Uri uri = Uri.parse('${baseUrl}Inbox/Send?Id=$cleanRoomId');

      final payload = {
        'Body': content,
        'BodyType': 'text',
        'ChannelId': int.tryParse(channelId) ?? 1,
        'AccountIds': accountId ?? '',
        'Attachment': '',
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(payload),
      );

      debugPrint('NoboxApiService: sendMessage response code: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('NoboxApiService: Error sending message: $e');
      return false;
    }
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '$hour:$minute';
      }
      return '${dt.day} ${_monthName(dt.month)}, $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  String _formatTimeOnly(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
