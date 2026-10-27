import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_inbox_screen.dart';

void main() {
  testWidgets('ChatInboxScreen renders conversations and filters tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatInboxScreen(),
      ),
    );

    // Verifikasi Header NoBox Chat
    expect(find.text('NoBox'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);

    // Verifikasi item obrolan
    expect(find.text('MENUJU SUKSES'), findsOneWidget);
    expect(find.text('TORNADO 🌪️'), findsOneWidget);

    // Tap tab 'Unassigned'
    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();

    // Verifikasi item obrolan Unassigned tampil
    expect(find.text('Budi Santoso'), findsOneWidget);
  });
}
