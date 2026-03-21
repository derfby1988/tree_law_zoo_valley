import 'package:flutter_test/flutter_test.dart';

import 'package:tree_law_zoo_valley/main.dart';

void main() {
  group('Auth input validation', () {
    test('isValidEmailOrPhone accepts valid values', () {
      expect(isValidEmailOrPhone('test@example.com'), isTrue);
      expect(isValidEmailOrPhone('0812345678'), isTrue);
    });

    test('validateEmailOrPhone rejects invalid values', () {
      expect(validateEmailOrPhone(''), isNotNull);
      expect(validateEmailOrPhone('bad-format'), isNotNull);
    });

    test('validateEmailOrPhone returns null for valid values', () {
      expect(validateEmailOrPhone('hello@treezoo.app'), isNull);
      expect(validateEmailOrPhone('0891234567'), isNull);
    });
  });
}
