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

  bool get isLoggedIn => _isLoggedIn && _token != null && _token!.isNotEmpty;
  String? get currentUsername => _currentUsername;
  String? get token => _token;
  String? get lastError => _lastError;
  String? get tenantId => _tenantId;
  String? get defaultAccountId => _defaultAccountId;

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
  Future<void> init() async {
    try {
      _token = await AppPreferences.getString(_tokenPrefKey);
      _currentUsername = await AppPreferences.getString(_usernamePrefKey);
      _tenantId = await AppPreferences.getString(_tenantIdPrefKey);
      _defaultAccountId = await AppPreferences.getString(_defaultAccountIdPrefKey);
      if (_token != null && _token!.isNotEmpty) {
        _isLoggedIn = true;
        await fetchAccounts();
      }
    } catch (e) {
      debugPrint('NoboxApiService: Error initializing: $e');
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
          final String channel =
              (chId == '2' || chNm.toLowerCase().contains('telegram'))
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
          final String? groupIdStr =
              (grpId != null && grpId.toString() != '0' && grpId.toString() != 'null')
                  ? grpId.toString()
                  : null;
          final bool isGroup = groupIdStr != null ||
              name.toLowerCase().contains('grup') ||
              name.toLowerCase().contains('group');

          // ExtId (Nomor HP/ID Telegram)
          final String? rawExt = (map['CtIdExt'] ??
                  map['ExtId'] ??
                  map['CtExtId'] ??
                  map['IdExt'] ??
                  map['Ct'] ??
                  map['CtNo'] ??
                  map['Phone'] ??
                  map['CtPhone'] ??
                  map['CtId'])
              ?.toString();
          final String extId = (rawExt != null && rawExt.isNotEmpty && rawExt != 'null')
              ? rawExt
              : name;

          // AccountId
          final String? rawAcc = (map['AccId'] ??
                  map['AccountId'] ??
                  map['IdAccount'] ??
                  map['AccountIds'])
              ?.toString();
          final String? accountId = (rawAcc != null && rawAcc.isNotEmpty && rawAcc != 'null' && rawAcc != '0')
              ? rawAcc
              : (_channelAccountMap[chId] ?? _defaultAccountId ?? _tenantId);

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
            extId: extId,
            accountId: accountId,
            groupId: groupIdStr,
          );
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
        'Sort': ['In ASC'],
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

        return items.map((json) {
          if (json is! Map) return null;
          final map = Map<String, dynamic>.from(json);

          final String msgId = map['Id']?.toString() ?? '';
          final String body = (map['Body'] ?? map['Msg'] ?? '').toString();
          final String sdr =
              (map['SdrMsg'] ?? map['Sdr'] ?? '').toString().toLowerCase();
          final bool isMe =
              sdr == 'me' || map['IsMe'] == true || map['IsMeLast'] == true;
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

      // 1. Tentukan AccountId yang valid (wajib string tunggal, misal: "1557")
      String effectiveAccountId = (accountId != null &&
              accountId.isNotEmpty &&
              accountId != '0' &&
              accountId != 'null')
          ? accountId
          : (_channelAccountMap[chanId.toString()] ??
              _defaultAccountId ??
              _tenantId ??
              '');

      if (effectiveAccountId.isEmpty) {
        await fetchAccounts();
        effectiveAccountId = _channelAccountMap[chanId.toString()] ??
            _defaultAccountId ??
            _tenantId ??
            '';
      }

      // 2. Format ExtId: nomor HP internasional tanpa + (misal 6282338765517) atau ID Telegram
      String cleanExt = (extId ?? '').trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanExt.startsWith('08')) {
        cleanExt = '628${cleanExt.substring(2)}';
      }
      if (cleanExt.isEmpty) {
        cleanExt = cleanRoomId;
      }

      final int? numericLinkId = int.tryParse(targetRoomId);

      // 3. URL resmi Serenity: menyertakan Id, IdLink, LinkId, IdExternal, ExtId pada query params
      final Map<String, String> queryParams = {
        'Id': targetRoomId,
        'IdLink': targetRoomId,
        'idLink': targetRoomId,
        'LinkId': targetRoomId,
      };
      if (cleanExt.isNotEmpty) {
        queryParams['IdExternal'] = cleanExt;
        queryParams['idExternal'] = cleanExt;
        queryParams['ExtId'] = cleanExt;
        queryParams['extId'] = cleanExt;
      }
      final Uri uri =
          Uri.parse('${baseUrl}Inbox/Send').replace(queryParameters: queryParams);

      // 4. Payload sesuai spesifikasi resmi NoBox.ai
      final Map<String, dynamic> payload = {
        'Body': content,
        'BodyType': 1,
        'ChannelId': chanId,
        'AccountIds': effectiveAccountId,
        'Attachment': '',
        'ExtId': cleanExt.isNotEmpty ? cleanExt : targetRoomId,
        'LinkId': numericLinkId ?? targetRoomId,
      };

      if (isGroup || (groupId != null && groupId.isNotEmpty && groupId != '0')) {
        final dynamic effectiveGrpId =
            int.tryParse(groupId ?? '') ?? (groupId ?? cleanRoomId);
        payload['GroupId'] = effectiveGrpId;
        payload['GrpId'] = effectiveGrpId;
      }

      debugPrint(
        'NoboxApiService: Sending message to $uri with payload: ${jsonEncode(payload)}',
      );

      http.Response response = await http
          .post(
            uri,
            headers: _buildHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'NoboxApiService: sendMessage response code: ${response.statusCode}, body: ${response.body}',
      );

      // Jika server menolak JSON karena mengharapkan parameter Form-URL-Encoded
      if (response.body.contains('Id Link or Id External')) {
        debugPrint('NoboxApiService: Retrying with Form-URL-Encoded format...');
        final Map<String, String> formPayload = {
          'Id': targetRoomId,
          'IdLink': targetRoomId,
          'idLink': targetRoomId,
          'LinkId': targetRoomId,
          'linkId': targetRoomId,
          'IdExternal': cleanExt,
          'idExternal': cleanExt,
          'ExtId': cleanExt,
          'extId': cleanExt,
          'Body': content,
          'body': content,
          'BodyType': '1',
          'bodyType': '1',
          'ChannelId': chanId.toString(),
          'channelId': chanId.toString(),
          'AccountIds': effectiveAccountId,
          'accountId': effectiveAccountId,
          'Attachment': '',
        };
        if (isGroup || (groupId != null && groupId.isNotEmpty && groupId != '0')) {
          final String grpStr = groupId ?? cleanRoomId;
          formPayload['GroupId'] = grpStr;
          formPayload['GrpId'] = grpStr;
        }

        final Map<String, String> formHeaders = Map<String, String>.from(_buildHeaders())
          ..['Content-Type'] = 'application/x-www-form-urlencoded';

        response = await http
            .post(
              uri,
              headers: formHeaders,
              body: formPayload,
            )
            .timeout(const Duration(seconds: 15));

        debugPrint(
          'NoboxApiService: Form-URL-Encoded response code: ${response.statusCode}, body: ${response.body}',
        );
      }

      bool isSuccess = false;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final dynamic data = jsonDecode(response.body);
          if (data is Map) {
            final dynamic err = data['Error'] ?? data['error'];
            if (err != null &&
                err.toString().isNotEmpty &&
                err.toString() != 'null') {
              _lastError = err is Map ? (err['Message']?.toString() ?? err.toString()) : err.toString();
              isSuccess = false;
            } else if (data['IsError'] == true) {
              _lastError = data['Message']?.toString() ??
                  data['Error']?.toString() ??
                  'Gagal mengirim pesan';
              isSuccess = false;
            } else {
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
        try {
          final dynamic data = jsonDecode(response.body);
          if (data is Map) {
            final dynamic err = data['Error'] ?? data['error'];
            if (err != null &&
                err.toString().isNotEmpty &&
                err.toString() != 'null') {
              _lastError = err is Map ? (err['Message']?.toString() ?? err.toString()) : err.toString();
            } else if (data['Message'] != null) {
              _lastError = data['Message'].toString();
            } else {
              _lastError = 'Gagal mengirim pesan (HTTP ${response.statusCode})';
            }
          } else {
            _lastError = 'Gagal mengirim pesan (HTTP ${response.statusCode})';
          }
        } catch (_) {
          _lastError = 'Gagal mengirim pesan (HTTP ${response.statusCode})';
        }
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
