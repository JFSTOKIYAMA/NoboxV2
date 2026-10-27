import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_inbox_screen.dart';

void main() {
  testWidgets('ChatInboxScreen renders empty state by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatInboxScreen(),
      ),
    );

    // Verifikasi Header NoBox Chat
    expect(find.text('NoBox'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);

    // Verifikasi Empty State
    expect(find.text('Belum Ada Percakapan'), findsOneWidget);
  });

  testWidgets('ChatInboxScreen renders populated conversations when provided', (WidgetTester tester) async {
    const List<ChatConversation> testConversations = [
      ChatConversation(
        id: '1',
        name: 'MENUJU SUKSES',
        lastMessage: 'Halo tim',
        time: '11:16',
        channel: 'Telegram',
        assignedTo: 'Awas',
        status: 'Assigned',
      ),
      ChatConversation(
        id: '2',
        name: 'Budi Santoso',
        lastMessage: 'Review akun',
        time: '12:00',
        channel: 'WhatsApp',
        assignedTo: 'Fawwas',
        status: 'Unassigned',
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatInboxScreen(
          initialConversations: testConversations,
        ),
      ),
    );

    // Verifikasi item obrolan
    expect(find.text('MENUJU SUKSES'), findsOneWidget);

    // Tap tab 'Unassigned'
    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();

    // Verifikasi item obrolan Unassigned tampil
    expect(find.text('Budi Santoso'), findsOneWidget);
  });
}
