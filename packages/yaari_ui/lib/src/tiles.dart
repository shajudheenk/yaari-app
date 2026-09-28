import 'package:flutter/material.dart';

import 'feel.dart';
import 'marks.dart';
import 'palette.dart';
import 'theme.dart';

/// A category tile: a white card floating on the brand field, the mark
/// centred, the name and price beneath.
///
/// This is the shape Pronto and Urban Company both land on, and the reason is
/// structural rather than cosmetic: when the ground carries the brand colour,
/// every tile can stay white, and a white card on colour reads as an object
/// you can pick up. Fifteen differently-coloured tiles compete with each
/// other; fifteen white ones with a coloured mark do not.
///
/// Presses with a spring — quick compression, release with a little
/// overshoot. That is the difference between a control that acknowledges you
/// and one that merely changes colour.
class YaariTile extends StatefulWidget {
  const YaariTile({
    super.key,
    required this.slug,
    required this.title,
    this.price,
    this.wasPrice,
    this.rating,
    this.ratingCount,
    this.onTap,
    this.heroTag,
  });

  final String slug;
  final String title;
  final String? price;

  /// Struck through beside the price when there is a saving to show.
  final String? wasPrice;

  /// Every competitor puts a rating on every tile, because in a marketplace
  /// the question is never "what is this" but "is it any good".
  final double? rating;
  final int? ratingCount;

  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  State<YaariTile> createState() => _YaariTileState();
}

class _YaariTileState extends State<YaariTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 340),
  );

  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.945)
      .animate(CurvedAnimation(
          parent: _c, curve: Curves.easeOut, reverseCurve: Curves.elasticOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = colourFor(widget.slug);

    Widget mark = YaariMark(widget.slug, size: 44, ink: c.deep, accent: c.base);
    if (widget.heroTag != null) {
      mark = Hero(tag: widget.heroTag!, child: mark);
    }

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      onTap: widget.onTap == null
          ? null
          : () {
              Buzz.pick();
              widget.onTap!();
            },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: YaariColors.ink.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The mark on its own tinted field — the only colour on the
              // card, which is what makes it the thing you see first.
              Center(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: mark,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.2,
                  color: YaariColors.ink,
                ),
              ),
              if (widget.rating != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFE8A317)),
                    const SizedBox(width: 2),
                    Text(
                      widget.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: YaariColors.ink,
                      ),
                    ),
                    if (widget.ratingCount != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        '(${widget.ratingCount})',
                        style: const TextStyle(
                            fontSize: 10.5, color: YaariColors.inkDim),
                      ),
                    ],
                  ],
                ),
              ],
              if (widget.price != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      widget.price!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: YaariColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (widget.wasPrice != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        widget.wasPrice!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: YaariColors.inkDim,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small coloured labels every app in this category uses to carry the
/// details that do not deserve a sentence — "Regular", "4h", "Available".
///
/// They are load-bearing, not decoration: a chip is how you fit six facts onto
/// a card without it becoming a paragraph.
class YaariBadge extends StatelessWidget {
  const YaariBadge(
    this.label, {
    super.key,
    this.colour,
    this.icon,
    this.solid = false,
  });

  final String label;
  final Color? colour;
  final IconData? icon;

  /// Filled rather than tinted, for the one chip on a card that should win.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = colour ?? YaariColors.ember;

    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 4.5, 9, 4.5),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: solid ? Colors.white : c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.1,
              color: solid ? Colors.white : c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbers that count up when they first appear.
///
/// A figure that lands already at its value is just text; one that runs up to
/// it reads as having been calculated. Used for earnings and totals, where the
/// number is the point of the screen.
class YaariCountUp extends StatelessWidget {
  const YaariCountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final num value;
  final String Function(num) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: YaariCurves.enter,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// A soft sweep of light across a placeholder while real content loads.
///
/// A static grey block says "broken"; a moving one says "coming". Same cost.
class YaariShimmer extends StatefulWidget {
  const YaariShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<YaariShimmer> createState() => _YaariShimmerState();
}

class _YaariShimmerState extends State<YaariShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.6 + _c.value * 3.2, 0),
            end: Alignment(-0.6 + _c.value * 3.2, 0),
            colors: const [
              Color(0xFFEDE7DC),
              Color(0xFFF8F5F0),
              Color(0xFFEDE7DC),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two ways to book, offered side by side before the catalogue.
///
/// Pronto and Wecasa both put this decision *before* the service list, and
/// both price the recurring option below the one-off. That ordering is the
/// point: it turns a standing arrangement from something you might discover
/// later into the default you were offered first.
class YaariBookingModes extends StatelessWidget {
  const YaariBookingModes({
    super.key,
    required this.onceLabel,
    required this.repeatLabel,
    this.repeatSaving,
    required this.onOnce,
    required this.onRepeat,
  });

  final String onceLabel;
  final String repeatLabel;

  /// "Save 15%" — shown on the repeat card only when there is a real
  /// discount configured, so the app never advertises a saving of nothing.
  final String? repeatSaving;

  final VoidCallback onOnce;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            icon: Icons.bolt_rounded,
            title: 'One-off',
            subtitle: onceLabel,
            colour: YaariColors.slate,
            onTap: onOnce,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _ModeCard(
            icon: Icons.event_repeat_rounded,
            title: 'Repeat',
            subtitle: repeatLabel,
            colour: YaariColors.good,
            badge: repeatSaving,
            onTap: onRepeat,
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colour,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color colour;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Buzz.pick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: YaariColors.ink.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: colour),
                ),
                const Spacer(),
                if (badge != null) YaariBadge(badge!, colour: YaariColors.good),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 11.5, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a price does and does not buy, as two ticked lists.
///
/// Lifted from Pronto, and the best single idea in any of these apps. Most
/// disputes in home services are not about quality — they are about scope,
/// somebody expecting the inside of the oven to be included. Saying so before
/// the booking costs one screen and removes the argument entirely.
class YaariScope extends StatelessWidget {
  const YaariScope({super.key, required this.includes, this.excludes = const []});

  final List<String> includes;
  final List<String> excludes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: YaariColors.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("WHAT'S INCLUDED",
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 9),
          for (final line in includes) _ScopeLine(line, included: true),
          if (excludes.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text('NOT INCLUDED',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 9),
            for (final line in excludes) _ScopeLine(line, included: false),
          ],
        ],
      ),
    );
  }
}

class _ScopeLine extends StatelessWidget {
  const _ScopeLine(this.text, {required this.included});

  final String text;
  final bool included;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: included ? YaariColors.good : const Color(0xFFC0433C),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: YaariColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
