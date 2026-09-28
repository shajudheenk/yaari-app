import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../booking.dart';
import '../data.dart';
import '../place.dart';
import '../plan.dart';
import 'area_picker.dart';
import 'booking_status.dart';
import 'notifications.dart';
import 'search.dart';
import 'service_detail.dart';

/// Explore.
///
/// Structured the way a consumer marketplace is: a greeting that knows who
/// you are and where you are, one prominent way to search, anything already
/// in flight lifted to the top, then categories grouped into families you can
/// scan rather than a flat wall of fifteen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.place,
    required this.onOpenAccount,
    required this.onOpenBookings,
  });

  final YaariAuth auth;
  final Place place;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenBookings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Trade>> _trades;
  CatalogueSearch? _catalogue;

  /// Distinct compliant people reachable from here, counted from the gate on
  /// every load. A fact, not a marketing figure.
  int? _checked;

  /// Anything already running. If there is a job in flight it is the only
  /// thing the customer opened the app to see, so it goes above everything.
  BookingSummary? _live;

  String? _planSaving;

  @override
  void initState() {
    super.initState();
    _trades = Api.trades();
    _warmSearch();
    _countSupply();
    _loadLive();
    _loadSaving();
    widget.place.addListener(_onAreaChanged);
  }

  @override
  void dispose() {
    widget.place.removeListener(_onAreaChanged);
    super.dispose();
  }

  void _onAreaChanged() {
    if (!mounted) return;
    setState(() => _checked = null);
    _countSupply();
  }

  Future<void> _warmSearch() async {
    try {
      final c = await CatalogueSearch.load();
      if (mounted) setState(() => _catalogue = c);
    } catch (_) {/* search loads it itself when opened */}
  }

  Future<void> _loadLive() async {
    try {
      final all = await BookingApi.myBookings();
      final live = all.where((b) => b.isLive).toList();
      if (mounted) {
        setState(() => _live = live.isEmpty ? null : live.first);
      }
    } catch (_) {/* the card simply does not appear */}
  }

  Future<void> _loadSaving() async {
    try {
      final bps = await PlanApi.discountBps();
      if (mounted && bps > 0) {
        setState(() => _planSaving = 'Save ${(bps / 100).round()}%');
      }
    } catch (_) {/* the badge is optional */}
  }

  /// Distinct people, not trade-slots: somebody doing two trades is one
  /// checked person, and inflating it would make the figure a lie.
  Future<void> _countSupply() async {
    try {
      final trades = await _trades;
      final ids = <String>{};
      await Future.wait(trades.map((t) async {
        try {
          for (final p in await Api.nearby(t.slug)) {
            ids.add(p.userId);
          }
        } catch (_) {/* one trade failing must not blank the count */}
      }));
      if (mounted) setState(() => _checked = ids.length);
    } catch (_) {/* leave it off rather than show a number we doubt */}
  }

  Future<void> _reload() async {
    setState(() {
      _trades = Api.trades();
      _checked = null;
    });
    await _trades;
    _warmSearch();
    _countSupply();
    _loadLive();
  }

  void _openSearch() {
    Navigator.of(context)
        .go((_) => SearchScreen(catalogue: _catalogue, place: widget.place));
  }

  void _openTrade(Trade t) {
    Navigator.of(context)
        .go((_) => ServiceDetailScreen(trade: t, place: widget.place));
  }

  @override
  Widget build(BuildContext context) {
    // The brand colour is the ground, not an accent. This is the one
    // structural decision that separates a consumer marketplace from a
    // settings screen: when the field carries the brand, every card on it
    // can stay white and the whole app reads as one product.
    return Scaffold(
      backgroundColor: Warm.ivory,
      body: RefreshIndicator(
        onRefresh: _reload,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: FutureBuilder<List<Trade>>(
          future: _trades,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _HomeSkeleton();
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 120),
                StateView(
                  icon: Icons.wifi_off_rounded,
                  title: 'No connection',
                  body: 'We could not reach Yaari. Check your signal and '
                      'pull down to try again.',
                  tone: ChipTone.danger,
                  action: 'Try again',
                  onAction: _reload,
                ),
              ]);
            }

            final trades = snap.data ?? [];
            final bySlug = {for (final t in trades) t.slug: t};

            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _Greeting(
                  place: widget.place,
                  checked: _checked,
                  onSearch: _openSearch,
                  onChangeArea: () => showAreaPicker(context, widget.place),
                  onNotifications: () => Navigator.of(context)
                      .go((_) => const NotificationsScreen()),
                  onAccount: widget.onOpenAccount,
                ),


                // Anything in flight outranks the whole catalogue.
                if (_live != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, Gap.xl),
                      child: Reveal(
                        delay: const Duration(milliseconds: 60),
                        child: _LiveStrip(
                          booking: _live!,
                          onTap: () async {
                            await Navigator.of(context).go((_) =>
                                BookingStatusScreen(bookingId: _live!.id));
                            _loadLive();
                          },
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Reveal(
                    delay: const Duration(milliseconds: 80),
                    child: _Popular(
                      trades: [
                        for (final slug in const [
                          'cleaner', 'electrician', 'care', 'plumber',
                          'hairdresser', 'cook',
                        ])
                          if (bySlug[slug] != null) bySlug[slug]!,
                      ],
                      onOpen: _openTrade,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, 0, Gap.page, Gap.xxl),
                    child: Reveal(
                      delay: const Duration(milliseconds: 100),
                      child: _ModeCards(
                        saving: _planSaving,
                        onOnce: _openSearch,
                        onRepeat: _openSearch,
                      ),
                    ),
                  ),
                ),

                // Grouped into families. Fifteen tiles in one block is a
                // directory; three named groups is a menu.
                for (final (gi, group) in categoryGroups.indexed) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, 0),
                      child: Reveal(
                        delay: Duration(milliseconds: 140 + gi * 40),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Gap.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Headline.of(group.$1,
                                    size: 19,
                                    boldColour: familyOf(group.$1).deep),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: familyOf(group.$1).tint,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${group.$2.where(bySlug.containsKey).length}',
                                  style: Txt.label.copyWith(
                                      color: familyOf(group.$1).deep),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, 0, Gap.page, Gap.xxl),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: Gap.md,
                        crossAxisSpacing: Gap.md,
                        // A fixed height, not an aspect ratio: the tile's
                        // content is a fixed height, and a ratio clipped the
                        // price line on narrow phones.
                        mainAxisExtent: 136,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final t = bySlug[
                              group.$2.where(bySlug.containsKey).elementAt(i)]!;
                          return Reveal(
                            delay: Duration(
                                milliseconds: 160 + gi * 40 + (i ~/ 3) * 45),
                            child: CategoryTile(
                              slug: t.slug,
                              title: t.shortName,
                              price: t.fromPence == null
                                  ? null
                                  : 'from ${formatRate(t.fromPence!, t.fromUnit ?? 'job')}',
                              heroTag: 'cat-${t.id}',
                              onTap: () => _openTrade(t),
                            ),
                          );
                        },
                        childCount: group.$2.where(bySlug.containsKey).length,
                      ),
                    ),
                  ),
                ],

                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(0, Gap.sm, 0, 120),
                  sliver: SliverToBoxAdapter(child: _Promise()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The header: who, where, and how many people are actually available.
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.place,
    required this.checked,
    required this.onSearch,
    required this.onChangeArea,
    required this.onNotifications,
    required this.onAccount,
  });

  final Place place;
  final int? checked;
  final VoidCallback onSearch;
  final VoidCallback onChangeArea;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;

  String get _salutation {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// The hero. Crimson burning out to coral, the headline said with emphasis,
  /// and search inside it — the one thing to do on arrival, placed where the
  /// eye already is.
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: Gap.xl),
        decoration: const BoxDecoration(
          gradient: Warm.hero,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Gap.page, Gap.md, Gap.page, Gap.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: onChangeArea,
                        scale: 0.98,
                        child: AnimatedBuilder(
                          animation: place,
                          builder: (context, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(GlyphFill.mapPin,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Txt.meta.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13),
                                ),
                              ),
                              const Icon(Icons.expand_more_rounded,
                                  size: 17, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _IconBtn(
                        icon: Icons.notifications_none_rounded,
                        onTap: onNotifications),
                    const SizedBox(width: Gap.sm),
                    _IconBtn(
                        icon: Icons.person_outline_rounded, onTap: onAccount),
                  ],
                ),
                const SizedBox(height: Gap.xl),
                Reveal(
                  child: Text(_salutation.toUpperCase(),
                      style: Txt.label.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 1.6)),
                ),
                const SizedBox(height: 6),
                const Reveal(
                  delay: Duration(milliseconds: 40),
                  child: Headline('Everything at home, ', 'handled.',
                      colour: Colors.white, size: 32),
                ),
                const SizedBox(height: Gap.xl),
                Reveal(
                  delay: const Duration(milliseconds: 80),
                  child: _SearchField(onTap: onSearch),
                ),
                if (checked != null) ...[
                  const SizedBox(height: Gap.lg),
                  Reveal(
                    delay: const Duration(milliseconds: 120),
                    child: Row(
                      children: [
                        const LiveDot(colour: Color(0xFFB9F6CA)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: CountUp(
                            value: checked!,
                            format: (v) =>
                                '${v.round()} verified pros near you right now',
                            style: Txt.meta.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The most booked trades, as full-colour cards you can swipe.
///
/// The App Store "Today" move: a colour field with the object large and the
/// words on top. It is the one place on the screen where colour is allowed to
/// be loud, which is exactly why the grid below can afford to be calm.
class _Popular extends StatelessWidget {
  const _Popular({required this.trades, required this.onOpen});

  final List<Trade> trades;
  final ValueChanged<Trade> onOpen;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
          child: Headline('Most ', 'booked', size: 19),
        ),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 14),
            itemCount: trades.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
            itemBuilder: (context, i) {
              final t = trades[i];
              final c = categoryOf(t.slug);
              final glyph = YaariMark.iconFor(t.slug);
              return Pressable(
                onTap: () => onOpen(t),
                scale: 0.96,
                child: Container(
                  width: 142,
                  decoration: BoxDecoration(
                    gradient: c.iconFill,
                    borderRadius: BorderRadius.circular(Radii.panel),
                    boxShadow: [
                      BoxShadow(
                        color: c.deep.withValues(alpha: 0.30),
                        blurRadius: 18,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // The glyph, huge and cropped, as texture.
                      if (glyph != null)
                        Positioned(
                          right: -22,
                          bottom: -18,
                          child: Icon(glyph,
                              size: 118,
                              color: Colors.white.withValues(alpha: 0.22)),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(Gap.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(glyph ?? GlyphFill.house,
                                  size: 20, color: Colors.white),
                            ),
                            const Spacer(),
                            Text(t.shortName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Txt.cardTitle.copyWith(
                                    color: Colors.white, fontSize: 16)),
                            if (t.fromPence != null)
                              Text(
                                  'from ${formatRate(t.fromPence!, t.fromUnit ?? 'job')}',
                                  style: Txt.meta.copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.lg),
        decoration: BoxDecoration(
          color: Surface.raised,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: Shade.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 21, color: Brand.c500),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text('Leaking tap, haircut, deep clean…',
                  style: Txt.bodySm.copyWith(fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Brand.c50,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.tune_rounded, size: 15, color: Brand.c600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact live-booking strip. The full experience lives on the status
/// screen; this is the doorway to it.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.booking, required this.onTap});

  final BookingSummary booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Coal.c900,
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: Shade.lg,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Brand.c500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.bolt_rounded,
                  size: 19, color: Brand.c300),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusStrip(
                      label: booking.statusLabel,
                      tone: ChipTone.success,
                      live: true),
                  const SizedBox(height: 5),
                  Text(booking.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.cardTitle.copyWith(color: Colors.white)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: Coal.c400),
          ],
        ),
      ),
    );
  }
}

/// One-off or standing arrangement, offered before the catalogue.
///
/// Putting this decision first is what turns a repeat plan from something
/// discovered later into the option you were shown at the start.
class _ModeCards extends StatelessWidget {
  const _ModeCards({
    required this.saving,
    required this.onOnce,
    required this.onRepeat,
  });

  final String? saving;
  final VoidCallback onOnce;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Mode(
            icon: GlyphFill.lightning,
            family: familyOf('Events & occasions'),
            title: 'One-off',
            body: 'A single visit, booked for when you need it',
            onTap: onOnce,
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: _Mode(
            icon: GlyphFill.repeat,
            family: familyOf('Outdoors & moving'),
            title: 'Repeat',
            body: 'Same person, same slot, every week',
            badge: saving,
            onTap: onRepeat,
          ),
        ),
      ],
    );
  }
}

class _Mode extends StatelessWidget {
  const _Mode({
    required this.icon,
    required this.family,
    required this.title,
    required this.body,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Category family;
  final String title;
  final String body;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(glyph: icon, family: family, size: 38),
              const Spacer(),
              if (badge != null)
                Pill(badge!, tone: ChipTone.success, dense: true),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(title, style: Txt.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 3),
          Text(body, style: Txt.meta, maxLines: 2),
        ],
      ),
    );
  }
}

/// The Yaari promise, told as a story you can swipe.
///
/// This is what Yaari actually is and nobody else in the market does: the
/// credential gate, the two-sided handshake, the insured window, the record.
/// It was one dark paragraph at the bottom of the screen. Now it is four
/// cards that turn over on their own.
class _Promise extends StatefulWidget {
  const _Promise();

  @override
  State<_Promise> createState() => _PromiseState();
}

class _PromiseState extends State<_Promise> {
  final _pages = PageController(viewportFraction: 0.88);
  int _index = 0;
  Timer? _auto;

  // Every line here is something the product enforces today. The chest-
  // camera recording and a platform insurance policy are planned, not live,
  // and go on this card when they are — a promise on the home screen that
  // the product does not keep is worse than no promise.
  static final _items = [
    (
      'Verified',
      GlyphFill.sealCheck,
      'Care & family',
      'Every licence, DBS and certificate is checked against the issuing '
          'register. If one lapses, that person leaves search the same day.',
    ),
    (
      'Insured',
      GlyphFill.umbrella,
      'Events & occasions',
      'Every professional holds their own public liability insurance, '
          'verified and in date — without it, they cannot be booked.',
    ),
    (
      'Two-sided',
      GlyphFill.checkCircle,
      'Hair & beauty',
      'Nobody starts or finishes a job alone. You confirm the start and you '
          'approve the finish, and both moments are stamped on the booking.',
    ),
    (
      'Supported',
      GlyphFill.headset,
      'Outdoors & moving',
      'One tap from any job to report a problem or raise an alarm. Every '
          'report is logged and followed up by our safety team.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pages.hasClients) return;
      final next = (_index + 1) % _items.length;
      _pages.animateToPage(next,
          duration: Motion.slow, curve: Motion.settle);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Headline('The Yaari ', 'promise',
                size: 22, boldColour: Brand.c600),
          ),
        ),
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _pages,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final (label, glyph, family, body) = _items[i];
              return Padding(
                padding: const EdgeInsets.only(right: Gap.md),
                child: NotchCard(
                  label: label,
                  body: body,
                  leading: AppIcon(
                      glyph: glyph, family: familyOf(family), size: 40),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Gap.sm),
        PageBars(count: _items.length, index: _index, colour: Brand.c500),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.huge),
        children: [
          const Skeleton(width: 120, height: 14),
          const SizedBox(height: Gap.lg),
          const Skeleton(width: 220, height: 32),
          const SizedBox(height: Gap.xl),
          const Skeleton(height: 54, radius: Radii.button),
          const SizedBox(height: Gap.xl),
          Row(children: const [
            Expanded(child: Skeleton(height: 108, radius: Radii.card)),
            SizedBox(width: Gap.md),
            Expanded(child: Skeleton(height: 108, radius: Radii.card)),
          ]),
          const SizedBox(height: Gap.xxl),
          const Skeleton(width: 140, height: 18),
          const SizedBox(height: Gap.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: Gap.md,
              crossAxisSpacing: Gap.md,
              mainAxisExtent: 136,
            ),
            itemCount: 6,
            itemBuilder: (_, __) =>
                const Skeleton(height: 120, radius: Radii.card),
          ),
        ],
      ),
    );
  }
}
