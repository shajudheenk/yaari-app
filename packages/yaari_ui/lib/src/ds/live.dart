import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'components.dart';
import 'tokens.dart';

/// The live-booking language: the dark hero card, the animated timeline, and
/// the success moment.
///
/// These carry the most emotional weight in the app. Everything before them
/// is a shop; this is the part where somebody is coming to your house, and it
/// should feel like being looked after rather than like a status field.

/// The card that dominates a booking in flight.
///
/// Dark, so it separates completely from the pale browsing surfaces and reads
/// as "something is happening now". A slow aurora drifts behind it — subtle
/// enough that you notice it only as the screen feeling awake.
class LiveCard extends StatefulWidget {
  const LiveCard({
    super.key,
    required this.status,
    required this.headline,
    this.detail,
    this.eta,
    this.proName,
    this.proPhotoUrl,
    this.actions = const [],
    this.accent,
  });

  /// The short state word — "On the way", "Working".
  final String status;

  /// The sentence that actually answers "what is happening".
  final String headline;

  final String? detail;
  final String? eta;
  final String? proName;
  final String? proPhotoUrl;
  final List<Widget> actions;
  final Color? accent;

  @override
  State<LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<LiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 9))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? Brand.c400;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.panel),
      child: Stack(
        children: [
          // The ground, plus a slowly wandering glow. Motion this slow does
          // not read as animation — it reads as the surface being alive.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * 2 * math.pi;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(math.cos(t) * 0.7, math.sin(t) * 0.5 - 0.3),
                      radius: 1.25,
                      colors: [
                        accent.withValues(alpha: 0.38),
                        Coal.c900,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const _Beacon(),
                    const SizedBox(width: Gap.sm),
                    Text(widget.status.toUpperCase(),
                        style: Txt.label.copyWith(color: Colors.white)),
                    const Spacer(),
                    if (widget.eta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(Radii.chip),
                        ),
                        child: Text(widget.eta!,
                            style: Txt.meta.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Text(widget.headline,
                    style: Txt.display.copyWith(
                        color: Colors.white, fontSize: 25)),
                if (widget.detail != null) ...[
                  const SizedBox(height: Gap.sm),
                  Text(widget.detail!,
                      style: Txt.body.copyWith(color: Coal.c300)),
                ],
                if (widget.proName != null) ...[
                  const SizedBox(height: Gap.xl),
                  Row(
                    children: [
                      Avatar(widget.proName!,
                          size: 42, photoUrl: widget.proPhotoUrl),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.proName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Txt.cardTitle.copyWith(
                                    color: Colors.white)),
                            Text('Your professional',
                                style: Txt.meta.copyWith(color: Coal.c400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.actions.isNotEmpty) ...[
                  const SizedBox(height: Gap.xl),
                  Row(
                    children: [
                      for (var i = 0; i < widget.actions.length; i++) ...[
                        Expanded(child: widget.actions[i]),
                        if (i < widget.actions.length - 1)
                          const SizedBox(width: Gap.md),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pulsing dot that means "this is live, not a snapshot".
class _Beacon extends StatefulWidget {
  const _Beacon();

  @override
  State<_Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<_Beacon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            // The ring expands and fades, like a radar return.
            Container(
              width: 4 + _c.value * 8,
              height: 4 + _c.value * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4ADE80)
                    .withValues(alpha: (1 - _c.value) * 0.55),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF4ADE80)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One stage of a booking.
class Stage {
  const Stage({
    required this.title,
    this.detail,
    required this.state,
    this.icon,
  });

  final String title;
  final String? detail;
  final StageState state;
  final IconData? icon;
}

enum StageState { done, active, waiting, failed }

/// The booking timeline.
///
/// The active stage is drawn larger and carries the beacon, so a glance at
/// the screen answers "where is this up to" before any reading happens. The
/// connecting rail fills as stages complete.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.stages, this.accent});

  final List<Stage> stages;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? Brand.c500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++)
          _StageRow(
            stage: stages[i],
            accent: c,
            first: i == 0,
            last: i == stages.length - 1,
          ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.accent,
    required this.first,
    required this.last,
  });

  final Stage stage;
  final Color accent;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = stage.state == StageState.done;
    final active = stage.state == StageState.active;
    final failed = stage.state == StageState.failed;

    final dotColour = failed
        ? Signal.danger
        : done
            ? Signal.success
            : active
                ? accent
                : Coal.c200;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: Motion.base,
                curve: Motion.spring,
                width: active ? 28 : 22,
                height: active ? 28 : 22,
                decoration: BoxDecoration(
                  color: done || active || failed
                      ? dotColour
                      : Surface.raised,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColour, width: 2),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 2),
                        ]
                      : null,
                ),
                child: Icon(
                  failed
                      ? Icons.close_rounded
                      : done
                          ? Icons.check_rounded
                          : stage.icon ?? Icons.circle,
                  size: active ? 15 : 12,
                  color: done || active || failed ? Colors.white : Coal.c300,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: done ? Signal.success : Coal.c200,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Gap.xl, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: Txt.cardTitle.copyWith(
                      fontSize: active ? 15 : 14,
                      color: stage.state == StageState.waiting
                          ? Coal.c400
                          : Coal.c900,
                    ),
                  ),
                  if (stage.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(stage.detail!, style: Txt.meta),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The moment a booking is confirmed.
///
/// A tick that draws itself, once, with a ring behind it. Deliberately the
/// only celebratory animation in the app — if everything congratulates you,
/// nothing does.
class SuccessMark extends StatefulWidget {
  const SuccessMark({super.key, this.size = 88, this.colour});

  final double size;
  final Color? colour;

  @override
  State<SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<SuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colour ?? Signal.success;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ring = Curves.easeOutCubic.transform(
              (_c.value / 0.55).clamp(0.0, 1.0));
          final tick = Curves.easeOutBack.transform(
              ((_c.value - 0.35) / 0.65).clamp(0.0, 1.0));
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ring,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Transform.scale(
                scale: tick,
                child: Container(
                  width: widget.size * 0.56,
                  height: widget.size * 0.56,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      size: widget.size * 0.32, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The compact status strip used on a booking row in a list.
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.label,
    required this.tone,
    this.live = false,
  });

  final String label;
  final ChipTone tone;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = switch (tone) {
      ChipTone.success => Signal.success,
      ChipTone.warning => Signal.warning,
      ChipTone.danger => Signal.danger,
      ChipTone.info => Signal.info,
      ChipTone.brand => Brand.c600,
      _ => Coal.c500,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            const _Beacon(),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: Txt.meta.copyWith(
                  color: c, fontWeight: FontWeight.w800, fontSize: 11.5)),
        ],
      ),
    );
  }
}
