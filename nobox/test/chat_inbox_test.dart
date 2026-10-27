import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_inbox_screen.dart';

void main() {
  testWidgets('ChatInboxScreen renders empty state by default and opens dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatInboxScreen(),
      ),
    );

    // Verifikasi Header NoBox Chat
    expect(find.text('NoBox'), findsOneWidget);
    expect(find.text('Belum Ada Percakapan'), findsOneWidget);

    // Verifikasi FAB menggunakan ikon '+'
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // Tap tombol '+' (FAB)
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // Verifikasi Form 'New Conversation' terbuka
    expect(find.text('New Conversation'), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Tap 'Cancel' untuk menutup dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('New Conversation'), findsNothing);
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
