import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/core/money.dart';

void main() {
  test(
    'converts decimal values to cents without floating point arithmetic',
    () {
      expect(parseMoneyToCents('12,5'), 1250);
      expect(parseMoneyToCents('12.05'), 1205);
      expect(parseMoneyToCents('0'), 0);
      expect(parseMoneyToCents('1.234'), isNull);
      expect(parseMoneyToCents('1.999'), isNull);
      expect(parseMoneyToCents(''), isNull);
      expect(parseMoneyToCents('-1'), isNull);
    },
  );
}
