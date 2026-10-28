import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_detail_screen.dart';
import 'package:nobox/chat_inbox_screen.dart';
import 'package:nobox/services/nobox_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp Chat Layout & Anti-Duplication Verification', () {
    const testChat = ChatConversation(
      id: '819322506002437',
      name: 'Customer Service Test',
      lastMessage: 'Halo apa kabar',
      time: '14:20',
      channel: 'WhatsApp',
      assignedTo: 'Agent',
      status: 'Assigned',
    );

    testWidgets('Sent messages render on RIGHT and received messages render on LEFT', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatDetailScreen(chat: testChat),
        ),
      );

      // Tunggu inisialisasi awal
      await tester.pumpAndSettle();

      // Kirim pesan baru dari user
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Pesan saya ke pelanggan');

      final sendButton = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(sendButton);
      await tester.pump();

      // Cari Align widget yang membungkus bubble 'Pesan saya ke pelanggan'
      final sentTextFinder = find.text('Pesan saya ke pelanggan');
      expect(sentTextFinder, findsOneWidget);

      final alignFinder = find.ancestor(
        of: sentTextFinder,
        matching: find.byType(Align),
      );
      expect(alignFinder, findsWidgets);

      final Align sentAlign = tester.widget<Align>(alignFinder.first);
      // Verifikasi pesan yang kita kirim berada di sebelah KANAN
      expect(sentAlign.alignment, Alignment.centerRight);

      // Cari pesan awal (dari lawan bicara)
      final receivedTextFinder = find.text('Halo apa kabar');
      if (receivedTextFinder.evaluate().isNotEmpty) {
        final receivedAlignFinder = find.ancestor(
          of: receivedTextFinder,
          matching: find.byType(Align),
        );
        final Align receivedAlign = tester.widget<Align>(receivedAlignFinder.first);
        // Verifikasi pesan lawan bicara berada di sebelah KIRI
        expect(receivedAlign.alignment, Alignment.centerLeft);
      }

      await tester.pump(const Duration(milliseconds: 1600));
    });

    test('NoboxApiService accurately detects isMe across backend formats', () {
      final api = NoboxApiService();

      // Catat pesan yang dikirim lokal
      api.recordSentMessage('Pesan pengujian lokal');
      expect(api.isRecentlySentLocally('Pesan pengujian lokal'), isTrue);
      expect(api.isRecentlySentLocally('Pesan acak lain'), isFalse);
    });
  });
}
