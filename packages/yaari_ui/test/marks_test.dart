import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaari_ui/yaari_ui.dart';

/// The marks replaced every photograph in the app, so a mark that fails to
/// draw leaves a blank space in production rather than a wrong picture.
///
/// These paint each one onto a real recording canvas — the same code path the
/// screen uses — and check it produced something. Reading pixels back would
/// be a stronger check but needs an async image round trip that stalls the
/// test binding, and a mark that records no drawing commands is the failure
/// worth catching anyway.
void main() {
  /// Paints a mark at the given size and reports roughly how much drawing it
  /// recorded. Zero means the paths fell outside the 48-unit grid, which on
  /// screen looks exactly like a missing icon.
  int drawn(String slug, double size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Drives the widget's own painter rather than a copy of it, so the test
    // cannot pass against code the app does not run.
    YaariMark.painterFor(slug).paint(canvas, Size(size, size));

    final picture = recorder.endRecording();
    final bytes = picture.approximateBytesUsed;
    picture.dispose();
    return bytes;
  }

  test('every known mark records drawing without throwing', () {
    for (final slug in YaariMark.known) {
      expect(() => drawn(slug, 96), returnsNormally,
          reason: '$slug threw while painting');
      expect(drawn(slug, 96), greaterThan(0),
          reason: '$slug recorded no drawing at all');
    }
  });

  test('marks draw at the size a register row actually uses', () {
    // 30 logical pixels is what YaariRegisterRow asks for. A mark that only
    // works at hero size is useless where it is used most.
    for (final slug in YaariMark.known) {
      expect(drawn(slug, 30), greaterThan(0), reason: '$slug drew nothing at row size');
    }
  });

  test('an unknown trade falls back rather than drawing nothing', () {
    expect(YaariMark.has('not-a-real-trade'), isFalse);
    expect(drawn('not-a-real-trade', 96), greaterThan(0),
        reason: 'a trade added to the database before the app knows about it '
            'must still look deliberate');
  });

  test('every trade the apps ship with has a mark', () {
    // The backend test checks this against the live database; this one fails
    // fast, without a network.
    const shipped = [
      'electrician', 'plumber', 'gas-engineer', 'cleaner', 'gardener',
      'handyman', 'painter', 'carpenter', 'pet-care', 'appliance-repair',
      'removals', 'window-cleaning', 'hairdresser', 'beauty', 'massage',
      // Care, household and occasions.
      'care', 'childcare', 'security', 'cook', 'maid', 'driver', 'dj',
      'personal-shopper',
    ];
    for (final slug in shipped) {
      expect(YaariMark.has(slug), isTrue, reason: 'no mark drawn for $slug');
    }
  });

  test('every tile in the grid has a mark and a glyph', () {
    // categoryGroups is what the home grid renders. A slug listed there with
    // no mark is a blank tile, and one with no Category falls back to the
    // brand colour, which looks like a bug rather than a decision.
    for (final (group, slugs) in categoryGroups) {
      expect(slugs, isNotEmpty, reason: 'group "$group" is empty');
      for (final slug in slugs) {
        expect(YaariMark.has(slug), isTrue,
            reason: '$slug is in "$group" but has no mark');
        expect(YaariMark.iconFor(slug), isNotNull,
            reason: '$slug is in "$group" but has no glyph, so its tile '
                'would fall back to a painted mark and look like a stranger');
      }
    }
  });

  test('every painted mark also has a line glyph', () {
    // The painted set is the fallback. If a trade has a painted mark but no
    // glyph, the fallback is what ships, and one tile on the grid would be in
    // a different visual language from the other twenty-three.
    for (final slug in YaariMark.known) {
      expect(YaariMark.iconFor(slug), isNotNull, reason: slug);
    }
  });

  test('no trade is listed in two groups at once', () {
    final seen = <String>{};
    for (final (_, slugs) in categoryGroups) {
      for (final slug in slugs) {
        expect(seen.add(slug), isTrue, reason: '$slug appears twice');
      }
    }
  });

  test('the dormant locksmith trade keeps its mark', () {
    // Switched off in the database, not deleted. Turning it back on should
    // not need an app release.
    expect(YaariMark.has('locksmith'), isTrue);
  });

  testWidgets('a mark renders in a real tree without error', (tester) async {
    // Wrap rather than Column: the set grows every time a trade is added, and
    // a fixed column silently turns that growth into an overflow failure that
    // says nothing about the marks themselves.
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(
            children: [for (final s in YaariMark.known) YaariMark(s, size: 30)],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(YaariMark), findsNWidgets(YaariMark.known.length));
  });
}
