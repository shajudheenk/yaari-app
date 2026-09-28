import 'package:flutter/material.dart';

/// Yaari's design tokens.
///
/// One source for colour, type, spacing, radius, elevation and motion. Every
/// component reads from here, which is what stops fifteen screens drifting
/// into fifteen dialects of the same idea.

// ---------------------------------------------------------------- colour

/// The brand ramp — sampled from the reference photograph.
///
/// A true crimson, not a terracotta. The wall in the photo is a saturated,
/// slightly cool red that holds its chroma in full sun and goes almost
/// oxblood in shadow. Orange-leaning reds go muddy at the dark end; this one
/// stays red all the way down, which is why the ramp works for both a
/// primary button and the shadowed face of a hero panel.
class Brand {
  static const c50  = Color(0xFFFDF0F1);
  static const c100 = Color(0xFFFADADC);
  static const c200 = Color(0xFFF3B0B4);
  static const c300 = Color(0xFFE98087);
  static const c400 = Color(0xFFDA4A55);
  static const c500 = Color(0xFFC9212B); // primary — the lit wall
  static const c600 = Color(0xFFA81922);
  static const c700 = Color(0xFF8A1720); // the wall in shadow
  static const c800 = Color(0xFF5E1016);
  static const c900 = Color(0xFF3A0A0E);
}

/// The sky ramp.
///
/// The second real colour in the photograph, not an accent. It occupies
/// roughly a quarter of the frame, so it earns the same weight here: full
/// panels, empty states, the live-booking ground — not just a link colour.
class Sky {
  static const c50  = Color(0xFFEDFAFB);
  static const c100 = Color(0xFFD2F2F6);
  static const c200 = Color(0xFFA6E5EC);
  static const c300 = Color(0xFF7AD7E2);
  static const c400 = Color(0xFF5CC9D6); // the sky itself
  static const c500 = Color(0xFF3FB3C4);
  static const c600 = Color(0xFF2E93A3);
  static const c700 = Color(0xFF24737F);
  static const c800 = Color(0xFF1A555E);
  static const c900 = Color(0xFF113A41);
}

/// The concrete ramp.
///
/// The pale blue-grey block. This is the structural colour — borders,
/// dividers, disabled states, secondary fills. It is a blue-grey and never a
/// neutral grey, because a neutral grey next to this red and this sky reads
/// as a third, unintended palette.
class Slate {
  static const c50  = Color(0xFFF2F6F7);
  static const c100 = Color(0xFFE2ECEE);
  static const c200 = Color(0xFFC9DCE1);
  static const c300 = Color(0xFFA9C7CD); // the lit face of the block
  static const c400 = Color(0xFF8CB2BB);
  static const c500 = Color(0xFF6F97A1);
  static const c600 = Color(0xFF587C86);
  static const c700 = Color(0xFF45616A);
  static const c800 = Color(0xFF33484F);
  static const c900 = Color(0xFF223137);
}

/// The near-black ramp. Named Coal rather than Ink because Flutter already
/// ships an `Ink` widget and the clash is silent until it is not.
///
/// Cooled from the old plum-biased black to sit under this palette: the
/// shadows in the photograph are blue-black, not brown-black.
class Coal {
  static const c900 = Color(0xFF101619);
  static const c800 = Color(0xFF1B2327);
  static const c700 = Color(0xFF2C3840);
  static const c600 = Color(0xFF465660);
  static const c500 = Color(0xFF596B73);
  static const c400 = Color(0xFF8E9CA4);
  static const c300 = Color(0xFFB7C2C7);
  static const c200 = Color(0xFFD8E0E3);
  static const c100 = Color(0xFFE9EEF0);
  static const c50  = Color(0xFFF4F7F8);
}

/// Grounds.
///
/// The photograph's white is a cool, sunlit concrete — not the warm cream
/// this app used to sit on. Warm cream under a crimson this saturated turns
/// the red orange by contrast, which is exactly what we are trying to lose.
class Surface {
  static const canvas   = Color(0xFFF1F4F3); // the lit floor
  static const raised   = Color(0xFFFFFFFF);
  static const sunken   = Color(0xFFE3E9EA);
  static const inverse  = Coal.c900;
}

/// The proportions of the reference photograph, as a usable rule.
///
/// Measured off the frame with the letterbox excluded. This is the brief:
/// red leads, sky is a genuine second, concrete does the structural work,
/// white is a sliver and black anchors. A screen that inverts this — a pale
/// page with a red button — is not this palette, whatever hex values it uses.
class Mix {
  /// Dominant. Hero panels, primary actions, the nav pill, section grounds.
  static const red      = 0.44;
  /// Second colour. Full panels and grounds, not links and icons.
  static const sky      = 0.28;
  /// Structure. Borders, dividers, secondary fills, disabled states.
  static const concrete = 0.22;
  /// Relief only. Cards that must float clear of a coloured ground.
  static const white    = 0.06;
}

/// Earned professional tiers.
///
/// Metallic rather than flat: each is a three-stop ramp so a badge reads as a
/// medal catching light, not a coloured sticker. Tiers come from rating and
/// completed jobs on the server (provider_tier()), never from payment, so the
/// badge always means the same thing.
@immutable
class Tier {
  const Tier._(this.key, this.label, this.light, this.base, this.deep,
      this.upliftBps, this.blurb);

  final String key;
  final String label;
  final Color light;
  final Color base;
  final Color deep;

  /// What the tier adds to the price. Mirrors tier_uplift_bps() in the
  /// database, which is what actually charges it.
  final int upliftBps;
  final String blurb;

  static const gold = Tier._('gold', 'Gold', Color(0xFFFFE7A3),
      Color(0xFFE2A83A), Color(0xFF8F6212), 2000,
      'Rated 4.8+ across 60+ jobs');
  static const silver = Tier._('silver', 'Silver', Color(0xFFF4F7F9),
      Color(0xFFAEB9C2), Color(0xFF5D6B75), 1000,
      'Rated 4.6+ across 25+ jobs');
  static const bronze = Tier._('bronze', 'Bronze', Color(0xFFF6CFAE),
      Color(0xFFC57F4A), Color(0xFF7C4621), 0,
      'Verified and building a record');

  static const all = [gold, silver, bronze];

  static Tier of(String? key) => switch (key) {
        'gold' => gold,
        'silver' => silver,
        _ => bronze,
      };

  LinearGradient get medal => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, base, deep],
        stops: const [0.0, 0.5, 1.0],
      );

  /// "+20%" or "Standard rate".
  String get upliftLabel =>
      upliftBps == 0 ? 'Standard rate' : '+${upliftBps ~/ 100}%';
}

/// Meaning, not decoration. These never get used for emphasis.
///
/// Danger is deliberately pulled away from Brand.c500 — when the primary
/// colour is already a red, an error state that is also red says nothing.
class Signal {
  static const success     = Color(0xFF127A55);
  static const successSoft = Color(0xFFDFF2EA);
  static const warning     = Color(0xFFB07407);
  static const warningSoft = Color(0xFFFCF1DC);
  static const danger      = Color(0xFF8A1720);
  static const dangerSoft  = Color(0xFFF7E3E4);
  static const info        = Sky.c700;
  static const infoSoft    = Sky.c50;
}

// ----------------------------------------------------------------- glyphs

/// Phosphor Light glyphs, by codepoint.
///
/// Bundled as a plain font: the phosphor_flutter package subclasses IconData,
/// which Flutter has made a final class, so it no longer compiles. Codepoints
/// were read from that package's own icon table.
class Glyph {
  static const _family = 'PhosphorLight';
  static const _package = 'yaari_ui';
  static const lightning = IconData(0xe2de, fontFamily: _family, fontPackage: _package);
  static const pipeWrench = IconData(0xed88, fontFamily: _family, fontPackage: _package);
  static const flame = IconData(0xe624, fontFamily: _family, fontPackage: _package);
  static const broom = IconData(0xec54, fontFamily: _family, fontPackage: _package);
  static const pottedPlant = IconData(0xec22, fontFamily: _family, fontPackage: _package);
  static const toolbox = IconData(0xeca0, fontFamily: _family, fontPackage: _package);
  static const paintRoller = IconData(0xe6f4, fontFamily: _family, fontPackage: _package);
  static const hammer = IconData(0xe80e, fontFamily: _family, fontPackage: _package);
  static const key = IconData(0xe2d6, fontFamily: _family, fontPackage: _package);
  static const pawPrint = IconData(0xe648, fontFamily: _family, fontPackage: _package);
  static const washingMachine = IconData(0xede8, fontFamily: _family, fontPackage: _package);
  static const truck = IconData(0xe4b4, fontFamily: _family, fontPackage: _package);
  static const sprayBottle = IconData(0xe7e4, fontFamily: _family, fontPackage: _package);
  static const scissors = IconData(0xeae0, fontFamily: _family, fontPackage: _package);
  static const sparkle = IconData(0xe6a2, fontFamily: _family, fontPackage: _package);
  static const flowerLotus = IconData(0xe6cc, fontFamily: _family, fontPackage: _package);
  static const handHeart = IconData(0xe810, fontFamily: _family, fontPackage: _package);
  static const baby = IconData(0xe774, fontFamily: _family, fontPackage: _package);
  static const shieldCheck = IconData(0xe40c, fontFamily: _family, fontPackage: _package);
  static const cookingPot = IconData(0xe764, fontFamily: _family, fontPackage: _package);
  static const basket = IconData(0xe964, fontFamily: _family, fontPackage: _package);
  static const steeringWheel = IconData(0xe9ac, fontFamily: _family, fontPackage: _package);
  static const vinylRecord = IconData(0xecac, fontFamily: _family, fontPackage: _package);
  static const shoppingBag = IconData(0xe416, fontFamily: _family, fontPackage: _package);
}

/// Phosphor Fill glyphs — solid, for white-on-colour app icons, where the
/// light weight disappears into the gradient behind it.
class GlyphFill {
  static const _family = 'PhosphorFill';
  static const _package = 'yaari_ui';
  static const lightning = IconData(0xe2de, fontFamily: _family, fontPackage: _package);
  static const pipeWrench = IconData(0xed88, fontFamily: _family, fontPackage: _package);
  static const flame = IconData(0xe624, fontFamily: _family, fontPackage: _package);
  static const broom = IconData(0xec54, fontFamily: _family, fontPackage: _package);
  static const pottedPlant = IconData(0xec22, fontFamily: _family, fontPackage: _package);
  static const toolbox = IconData(0xeca0, fontFamily: _family, fontPackage: _package);
  static const paintRoller = IconData(0xe6f4, fontFamily: _family, fontPackage: _package);
  static const hammer = IconData(0xe80e, fontFamily: _family, fontPackage: _package);
  static const key = IconData(0xe2d6, fontFamily: _family, fontPackage: _package);
  static const pawPrint = IconData(0xe648, fontFamily: _family, fontPackage: _package);
  static const washingMachine = IconData(0xede8, fontFamily: _family, fontPackage: _package);
  static const truck = IconData(0xe4b4, fontFamily: _family, fontPackage: _package);
  static const sprayBottle = IconData(0xe7e4, fontFamily: _family, fontPackage: _package);
  static const scissors = IconData(0xeae0, fontFamily: _family, fontPackage: _package);
  static const sparkle = IconData(0xe6a2, fontFamily: _family, fontPackage: _package);
  static const flowerLotus = IconData(0xe6cc, fontFamily: _family, fontPackage: _package);
  static const handHeart = IconData(0xe810, fontFamily: _family, fontPackage: _package);
  static const baby = IconData(0xe774, fontFamily: _family, fontPackage: _package);
  static const shieldCheck = IconData(0xe40c, fontFamily: _family, fontPackage: _package);
  static const cookingPot = IconData(0xe764, fontFamily: _family, fontPackage: _package);
  static const basket = IconData(0xe964, fontFamily: _family, fontPackage: _package);
  static const steeringWheel = IconData(0xe9ac, fontFamily: _family, fontPackage: _package);
  static const vinylRecord = IconData(0xecac, fontFamily: _family, fontPackage: _package);
  static const shoppingBag = IconData(0xe416, fontFamily: _family, fontPackage: _package);
  static const sealCheck = IconData(0xe606, fontFamily: _family, fontPackage: _package);
  static const umbrella = IconData(0xe684, fontFamily: _family, fontPackage: _package);
  static const videoCamera = IconData(0xe4da, fontFamily: _family, fontPackage: _package);
  static const headset = IconData(0xe584, fontFamily: _family, fontPackage: _package);
  static const clockCountdown = IconData(0xed2c, fontFamily: _family, fontPackage: _package);
  static const house = IconData(0xe2c2, fontFamily: _family, fontPackage: _package);
  static const checkCircle = IconData(0xe184, fontFamily: _family, fontPackage: _package);
  static const arrowRight = IconData(0xe06c, fontFamily: _family, fontPackage: _package);
  static const star = IconData(0xe46a, fontFamily: _family, fontPackage: _package);
  static const mapPin = IconData(0xe316, fontFamily: _family, fontPackage: _package);
  static const calendarCheck = IconData(0xe712, fontFamily: _family, fontPackage: _package);
  static const repeat = IconData(0xe3f6, fontFamily: _family, fontPackage: _package);
}

// ------------------------------------------------------------------ type

/// The two faces, namespaced for the package that ships them. Getting the
/// `packages/` prefix wrong fails silently — you just get the system font —
/// so they are constants rather than strings at the call site.
class Face {
  static const display = 'packages/yaari_ui/Fraunces';
  static const text    = 'packages/yaari_ui/Manrope';
}

/// A type scale with real jumps in it.
///
/// Consumer apps read as premium largely because their hierarchy is violent:
/// the headline is three times the metadata, not twenty percent larger. Every
/// size here is deliberate and there are no in-between values to reach for.
class Txt {
  static const hero = TextStyle(
      fontFamily: Face.display, fontSize: 34, fontWeight: FontWeight.w700,
      height: 1.05, letterSpacing: -1.0, color: Coal.c900);

  static const display = TextStyle(
      fontFamily: Face.display, fontSize: 27, fontWeight: FontWeight.w700,
      height: 1.1, letterSpacing: -0.7, color: Coal.c900);

  static const title = TextStyle(
      fontFamily: Face.text, fontSize: 19, fontWeight: FontWeight.w800,
      height: 1.2, letterSpacing: -0.4, color: Coal.c900);

  static const section = TextStyle(
      fontFamily: Face.text, fontSize: 16, fontWeight: FontWeight.w800,
      height: 1.25, letterSpacing: -0.3, color: Coal.c900);

  static const cardTitle = TextStyle(
      fontFamily: Face.text, fontSize: 14.5, fontWeight: FontWeight.w800,
      height: 1.25, letterSpacing: -0.2, color: Coal.c900);

  static const body = TextStyle(
      fontFamily: Face.text, fontSize: 14, fontWeight: FontWeight.w500,
      height: 1.5, color: Coal.c700);

  static const bodySm = TextStyle(
      fontFamily: Face.text, fontSize: 12.5, fontWeight: FontWeight.w500,
      height: 1.45, color: Coal.c500);

  static const meta = TextStyle(
      fontFamily: Face.text, fontSize: 11.5, fontWeight: FontWeight.w600,
      height: 1.3, color: Coal.c500);

  static const label = TextStyle(
      fontFamily: Face.text, fontSize: 10.5, fontWeight: FontWeight.w800,
      height: 1.2, letterSpacing: 1.0, color: Coal.c500);

  /// Prices and counts. Tabular so columns of figures line up, which is the
  /// cheapest possible signal that somebody was careful with the numbers.
  static const price = TextStyle(
      fontFamily: Face.text, fontSize: 17, fontWeight: FontWeight.w800,
      height: 1.1, letterSpacing: -0.4, color: Coal.c900,
      fontFeatures: [FontFeature.tabularFigures()]);

  static const priceLg = TextStyle(
      fontFamily: Face.display, fontSize: 30, fontWeight: FontWeight.w700,
      height: 1, letterSpacing: -0.8, color: Coal.c900,
      fontFeatures: [FontFeature.tabularFigures()]);

  static const button = TextStyle(
      fontFamily: Face.text, fontSize: 15, fontWeight: FontWeight.w800,
      height: 1.1, letterSpacing: -0.2);
}

// --------------------------------------------------------------- metrics

/// A 4pt grid. Named rather than numeric so spacing decisions are legible in
/// the code and consistent between screens.
class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const huge = 40.0;

  /// The page gutter. One value, used everywhere, so nothing is ever
  /// accidentally three pixels out from the thing above it.
  static const page = 20.0;
}

/// Radii carry meaning: the larger the surface, the softer the corner.
class Radii {
  static const chip = 99.0;
  static const button = 16.0;
  static const card = 20.0;
  static const panel = 26.0;
  static const sheet = 30.0;
}

/// Shadows take their tint from Coal, which is now a blue-black. A neutral
/// grey shadow under a saturated red card is what makes cheap UI look dirty.
class Shade {
  static List<BoxShadow> get sm => [
        BoxShadow(
            color: Coal.c900.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
            color: Coal.c900.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, 6)),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
            color: Coal.c900.withValues(alpha: 0.09),
            blurRadius: 28, offset: const Offset(0, 12)),
      ];

  /// For a card in the brand colour — the shadow takes the card's own hue so
  /// it reads as light falling past it rather than a grey smudge.
  static List<BoxShadow> tinted(Color c) => [
        BoxShadow(
            color: c.withValues(alpha: 0.28),
            blurRadius: 24, offset: const Offset(0, 10)),
      ];
}

// ---------------------------------------------------------------- motion

/// Motion that decelerates hard: fast in, slow to settle, the way something
/// with mass moves. Material's symmetrical default easing is a large part of
/// why an undesigned Flutter app reads as an undesigned Flutter app.
class Motion {
  static const enter = Cubic(0.16, 1.0, 0.3, 1.0);
  static const exit = Cubic(0.4, 0.0, 0.9, 0.2);
  static const settle = Cubic(0.2, 0.0, 0.0, 1.0);
  static const spring = Cubic(0.18, 1.4, 0.4, 1.0);

  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 480);
  static const page = Duration(milliseconds: 420);
}
