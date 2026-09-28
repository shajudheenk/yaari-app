// Contrast guard for the palette sampled from the reference photograph.
//
// The brief is a saturated crimson, a bright sky and a pale concrete. Two of
// those three are light enough that white text on them is unreadable, and
// that mistake is invisible in a simulator screenshot on a bright desk. These
// tests fail the build instead.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaari_ui/yaari_ui.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _aaNormal = 4.5; // body and meta text
const _aaLarge = 3.0; // 18pt+, or 14pt+ bold

void main() {
  group('text on a coloured ground', () {
    test('white reads on every brand tone we put it on', () {
      for (final bg in [Brand.c500, Brand.c600, Brand.c700]) {
        expect(contrast(bg, Colors.white), greaterThanOrEqualTo(_aaNormal),
            reason: 'white on $bg');
      }
    });

    test('the sky panel carries dark text, never white', () {
      expect(contrast(Sky.c400, Coal.c900), greaterThanOrEqualTo(_aaNormal));
      // The trap: Sky.c400 is bright enough that white on it is ~2:1.
      expect(contrast(Sky.c400, Colors.white), lessThan(_aaLarge),
          reason: 'if this ever passes, the sky token has been darkened and '
              'the rule below should be revisited');
      expect(contrast(Sky.c700, Colors.white), greaterThanOrEqualTo(_aaNormal),
          reason: 'c700 is the sky tone that may carry white');
    });

    test('concrete carries dark text; only its deep end carries white', () {
      expect(contrast(Slate.c300, Coal.c900), greaterThanOrEqualTo(_aaNormal));
      expect(contrast(Slate.c700, Colors.white), greaterThanOrEqualTo(_aaNormal));
    });
  });

  group('text on the page ground', () {
    const grounds = {
      'canvas': Surface.canvas,
      'raised': Surface.raised,
      'sunken': Surface.sunken,
    };

    test('body and meta text pass AA on every ground', () {
      for (final e in grounds.entries) {
        expect(contrast(e.value, Coal.c900), greaterThanOrEqualTo(_aaNormal),
            reason: 'body on ${e.key}');
        expect(contrast(e.value, Coal.c500), greaterThanOrEqualTo(_aaNormal),
            reason: 'meta on ${e.key} — Coal.c500 is the Txt.meta colour');
      }
    });

    test('the brand reads as a price and a link on every ground', () {
      for (final e in grounds.entries) {
        expect(contrast(e.value, Brand.c500), greaterThanOrEqualTo(_aaNormal),
            reason: 'brand text on ${e.key}');
      }
    });

    test('Coal.c400 is a decorative tone and is not fit for small text', () {
      // Documents intent: it is used for chevrons and dividers on light
      // grounds, and for secondary text on dark ones. Both are fine; small
      // text on a light ground is not.
      expect(contrast(Surface.canvas, Coal.c400), lessThan(_aaNormal));
      expect(contrast(Coal.c900, Coal.c400), greaterThanOrEqualTo(_aaNormal));
    });
  });

  group('signal colours stay distinguishable from the brand', () {
    test('white reads on success and danger', () {
      expect(contrast(Signal.success, Colors.white),
          greaterThanOrEqualTo(_aaNormal));
      expect(contrast(Signal.danger, Colors.white),
          greaterThanOrEqualTo(_aaNormal));
    });

    test('danger is not mistakable for the primary', () {
      // Both are red. If they are too close, an error state says nothing on a
      // screen whose primary action is already crimson.
      final d = (Signal.danger.r - Brand.c500.r).abs() +
          (Signal.danger.g - Brand.c500.g).abs() +
          (Signal.danger.b - Brand.c500.b).abs();
      expect(d, greaterThan(0.15), reason: 'danger too close to Brand.c500');
    });
  });

  group('the mix is the brief', () {
    test('the declared proportions describe one whole frame', () {
      final sum = Mix.red + Mix.sky + Mix.concrete + Mix.white;
      expect(sum, closeTo(1.0, 0.001));
    });

    test('red leads and sky is a real second, not an accent', () {
      expect(Mix.red, greaterThan(Mix.sky));
      expect(Mix.sky, greaterThan(Mix.white * 4),
          reason: 'sky is a ground colour in this palette, not a trim');
    });
  });
}
