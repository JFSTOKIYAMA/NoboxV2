import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/chat_inbox_screen.dart';
import 'package:nobox/services/app_theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dark/Light Theme Toggle Tests', () {
    test('AppThemeController toggles correctly and retains state', () {
      final controller = AppThemeController.instance;
      controller.setDarkMode(true);
      expect(controller.isDarkMode, isTrue);

      controller.toggleTheme();
      expect(controller.isDarkMode, isFalse);

      controller.toggleTheme();
      expect(controller.isDarkMode, isTrue);
    });

    testWidgets('Tapping theme toggle in 3-dots menu of ChatInboxScreen switches theme', (WidgetTester tester) async {
      final controller = AppThemeController.instance;
      controller.setDarkMode(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatInboxScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Buka menu titik tiga
      final moreButtonFinder = find.byIcon(Icons.more_vert_rounded);
      expect(moreButtonFinder, findsOneWidget);
      await tester.tap(moreButtonFinder);
      await tester.pumpAndSettle();

      // Pastikan opsi 'Mode Terang' dan 'Keluar Akun' ada di menu
      final lightModeOptionFinder = find.text('Mode Terang');
      expect(lightModeOptionFinder, findsOneWidget);
      expect(find.text('Keluar Akun'), findsOneWidget);

      // Tap opsi 'Mode Terang'
      await tester.tap(lightModeOptionFinder);
      await tester.pumpAndSettle();

      // Sekarang mode terang aktif
      expect(controller.isDarkMode, isFalse);

      // Buka kembali menu titik tiga di mode terang
      await tester.tap(moreButtonFinder);
      await tester.pumpAndSettle();

      // Pastikan opsi 'Mode Gelap' tampil
      final darkModeOptionFinder = find.text('Mode Gelap');
      expect(darkModeOptionFinder, findsOneWidget);

      // Tap opsi 'Mode Gelap'
      await tester.tap(darkModeOptionFinder);
      await tester.pumpAndSettle();

      // Kembali ke mode gelap
      expect(controller.isDarkMode, isTrue);
    });
  });
}
