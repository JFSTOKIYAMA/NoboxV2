import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../chat_inbox_screen.dart';
import 'app_preferences.dart';

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

  ChatMessageItem copyWith({
    String? id,
    String? content,
    bool? isMe,
    String? time,
    bool? isPending,
    String? senderName,
  }) {
    return ChatMessageItem(
      id: id ?? this.id,
      content: content ?? this.content,
      isMe: isMe ?? this.isMe,
      time: time ?? this.time,
      isPending: isPending ?? this.isPending,
      senderName: senderName ?? this.senderName,
    );
  }
}

/// Service komunikasi dengan server nobox.ai (REST API)
/// Mengimplementasikan protokol resmi NoBox.Ai SDK:
/// - X-App-Name, User-Agent, X-App-Version
/// - AccountAPI/GenerateToken
/// - Services/Chat/Chatrooms/List & Services/Chat/ChatMessages/List
/// - Inbox/Send dengan payload ExtId, ChannelId, AccountIds, BodyType = 1
class NoboxApiService {
  static final NoboxApiService _instance = NoboxApiService._internal();
  factory NoboxApiService() => _instance;
  NoboxApiService._internal();

  static const String baseUrl = 'https://id.nobox.ai/';
  static const String _tokenPrefKey = 'auth_token';
  static const String _usernamePrefKey = 'last_username';
  static const String _tenantIdPrefKey = 'tenant_id';
  static const String _defaultAccountIdPrefKey = 'default_account_id';

  String? _token;
  String? _tenantId;
  String? _defaultAccountId;
  String? _currentUsername;
  String? _lastError;
  bool _isLoggedIn = false;

  final Map<String, String> _channelAccountMap = {};
  final Map<String, ChatConversation> _roomCache = {};
  final Map<String, DateTime> _locallySentMessageTimes = {};

  bool get isLoggedIn => _isLoggedIn && _token != null && _token!.isNotEmpty;
  String? get currentUsername => _currentUsername;
  String? get token => _token;
  String? get lastError => _lastError;
  String? get tenantId => _tenantId;
  String? get defaultAccountId => _defaultAccountId;

  /// Mencatat pesan yang dikirim oleh perangkat ini agar selalu teridentifikasi sebagai pesan kita (isMe)
  void recordSentMessage(String content) {
    final trimmed = content.trim();
    if (trimmed.isNotEmpty) {
      _locallySentMessageTimes[trimmed] = DateTime.now();
      // Bersihkan pesan yang lebih lama dari 15 menit
      final cutoff = DateTime.now().subtract(const Duration(minutes: 15));
      _locallySentMessageTimes.removeWhere((_, time) => time.isBefore(cutoff));
    }
  }

  /// Memeriksa apakah pesan teks ini baru saja dikirim oleh perangkat lokal
  bool isRecentlySentLocally(String content) {
    final trimmed = content.trim();
    final time = _locallySentMessageTimes[trimmed];
    if (time == null) return false;
    return DateTime.now().difference(time).inMinutes < 15;
  }

  /// Menentukan secara komprehensif apakah pesan dikirim oleh kita (isMe = true / sebelah kanan)
  /// Mendukung semua format backend Serenity/NoBox (int 1, string '1', bool true, Direction, SdrMsg, dsb.)
  bool _determineIsMe(Map<String, dynamic> map, String body) {
    // 1. Periksa atribut eksplisit IsMe / IsMeLast
    final dynamic isMeVal = map['IsMe'] ?? map['IsMeLast'];
    if (isMeVal == true || isMeVal == 1 || isMeVal == '1' || isMeVal == 'true') {
      return true;
    }

    // 2. Periksa flag Out / IsOut / Outgoing
    final dynamic outVal =
        map['Out'] ?? map['IsOut'] ?? map['Outgoing'] ?? map['IsOutgoing'];
    if (outVal == true || outVal == 1 || outVal == '1' || outVal == 'true') {
      return true;
    }

    // 3. Periksa arah Direction / Direct / MsgDirection
    final dynamic dirVal =
        map['Direction'] ?? map['Direct'] ?? map['MsgDirection'];
    if (dirVal == 1 ||
        dirVal == '1' ||
        dirVal?.toString().toLowerCase() == 'out' ||
        dirVal?.toString().toLowerCase() == 'outbound') {
      return true;
    }

    // 4. Periksa SenderType (1 = Agent/User, 2 = Customer/Contact)
    final dynamic sdrType = map['SenderType'] ?? map['SdrType'];
    if (sdrType == 1 || sdrType == '1') {
      return true;
    }

    // 5. Periksa SdrMsg / Sdr
    final String sdrMsg =
        (map['SdrMsg'] ?? '').toString().toLowerCase().trim();
    if (const ['you', 'me', 'agent', 'admin', 'operator', 'self', 'user']
        .contains(sdrMsg)) {
      return true;
    }

    final String sdr = (map['Sdr'] ?? '').toString().toLowerCase().trim();
    if (const ['you', 'me', 'agent', 'self'].contains(sdr)) {
      return true;
    }
    if (_currentUsername != null &&
        _currentUsername!.isNotEmpty &&
        (sdr == _currentUsername!.toLowerCase() ||
            sdrMsg == _currentUsername!.toLowerCase())) {
      return true;
    }

    // 6. Pencocokan dengan cache pesan yang baru dikirim dari perangkat ini
    if (isRecentlySentLocally(body)) {
      return true;
    }

    return false;
  }

  /// Header resmi NoBox SDK
  Map<String, String> _buildHeaders({bool requiresAuth = true}) {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Name': 'NoBoxChat',
      'X-App-Version': '1.0.0',
      'User-Agent': 'NoBoxChat/1.0.0',
    };
    if (requiresAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Inisialisasi token & akun dari penyimpanan lokal
  Future<void> init({bool syncAccounts = true}) async {
    try {
      _token = await AppPreferences.getString(_tokenPrefKey);
      _currentUsername = await AppPreferences.getString(_usernamePrefKey);
      _tenantId = await AppPreferences.getString(_tenantIdPrefKey);
      _defaultAccountId = await AppPreferences.getString(_defaultAccountIdPrefKey);
      if (_token != null && _token!.trim().isNotEmpty) {
        _isLoggedIn = true;
        if (syncAccounts) {
          unawaited(
            fetchAccounts().catchError((dynamic err) {
              debugPrint('NoboxApiService: background fetchAccounts error: $err');
            }),
          );
        }
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error initializing: $e');
      _isLoggedIn = false;
    }
  }

  /// Autentikasi ke nobox.ai menggunakan username & password (AccountAPI/GenerateToken)
  Future<bool> login(String username, String password) async {
    _lastError = null;
    try {
      final Uri uri = Uri.parse('${baseUrl}AccountAPI/GenerateToken');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(requiresAuth: false),
            body: jsonEncode({'userName': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'NoboxApiService: login response status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        String? extractedToken;

        if (data is Map) {
          extractedToken = (data['token'] ??
                  data['Data'] ??
                  data['token_access'] ??
                  data['access_token'] ??
                  data['Token'])
              ?.toString();
        } else if (data is String && data.isNotEmpty) {
          extractedToken = data;
        }

        if (extractedToken != null && extractedToken.isNotEmpty) {
          _token = extractedToken;
          _currentUsername = username;
          _isLoggedIn = true;
          _lastError = null;

          await AppPreferences.setString(_tokenPrefKey, _token!);
          await AppPreferences.setString(_usernamePrefKey, username);

          // Ambil daftar akun & tenant ID
          await fetchAccounts();
          return true;
        } else {
          _lastError = 'Format respons token dari nobox.ai tidak dikenali.';
          return false;
        }
      } else {
        _lastError =
            'Gagal masuk (HTTP ${response.statusCode}). Periksa email & password akun nobox.ai Anda.';
        return false;
      }
    } catch (e) {
      _lastError = 'Kendala koneksi ke id.nobox.ai: $e';
      debugPrint('NoboxApiService: Login error: $e');
      return false;
    }
  }

  /// Logout dan hapus sesi token
  Future<void> logout() async {
    _token = null;
    _currentUsername = null;
    _isLoggedIn = false;
    _lastError = null;
    _defaultAccountId = null;
    _channelAccountMap.clear();
    _roomCache.clear();
    await AppPreferences.remove(_tokenPrefKey);
    await AppPreferences.remove(_defaultAccountIdPrefKey);
  }

  /// Set token secara manual jika didapatkan dari sesi aktif
  Future<void> setSessionToken(String token, {String? username}) async {
    _token = token;
    _currentUsername = username ?? 'Agent';
    _isLoggedIn = true;
    _lastError = null;
    await AppPreferences.setString(_tokenPrefKey, token);
    if (username != null) {
      await AppPreferences.setString(_usernamePrefKey, username);
    }
    await fetchAccounts();
  }

  /// Mengambil daftar akun & tenant ID (Services/Nobox/Account/List)
  Future<void> fetchAccounts() async {
    if (!isLoggedIn) return;
    try {
      final Uri uri = Uri.parse('${baseUrl}Services/Nobox/Account/List');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode({
              'IncludeColumns': ['Id', 'Name', 'Channel', 'TenantId'],
              'ColumnSelection': 1,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> entities = [];
        if (data is Map && data['Entities'] is List) {
          entities = data['Entities'] as List<dynamic>;
        } else if (data is List) {
          entities = data;
        }

        if (entities.isNotEmpty) {
          for (final acc in entities) {
            if (acc is Map) {
              final accId = acc['Id']?.toString();
              final chan = acc['Channel']?.toString() ?? '1';
              final tenant = acc['TenantId']?.toString();

              if (accId != null && accId.isNotEmpty) {
                _channelAccountMap[chan] = accId;
                if (_defaultAccountId == null) {
                  _defaultAccountId = accId;
                  await AppPreferences.setString(_defaultAccountIdPrefKey, accId);
                }
              }

              if (tenant != null && tenant.isNotEmpty) {
                _tenantId = tenant;
                await AppPreferences.setString(_tenantIdPrefKey, tenant);
              }
            }
          }
          debugPrint(
            'NoboxApiService: Accounts loaded. DefaultAccountId: $_defaultAccountId, Channels: $_channelAccountMap',
          );
        }
      }
    } catch (e) {
      debugPrint('NoboxApiService: fetchAccounts error: $e');
    }
  }

  /// 1. Mengambil daftar percakapan dari nobox.ai (Services/Chat/Chatrooms/List)
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
        'ColumnSelection': 2,
        'IncludeColumns': [
          'Ct',
          'CtRealNm',
          'CtIdExt',
          'CtId',
          'LastMsg',
          'SdrMsg',
          'Up',
          'In',
          'St',
          'ChId',
          'ChAcc',
          'ChAccId',
          'Uc',
          'GrpId',
          'Tags',
          'CtRealId',
          'UsrNm',
        ],
      };

      if (filterStatus != null && filterStatus != 'All') {
        int st = 1;
        if (filterStatus == 'Assigned') st = 2;
        if (filterStatus == 'Resolved') st = 3;
        payload['EqualityFilter'] = {'St': st};
      }

      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> items = [];
        if (data is List) {
          items = data;
        } else if (data is Map) {
          final dynamic raw =
              data['Entities'] ?? data['Data'] ?? data['Values'] ?? data['data'];
          if (raw is List) {
            items = raw;
          }
        }

        if (items.isNotEmpty && items.first is Map) {
          final sample = items.first as Map;
          debugPrint('=== [FORENSIC: Chatrooms/List] ===');
          debugPrint('Total chatrooms fetched: ${items.length}');
          debugPrint('Columns: ${sample.keys.toList()}');
          debugPrint('Sample RoomId: ${sample['Id']}, LinkId: ${sample['LinkId'] ?? sample['IdLink']}, ExtId: ${sample['CtIdExt'] ?? sample['ExtId'] ?? sample['CtNo']}');
          debugPrint('==================================');
        }

        return items.map((json) {
          if (json is! Map) return null;
          final map = Map<String, dynamic>.from(json);

          // ID
          final String id = map['Id']?.toString() ?? '';

          // Name (Prioritaskan Contact Name -> Contact Real Name -> Contact Name unjoined -> Contact Number)
          final dynamic rawNameVal = map['Ct'] ??
              map['CtRealNm'] ??
              map['CtNm'] ??
              map['ContactName'] ??
              map['Name'] ??
              map['Title'];
          String rawName = (rawNameVal ?? '').toString().trim();
          if (rawName == 'null') rawName = '';
          final String name = rawName.isNotEmpty
              ? rawName
              : ((map['CtIdExt'] ?? map['ExtId'] ?? map['CtNo'])?.toString() ?? 'Tanpa Nama');

          // Subtitle / Group / Funnel / Channel Account
          final String? subtitle =
              (map['FnNm'] ?? map['GroupNm'] ?? map['ChAcc'])?.toString();

          // Last message
          String lastMsg = (map['LastMsg'] ?? map['Msg'] ?? map['Body'] ?? map['Category'] ?? '').toString().trim();
          if (lastMsg.isEmpty || lastMsg == 'null') {
            lastMsg = 'Percakapan kosong';
          }

          // Format waktu
          final String rawTime = (map['Up'] ?? map['In'] ?? '').toString();
          final String time = _formatTimestamp(rawTime);

          // Channel (Telegram / WhatsApp)
          final String chNm = (map['ChNm'] ?? map['Channel'] ?? '').toString();
          final String chId = map['ChId']?.toString() ?? '1';
          final String channel =
              (chId == '2' || chNm.toLowerCase().contains('telegram'))
                  ? 'Telegram'
                  : 'WhatsApp';

          // Assigned Agent
          final dynamic rawAgent = map['UsrNm'] ??
              map['AgentName'] ??
              map['ChAcc'] ??
              map['UserName'] ??
              'Belum Ditugaskan';
          final String assignedTo = rawAgent.toString();

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
          final String? groupIdStr =
              (grpId != null && grpId.toString() != '0' && grpId.toString() != 'null')
                  ? grpId.toString()
                  : null;
          final bool isGroup = groupIdStr != null ||
              name.toLowerCase().contains('grup') ||
              name.toLowerCase().contains('group');

          // LinkId (CtId di Serenity adalah IdLink / primary key dari tabel Link)
          final dynamic rawLinkId = map['CtId'] ??
              map['LinkId'] ??
              map['IdLink'] ??
              map['LkId'] ??
              map['Link'];
          final String? linkId = (rawLinkId != null &&
                  rawLinkId.toString() != '0' &&
                  rawLinkId.toString() != 'null' &&
                  rawLinkId.toString() != id)
              ? rawLinkId.toString()
              : null;

          // ExtId (Nomor HP / ID Eksternal / ID Telegram)
          final String? rawExt = (map['CtIdExt'] ??
                  map['ExtId'] ??
                  map['CtExtId'] ??
                  map['IdExt'] ??
                  map['CtNo'] ??
                  map['Phone'] ??
                  map['CtPhone'] ??
                  map['ContactNumber'] ??
                  map['Mobile'])
              ?.toString()
              .trim();
          final String extId = (rawExt != null && rawExt.isNotEmpty && rawExt != 'null')
              ? rawExt
              : (RegExp(r'^[0-9+ \-]+$').hasMatch(name.trim()) ? name.trim() : '');

          // AccountId
          final String? rawAcc = (map['ChAccId'] ??
                  map['AccId'] ??
                  map['AccountId'] ??
                  map['IdAccount'] ??
                  map['AccountIds'])
              ?.toString();
          final String? accountId = (rawAcc != null && rawAcc.isNotEmpty && rawAcc != 'null' && rawAcc != '0')
              ? rawAcc
              : (_channelAccountMap[chId] ?? _defaultAccountId ?? _tenantId);

          final chat = ChatConversation(
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
            extId: extId.isNotEmpty ? extId : null,
            accountId: accountId,
            groupId: groupIdStr,
            linkId: linkId,
          );
          if (id.isNotEmpty) {
            _roomCache[id] = chat;
          }
          return chat;
        }).whereType<ChatConversation>().toList();
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error fetching conversations: $e');
    }
    return [];
  }

  /// 2. Mengambil riwayat pesan di suatu room dari nobox.ai (Services/Chat/ChatMessages/List)
  Future<List<ChatMessageItem>> getMessages(String roomId, {String? extId}) async {
    if (!isLoggedIn) {
      return [];
    }

    try {
      final Uri uri = Uri.parse('${baseUrl}Services/Chat/ChatMessages/List');
      final int? numericRoomId =
          int.tryParse(roomId.replaceAll(RegExp(r'[^0-9]'), ''));

      final Map<String, dynamic> equalityFilter = {};
      if (numericRoomId != null) {
        equalityFilter['RoomId'] = numericRoomId;
      } else if (roomId.isNotEmpty && roomId != '0') {
        equalityFilter['RoomId'] = roomId;
      } else if (extId != null && extId.isNotEmpty) {
        equalityFilter['ExtId'] = extId;
      }

      final payload = {
        'Take': 50,
        'Skip': 0,
        'Sort': ['In DESC'],
        'ColumnSelection': 2,
        'IncludeColumns': [
          'Id',
          'RoomId',
          'Body',
          'Msg',
          'SdrMsg',
          'Sdr',
          'IsMe',
          'IsMeLast',
          'Out',
          'IsOut',
          'Outgoing',
          'Direction',
          'Direct',
          'MsgDirection',
          'SenderType',
          'SdrType',
          'In',
          'Up',
          'SenderName',
          'Ct',
        ],
        'EqualityFilter': equalityFilter,
      };

      final response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> items = [];
        if (data is List) {
          items = data;
        } else if (data is Map) {
          final dynamic raw =
              data['Entities'] ?? data['Data'] ?? data['Values'] ?? data['data'];
          if (raw is List) {
            items = raw;
          }
        }

        final List<ChatMessageItem> messages = items.map((json) {
          if (json is! Map) return null;
          final map = Map<String, dynamic>.from(json);

          final String msgId = map['Id']?.toString() ?? '';
          final String body = (map['Body'] ?? map['Msg'] ?? '').toString();
          final bool isMe = _determineIsMe(map, body);
          final String rawTime = (map['In'] ?? map['Up'] ?? '').toString();

          return ChatMessageItem(
            id: msgId,
            content: body,
            isMe: isMe,
            time: _formatTimeOnly(rawTime),
            senderName: map['SenderName']?.toString() ?? map['Ct']?.toString(),
          );
        }).whereType<ChatMessageItem>().toList();

        // Balikkan urutan agar pesan terbaru berada di bawah (kronologis natural obrolan)
        return messages.reversed.toList();
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error fetching messages: $e');
    }
    return [];
  }

  /// 3. Mengirim pesan dari NoBox Chat langsung ke nobox.ai (Inbox/Send)
  /// Sesuai spesifikasi resmi NoBox.ai REST API:
  /// - URL: POST https://id.nobox.ai/Inbox/Send?Id={RoomId}
  /// - Headers: Content-Type: application/json, Authorization: Bearer `AUTH_TOKEN`
  /// - Payload 1-on-1: Body, BodyType (1), ChannelId, AccountIds, Attachment (""), ExtId, LinkId
  /// - Payload Grup: Body, BodyType (1), ChannelId, AccountIds, Attachment (""), GroupId, GrpId
  Future<bool> sendMessage({
    required String roomId,
    required String content,
    String channelId = '1',
    String? accountId,
    String? extId,
    String? linkId,
    bool isGroup = false,
    String? groupId,
  }) async {
    if (!isLoggedIn) {
      _lastError = 'Belum masuk ke akun nobox.ai.';
      return false;
    }

    try {
      final String cleanRoomId = roomId.replaceAll(RegExp(r'[^0-9]'), '');
      final String targetRoomId = cleanRoomId.isNotEmpty ? cleanRoomId : roomId;
      final int chanId = int.tryParse(channelId) ?? 1;

      // Lookup room cache jika extId, linkId, atau accountId tidak lengkap
      final ChatConversation? cachedRoom = _roomCache[targetRoomId];

      // 1. Tentukan AccountId yang valid (wajib string tunggal, misal: "1557")
      String effectiveAccountId = (accountId != null &&
              accountId.isNotEmpty &&
              accountId != '0' &&
              accountId != 'null')
          ? accountId
          : (cachedRoom?.accountId ??
              _channelAccountMap[chanId.toString()] ??
              _defaultAccountId ??
              _tenantId ??
              '');

      if (effectiveAccountId.isEmpty) {
        await fetchAccounts();
        effectiveAccountId = cachedRoom?.accountId ??
            _channelAccountMap[chanId.toString()] ??
            _defaultAccountId ??
            _tenantId ??
            '';
      }

      // 2. Format ExtId penerima (Nomor HP internasional tanpa + / ID Telegram)
      String cleanExt = (extId ?? cachedRoom?.extId ?? '').trim();
      final String digitsOnly = cleanExt.replaceAll(RegExp(r'[^0-9]'), '');
      if (chanId == 1) {
        // WhatsApp: nomor HP internasional tanpa '+' (contoh: 6282338765517)
        if (digitsOnly.startsWith('08')) {
          cleanExt = '628${digitsOnly.substring(2)}';
        } else if (digitsOnly.startsWith('8')) {
          cleanExt = '62$digitsOnly';
        } else if (digitsOnly.isNotEmpty) {
          cleanExt = digitsOnly;
        }
      } else {
        // Telegram: ID numerik pengguna atau username tanpa @
        if (digitsOnly.isNotEmpty) {
          cleanExt = digitsOnly;
        } else {
          cleanExt = cleanExt.replaceAll('@', '');
        }
      }

      // 3. Tentukan LinkId numerik (Int64 / long pada Serenity C#)
      // LinkId HANYA dikirim jika merupakan CtId/LinkId yang valid dari Serenity.
      // JANGAN PERNAH menyamakan LinkId dengan targetRoomId karena akan menyebabkan
      // server gagal menemukan record Link dan memicu error "Id Link or Id External must have value".
      final String? rawLink = (linkId != null &&
              linkId.isNotEmpty &&
              linkId != '0' &&
              linkId != 'null' &&
              linkId != targetRoomId &&
              linkId != cleanRoomId)
          ? linkId
          : (cachedRoom?.linkId != null &&
                  cachedRoom!.linkId != targetRoomId &&
                  cachedRoom.linkId != cleanRoomId)
              ? cachedRoom.linkId
              : null;
      final String cleanLinkDigits =
          rawLink != null ? rawLink.replaceAll(RegExp(r'[^0-9]'), '') : '';
      final int? numericLinkId =
          cleanLinkDigits.isNotEmpty ? int.tryParse(cleanLinkDigits) : null;

      // 4. Validasi pra-pengiriman: pastikan minimal salah satu dari LinkId atau ExtId bernilai
      if ((numericLinkId == null || numericLinkId == 0) && cleanExt.isEmpty) {
        _lastError =
            'Id Link or Id External must have value. Pastikan kontak tujuan memiliki nomor telepon atau link percakapan yang valid.';
        return false;
      }

      // 5. URL resmi NoBox.ai REST API: POST https://id.nobox.ai/Inbox/Send?Id={RoomId}
      final Uri uri = Uri.parse('${baseUrl}Inbox/Send?Id=$targetRoomId');

      // 6. Payload JSON murni sesuai kontrak REST API NoBox.ai
      final Map<String, dynamic> payload = {
        'Body': content,
        'BodyType': 1,
        'ChannelId': chanId,
        'AccountIds': effectiveAccountId,
        'Attachment': '',
      };

      if (cleanExt.isNotEmpty) {
        payload['ExtId'] = cleanExt;
      }

      // Hanya sertakan LinkId jika valid dan BUKAN targetRoomId
      if (numericLinkId != null &&
          numericLinkId > 0 &&
          numericLinkId != int.tryParse(targetRoomId)) {
        payload['LinkId'] = numericLinkId;
      }

      if (isGroup || (groupId != null && groupId.isNotEmpty && groupId != '0')) {
        final dynamic effectiveGrpId =
            int.tryParse(groupId ?? '') ?? (groupId ?? cleanRoomId);
        payload['GroupId'] = effectiveGrpId;
        payload['GrpId'] = effectiveGrpId;
      }

      // Diagnostik forensik aman (tanpa kredensial dan dengan data sensitif tersamar)
      final String maskedExt = cleanExt.length > 4
          ? '${cleanExt.substring(0, 2)}***${cleanExt.substring(cleanExt.length - 2)}'
          : (cleanExt.isNotEmpty ? '***' : '(empty)');

      debugPrint('=== [FORENSIC: Inbox/Send Request] ===');
      debugPrint('URI: $uri');
      debugPrint('ChannelId: $chanId');
      debugPrint('AccountId present: ${effectiveAccountId.isNotEmpty}');
      debugPrint('ExtId: $maskedExt');
      debugPrint('LinkId: $numericLinkId');
      debugPrint('IsGroup: $isGroup, GroupId: $groupId');
      debugPrint('Payload Keys: ${payload.keys.toList()}');
      debugPrint('======================================');

      int attempts = 0;
      http.Response response = http.Response('', 500);
      bool isSuccess = false;

      while (attempts < 3) {
        attempts++;
        response = await http
            .post(
              uri,
              headers: _buildHeaders(),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        final String bodyLower = response.body.toLowerCase();
        final bool isRateLimit = response.statusCode == 429 ||
            bodyLower.contains('too many requests') ||
            bodyLower.contains('try again after');

        if (isRateLimit && attempts < 3) {
          final int waitMs = 1200 + (attempts * 500);
          debugPrint('NoboxApiService: Rate limited (attempt $attempts), waiting ${waitMs}ms...');
          await Future<void>.delayed(Duration(milliseconds: waitMs));
          continue;
        }

        debugPrint('=== [FORENSIC: Inbox/Send Response (Attempt $attempts)] ===');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('=======================================');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final dynamic data = jsonDecode(response.body);
            if (data is Map) {
              final dynamic err = data['Error'] ?? data['error'];
              if (err != null &&
                  err.toString().isNotEmpty &&
                  err.toString() != 'null') {
                _lastError = err is Map
                    ? (err['Message']?.toString() ?? err.toString())
                    : err.toString();
                isSuccess = false;
              } else if (data['IsError'] == true) {
                _lastError = data['Message']?.toString() ??
                    data['Error']?.toString() ??
                    'Gagal mengirim pesan';
                isSuccess = false;
              } else {
                final String dataStr = (data['Data'] ?? '').toString();
                if (dataStr.contains('Total Sent=0') && attempts < 3) {
                  debugPrint('NoboxApiService: Total Sent=0, retrying after 1500ms...');
                  await Future<void>.delayed(const Duration(milliseconds: 1500));
                  continue;
                }
                isSuccess = true;
                _lastError = null;
              }
            } else {
              isSuccess = true;
              _lastError = null;
            }
          } catch (_) {
            isSuccess = true;
            _lastError = null;
          }
        } else {
          if (attempts < 3) {
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            continue;
          }
          _lastError = 'Gagal mengirim pesan (HTTP ${response.statusCode})';
        }

        break;
      }

      if (isSuccess) {
        recordSentMessage(content);
      }

      return isSuccess;
    } catch (e) {
      _lastError = 'Kendala pengiriman: $e';
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
