import 'package:flutter_test/flutter_test.dart';
import 'package:nobox/services/nobox_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NoboxApiService sendMessage validation tests', () {
    final apiService = NoboxApiService();

    test('sendMessage returns false with descriptive error when user is not logged in', () async {
      final result = await apiService.sendMessage(
        roomId: '12345',
        content: 'Halo',
      );
      expect(result, isFalse);
      expect(apiService.lastError, contains('Belum masuk'));
    });

    test('Pre-flight validation catches missing LinkId and ExtId', () async {
      await apiService.setSessionToken('dummy_token_for_unit_test');
      
      final result = await apiService.sendMessage(
        roomId: '',
        content: 'Halo',
        linkId: '0',
        extId: '',
      );

      expect(result, isFalse);
      expect(apiService.lastError, contains('Id Link or Id External must have value'));
      
      await apiService.logout();
    });
  });
}
