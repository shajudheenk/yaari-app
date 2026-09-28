import 'package:flutter_test/flutter_test.dart';
import 'package:yaari_ui/yaari_ui.dart';

/// The rate-limit message came back from the server correctly and the app
/// still showed "Could not send a code", because `details` was not the shape
/// the extractor expected. These pin down every shape it can arrive in.
void main() {
  const fallback = 'Could not send a code.';
  const real = 'Too many codes requested. Try again in an hour.';

  String extract(Object? details) =>
      YaariAuth.messageFrom(details, fallback);

  test('a decoded map', () {
    expect(extract({'error': 'rate_limited', 'message': real}), real);
  });

  test('a raw JSON string body', () {
    expect(extract('{"error":"rate_limited","message":"$real"}'), real);
  });

  test('nested one level under error', () {
    expect(extract({'error': {'message': real}}), real);
  });

  test('a plain string message', () {
    expect(extract(real), real);
  });

  test('GoTrue style error_description', () {
    expect(extract({'error_description': real}), real);
  });

  test('falls back when there is nothing usable', () {
    expect(extract(null), fallback);
    expect(extract({}), fallback);
    expect(extract(''), fallback);
    expect(extract('not json {'), 'not json {');
    expect(extract({'code': 429}), fallback);
  });

  test('does not recurse forever on a self-referencing map', () {
    final loop = <String, dynamic>{};
    loop['error'] = loop;
    expect(extract(loop), fallback);
  });
}
