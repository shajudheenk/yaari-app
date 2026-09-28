import 'package:flutter/material.dart';

import 'theme.dart';

/// A colour per category.
///
/// A grid where every tile is the same colour is a spreadsheet. Giving each
/// trade its own hue means people navigate by colour before they read a word
/// — after two visits you reach for the green tile without thinking, which is
/// how the apps that feel fast actually feel fast.
///
/// The hues are deliberately drawn from the work itself: copper for the
/// electrician, water-blue for the plumber, flame for gas, garden green,
/// timber for the carpenter, and so on. Nothing is assigned at random, so the
/// palette stays coherent as trades are added.
class TradeColour {
  const TradeColour({
    required this.base,
    required this.deep,
    required this.tint,
  });

  /// The colour of the mark and the accents.
  final Color base;

  /// For text on a pale ground, where `base` would be too light to read.
  final Color deep;

  /// The tile's background. Kept very pale so a screen of fifteen of them
  /// still reads as one surface rather than a bag of sweets.
  final Color tint;

  /// The gradient behind a category's own screen.
  LinearGradient get wash => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint, Color.lerp(tint, Colors.white, 0.55)!],
      );

  /// The warm band used on hero cards — the colour at full strength falling
  /// away to a deeper shade, which is what gives it weight on screen.
  LinearGradient get rich => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, deep],
      );
}

/// Looks up a trade's colour. An unknown slug falls back to the brand ember
/// rather than to grey, so a trade added to the database before the app knows
/// about it still looks intentional.
TradeColour colourFor(String slug) => _palette[slug] ?? _fallback;

const _fallback = TradeColour(
  base: YaariColors.ember,
  deep: YaariColors.emberDeep,
  tint: YaariColors.emberTint,
);

const _palette = <String, TradeColour>{
  // Copper wire.
  'electrician': TradeColour(
    base: Color(0xFFE08A1E), deep: Color(0xFF9A5A06), tint: Color(0xFFFEF3E0)),
  // Water.
  'plumber': TradeColour(
    base: Color(0xFF2E86C7), deep: Color(0xFF1B5A8A), tint: Color(0xFFE6F2FB)),
  // Flame.
  'gas-engineer': TradeColour(
    base: Color(0xFFE2542C), deep: Color(0xFF9E3315), tint: Color(0xFFFDEDE7)),
  // Suds.
  'cleaner': TradeColour(
    base: Color(0xFF1FA8A0), deep: Color(0xFF0E6B66), tint: Color(0xFFE2F6F5)),
  // Lawn.
  'gardener': TradeColour(
    base: Color(0xFF4F9D3A), deep: Color(0xFF2F6522), tint: Color(0xFFEBF6E7)),
  // Toolbox steel.
  'handyman': TradeColour(
    base: Color(0xFF5B6BB5), deep: Color(0xFF36427A), tint: Color(0xFFECEEF9)),
  // Fresh paint.
  'painter': TradeColour(
    base: Color(0xFFD1478B), deep: Color(0xFF8C2557), tint: Color(0xFFFCEAF3)),
  // Timber.
  'carpenter': TradeColour(
    base: Color(0xFFA9732F), deep: Color(0xFF6E4818), tint: Color(0xFFF8EFE2)),
  // Brass.
  'locksmith': TradeColour(
    base: Color(0xFF8A7B3F), deep: Color(0xFF574C22), tint: Color(0xFFF4F1E4)),
  // Warm, for animals.
  'pet-care': TradeColour(
    base: Color(0xFFCE7A33), deep: Color(0xFF8B4C14), tint: Color(0xFFFBEEE2)),
  // Appliance enamel.
  'appliance-repair': TradeColour(
    base: Color(0xFF4E7D8C), deep: Color(0xFF2C505C), tint: Color(0xFFE9F2F5)),
  // Van.
  'removals': TradeColour(
    base: Color(0xFF6C63C4), deep: Color(0xFF423A88), tint: Color(0xFFEEECFA)),
  // Clean glass.
  'window-cleaning': TradeColour(
    base: Color(0xFF3FA9C9), deep: Color(0xFF1F6B84), tint: Color(0xFFE6F5FA)),
  // Salon.
  'hairdresser': TradeColour(
    base: Color(0xFFB2519E), deep: Color(0xFF702F63), tint: Color(0xFFF8EAF6)),
  // Polish.
  'beauty': TradeColour(
    base: Color(0xFFE05A78), deep: Color(0xFF9A2C45), tint: Color(0xFFFDEBEF)),
  // Calm.
  'massage': TradeColour(
    base: Color(0xFF7E63B8), deep: Color(0xFF4C3880), tint: Color(0xFFF1ECFA)),
};

/// The warm ground the whole app sits on.
///
/// Competitors all run a soft gradient rather than a flat fill, and it is most
/// of why their screens look lit rather than printed. Cheap to draw, and it
/// stops a long scroll feeling like a spreadsheet.
const yaariWash = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFF4EC), Color(0xFFF7F4EF)],
  stops: [0, 0.42],
);
