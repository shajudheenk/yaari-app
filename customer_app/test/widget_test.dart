import 'package:flutter_test/flutter_test.dart';
import 'package:yaari_ui/yaari_ui.dart';

void main() {
  group('price formatting', () {
    test('whole pounds drop the decimals', () {
      expect(formatPence(3500), '£35');
      expect(formatPence(12000), '£120');
    });

    test('part pounds keep two decimals', () {
      expect(formatPence(4550), '£45.50');
      expect(formatPence(99), '£0.99');
    });

    test('hourly rates are marked, job rates are not', () {
      expect(formatRate(3500, 'hour'), '£35/hr');
      expect(formatRate(12000, 'job'), '£120');
    });
  });

  group('distance formatting', () {
    test('converts metres to miles for a UK audience', () {
      expect(formatDistance(1609.34), '1.0 mi');
      expect(formatDistance(4023.35), '2.5 mi');
    });

    test('very short distances read as nearby rather than 0.0 mi', () {
      expect(formatDistance(50), 'nearby');
    });
  });
}
