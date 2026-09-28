import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'feel.dart';
import 'theme.dart';

/// A catalogue photograph.
///
/// The database stores paths, not absolute URLs, so the same rows work against
/// a staging project or a self-hosted instance without a data migration.
/// [YaariPhoto] joins the path to whichever backend the app was built against.
class YaariPhoto extends StatelessWidget {
  const YaariPhoto({
    super.key,
    required this.path,
    required this.baseUrl,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
  });

  final String? path;
  final String baseUrl;
  final BoxFit fit;
  final IconData fallbackIcon;

  String? get _url {
    final p = path;
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return '$baseUrl$p';
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return _Placeholder(icon: fallbackIcon);

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 260),
      fadeInCurve: Curves.easeOut,
      placeholder: (_, __) => const _Shimmer(),
      // A missing photograph must never look like a broken app: the tile keeps
      // its shape and shows the trade's icon instead.
      errorWidget: (_, __, ___) => _Placeholder(icon: fallbackIcon),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: YaariColors.slateTint,
        child: Center(
          child: Icon(icon, size: 24, color: YaariColors.slate.withValues(alpha: 0.55)),
        ),
      );
}

/// A slow sweep across the empty tile while the photograph downloads, so a
/// slow connection reads as loading rather than as nothing happening.
class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Someone who has asked for less motion gets the flat tile, not the sweep.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const ColoredBox(color: YaariColors.slateTint);
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.6 + _c.value * 3.2, -0.4),
            end: Alignment(-0.6 + _c.value * 3.2, 0.4),
            colors: const [
              YaariColors.slateTint,
              Color(0xFFF3FAFB),
              YaariColors.slateTint,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Fades and lifts its child into place once, shortly after first build.
///
/// Used to stagger a grid so it assembles rather than appearing all at once.
/// Honours the platform's reduce-motion setting.
class YaariReveal extends StatefulWidget {
  const YaariReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<YaariReveal> createState() => _YaariRevealState();
}

class _YaariRevealState extends State<YaariReveal> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 420);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duration,
  );

  Timer? _start;
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });

    // An entrance animation must never be the only thing standing between the
    // reader and the content. A ticker can be starved — a backgrounded tab, a
    // muted TickerMode, a device under load — and an opacity that starts at
    // zero would then leave the screen permanently blank. If the animation has
    // not finished by the time it should have, the content is simply shown.
    _failsafe = Timer(widget.delay + _duration + const Duration(seconds: 1), () {
      if (mounted && !_c.isCompleted) _c.value = 1;
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _failsafe?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;

    final curve = CurvedAnimation(parent: _c, curve: YaariCurves.enter);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Shrinks slightly while held, the way a physical button gives, and taps
/// back through the glass when released.
class YaariPressable extends StatefulWidget {
  const YaariPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Off for anything that already fires its own, heavier feedback, so a
  /// single action never buzzes twice.
  final bool haptic;

  @override
  State<YaariPressable> createState() => _YaariPressableState();
}

class _YaariPressableState extends State<YaariPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        if (widget.haptic) Buzz.tap();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: YaariCurves.enter,
        child: widget.child,
      ),
    );
  }
}
