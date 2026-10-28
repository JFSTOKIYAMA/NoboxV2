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

    testWidgets('Tapping theme toggle button in ChatInboxScreen switches theme', (WidgetTester tester) async {
      final controller = AppThemeController.instance;
      controller.setDarkMode(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatInboxScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Saat dark mode aktif, icon bulan (dark_mode_rounded) tampil sesuai temanya
      final darkModeIconFinder = find.byIcon(Icons.dark_mode_rounded);
      expect(darkModeIconFinder, findsOneWidget);

      // Tap tombol toggle
      await tester.tap(darkModeIconFinder);
      await tester.pumpAndSettle();

      // Setelah di-tap, sekarang mode terang, icon matahari (light_mode_rounded) tampil sesuai temanya
      expect(controller.isDarkMode, isFalse);
      final lightModeIconFinder = find.byIcon(Icons.light_mode_rounded);
      expect(lightModeIconFinder, findsOneWidget);

      // Kembalikan ke mode gelap
      await tester.tap(lightModeIconFinder);
      await tester.pumpAndSettle();
      expect(controller.isDarkMode, isTrue);
    });
  });
}
