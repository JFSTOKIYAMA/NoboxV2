import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_detail_screen.dart';
import 'package:nobox/chat_inbox_screen.dart';

void main() {
  testWidgets('ChatDetailScreen renders chat header and sends message', (WidgetTester tester) async {
    const testChat = ChatConversation(
      id: '829684391338053',
      name: 'MENUJU SUKSES',
      subtitle: 'SMKN 1 Pasuruan',
      lastMessage: 'Halo',
      time: '11:16',
      channel: 'Telegram',
      assignedTo: 'Awas',
      status: 'Assigned',
    );

    String? sentMessage;

    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailScreen(
          chat: testChat,
          onMessageSent: (msg) {
            sentMessage = msg;
          },
        ),
      ),
    );

    // Verifikasi Header
    expect(find.text('MENUJU SUKSES'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('nobox.ai sync'), findsOneWidget);

    // Ketik pesan pada input bar
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);
    await tester.enterText(inputFinder, 'Pesan uji coba NoBox AI');

    // Tekan tombol kirim
    final sendButton = find.byIcon(Icons.arrow_upward_rounded);
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pump();

    // Verifikasi callback pengiriman terpanggil
    expect(sentMessage, 'Pesan uji coba NoBox AI');
    expect(find.text('Pesan uji coba NoBox AI'), findsOneWidget);
  });
}
