import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/core/money.dart';

void main() {
  test(
    'parses decimal values into cents without floating point arithmetic',
    () {
      expect(parseMoneyToCents('12,5'), 1250);
      expect(parseMoneyToCents('12.05'), 1205);
      expect(parseMoneyToCents('0'), 0);
      expect(parseMoneyToCents('1.999'), isNull);
      expect(parseMoneyToCents(''), isNull);
      expect(parseMoneyToCents('-1'), isNull);
    },
  );

  test('formats cents using a fixed two-digit fraction', () {
    expect(formatMoneyCents(1205), '12,05');
    expect(formatMoneyCents(0), '0,00');
  });
}
