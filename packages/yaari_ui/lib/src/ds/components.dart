import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

// ---------------------------------------------------------------- press

/// Wraps anything tappable in a spring.
///
/// Compresses fast and releases with a little overshoot. It is the single
/// cheapest thing that separates an app which feels built from one which
/// feels assembled — every touch gets an answer with physics in it.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 330));

  late final Animation<double> _a = Tween<double>(begin: 1, end: widget.scale)
      .animate(CurvedAnimation(
          parent: _c, curve: Curves.easeOut, reverseCurve: Curves.elasticOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on == null ? null : (_) => _c.forward(),
      onTapUp: on == null ? null : (_) => _c.reverse(),
      onTapCancel: on == null ? null : () => _c.reverse(),
      onTap: on == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              on();
            },
      child: ScaleTransition(scale: _a, child: widget.child),
    );
  }
}

// --------------------------------------------------------------- buttons

enum BtnKind { primary, secondary, ghost, dark }

class Btn extends StatelessWidget {
  const Btn(
    this.label, {
    super.key,
    this.onTap,
    this.kind = BtnKind.primary,
    this.icon,
    this.busy = false,
    this.colour,
    this.full = true,
  });

  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final IconData? icon;
  final bool busy;

  /// Overrides the brand colour — used so a category screen's button carries
  /// that category's identity rather than breaking out of it.
  final Color? colour;

  final bool full;

  @override
  Widget build(BuildContext context) {
    final accent = colour ?? Brand.c500;
    final off = onTap == null || busy;

    late final Color bg, fg;
    Border? border;
    switch (kind) {
      case BtnKind.primary:
        bg = off ? Coal.c200 : accent;
        fg = off ? Coal.c400 : Colors.white;
      case BtnKind.dark:
        bg = off ? Coal.c200 : Coal.c900;
        fg = off ? Coal.c400 : Colors.white;
      case BtnKind.secondary:
        bg = Colors.white;
        fg = off ? Coal.c400 : accent;
        border = Border.all(
            color: off ? Coal.c200 : accent.withValues(alpha: 0.4), width: 1.5);
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = off ? Coal.c400 : accent;
    }

    return Pressable(
      onTap: off ? null : onTap,
      scale: 0.975,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.settle,
        width: full ? double.infinity : null,
        padding: EdgeInsets.symmetric(
            horizontal: full ? Gap.xl : Gap.lg, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: kind == BtnKind.primary && !off
              ? Shade.tinted(accent)
              : kind == BtnKind.dark && !off
                  ? Shade.md
                  : null,
        ),
        child: Row(
          mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
              )
            else ...[
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: Gap.sm),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.button.copyWith(color: fg)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- chips

enum ChipTone { neutral, brand, success, warning, danger, info, dark }

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.tone = ChipTone.neutral,
    this.icon,
    this.solid = false,
    this.colour,
    this.dense = false,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;
  final bool solid;

  /// Overrides the tone entirely, for category-coloured chips.
  final Color? colour;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = colour ??
        switch (tone) {
          ChipTone.neutral => Coal.c600,
          ChipTone.brand => Brand.c600,
          ChipTone.success => Signal.success,
          ChipTone.warning => Signal.warning,
          ChipTone.danger => Signal.danger,
          ChipTone.info => Signal.info,
          ChipTone.dark => Coal.c900,
        };

    return Container(
      padding: EdgeInsets.fromLTRB(
          icon == null ? (dense ? 8 : 10) : (dense ? 6 : 8),
          dense ? 3.5 : 5,
          dense ? 8 : 10,
          dense ? 3.5 : 5),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 12.5, color: solid ? Colors.white : c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: Face.text,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.1,
              color: solid ? Colors.white : c,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- cards

/// The standard raised surface. One radius, one shadow, one padding — so
/// every card in the app is visibly the same object.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.colour,
    this.gradient,
    this.radius = Radii.card,
    this.shadow,
    this.border,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? colour;
  final Gradient? gradient;
  final double radius;
  final List<BoxShadow>? shadow;
  final Border? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (colour ?? Surface.raised) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? Shade.md,
        border: border,
      ),
      child: child,
    );
    return onTap == null ? body : Pressable(onTap: onTap, child: body);
  }
}

// ---------------------------------------------------------------- avatar

/// Initials on a colour derived from the name.
///
/// Deterministic, so the same person is always the same colour — which makes
/// a returning tradesperson recognisable in a list before you read the name.
/// Real photographs slot in later without the layout moving.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 46, this.photoUrl});

  final String name;
  final double size;
  final String? photoUrl;

  static const _bank = [
    Color(0xFF3E6E8E), Color(0xFF8A5A3C), Color(0xFF4E7A52),
    Color(0xFF7A4E7E), Color(0xFF9A6A2A), Color(0xFF445E9A),
    Color(0xFF8A4550), Color(0xFF2F7069),
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Color get _colour =>
      _bank[name.codeUnits.fold<int>(0, (a, b) => a + b) % _bank.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colour,
        shape: BoxShape.circle,
        image: photoUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(photoUrl!), fit: BoxFit.cover),
      ),
      child: photoUrl != null
          ? null
          : Text(
              _initials,
              style: TextStyle(
                fontFamily: Face.text,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
    );
  }
}

// ------------------------------------------------------------ skeletons

/// A sweep of light across a placeholder.
///
/// A static grey block reads as broken; a moving one reads as loading. Same
/// cost, entirely different impression while the network is slow.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1250))
    ..repeat();

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
            begin: Alignment(-1.8 + _c.value * 3.6, 0),
            end: Alignment(-0.8 + _c.value * 3.6, 0),
            colors: const [Coal.c100, Surface.raised, Coal.c100],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- states

/// Empty, error and "nothing here yet" — designed rather than defaulted.
///
/// A consumer app is judged on these as much as the happy path, because the
/// first time anyone opens Bookings it is empty.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.tone = ChipTone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = switch (tone) {
      ChipTone.danger => Signal.danger,
      ChipTone.success => Signal.success,
      ChipTone.warning => Signal.warning,
      _ => Brand.c500,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xxl, vertical: Gap.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 33, color: c),
            ),
            const SizedBox(height: Gap.xl),
            Text(title, textAlign: TextAlign.center, style: Txt.title),
            const SizedBox(height: Gap.sm),
            Text(body, textAlign: TextAlign.center, style: Txt.body),
            if (action != null && onAction != null) ...[
              const SizedBox(height: Gap.xl),
              Btn(action!, onTap: onAction, kind: BtnKind.secondary,
                  full: false, colour: c),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- reveal

/// Content that rises into place instead of appearing.
///
/// Carries a failsafe: if the animation never runs — a throttled background
/// tab, a driver quirk — the child is shown anyway. Invisible content is a
/// far worse bug than an un-animated entrance.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.base);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
    // Failsafe: content must never be able to stay invisible.
    Future.delayed(widget.delay + const Duration(seconds: 2), () {
      if (mounted && _c.value == 0) _c.value = 1;
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Motion.enter);
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A figure that runs up to its value.
///
/// Used only where the number is the point of the screen — a total, a count
/// of people available. Everywhere else it would be noise.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 850),
  });

  final num value;
  final String Function(num) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: duration,
        curve: Motion.enter,
        builder: (context, v, _) => Text(format(v), style: style),
      );
}

// --------------------------------------------------------------- sheets

/// The app's bottom sheet.
///
/// Everything that is a choice rather than a destination happens here —
/// picking an area, a slot, a frequency. Sheets keep the user on the screen
/// they were reading, which is most of why modern apps feel less like
/// navigating a website.
Future<T?> showYaariSheet<T>(
  BuildContext context, {
  required Widget child,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Coal.c900.withValues(alpha: 0.42),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height *
              (expand ? 0.92 : 0.78),
        ),
        decoration: const BoxDecoration(
          color: Surface.canvas,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Coal.c200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    ),
  );
}

/// A sheet's own header: title, optional subtitle, close affordance.
class SheetHead extends StatelessWidget {
  const SheetHead({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.md, Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Txt.display.copyWith(fontSize: 22)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Txt.bodySm),
                ],
              ],
            ),
          ),
          Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                  color: Coal.c100, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 18, color: Coal.c700),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- headings

/// A section heading with an optional action on the right.
class SectionHead extends StatelessWidget {
  const SectionHead(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.trailing,
    this.light = false,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  /// Set when the heading sits on the brand field rather than on paper.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Text(title,
              style: Txt.section.copyWith(
                  color: light ? Colors.white : Coal.c900)),
          if (trailing != null) ...[
            const SizedBox(width: Gap.sm),
            trailing!,
          ],
          const Spacer(),
          if (action != null && onAction != null)
            Pressable(
              onTap: onAction,
              child: Row(
                children: [
                  Text(action!,
                      style: Txt.meta.copyWith(
                          color: light ? Colors.white : Brand.c600,
                          fontWeight: FontWeight.w800)),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: light ? Colors.white : Brand.c600),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
