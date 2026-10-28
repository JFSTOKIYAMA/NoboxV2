import 'package:flutter/material.dart';
import 'chat_inbox_screen.dart';
import 'services/app_theme_controller.dart';

/// Dialog "New Conversation" sesuai rancangan form dengan pendekatan Anti-AI Slop:
/// Modern, presisi, interaktif, dan rapi.
class NewConversationDialog extends StatefulWidget {
  final ValueChanged<ChatConversation>? onCreated;

  const NewConversationDialog({super.key, this.onCreated});

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  String _selectedChatType = 'Private';
  String _selectedChannel = '--select--';
  String _selectedAccount = '--select--';
  String _toType = 'Contact'; // 'Contact', 'Link', 'Manual'
  String _selectedContact = '--select--';

  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _linkInputController = TextEditingController();

  final List<String> _chatTypes = const ['Private', 'Group'];
  final List<String> _channels = const ['--select--', 'Telegram', 'WhatsApp'];
  final List<String> _accounts = const ['--select--', 'Awas', 'Fawwas'];
  final List<String> _contacts = const [
    '--select--',
    'Juhri - SMKN 1 PASURUAN',
    'Ordi / Jordy - SMKN 11 Malang',
    'Yasmin - SMKN 11 Malang',
    'Harits - SMKN 1 PASURUAN',
    'I\'zas - SMKN 1 Pasuruan',
  ];

  @override
  void dispose() {
    _manualInputController.dispose();
    _linkInputController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedChannel == '--select--' || _selectedAccount == '--select--') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan pilih Channel dan Account terlebih dahulu'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    String contactName = 'Percakapan Baru';
    String? extId;
    String? linkId;
    if (_toType == 'Contact' && _selectedContact != '--select--') {
      contactName = _selectedContact.split(' - ').first;
    } else if (_toType == 'Manual' && _manualInputController.text.trim().isNotEmpty) {
      contactName = _manualInputController.text.trim();
      extId = _manualInputController.text.trim();
    } else if (_toType == 'Link' && _linkInputController.text.trim().isNotEmpty) {
      contactName = 'Link Kontak';
      linkId = _linkInputController.text.trim();
    }

    final ChatConversation newChat = ChatConversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: contactName,
      subtitle: _selectedContact.contains(' - ')
          ? _selectedContact.split(' - ').last
          : 'Baru dibuat',
      lastMessage: 'Percakapan dimulai',
      time: 'Baru saja',
      channel: _selectedChannel,
      assignedTo: _selectedAccount,
      status: 'Assigned',
      isGroup: _selectedChatType == 'Group',
      extId: extId,
      accountId: _selectedAccount != '--select--' ? _selectedAccount : null,
      linkId: linkId,
    );

    widget.onCreated?.call(newChat);
    Navigator.of(context).pop(newChat);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppThemeController.instance.isDarkMode;
    const Color brandPrimary = Color(0xFF0066FF);
    final Color surfaceBg =
        isDark ? const Color(0xFF111726) : Colors.white;
    final Color inputBg =
        isDark ? const Color(0xFF161F33) : const Color(0xFFF8FAFC);
    final Color borderColor =
        isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0);
    final Color textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final Color labelColor =
        isDark ? Colors.white : const Color(0xFF334155);
    final Color hintColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF94A3B8);
    final Color closeIconColor =
        isDark ? Colors.white60 : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : const Color(0xFFE2E8F0),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Title "New Conversation" & Close 'X'
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'New Conversation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: brandPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: closeIconColor,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 1. Row: Chat
              _buildFormRow(
                label: 'Chat',
                labelColor: labelColor,
                child: _buildDropdown(
                  value: _selectedChatType,
                  items: _chatTypes,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedChatType = val);
                  },
                  inputBg: inputBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 18),

              // 2. Row: Channel
              _buildFormRow(
                label: 'Channel',
                labelColor: labelColor,
                child: _buildDropdown(
                  value: _selectedChannel,
                  items: _channels,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedChannel = val);
                  },
                  inputBg: inputBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 18),

              // 3. Row: Account
              _buildFormRow(
                label: 'Account',
                labelColor: labelColor,
                child: _buildDropdown(
                  value: _selectedAccount,
                  items: _accounts,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccount = val);
                  },
                  inputBg: inputBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  isDark: isDark,
                ),
              ),

              const SizedBox(height: 18),

              // 4. Row: To (Radio Group)
              _buildFormRow(
                label: 'To',
                labelColor: labelColor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildRadioOption('Contact', isDark),
                          const SizedBox(width: 16),
                          _buildRadioOption('Link', isDark),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildRadioOption('Manual', isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 5. Row: Contact (or dynamic input based on To selection)
              if (_toType == 'Contact')
                _buildFormRow(
                  label: 'Contact',
                  labelColor: labelColor,
                  child: _buildDropdown(
                    value: _selectedContact,
                    items: _contacts,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedContact = val);
                    },
                    inputBg: inputBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                )
              else if (_toType == 'Link')
                _buildFormRow(
                  label: 'Link',
                  labelColor: labelColor,
                  child: TextField(
                    controller: _linkInputController,
                    style: TextStyle(color: textColor, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'https://t.me/... atau wa.me/...',
                      hintStyle: TextStyle(
                        color: hintColor,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: brandPrimary, width: 1.5),
                      ),
                    ),
                  ),
                )
              else
                _buildFormRow(
                  label: 'Manual',
                  labelColor: labelColor,
                  child: TextField(
                    controller: _manualInputController,
                    style: TextStyle(color: textColor, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Nomor telepon atau username',
                      hintStyle: TextStyle(
                        color: hintColor,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: brandPrimary, width: 1.5),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              // 6. Action Buttons: Cancel (Outlined) & Create (Filled)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? brandPrimary : const Color(0xFF475569),
                        side: BorderSide(
                          color: isDark ? brandPrimary : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: brandPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required Widget child,
    required Color labelColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Color inputBg,
    required Color borderColor,
    required Color textColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF161F33) : Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            size: 22,
          ),
          style: TextStyle(
            color: textColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: item == '--select--'
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : const Color(0xFF94A3B8))
                      : textColor,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRadioOption(String title, bool isDark) {
    const Color brandPrimary = Color(0xFF0066FF);
    final bool isSelected = _toType == title;

    return InkWell(
      onTap: () {
        setState(() {
          _toType = title;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? brandPrimary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : const Color(0xFFCBD5E1)),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
