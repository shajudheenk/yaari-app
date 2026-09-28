import 'package:flutter/material.dart';

import '../marks.dart';
import 'category.dart';
import 'components.dart';
import 'tokens.dart';

/// Components that know about Yaari specifically: categories, professionals,
/// bookings, progress. The generic kit lives in components.dart; this is the
/// layer where the product's own vocabulary appears.

// ------------------------------------------------------------- category

/// A category tile.
///
/// White card, the mark on its category's own tinted field, name and price
/// beneath. The card stays white so fifteen of them read as one grid; the
/// colour arrives only in the mark's field, which is enough to make a
/// category findable at a glance without the screen turning into confetti.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.slug,
    required this.title,
    this.price,
    this.badge,
    this.onTap,
    this.heroTag,
  });

  final String slug;
  final String title;
  final String? price;

  /// "Popular", "New" — the one piece of merchandising a tile can carry
  /// without becoming cluttered.
  final String? badge;

  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(slug);

    Widget icon = YaariMark(slug, size: 50);
    if (heroTag != null) icon = Hero(tag: heroTag!, child: icon);

    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 14, 11, 12),
        decoration: BoxDecoration(
          color: Surface.raised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: c.tint, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: c.deep.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const Spacer(),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.tint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(badge!,
                        style: Txt.label
                            .copyWith(color: c.deep, fontSize: 9.5)),
                  ),
              ],
            ),
            const Spacer(),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.cardTitle
                    .copyWith(fontSize: 13.5, letterSpacing: -0.2)),
            if (price != null) ...[
              const SizedBox(height: 2),
              Text(price!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Txt.meta.copyWith(
                      fontSize: 11.5,
                      color: c.deep,
                      fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tradesperson, presented as a person rather than a row in a table.
///
/// Everyone on the list has already passed the compliance gate, so the card
/// leads with what actually differs between them — rating, jobs done,
/// distance, price — and states the checks once, quietly, at the foot.
class ProCard extends StatelessWidget {
  const ProCard({
    super.key,
    required this.name,
    required this.slug,
    this.bio,
    this.rating,
    this.ratingCount,
    this.jobsDone,
    this.distance,
    this.rate,
    this.photoUrl,
    this.selected = false,
    this.onTap,
    this.badges = const [],
  });

  final String name;
  final String slug;
  final String? bio;
  final double? rating;
  final int? ratingCount;
  final int? jobsDone;
  final String? distance;
  final String? rate;
  final String? photoUrl;
  final bool selected;
  final VoidCallback? onTap;

  /// Extra trust signals — "Fast response", "Repeat customers".
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(slug);

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.settle,
        decoration: BoxDecoration(
          color: Surface.raised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: selected ? c.base : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected ? Shade.tinted(c.base) : Shade.md,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Avatar(name, size: 52, photoUrl: photoUrl),
                      // The verified dot sits on the face, the way every
                      // marketplace marks a checked account.
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Surface.raised, shape: BoxShape.circle),
                          child: const Icon(Icons.verified_rounded,
                              size: 15, color: Signal.success),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Txt.cardTitle.copyWith(fontSize: 15.5)),
                            ),
                            if (rate != null)
                              Text(rate!, style: Txt.price.copyWith(
                                  fontSize: 15, color: c.deep)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (rating != null)
                              _Stat(
                                icon: Icons.star_rounded,
                                colour: const Color(0xFFE0A012),
                                text: ratingCount == null
                                    ? rating!.toStringAsFixed(1)
                                    : '${rating!.toStringAsFixed(1)} ($ratingCount)',
                              ),
                            if (jobsDone != null)
                              _Stat(
                                icon: Icons.check_circle_rounded,
                                colour: Signal.success,
                                text: '$jobsDone jobs',
                              ),
                            if (distance != null)
                              _Stat(
                                icon: Icons.near_me_rounded,
                                colour: Coal.c500,
                                text: distance!,
                              ),
                          ],
                        ),
                        if (bio != null) ...[
                          const SizedBox(height: Gap.sm),
                          Text(bio!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Txt.bodySm),
                        ],
                        if (badges.isNotEmpty) ...[
                          const SizedBox(height: Gap.sm),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final b in badges)
                                Pill(b, colour: c.deep, dense: true),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // The compliance line, said once and quietly, because it is true
            // of everyone here — shouting it on every card would devalue it.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg, vertical: 9),
              decoration: const BoxDecoration(
                color: Signal.successSoft,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(Radii.card - 2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded,
                      size: 13, color: Signal.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ID, insurance and trade registration checked today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.meta.copyWith(
                          color: const Color(0xFF14613C), fontSize: 11),
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.colour, required this.text});

  final IconData icon;
  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colour),
        const SizedBox(width: 3),
        Text(text,
            style: Txt.meta.copyWith(
                color: Coal.c700, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// --------------------------------------------------------------- service

/// One bookable job, with its scope and price.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.name,
    required this.price,
    required this.slug,
    this.description,
    this.duration,
    this.popular = false,
    this.fixedPrice = true,
    this.selected = false,
    this.onTap,
  });

  final String name;
  final String price;
  final String slug;
  final String? description;
  final String? duration;
  final bool popular;
  final bool fixedPrice;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(slug);

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.settle,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: selected ? c.tint : Surface.raised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
              color: selected ? c.base : Colors.transparent, width: 2),
          boxShadow: selected ? Shade.tinted(c.base) : Shade.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Txt.cardTitle.copyWith(fontSize: 15)),
                  if (description != null) ...[
                    const SizedBox(height: 3),
                    Text(description!, style: Txt.bodySm),
                  ],
                  const SizedBox(height: Gap.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (duration != null)
                        Pill(duration!,
                            icon: Icons.schedule_rounded,
                            colour: c.deep,
                            dense: true),
                      if (popular)
                        const Pill('Popular',
                            icon: Icons.trending_up_rounded,
                            tone: ChipTone.warning,
                            dense: true),
                      Pill(fixedPrice ? 'Fixed price' : 'Per hour',
                          tone: ChipTone.success, dense: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: Txt.price.copyWith(color: c.deep)),
                const SizedBox(height: Gap.sm),
                AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.settle,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? c.base : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? c.base : Coal.c200, width: 2),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- progress

/// Where you are in the booking journey.
///
/// Segmented rather than a single bar, because the segments are the steps —
/// a continuous bar tells you how far along you are but not how many
/// decisions are left, and the second is the anxious question.
class Steps extends StatelessWidget {
  const Steps({
    super.key,
    required this.step,
    required this.of,
    required this.label,
    this.colour,
  });

  final int step;
  final int of;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final c = colour ?? Brand.c500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= of; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.settle,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? c : c.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (i < of) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Text('STEP $step OF $of',
                style: Txt.label.copyWith(color: c, fontSize: 9.5)),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Txt.meta),
            ),
          ],
        ),
      ],
    );
  }
}

/// The bar pinned to the bottom of a booking step: the running price on the
/// left, what happens next on the right.
///
/// Pinning the figure means the price is never something you have to scroll
/// back to check — the single thing every booking funnel in this category
/// gets right.
class PriceBar extends StatelessWidget {
  const PriceBar({
    super.key,
    required this.caption,
    required this.price,
    this.wasPrice,
    required this.action,
    this.onAction,
    this.busy = false,
    this.colour,
    this.note,
  });

  final String caption;
  final String price;
  final String? wasPrice;
  final String action;
  final VoidCallback? onAction;
  final bool busy;
  final Color? colour;

  /// A line under the button — a cancellation promise, a payment note.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Surface.raised,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(Radii.panel)),
        boxShadow: Shade.lg,
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(caption, style: Txt.meta),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(price, style: Txt.priceLg.copyWith(fontSize: 26)),
                          if (wasPrice != null) ...[
                            const SizedBox(width: 7),
                            Text(wasPrice!,
                                style: Txt.body.copyWith(
                                    color: Coal.c400,
                                    decoration: TextDecoration.lineThrough)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.md),
                SizedBox(
                  width: 168,
                  child: Btn(action,
                      onTap: onAction, busy: busy, colour: colour),
                ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 13, color: Coal.c500),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note!, style: Txt.meta)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
