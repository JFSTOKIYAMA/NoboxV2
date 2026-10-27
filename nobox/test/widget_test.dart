import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nobox/loading_screen.dart';
import 'package:nobox/main.dart';

void main() {
  testWidgets('LoadingScreen renders and transitions smoke test', (WidgetTester tester) async {
    // Build LoadingScreen
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingScreen(
          destination: MyHomePage(title: 'Nobox Workspace'),
          duration: Duration(milliseconds: 500),
        ),
      ),
    );

    // Verifikasi teks 'Loading' dan brand 'NO' / 'BOX' ada
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);
    expect(find.text('BOX'), findsOneWidget);

    // Lewati waktu animasi loading hingga selesai dan navigasi ke MyHomePage
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verifikasi counter di MyHomePage
    expect(find.text('0'), findsOneWidget);

    // Tekan tombol '+'
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verifikasi counter bertambah menjadi 1
    expect(find.text('1'), findsOneWidget);
  });
}
