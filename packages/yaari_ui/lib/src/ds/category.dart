import 'package:flutter/material.dart';

import 'tokens.dart';

/// A visual identity per service category.
///
/// The colours are not decorative and they are not arbitrary. Each is taken
/// from the material or the sensation of the work itself — copper for the
/// electrician, water for the plumber, flame for gas, chlorophyll for the
/// gardener, lavender for massage. People navigate a grid by colour long
/// before they read a label, so a category whose hue matches what it *is*
/// gets found faster.
///
/// Three constraints keep it a system rather than a paintbox:
///   - every `base` sits in a similar lightness and chroma band, so no tile
///     shouts over its neighbours;
///   - `onTint` is always legible on `tint`, checked as a pair;
///   - related trades sit near each other in hue, so the grid reads in
///     families rather than as confetti.
@immutable
class Category {
  const Category({
    required this.base,
    required this.deep,
    required this.tint,
    required this.glyph,
    this.top,
  });

  /// The bright end of the app-icon gradient. Null derives it from [base].
  final Color? top;

  /// The app-icon fill: bright at the top-left, rich at the bottom-right,
  /// the way a lit object reads.
  LinearGradient get iconFill => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top ?? Color.lerp(base, Colors.white, 0.3)!, base],
      );

  /// The identity colour: marks, accents, the selected state.
  final Color base;

  /// For text and icons on a pale ground, where `base` would fail contrast.
  final Color deep;

  /// The pale field a mark sits on inside a card.
  final Color tint;

  /// Fallback glyph, used anywhere the drawn mark is too small to read.
  final IconData glyph;

  /// The wash behind a category's own screen — its colour at strength,
  /// falling to a deeper shade. Gives the header weight without an image.
  LinearGradient get header => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, deep],
      );

  /// A whisper of the colour, for a card ground that should read as tinted
  /// paper rather than as a coloured block.
  LinearGradient get whisper => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint, Color.lerp(tint, Colors.white, 0.6)!],
      );
}

/// One colour per family, not per trade.
///
/// Twenty-four hues read as a children's app; one hue read as a bank. Six —
/// one per family of work, each a two-stop gradient like an app icon — gives
/// the grid colour to navigate by while keeping it a system. `deep` is kept
/// dark enough to pass AA as text on white, separately from the gradient,
/// which is free to be bright.
const _families = <String, Category>{
  'Help at home': Category(
      top: Color(0xFFFF9B78), base: Color(0xFFEF4F3C),
      deep: Color(0xFFB81E28), tint: Color(0xFFFFEEE8),
      glyph: GlyphFill.house),
  'Care & family': Category(
      top: Color(0xFFFFA6C6), base: Color(0xFFE2558F),
      deep: Color(0xFFA3235C), tint: Color(0xFFFDEBF3),
      glyph: GlyphFill.handHeart),
  'Repairs & trades': Category(
      top: Color(0xFFFFCB5C), base: Color(0xFFF0891F),
      deep: Color(0xFFA24E08), tint: Color(0xFFFFF3DE),
      glyph: GlyphFill.toolbox),
  'Outdoors & moving': Category(
      top: Color(0xFF6CE0BD), base: Color(0xFF1FA88F),
      deep: Color(0xFF0D6E5E), tint: Color(0xFFE1F6F0),
      glyph: GlyphFill.truck),
  'Hair & beauty': Category(
      top: Color(0xFFCFA6FF), base: Color(0xFF8E5BE6),
      deep: Color(0xFF5E32B8), tint: Color(0xFFF0E9FD),
      glyph: GlyphFill.sparkle),
  'Events & occasions': Category(
      top: Color(0xFF82CFFF), base: Color(0xFF4682EE),
      deep: Color(0xFF2946B8), tint: Color(0xFFE6EFFE),
      glyph: GlyphFill.vinylRecord),
};

const _house = Category(
    top: Color(0xFFFF9B78), base: Brand.c500, deep: Brand.c700,
    tint: Brand.c50, glyph: GlyphFill.house);

/// The identity for a trade: its family's. An unknown trade gets the house
/// identity rather than grey, so it still looks deliberate.
Category categoryOf(String slug) => _families[groupOf(slug)] ?? _house;

/// The identity of a family by name, for section headers.
Category familyOf(String group) => _families[group] ?? _house;

/// Which families the grid groups into, and what to call them.
///
/// Fifteen tiles in one undifferentiated block is a directory. Three named
/// groups of five is a menu, and a menu is what people can actually scan.
const categoryGroups = <(String, List<String>)>[
  ('Help at home', ['cleaner', 'maid', 'cook']),
  ('Care & family', ['care', 'childcare', 'pet-care']),
  ('Repairs & trades', [
    'electrician', 'plumber', 'gas-engineer', 'handyman',
    'carpenter', 'appliance-repair', 'painter', 'locksmith',
  ]),
  ('Outdoors & moving', [
    'gardener', 'window-cleaning', 'removals', 'driver',
  ]),
  ('Hair & beauty', ['hairdresser', 'beauty', 'massage']),
  ('Events & occasions', ['dj', 'security', 'personal-shopper']),
];

/// The group a slug belongs to, for screens that need to show it out of
/// context — search results, a booking card.
String? groupOf(String slug) {
  for (final (name, slugs) in categoryGroups) {
    if (slugs.contains(slug)) return name;
  }
  return null;
}
