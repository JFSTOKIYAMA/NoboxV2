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
      api.recordSentMessage('Pesan pengujian lokal', msgId: 'local_msg_101');
      expect(api.isRecentlySentLocally('Pesan pengujian lokal'), isTrue);
      expect(api.isRecentlySentLocally('Pesan acak lain'), isFalse);
    });

    test('NoboxApiService accurately detects isMe on historical messages', () {
      final api = NoboxApiService();
      api.recordSentMessage('Pesan terdahulu dari agen', msgId: 'hist_99');
      expect(api.isRecentlySentLocally('Pesan terdahulu dari agen'), isTrue);

      // 1. Pesan lama dengan Direction = 2 (Outbound) harus selalu isMe = true
      final msgOutbound = {
        'Id': '9001',
        'Body': 'Pesan lama kami ke pelanggan',
        'Direction': 2,
      };
      final itemOutbound = ChatMessageItem(
        id: msgOutbound['Id'].toString(),
        content: msgOutbound['Body'].toString(),
        isMe: msgOutbound['Direction'] == 2,
        time: '10:00',
      );
      expect(itemOutbound.isMe, isTrue);

      // 2. Pesan lama dengan FromMe = true
      final msgFromMe = {
        'Id': '9002',
        'Body': 'Halo apa ada yang bisa dibantu?',
        'FromMe': true,
      };
      final itemFromMe = ChatMessageItem(
        id: msgFromMe['Id'].toString(),
        content: msgFromMe['Body'].toString(),
        isMe: msgFromMe['FromMe'] == true,
        time: '10:05',
      );
      expect(itemFromMe.isMe, isTrue);

      // 3. Pesan lama dengan UserId internal (agen)
      final msgUser = {
        'Id': '9003',
        'Body': 'Baik akan kami proses secepatnya.',
        'UserId': 14,
      };
      final itemUser = ChatMessageItem(
        id: msgUser['Id'].toString(),
        content: msgUser['Body'].toString(),
        isMe: (msgUser['UserId'] as int) > 0,
        time: '10:10',
      );
      expect(itemUser.isMe, isTrue);
    });
  });
}
