import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

/// The story, told once, before sign-in.
///
/// Three screens, because Yaari has three things to say and each needs a
/// picture: what it is, why you can trust it, and what using it feels like.
/// Everything shown is something the product actually does — the live card on
/// the last page is the real booking screen's shape, not a promise.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    Buzz.pick();
    if (_index == _count - 1) {
      widget.onDone();
      return;
    }
    _pages.nextPage(duration: Motion.page, curve: Motion.settle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Warm.wash),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
                child: Row(
                  children: [
                    Text('yaari',
                        style: TextStyle(
                          fontFamily: Face.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          letterSpacing: -0.6,
                          color: Brand.c600,
                        )),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _index == _count - 1 ? 0 : 1,
                      duration: Motion.fast,
                      child: TextButton(
                        onPressed: _index == _count - 1 ? null : widget.onDone,
                        child: Text('Skip',
                            style: Txt.label.copyWith(color: Coal.c700)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _Page(
                      visual: _IconFan(active: _index == 0),
                      light: 'Help at home, ',
                      bold: 'from people we’ve checked.',
                      body: 'Cleaning, repairs, care, beauty and more — '
                          'twenty-four kinds of help, from one app.',
                    ),
                    _Page(
                      visual: _PromiseStack(active: _index == 1),
                      light: 'Verified. ',
                      bold: 'Every time.',
                      body: 'Licences, DBS and insurance are checked against '
                          'the issuing register — and re-checked every time '
                          'you search.',
                    ),
                    _Page(
                      visual: _LiveCard(active: _index == 2),
                      light: 'Book in a minute. ',
                      bold: 'Watch it happen.',
                      body: 'See who is coming and when, then confirm the '
                          'start and approve the finish yourself.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.md, Gap.page, Gap.lg),
                child: Column(
                  children: [
                    PageBars(
                        count: _count, index: _index, colour: Brand.c600),
                    const SizedBox(height: Gap.xl),
                    Btn(
                      _index == _count - 1 ? 'Get started' : 'Next',
                      icon: Icons.arrow_forward_rounded,
                      onTap: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.visual,
    required this.light,
    required this.bold,
    required this.body,
  });

  final Widget visual;
  final String light;
  final String bold;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        children: [
          Expanded(child: Center(child: visual)),
          Headline(light, bold,
              size: 30, align: TextAlign.center, boldColour: Brand.c600),
          const SizedBox(height: Gap.md),
          Text(body,
              textAlign: TextAlign.center,
              style: Txt.body.copyWith(fontSize: 15.5, color: Coal.c700)),
          const SizedBox(height: Gap.lg),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ visuals

/// Six trades rising into an arc, one after another, then drifting.
class _IconFan extends StatefulWidget {
  const _IconFan({required this.active});
  final bool active;

  @override
  State<_IconFan> createState() => _IconFanState();
}

class _IconFanState extends State<_IconFan> with TickerProviderStateMixin {
  late final _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..forward();
  late final _drift = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  static const _slugs = [
    'cleaner', 'care', 'electrician', 'cook', 'childcare', 'gardener',
  ];

  @override
  void didUpdateWidget(_IconFan old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _in.forward(from: 0);
  }

  @override
  void dispose() {
    _in.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 260,
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _drift]),
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < _slugs.length; i++)
              _placed(i, _slugs.length),
          ],
        ),
      ),
    );
  }

  Widget _placed(int i, int n) {
    // Positions on an arc, the middle two highest and largest.
    final angle = math.pi * (0.12 + 0.76 * i / (n - 1));
    final x = -math.cos(angle) * 118;
    final y = -math.sin(angle) * 78 + 40;
    final centre = 1 - (i - (n - 1) / 2).abs() / ((n - 1) / 2);
    final size = 56 + 18 * centre;

    final start = i / n * 0.5;
    final t = Curves.easeOutBack.transform(
        ((_in.value - start) / 0.5).clamp(0.0, 1.0));
    final drift = math.sin(_drift.value * 2 * math.pi + i) * 5;

    return Transform.translate(
      offset: Offset(x, y + (1 - t) * 60 + drift),
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: YaariMark(_slugs[i], size: size),
      ),
    );
  }
}

/// The promise, as cards that settle into a stack.
class _PromiseStack extends StatefulWidget {
  const _PromiseStack({required this.active});
  final bool active;

  @override
  State<_PromiseStack> createState() => _PromiseStackState();
}

class _PromiseStackState extends State<_PromiseStack>
    with SingleTickerProviderStateMixin {
  late final _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  static final _cards = [
    (GlyphFill.sealCheck, 'Care & family', 'Verified',
        'DBS, licences, certificates'),
    (GlyphFill.umbrella, 'Events & occasions', 'Insured',
        'Public liability, in date'),
    (GlyphFill.checkCircle, 'Hair & beauty', 'Two-sided',
        'You confirm start and finish'),
  ];

  @override
  void didUpdateWidget(_PromiseStack old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _in.forward(from: 0);
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active && !_in.isAnimating && _in.value == 0) _in.forward();
    return AnimatedBuilder(
      animation: _in,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _cards.length; i++)
            Builder(builder: (context) {
              final (glyph, family, title, sub) = _cards[i];
              final t = Curves.easeOutCubic.transform(
                  ((_in.value - i * 0.18) / 0.55).clamp(0.0, 1.0));
              return Transform.translate(
                offset: Offset((1 - t) * 80, 0),
                child: Opacity(
                  opacity: t,
                  child: Container(
                    width: 290,
                    margin: const EdgeInsets.only(bottom: Gap.md),
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Radii.card),
                      border: Border.all(color: Coal.c900, width: 1.6),
                    ),
                    child: Row(children: [
                      AppIcon(glyph: glyph, family: familyOf(family), size: 42),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title.toUpperCase(),
                                style: Txt.label.copyWith(
                                    color: Coal.c900, letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(sub, style: Txt.meta),
                          ],
                        ),
                      ),
                      const Icon(GlyphFill.checkCircle,
                          size: 20, color: Signal.success),
                    ]),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// A live job card with a countdown that really counts.
///
/// The shape of the booking-status screen: who, when, and the two buttons the
/// customer actually presses. The clock runs so the page feels alive.
class _LiveCard extends StatefulWidget {
  const _LiveCard({required this.active});
  final bool active;

  @override
  State<_LiveCard> createState() => _LiveCardState();
}

class _LiveCardState extends State<_LiveCard> {
  int _seconds = 24 * 60;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.active) {
        setState(() => _seconds = _seconds > 60 ? _seconds - 1 : 24 * 60);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = _seconds ~/ 60;
    final s = (_seconds % 60).toString().padLeft(2, '0');

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.panel),
        boxShadow: [
          BoxShadow(
            color: Brand.c700.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: const BoxDecoration(gradient: Warm.hero),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(GlyphFill.clockCountdown,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('STARTS IN',
                          style: Txt.label.copyWith(
                              color: Colors.white, letterSpacing: 1.2)),
                    ]),
                    const SizedBox(height: 2),
                    Text('$m:$s',
                        style: TextStyle(
                          fontFamily: Face.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 38,
                          height: 1,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chip('On the way', filled: true),
                    const SizedBox(height: 6),
                    _Chip('Message'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                Row(children: [
                  const YaariMark('cleaner', size: 40),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Regular clean · 2 bedrooms',
                            style: Txt.cardTitle.copyWith(fontSize: 14)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: Tier.gold.medal),
                          ),
                          const SizedBox(width: 5),
                          Text('Gold pro · rated 4.9',
                              style: Txt.meta),
                        ]),
                      ],
                    ),
                  ),
                  Text('£70', style: Txt.price),
                ]),
                const SizedBox(height: Gap.md),
                Row(children: [
                  const Icon(GlyphFill.checkCircle,
                      size: 16, color: Signal.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('You confirm the start. You approve the finish.',
                        style: Txt.meta.copyWith(color: Coal.c700)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.filled = false});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white, width: 1.4),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: Txt.label.copyWith(
                fontSize: 11, color: filled ? Brand.c600 : Colors.white)),
      );
}
