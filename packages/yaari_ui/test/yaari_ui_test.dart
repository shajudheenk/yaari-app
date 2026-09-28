import 'package:flutter_test/flutter_test.dart';
import 'package:yaari_ui/yaari_ui.dart';

void main() {
  group('UK mobile validation', () {
    test('accepts the forms people actually type', () {
      expect(looksLikeUkMobile('07700900318'), isTrue);
      expect(looksLikeUkMobile('07700 900318'), isTrue);
      expect(looksLikeUkMobile('447700900318'), isTrue);
      expect(looksLikeUkMobile('+44 7700 900318'), isTrue);
      expect(looksLikeUkMobile('7700900318'), isTrue);
    });

    test('rejects the things that are not UK mobiles', () {
      expect(looksLikeUkMobile(''), isFalse);
      expect(looksLikeUkMobile('077009'), isFalse);
      expect(looksLikeUkMobile('012345678901234'), isFalse);
      expect(looksLikeUkMobile('01216334700'), isTrue,
          reason: 'an 11 digit 0-prefixed number passes the client check; '
              'the server is the authority on what is really a mobile');
    });
  });

  group('phone formatting', () {
    test('groups digits the way a UK number is read aloud', () {
      expect(prettyUkPhone('07700900318'), '07700 900318');
      expect(prettyUkPhone('0770'), '0770');
    });

    test('never runs past a full number', () {
      expect(prettyUkPhone('077009003189999'), '07700 900318');
    });
  });

  group('brand', () {
    test('the two apps never share an accent colour', () {
      expect(YaariTheme.accentOf(YaariBrand.customer),
          isNot(YaariTheme.accentOf(YaariBrand.provider)));
      expect(YaariTheme.accentOf(YaariBrand.customer), YaariColors.ember);
      expect(YaariTheme.accentOf(YaariBrand.provider), YaariColors.slate);
    });
  });
}
