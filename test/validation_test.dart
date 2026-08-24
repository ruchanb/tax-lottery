import 'package:flutter_test/flutter_test.dart';
import 'package:kar_upahar/src/domain/validation.dart';

void main() {
  group('bill validation', () {
    test('requires a nine digit seller PAN', () {
      expect(validatePan('123456789'), isNull);
      expect(validatePan('1234'), isNotNull);
      expect(validatePan('12345678x'), isNotNull);
    });

    test('requires an amount strictly greater than Rs 100', () {
      expect(validateAmount('100'), isNotNull);
      expect(validateAmount('100.01'), isNull);
      expect(validateAmount('1,250'), isNull);
    });

    test('accepts Nepal mobile prefixes', () {
      expect(validateNepalMobile('9812345678'), isNull);
      expect(validateNepalMobile('+977 9812345678'), isNull);
      expect(validateNepalMobile('9612345678'), isNotNull);
    });
  });

  test('calculates fortnightly draw dates', () {
    expect(nextDrawDate(DateTime(2026, 8, 15)), DateTime(2026, 8, 16));
    expect(nextDrawDate(DateTime(2026, 8, 16)), DateTime(2026, 9, 1));
    expect(nextDrawDate(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
  });
}
