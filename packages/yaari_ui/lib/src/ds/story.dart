import 'package:flutter/material.dart';

import 'tokens.dart';

/// The warm ground the story is told on.
///
/// Ivory into blush into coral, the colour of late sun on a wall. It is what
/// makes a home-services app feel like it is about homes: warm where the
/// previous greys and whites felt clinical. Crimson is kept for action.
class Warm {
  static const ivory = Color(0xFFFFF8F2);
  static const cream = Color(0xFFFFEFE4);
  static const blush = Color(0xFFFFD9C8);
  static const peach = Color(0xFFFFB597);
  static const coral = Color(0xFFF26B4E);

  /// Top-to-bottom wash for story screens and heroes.
  static const wash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ivory, cream, blush, peach],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  /// The hero: crimson at the top-left, burning out to coral and peach.
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Brand.c600, Brand.c500, coral, Color(0xFFF79A6E)],
    stops: [0.0, 0.35, 0.78, 1.0],
  );
}

/// A two-weight uppercase headline: "SELECT **YOUR SERVICES**".
///
/// The lighter half sets up, the heavier half lands. It is the single most
/// recognisable thing about how Wecasa talks, and it works because it reads
/// like a sentence someone said with emphasis rather than a label.
class Headline extends StatelessWidget {
  const Headline(
    this.light,
    this.bold, {
    super.key,
    this.colour = Coal.c900,
    this.size = 26,
    this.align = TextAlign.start,
    this.boldColour,
  });

  final String light;
  final String bold;
  final Color colour;
  final Color? boldColour;
  final double size;
  final TextAlign align;

  /// Splits a plain title so its last word carries the weight:
  /// "Help at home" becomes HELP AT **HOME**.
  factory Headline.of(String title,
      {Key? key, Color colour = Coal.c900, double size = 20, Color? boldColour}) {
    final i = title.lastIndexOf(' ');
    return Headline(
      i < 0 ? '' : title.substring(0, i + 1),
      i < 0 ? title : title.substring(i + 1),
      key: key,
      colour: colour,
      size: size,
      boldColour: boldColour,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: Face.text,
      fontSize: size,
      height: 1.08,
      letterSpacing: size * 0.01,
      color: colour,
    );
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: light.toUpperCase(),
            style: base.copyWith(fontWeight: FontWeight.w500)),
        TextSpan(
            text: bold.toUpperCase(),
            style: base.copyWith(
                fontWeight: FontWeight.w800,
                color: boldColour ?? colour)),
      ]),
      textAlign: align,
    );
  }
}

/// An outlined card with its label set into the top border.
///
/// Wecasa's "advantages" card. Graphic rather than soft: a dark outline and
/// a pill that breaks it, which reads as confident where another drop-shadowed
/// white card would read as more of the same.
class NotchCard extends StatelessWidget {
  const NotchCard({
    super.key,
    required this.label,
    required this.body,
    this.leading,
    this.ink = Coal.c900,
    this.fill = Colors.white,
  });

  final String label;
  final String body;
  final Widget? leading;
  final Color ink;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.fromLTRB(Gap.lg, 26, Gap.lg, Gap.lg),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: ink, width: 1.6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: Gap.md),
              ],
              Expanded(
                child: Text(body,
                    style: Txt.body.copyWith(
                        fontSize: 14.5, height: 1.4, color: ink)),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: ink, width: 1.6),
              ),
              child: Text(label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: Face.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.8,
                    color: ink,
                  )),
            ),
          ),
        ),
      ],
    );
  }
}

/// A status dot that breathes. Says "this is live" without a word.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.colour = const Color(0xFF34D399), this.size = 8});

  final Color colour;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          Container(
            width: s * (1 + 1.4 * _t.value),
            height: s * (1 + 1.4 * _t.value),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.colour.withValues(alpha: 0.45 * (1 - _t.value)),
            ),
          ),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: widget.colour),
          ),
        ]),
      ),
    );
  }
}

/// Page position as short bars, the active one long. Used under the story
/// and the promise carousel.
class PageBars extends StatelessWidget {
  const PageBars({
    super.key,
    required this.count,
    required this.index,
    this.colour = Coal.c900,
  });

  final int count;
  final int index;
  final Color colour;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.settle,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? colour : colour.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      );
}
