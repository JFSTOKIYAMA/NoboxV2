import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_inbox_screen.dart';
import 'package:nobox/login_screen.dart';
import 'package:nobox/main.dart';
import 'package:nobox/services/nobox_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Persistence & Auto-Login Tests', () {
    final apiService = NoboxApiService();

    tearDown(() async {
      await apiService.logout();
    });

    testWidgets('App opens ChatInboxScreen directly when user has active session (not logged out)',
        (WidgetTester tester) async {
      // 1. Simulasikan pengguna yang sudah login sebelumnya
      await apiService.setSessionToken('active_session_token_xyz', username: 'agen_sukses');
      expect(apiService.isLoggedIn, isTrue);

      // 2. Jalankan aplikasi seperti saat pengguna baru membuka aplikasi
      await tester.pumpWidget(const MyApp());

      // 3. Verifikasi LoadingScreen tampil terlebih dahulu
      expect(find.text('Loading'), findsOneWidget);

      // 4. Selesaikan durasi loading screen (3200ms) dan transisi fade
      await tester.pump(const Duration(milliseconds: 3800));
      await tester.pump(const Duration(milliseconds: 700));

      // 5. Pastikan aplikasi langsung masuk ke ChatInboxScreen tanpa meminta login
      expect(find.byType(ChatInboxScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);

      // Bersihkan widget tree agar timer periodik ditutup rapi
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('App opens LoginScreen when user has logged out',
        (WidgetTester tester) async {
      // 1. Pastikan pengguna dalam kondisi logout
      await apiService.logout();
      expect(apiService.isLoggedIn, isFalse);

      // 2. Buka aplikasi
      await tester.pumpWidget(const MyApp());

      // 3. Selesaikan durasi loading screen
      await tester.pump(const Duration(milliseconds: 3800));
      await tester.pump(const Duration(milliseconds: 700));

      // 4. Pastikan aplikasi masuk ke LoginScreen karena belum/sudah logout
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ChatInboxScreen), findsNothing);

      // Bersihkan widget tree
      await tester.pumpWidget(const SizedBox());
    });
  });
}
