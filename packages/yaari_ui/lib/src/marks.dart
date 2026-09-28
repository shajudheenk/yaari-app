import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ds/category.dart';
import 'ds/tokens.dart';

/// The service icons.
///
/// Built the way a phone's own app icons are, because that is the visual
/// language people already read as polished: a continuous-curve squircle
/// filled with the family's gradient, a soft gloss across the upper half, a
/// coloured shadow beneath, and one solid white glyph. Colour to navigate by,
/// without a single face or cartoon in the set.
///
/// The painted marks further down remain the fallback for a trade the app has
/// not been taught yet, and are what the paint tests exercise.
class YaariMark extends StatelessWidget {
  const YaariMark(
    this.slug, {
    super.key,
    this.size = 44,
    this.ink,
    this.accent,
    this.shadow = true,
  });

  final String slug;
  final double size;

  /// Kept for older call sites. The icon carries its own colour now.
  final Color? ink;
  final Color? accent;

  /// Off inside tight rows, where a shadow reads as dirt rather than depth.
  final bool shadow;

  static bool has(String slug) => _art.containsKey(slug);
  static Iterable<String> get known => _art.keys;

  /// The glyph for a trade, or null for one the app has not been taught.
  static IconData? iconFor(String slug) => _glyphs[slug];

  @visibleForTesting
  static CustomPainter painterFor(String slug, {Color? ink, Color? accent}) =>
      _ArtPainter(
          draw: _art[slug] ?? _fallback,
          palette: _paletteFor(slug, ink, accent));

  static _Tones _paletteFor(String slug, Color? ink, Color? accent) {
    final cat = categoryOf(slug);
    final base = accent ?? cat.base;
    final deep = ink ?? cat.deep;
    return _Tones(
      base: base,
      deep: deep,
      light: Color.lerp(base, Colors.white, 0.42)!,
      pale: Color.lerp(base, Colors.white, 0.78)!,
      shade: Color.lerp(deep, Colors.black, 0.12)!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final glyph = _glyphs[slug];
    if (glyph == null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ArtPainter(
              draw: _art[slug] ?? _fallback,
              palette: _paletteFor(slug, ink, accent)),
        ),
      );
    }
    return AppIcon(
      glyph: glyph,
      family: categoryOf(slug),
      size: size,
      shadow: shadow,
    );
  }
}

/// A squircle app icon: gradient, gloss, shadow, white glyph.
///
/// Public so the story screens and promise cards can use the same object for
/// things that are not trades — a seal for "verified", an umbrella for
/// "insured" — and the whole app speaks one visual language.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.glyph,
    required this.family,
    this.size = 44,
    this.shadow = true,
  });

  final IconData glyph;
  final Category family;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final shape = ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.58));

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: family.iconFill,
          shadows: shadow
              ? [
                  BoxShadow(
                    color: family.deep.withValues(alpha: 0.32),
                    blurRadius: size * 0.28,
                    offset: Offset(0, size * 0.12),
                  ),
                ]
              : const [],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gloss: light falling on the top half of a moulded surface.
            DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            Center(
              child: Icon(
                glyph,
                size: size * 0.52,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: family.deep.withValues(alpha: 0.35),
                    blurRadius: size * 0.08,
                    offset: Offset(0, size * 0.03),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One glyph per trade. Objects, never faces.
const _glyphs = <String, IconData>{
  'electrician': GlyphFill.lightning,
  'plumber': GlyphFill.pipeWrench,
  'gas-engineer': GlyphFill.flame,
  'cleaner': GlyphFill.broom,
  'gardener': GlyphFill.pottedPlant,
  'handyman': GlyphFill.toolbox,
  'painter': GlyphFill.paintRoller,
  'carpenter': GlyphFill.hammer,
  'locksmith': GlyphFill.key,
  'pet-care': GlyphFill.pawPrint,
  'appliance-repair': GlyphFill.washingMachine,
  'removals': GlyphFill.truck,
  'window-cleaning': GlyphFill.sprayBottle,
  'hairdresser': GlyphFill.scissors,
  'beauty': GlyphFill.sparkle,
  'massage': GlyphFill.flowerLotus,
  'care': GlyphFill.handHeart,
  'childcare': GlyphFill.baby,
  'security': GlyphFill.shieldCheck,
  'cook': GlyphFill.cookingPot,
  'maid': GlyphFill.basket,
  'driver': GlyphFill.steeringWheel,
  'dj': GlyphFill.vinylRecord,
  'personal-shopper': GlyphFill.shoppingBag,
};

/// The tones every illustration is built from.
@immutable
class _Tones {
  const _Tones({
    required this.base,
    required this.deep,
    required this.light,
    required this.pale,
    required this.shade,
  });

  final Color base;
  final Color deep;
  final Color light;
  final Color pale;
  final Color shade;

  @override
  bool operator ==(Object other) =>
      other is _Tones && other.base == base && other.deep == deep;

  @override
  int get hashCode => Object.hash(base, deep);
}

typedef _Draw = void Function(Canvas c, _Tones t);

class _ArtPainter extends CustomPainter {
  _ArtPainter({required this.draw, required this.palette});

  final _Draw draw;
  final _Tones palette;

  static const _grid = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Authored once at 48 units and scaled, so a 24px row mark and a 96px
    // hero are the same drawing rather than two that drifted apart.
    canvas.save();
    canvas.scale(size.shortestSide / _grid);

    // Everything is drawn into a layer so the lighting passes below land only
    // on pixels the mark actually painted — the gloss follows the object's
    // silhouette instead of sitting on it as a square.
    const box = Rect.fromLTWH(0, 0, _grid, _grid);
    canvas.saveLayer(box, Paint());
    draw(canvas, palette);

    // Specular: a soft key light from the upper left. This is what turns a
    // flat vector into something that reads as a moulded object.
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.radial(
          const Offset(15, 10),
          24,
          [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Occlusion: the underside falls into shadow, so the object has a floor.
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.linear(
          const Offset(0, 20),
          const Offset(0, 44),
          [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.16),
          ],
        ),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.draw != draw || old.palette != palette;
}

// ------------------------------------------------------------- helpers

/// A fill lit from the upper left.
///
/// Every shape in every mark goes through here, so one change gives the whole
/// set a single consistent light source: each surface is a little brighter
/// toward the light and a little deeper away from it. That ramp is most of
/// what separates a 3D icon from a flat one.
Paint _fill(Color c) {
  final hsl = HSLColor.fromColor(c);
  final lit = hsl
      .withLightness((hsl.lightness + 0.09).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.04).clamp(0.0, 1.0))
      .toColor()
      .withValues(alpha: c.a);
  final dim = hsl
      .withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0))
      .toColor()
      .withValues(alpha: c.a);
  return Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true
    ..shader = ui.Gradient.linear(
      const Offset(8, 4),
      const Offset(40, 44),
      [lit, c, dim],
      const [0.0, 0.45, 1.0],
    );
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _rrect(Canvas c, Paint p, double x, double y, double w, double h,
        [double r = 3]) =>
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        p);

void _shape(Canvas c, Paint p, void Function(Path) build) {
  final path = Path();
  build(path);
  c.drawPath(path, p);
}

/// The soft ellipse every object sits on. Grounds the illustration so it
/// reads as a thing on a surface rather than a sticker floating in space.
void _ground(Canvas c, _Tones t) {
  // A contact shadow that is darkest where the object touches down and
  // feathers out — a flat ellipse reads as a sticker, a soft one as weight.
  final shadow = Rect.fromCenter(
      center: const Offset(24, 41.5), width: 34, height: 8);
  c.drawOval(
    shadow,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        const Offset(24, 41.5),
        17,
        [
          t.shade.withValues(alpha: 0.30),
          t.shade.withValues(alpha: 0.10),
          t.shade.withValues(alpha: 0.0),
        ],
        const [0.0, 0.55, 1.0],
      ),
  );
}

// --------------------------------------------------------------- the art

final Map<String, _Draw> _art = {
  // A socket plate, catching light on its left face.
  'electrician': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.deep), 11, 8, 26, 30, 6);
    _rrect(c, _fill(t.base), 11, 8, 26, 27, 6);
    _rrect(c, _fill(t.light), 14, 11, 9, 21, 4);
    _rrect(c, _fill(t.deep), 18.5, 16, 3.5, 7, 1.6);
    _rrect(c, _fill(t.deep), 26, 16, 3.5, 7, 1.6);
    _rrect(c, _fill(t.deep), 21, 27, 6, 3.2, 1.4);
    // The spark: the one thing that says "live".
    _shape(c, _fill(const Color(0xFFFFD34D)), (p) {
      p.moveTo(33, 4);
      p.lineTo(28.5, 12);
      p.lineTo(31.5, 12);
      p.lineTo(29, 19);
      p.lineTo(36, 10);
      p.lineTo(32.5, 10);
      p.close();
    });
  },

  // A tap with a bead of water falling from it.
  'plumber': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.deep), 18, 22, 12, 4, 2);
    _rrect(c, _fill(t.base), 20, 10, 8, 14, 3);
    _rrect(c, _fill(t.light), 21, 11, 3, 12, 1.5);
    _rrect(c, _fill(t.base), 28, 13, 9, 5, 2.5);
    _rrect(c, _fill(t.deep), 33, 16, 4, 6, 2);
    _rrect(c, _fill(t.deep), 14, 12, 8, 3.5, 1.8);
    c.drawCircle(const Offset(18, 13.7), 2.6, _fill(t.light));
    _shape(c, _fill(const Color(0xFF58B6E8)), (p) {
      p.moveTo(35, 26);
      p.cubicTo(38.5, 31, 39, 33, 39, 34.2);
      p.arcToPoint(const Offset(31, 34.2), radius: const Radius.circular(4));
      p.cubicTo(31, 33, 31.5, 31, 35, 26);
      p.close();
    });
    c.drawCircle(const Offset(33.5, 33), 1.2, _fill(Colors.white.withValues(alpha: 0.7)));
  },

  // A flame on a burner ring — outer body, hot core, dark base.
  'gas-engineer': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.base), (p) {
      p.moveTo(24, 6);
      p.cubicTo(31, 14, 33, 18, 33, 23);
      p.arcToPoint(const Offset(15, 23), radius: const Radius.circular(9));
      p.cubicTo(15, 18, 17, 14, 24, 6);
      p.close();
    });
    _shape(c, _fill(const Color(0xFFFFC94D)), (p) {
      p.moveTo(24, 15);
      p.cubicTo(27.5, 19.5, 28.5, 21.5, 28.5, 24);
      p.arcToPoint(const Offset(19.5, 24), radius: const Radius.circular(4.5));
      p.cubicTo(19.5, 21.5, 20.5, 19.5, 24, 15);
      p.close();
    });
    _rrect(c, _fill(t.deep), 12, 32, 24, 4.5, 2.2);
    _rrect(c, _fill(t.shade), 16, 36, 4, 4, 1.6);
    _rrect(c, _fill(t.shade), 28, 36, 4, 4, 1.6);
  },

  // A bucket of suds.
  'cleaner': (c, t) {
    _ground(c, t);
    c.drawArc(
        Rect.fromLTWH(14, 10, 20, 20), 3.34, 2.6, false, _stroke(t.deep, 2.4));
    _shape(c, _fill(t.base), (p) {
      p.moveTo(12, 19);
      p.lineTo(36, 19);
      p.lineTo(32.5, 39);
      p.lineTo(15.5, 39);
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(15, 19);
      p.lineTo(21, 19);
      p.lineTo(19.5, 39);
      p.lineTo(16.8, 39);
      p.close();
    });
    _rrect(c, _fill(t.deep), 12, 17, 24, 3.4, 1.7);
    // Suds over the rim.
    c.drawCircle(const Offset(20, 15), 3.6, _fill(t.pale));
    c.drawCircle(const Offset(26, 13), 2.8, _fill(t.pale));
    c.drawCircle(const Offset(31, 16), 2.2, _fill(t.pale));
    c.drawCircle(const Offset(19, 14), 1.1, _fill(Colors.white));
  },

  // A potted plant.
  'gardener': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.base), (p) {
      p.moveTo(23, 26);
      p.cubicTo(23, 17, 29, 11, 37, 10);
      p.cubicTo(36.5, 19, 31, 25, 23, 26);
      p.close();
    });
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(23, 29);
      p.cubicTo(23, 22, 18, 17, 11, 16);
      p.cubicTo(11.5, 24, 16, 29, 23, 29);
      p.close();
    });
    c.drawLine(const Offset(24, 33), const Offset(24, 20), _stroke(t.shade, 2));
    _shape(c, _fill(const Color(0xFFB4693C)), (p) {
      p.moveTo(15, 31);
      p.lineTo(33, 31);
      p.lineTo(30.5, 41);
      p.lineTo(17.5, 41);
      p.close();
    });
    _rrect(c, _fill(const Color(0xFF8E4F2A)), 14, 29, 20, 3.6, 1.8);
  },

  // A toolbox with a latch.
  'handyman': (c, t) {
    _ground(c, t);
    c.drawArc(Rect.fromLTWH(17, 8, 14, 14), 3.34, 2.6, false,
        _stroke(t.deep, 2.6));
    _rrect(c, _fill(t.deep), 9, 18, 30, 21, 4);
    _rrect(c, _fill(t.base), 9, 18, 30, 8, 4);
    _rrect(c, _fill(t.light), 12, 20, 8, 4, 2);
    _rrect(c, _fill(const Color(0xFFFFD34D)), 21, 27, 6, 7, 2);
    _rrect(c, _fill(t.shade), 22.5, 29.5, 3, 2, 1);
  },

  // A roller, and the stripe it has just laid down.
  'painter': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.base), 11, 20, 26, 6.5, 3.2);
    _rrect(c, _fill(t.pale), 13, 21.2, 8, 4, 2);
    _rrect(c, _fill(t.deep), 11, 8, 22, 9, 3.5);
    _rrect(c, _fill(t.base), 11, 8, 22, 5.5, 3);
    _rrect(c, _fill(t.light), 13.5, 9, 6, 3.5, 1.8);
    _rrect(c, _fill(t.shade), 21, 17, 3.2, 6, 1.6);
    _rrect(c, _fill(t.shade), 18, 23, 6, 15, 3);
  },

  // A saw with a wooden handle.
  'carpenter': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.base), (p) {
      p.moveTo(6, 14);
      p.lineTo(31, 14);
      p.lineTo(31, 24);
      p.lineTo(6, 20);
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(6, 14);
      p.lineTo(31, 14);
      p.lineTo(31, 17);
      p.lineTo(6, 16.5);
      p.close();
    });
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(6, 20);
      for (var i = 0; i < 5; i++) {
        final x = 6 + i * 5.0;
        p.lineTo(x + 2.5, 25 + i * 0.7);
        p.lineTo(x + 5, 20.8 + i * 0.8);
      }
      p.lineTo(31, 24);
      p.close();
    });
    _shape(c, _fill(const Color(0xFFB4693C)), (p) {
      p.moveTo(31, 10);
      p.lineTo(38, 11);
      p.arcToPoint(const Offset(40, 16), radius: const Radius.circular(4));
      p.lineTo(40, 24);
      p.arcToPoint(const Offset(35, 28), radius: const Radius.circular(4));
      p.lineTo(31, 28);
      p.close();
    });
  },

  // A paw.
  'pet-care': (c, t) {
    _ground(c, t);
    for (final o in const [
      [15.0, 17.0, 3.4, 4.4],
      [23.0, 13.5, 3.5, 4.6],
      [31.0, 17.0, 3.4, 4.4],
    ]) {
      c.drawOval(
          Rect.fromCenter(
              center: Offset(o[0], o[1]), width: o[2] * 2, height: o[3] * 2),
          _fill(t.base));
    }
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(36.5, 24), width: 6, height: 7.6),
        _fill(t.base));
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(22, 24);
      p.cubicTo(28, 24, 32.5, 28, 32.5, 32.5);
      p.cubicTo(32.5, 36, 29.6, 38.5, 26.5, 38.5);
      p.cubicTo(24.4, 38.5, 23.3, 37.4, 22, 37.4);
      p.cubicTo(20.7, 37.4, 19.6, 38.5, 17.5, 38.5);
      p.cubicTo(14.4, 38.5, 11.5, 36, 11.5, 32.5);
      p.cubicTo(11.5, 28, 16, 24, 22, 24);
      p.close();
    });
    c.drawOval(
        Rect.fromCenter(center: const Offset(18, 29), width: 7, height: 5),
        _fill(Colors.white.withValues(alpha: 0.22)));
  },

  // A washing machine mid-cycle.
  'appliance-repair': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.deep), 10, 7, 28, 32, 5);
    _rrect(c, _fill(t.base), 10, 7, 28, 29, 5);
    _rrect(c, _fill(t.light), 12.5, 9, 6, 25, 3);
    _rrect(c, _fill(t.deep), 10, 14, 28, 1.8, 0.9);
    c.drawCircle(const Offset(24, 26), 8.6, _fill(t.deep));
    c.drawCircle(const Offset(24, 26), 6.6, _fill(const Color(0xFF9FD8F0)));
    _shape(c, _fill(const Color(0xFF58B6E8)), (p) {
      p.moveTo(17.6, 27.5);
      p.cubicTo(20, 25.5, 22, 29, 24.5, 27.2);
      p.cubicTo(27, 25.4, 28.6, 28.6, 30.4, 27.4);
      p.lineTo(30.4, 31);
      p.arcToPoint(const Offset(17.6, 31), radius: const Radius.circular(6.6));
      p.close();
    });
    c.drawCircle(const Offset(15, 11), 1.7, _fill(const Color(0xFF6EDC8F)));
    c.drawCircle(const Offset(20, 11), 1.7, _fill(t.pale));
  },

  // A van.
  'removals': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.base), 4, 15, 22, 17, 3);
    _rrect(c, _fill(t.light), 6, 17, 7, 13, 2);
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(26, 19);
      p.lineTo(34, 19);
      p.lineTo(41, 26);
      p.lineTo(41, 32);
      p.lineTo(26, 32);
      p.close();
    });
    _shape(c, _fill(const Color(0xFF9FD8F0)), (p) {
      p.moveTo(28, 21);
      p.lineTo(33.3, 21);
      p.lineTo(38, 25.6);
      p.lineTo(28, 25.6);
      p.close();
    });
    c.drawCircle(const Offset(14, 33), 4.6, _fill(t.shade));
    c.drawCircle(const Offset(14, 33), 2.1, _fill(t.pale));
    c.drawCircle(const Offset(34, 33), 4.6, _fill(t.shade));
    c.drawCircle(const Offset(34, 33), 2.1, _fill(t.pale));
  },

  // A pane, half squeegeed clean.
  'window-cleaning': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.deep), 7, 7, 28, 30, 3);
    _rrect(c, _fill(const Color(0xFFBFE4F5)), 9.5, 9.5, 23, 25, 2);
    _shape(c, _fill(Colors.white.withValues(alpha: 0.75)), (p) {
      p.moveTo(9.5, 26);
      p.lineTo(32.5, 12);
      p.lineTo(32.5, 34.5);
      p.lineTo(9.5, 34.5);
      p.close();
    });
    c.drawLine(const Offset(21, 9.5), const Offset(21, 34.5),
        _stroke(t.deep, 1.8));
    c.drawLine(const Offset(9.5, 22), const Offset(32.5, 22),
        _stroke(t.deep, 1.8));
    _rrect(c, _fill(t.base), 26, 22, 16, 4.2, 2.1);
    _rrect(c, _fill(t.shade), 33, 25, 9, 3, 1.5);
  },

  // Scissors.
  'hairdresser': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.light), (p) {
      p.moveTo(16, 6);
      p.lineTo(19.5, 7.5);
      p.lineTo(28, 27);
      p.lineTo(25, 29);
      p.close();
    });
    _shape(c, _fill(t.base), (p) {
      p.moveTo(32, 6);
      p.lineTo(28.5, 7.5);
      p.lineTo(20, 27);
      p.lineTo(23, 29);
      p.close();
    });
    c.drawCircle(const Offset(17, 34), 5.2, _fill(t.deep));
    c.drawCircle(const Offset(17, 34), 2.6, _fill(Colors.white));
    c.drawCircle(const Offset(31, 34), 5.2, _fill(t.deep));
    c.drawCircle(const Offset(31, 34), 2.6, _fill(Colors.white));
    c.drawCircle(const Offset(24, 27.5), 1.7, _fill(t.shade));
  },

  // A polish bottle with a brush.
  'beauty': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.base), (p) {
      p.moveTo(15, 21);
      p.lineTo(33, 21);
      p.lineTo(33, 36);
      p.arcToPoint(const Offset(29, 40), radius: const Radius.circular(4));
      p.lineTo(19, 40);
      p.arcToPoint(const Offset(15, 36), radius: const Radius.circular(4));
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(17.5, 22);
      p.lineTo(22, 22);
      p.lineTo(22, 38);
      p.lineTo(18.5, 38);
      p.arcToPoint(const Offset(17.5, 36), radius: const Radius.circular(2));
      p.close();
    });
    _rrect(c, _fill(t.deep), 20, 17, 8, 4.5, 1.6);
    _rrect(c, _fill(t.shade), 21, 5, 6, 12, 2.6);
    c.drawCircle(const Offset(24, 6.5), 3, _fill(t.deep));
    // A finished nail beside the bottle.
    _shape(c, _fill(t.pale), (p) {
      p.moveTo(36, 28);
      p.arcToPoint(const Offset(42, 28), radius: const Radius.circular(3));
      p.lineTo(42, 35);
      p.arcToPoint(const Offset(36, 35), radius: const Radius.circular(3));
      p.close();
    });
    _shape(c, _fill(t.base), (p) {
      p.moveTo(36, 28);
      p.arcToPoint(const Offset(42, 28), radius: const Radius.circular(3));
      p.lineTo(42, 31);
      p.lineTo(36, 31);
      p.close();
    });
  },

  // Stacked massage stones and an oil drop.
  'massage': (c, t) {
    _ground(c, t);
    c.drawOval(
        Rect.fromCenter(center: const Offset(24, 34), width: 26, height: 9),
        _fill(t.deep));
    c.drawOval(
        Rect.fromCenter(center: const Offset(24, 26), width: 21, height: 8),
        _fill(t.base));
    c.drawOval(
        Rect.fromCenter(center: const Offset(24, 19), width: 16, height: 7),
        _fill(t.light));
    c.drawOval(
        Rect.fromCenter(center: const Offset(24, 13), width: 11, height: 5.5),
        _fill(t.pale));
    c.drawOval(
        Rect.fromCenter(center: const Offset(21, 12), width: 4, height: 2),
        _fill(Colors.white.withValues(alpha: 0.8)));
    _shape(c, _fill(const Color(0xFF9BD9A8)), (p) {
      p.moveTo(39, 8);
      p.cubicTo(42.5, 13, 43, 15, 43, 16.5);
      p.arcToPoint(const Offset(35, 16.5), radius: const Radius.circular(4));
      p.cubicTo(35, 15, 35.5, 13, 39, 8);
      p.close();
    });
  },

  // Kept drawn though the trade is dormant, so switching it back on in the
  // database does not need an app release.
  'locksmith': (c, t) {
    _ground(c, t);
    c.drawArc(Rect.fromLTWH(15, 8, 18, 20), 3.14, 3.14, false,
        _stroke(t.deep, 4));
    _rrect(c, _fill(t.base), 11, 20, 26, 19, 4);
    _rrect(c, _fill(t.light), 13.5, 22, 7, 15, 3);
    c.drawCircle(const Offset(24, 27), 3.4, _fill(t.deep));
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(22.6, 28);
      p.lineTo(25.4, 28);
      p.lineTo(24.6, 34);
      p.lineTo(23.4, 34);
      p.close();
    });
  },
  // A cupped hand with a heart resting in it. The whole trade is "someone is
  // looked after", and a hand under the heart says that where a cross or a
  // stethoscope would say "clinical" — which is exactly what this is not.
  'care': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.base), (p) {
      p.moveTo(9, 27);
      p.cubicTo(9, 24.5, 12, 23.5, 13.8, 25.4);
      p.lineTo(19, 30.5);
      p.lineTo(19, 22);
      p.cubicTo(19, 19.6, 22.6, 19.6, 22.6, 22);
      p.lineTo(22.6, 33);
      p.cubicTo(31, 33, 35, 34.5, 35, 38);
      p.lineTo(35, 40);
      p.lineTo(16, 40);
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(19, 22);
      p.cubicTo(19, 19.6, 22.6, 19.6, 22.6, 22);
      p.lineTo(22.6, 33);
      p.lineTo(19, 33);
      p.close();
    });
    _shape(c, _fill(const Color(0xFFE0475E)), (p) {
      p.moveTo(29, 20.5);
      p.cubicTo(29, 14.5, 37.5, 14.5, 37.5, 20.5);
      p.cubicTo(37.5, 24.5, 33.2, 27.2, 33.2, 27.2);
      p.cubicTo(33.2, 27.2, 29, 24.5, 29, 20.5);
      p.close();
    });
    c.drawCircle(const Offset(31.4, 19.4), 1.3,
        _fill(Colors.white.withValues(alpha: 0.55)));
  },

  // A teddy bear. A rattle reads as "baby" only; a bear reads as "child",
  // which covers the after-school end of this trade too.
  'childcare': (c, t) {
    _ground(c, t);
    c.drawCircle(const Offset(14.5, 14.5), 6, _fill(t.deep));
    c.drawCircle(const Offset(33.5, 14.5), 6, _fill(t.deep));
    c.drawCircle(const Offset(14.5, 14.5), 3.2, _fill(t.pale));
    c.drawCircle(const Offset(33.5, 14.5), 3.2, _fill(t.pale));
    c.drawCircle(const Offset(24, 22), 14, _fill(t.base));
    _shape(c, _fill(t.light), (p) {
      p.addOval(Rect.fromCircle(center: const Offset(19, 17), radius: 7));
    });
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(24, 27), width: 15, height: 11),
        _fill(t.pale));
    c.drawCircle(const Offset(19.5, 19), 1.9, _fill(t.deep));
    c.drawCircle(const Offset(28.5, 19), 1.9, _fill(t.deep));
    c.drawCircle(const Offset(20.1, 18.4), 0.7, _fill(Colors.white));
    c.drawCircle(const Offset(29.1, 18.4), 0.7, _fill(Colors.white));
    c.drawOval(
        Rect.fromCenter(center: const Offset(24, 25), width: 4.6, height: 3.4),
        _fill(t.deep));
    c.drawArc(Rect.fromLTWH(20.5, 26.5, 7, 5), 0.25, 2.64, false,
        _stroke(t.deep, 1.5));
  },

  // A shield with a chevron. The one mark in the set that is a symbol rather
  // than an object, because security has no tool a customer would recognise.
  'security': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(24, 6);
      p.lineTo(39, 11);
      p.lineTo(39, 24);
      p.cubicTo(39, 33, 31.5, 39, 24, 42);
      p.cubicTo(16.5, 39, 9, 33, 9, 24);
      p.lineTo(9, 11);
      p.close();
    });
    _shape(c, _fill(t.base), (p) {
      p.moveTo(24, 8.6);
      p.lineTo(36.6, 12.8);
      p.lineTo(36.6, 24);
      p.cubicTo(36.6, 31.6, 30.4, 36.8, 24, 39.4);
      p.cubicTo(17.6, 36.8, 11.4, 31.6, 11.4, 24);
      p.lineTo(11.4, 12.8);
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(24, 8.6);
      p.lineTo(24, 39.4);
      p.cubicTo(17.6, 36.8, 11.4, 31.6, 11.4, 24);
      p.lineTo(11.4, 12.8);
      p.close();
    });
    _shape(c, _fill(Colors.white.withValues(alpha: 0.92)), (p) {
      p.moveTo(17.5, 23.5);
      p.lineTo(20.2, 20.8);
      p.lineTo(22.8, 23.4);
      p.lineTo(29.2, 17);
      p.lineTo(31.9, 19.7);
      p.lineTo(22.8, 28.8);
      p.close();
    });
  },

  // A covered pot with steam coming off it. A chef's hat would say
  // restaurant; a pot on the hob says someone is cooking in your kitchen.
  'cook': (c, t) {
    _ground(c, t);
    _shape(c, _stroke(t.pale, 2), (p) {
      p.moveTo(19, 13);
      p.cubicTo(17, 10.5, 21, 9, 19, 6);
      p.moveTo(24, 12);
      p.cubicTo(22, 9, 26, 7.5, 24, 4.5);
      p.moveTo(29, 13);
      p.cubicTo(27, 10.5, 31, 9, 29, 6);
    });
    _rrect(c, _fill(t.deep), 10, 16, 28, 4, 2);
    _rrect(c, _fill(t.base), 12, 19, 24, 18, 4);
    _shape(c, _fill(t.light), (p) {
      p.addRRect(RRect.fromRectAndCorners(
          const Rect.fromLTWH(14.5, 21, 7, 14),
          topLeft: const Radius.circular(3),
          bottomLeft: const Radius.circular(3)));
    });
    _rrect(c, _fill(t.deep), 5, 21, 8, 3.4, 1.7);
    _rrect(c, _fill(t.deep), 35, 21, 8, 3.4, 1.7);
    _rrect(c, _fill(t.shade), 22, 12.5, 4, 4, 2);
  },

  // A basket of folded linen. Household help is not one task, so the mark is
  // the pile of them rather than a mop.
  'maid': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(Colors.white.withValues(alpha: 0.95)), 14, 13, 20, 6, 2);
    _rrect(c, _fill(t.pale), 14, 13, 20, 3, 1.5);
    _rrect(c, _fill(t.light), 12, 18, 24, 6, 2);
    _rrect(c, _fill(t.base), 12, 18, 24, 3, 1.5);
    _shape(c, _fill(t.deep), (p) {
      p.moveTo(8, 23);
      p.lineTo(40, 23);
      p.lineTo(36.5, 40);
      p.lineTo(11.5, 40);
      p.close();
    });
    _shape(c, _fill(t.base), (p) {
      p.moveTo(8, 23);
      p.lineTo(24, 23);
      p.lineTo(24, 40);
      p.lineTo(11.5, 40);
      p.close();
    });
    for (var i = 0; i < 4; i++) {
      final x = 13.5 + i * 7.0;
      c.drawLine(Offset(x, 24.5), Offset(x - 1.2, 38.5),
          _stroke(t.shade.withValues(alpha: 0.35), 1.2));
    }
    _rrect(c, _fill(t.shade), 7, 21.5, 34, 3.4, 1.7);
  },

  // A car, three-quarter on. Drawn small and friendly rather than executive:
  // most of these jobs are a school run, not a wedding.
  'driver': (c, t) {
    _ground(c, t);
    _shape(c, _fill(t.base), (p) {
      p.moveTo(7, 34);
      p.lineTo(7, 27);
      p.cubicTo(7, 25, 9, 24, 11, 23.6);
      p.lineTo(15, 15.5);
      p.cubicTo(15.6, 14, 17, 13, 18.6, 13);
      p.lineTo(31, 13);
      p.cubicTo(32.6, 13, 33.8, 14, 34.4, 15.5);
      p.lineTo(37.6, 23.6);
      p.cubicTo(39.6, 24, 41, 25, 41, 27);
      p.lineTo(41, 34);
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(7, 34);
      p.lineTo(7, 27);
      p.cubicTo(7, 25, 9, 24, 11, 23.6);
      p.lineTo(15, 15.5);
      p.cubicTo(15.6, 14, 17, 13, 18.6, 13);
      p.lineTo(24, 13);
      p.lineTo(24, 34);
      p.close();
    });
    _shape(c, _fill(t.pale), (p) {
      p.moveTo(17.6, 16.4);
      p.lineTo(30.4, 16.4);
      p.lineTo(33, 23);
      p.lineTo(15, 23);
      p.close();
    });
    c.drawLine(const Offset(24, 16.4), const Offset(24, 23),
        _stroke(t.base.withValues(alpha: 0.5), 1.2));
    _rrect(c, _fill(t.shade), 5.5, 26.5, 5, 3, 1.5);
    _rrect(c, _fill(const Color(0xFFFFD34D)), 37.5, 26.5, 5, 3, 1.5);
    c.drawCircle(const Offset(14.5, 34), 4.6, _fill(t.shade));
    c.drawCircle(const Offset(33.5, 34), 4.6, _fill(t.shade));
    c.drawCircle(const Offset(14.5, 34), 2.1, _fill(t.pale));
    c.drawCircle(const Offset(33.5, 34), 2.1, _fill(t.pale));
  },

  // A record on a deck, with the tonearm down. Headphones would work for a
  // listener; the deck says someone is playing.
  'dj': (c, t) {
    _ground(c, t);
    _rrect(c, _fill(t.deep), 5, 12, 38, 28, 4);
    _rrect(c, _fill(t.base), 5, 12, 38, 25, 4);
    c.drawCircle(const Offset(21, 25), 12, _fill(t.shade));
    c.drawCircle(const Offset(21, 25), 12, _stroke(t.deep, 1));
    for (final r in [9.5, 7.5, 5.5]) {
      c.drawCircle(const Offset(21, 25), r,
          _stroke(Colors.white.withValues(alpha: 0.13), 0.8));
    }
    c.drawCircle(const Offset(21, 25), 3.6, _fill(t.light));
    c.drawCircle(const Offset(21, 25), 0.9, _fill(t.deep));
    _shape(c, _fill(Colors.white.withValues(alpha: 0.10)), (p) {
      p.moveTo(21, 13);
      p.arcToPoint(const Offset(33, 25),
          radius: const Radius.circular(12), clockwise: true);
      p.lineTo(21, 25);
      p.close();
    });
    c.drawCircle(const Offset(37, 16.5), 2.6, _fill(t.pale));
    c.drawLine(const Offset(37, 16.5), const Offset(27, 29),
        _stroke(t.pale, 1.6));
    c.drawCircle(const Offset(27, 29), 1.5, _fill(t.deep));
    _rrect(c, _fill(t.pale), 34, 30, 6, 2.2, 1.1);
    _rrect(c, _fill(const Color(0xFF4ADE80)), 34, 34, 6, 2.2, 1.1);
  },

  // A shopping bag with a gift tag. The tag is what separates it from
  // "groceries" — this trade is as much about choosing as carrying.
  'personal-shopper': (c, t) {
    _ground(c, t);
    c.drawArc(Rect.fromLTWH(17, 7, 14, 14), 3.14, 3.14, false,
        _stroke(t.deep, 2.4));
    _shape(c, _fill(t.base), (p) {
      p.moveTo(11, 15);
      p.lineTo(37, 15);
      p.lineTo(39, 40);
      p.lineTo(9, 40);
      p.close();
    });
    _shape(c, _fill(t.light), (p) {
      p.moveTo(11, 15);
      p.lineTo(24, 15);
      p.lineTo(24, 40);
      p.lineTo(9, 40);
      p.close();
    });
    _rrect(c, _fill(t.deep), 9, 14, 30, 3.4, 1.7);
    _shape(c, _fill(t.pale), (p) {
      p.moveTo(28, 22);
      p.lineTo(36, 22);
      p.lineTo(36, 30);
      p.lineTo(32, 33.5);
      p.lineTo(28, 30);
      p.close();
    });
    c.drawCircle(const Offset(32, 25.4), 1.5, _fill(t.deep));
  },
};

/// For a trade the app has not been taught yet: a plain toolbox, so the tile
/// still looks drawn rather than broken.
void _fallback(Canvas c, _Tones t) {
  _ground(c, t);
  _rrect(c, _fill(t.deep), 9, 17, 30, 22, 4);
  _rrect(c, _fill(t.base), 9, 17, 30, 8, 4);
  _rrect(c, _fill(t.light), 12, 19, 8, 4, 2);
  _rrect(c, _fill(const Color(0xFFFFD34D)), 21, 26, 6, 7, 2);
}
