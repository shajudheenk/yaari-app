import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import '../place.dart';
import 'confirm_booking.dart';

/// Who can take this job — on a map.
///
/// The list comes from `map_providers()`, which filters on live credential
/// validity, so everyone drawn here has already passed the gate. What differs
/// between them is where they are, how proven they are, and what they cost,
/// and the screen is built around exactly those three: position on the map,
/// a Gold / Silver / Bronze medal, and the price on the pin.
///
/// Pins are neighbourhoods, not homes. The server snaps each position to a
/// ~500 m square before it ever leaves the database.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({
    super.key,
    required this.trade,
    required this.service,
    required this.place,
  });

  final Trade trade;
  final Service service;
  final Place place;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  List<NearbyProvider> _all = const [];
  bool _loading = true;
  String? _error;
  int _radiusM = 15000;

  /// Null shows every tier.
  Tier? _tier;
  String? _selected;

  final _cards = PageController(viewportFraction: 0.86);

  static const _sheetHeight = 312.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cards.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.mapProviders(
        widget.trade.slug,
        lat: widget.place.lat,
        lng: widget.place.lng,
        radiusM: _radiusM,
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        _selected = list.isEmpty ? null : list.first.userId;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load who is nearby. Check your connection.';
        });
      }
    }
  }

  List<NearbyProvider> get _shown => _tier == null
      ? _all
      : _all.where((p) => p.tier == _tier!.key).toList();

  int _countFor(Tier t) => _all.where((p) => p.tier == t.key).length;

  void _selectFromMap(String id) {
    Buzz.pick();
    final i = _shown.indexWhere((p) => p.userId == id);
    setState(() => _selected = id);
    if (i >= 0 && _cards.hasClients) {
      _cards.animateToPage(i, duration: Motion.base, curve: Motion.settle);
    }
  }

  void _filter(Tier? t) {
    Buzz.tap();
    setState(() {
      _tier = t;
      final shown = _shown;
      if (shown.every((p) => p.userId != _selected)) {
        _selected = shown.isEmpty ? null : shown.first.userId;
      }
    });
    if (_cards.hasClients) _cards.jumpToPage(0);
  }

  void _continue(NearbyProvider pro) {
    Buzz.commit();
    Navigator.of(context).go(
      (_) => ConfirmBookingScreen(
        trade: widget.trade,
        service: widget.service,
        provider: pro,
        place: widget.place,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(widget.trade.slug);
    final shown = _shown;
    final home = LatLng(widget.place.lat, widget.place.lng);

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: Stack(
        children: [
          // --------------------------------------------------------- map
          Positioned.fill(
            child: ProMap(
              home: home,
              bottomInset: _sheetHeight,
              selectedId: _selected,
              onSelect: _selectFromMap,
              pins: [
                for (final p in shown)
                  if (p.displayLat != null && p.displayLng != null)
                    ProMapPin(
                      id: p.userId,
                      at: LatLng(p.displayLat!, p.displayLng!),
                      tier: Tier.of(p.tier),
                      price: formatPence(p.priceFor(widget.service.ratePence)),
                      freeNow: p.availableNow,
                    ),
              ],
            ),
          ),

          // A soft fade under the top controls so they read on any map.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 170,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Surface.canvas.withValues(alpha: 0.95),
                      Surface.canvas.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ------------------------------------------------------ top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _RoundButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.lg, vertical: 10),
                        decoration: BoxDecoration(
                          color: Surface.raised,
                          borderRadius: BorderRadius.circular(Radii.chip),
                          boxShadow: Shade.md,
                        ),
                        child: Row(children: [
                          YaariMark(widget.trade.slug, size: 24),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(
                              '${widget.service.name} · ${widget.place.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Txt.cardTitle.copyWith(fontSize: 14),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: Gap.md),
                  if (_all.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _TierChip(
                          label: 'All',
                          count: _all.length,
                          selected: _tier == null,
                          onTap: () => _filter(null),
                        ),
                        for (final t in Tier.all)
                          if (_countFor(t) > 0) ...[
                            const SizedBox(width: Gap.sm),
                            _TierChip(
                              label: t.label,
                              tier: t,
                              count: _countFor(t),
                              selected: _tier == t,
                              onTap: () => _filter(t),
                            ),
                          ],
                        const SizedBox(width: Gap.sm),
                        _RoundButton(
                          icon: Icons.info_outline_rounded,
                          small: true,
                          onTap: () => showYaariSheet<void>(context,
                              child: _TierSheet(
                                  basePence: widget.service.ratePence,
                                  unit: widget.service.rateUnit)),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),

          // -------------------------------------------------- bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _sheetHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Surface.canvas,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.sheet)),
                boxShadow: [
                  BoxShadow(
                    color: Coal.c900.withValues(alpha: 0.14),
                    blurRadius: 30,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _loading
                    ? const _SheetSkeleton()
                    : _error != null
                        ? _SheetMessage(
                            icon: Icons.wifi_off_rounded,
                            title: 'Not loaded',
                            body: _error!,
                            action: 'Try again',
                            onAction: _load,
                          )
                        : _all.isEmpty
                            ? _SheetMessage(
                                icon: Icons.travel_explore_rounded,
                                title: _radiusM < 30000
                                    ? 'No one this close yet'
                                    : 'No verified ${widget.trade.name.toLowerCase()} here yet',
                                body: _radiusM < 30000
                                    ? 'Nobody checked for this job within '
                                        '${(_radiusM / 1609).round()} miles. '
                                        'Look a little further out?'
                                    : 'We only list people whose '
                                        'credentials we have verified, and '
                                        'we are onboarding here now.',
                                action: _radiusM < 30000
                                    ? 'Search further'
                                    : 'Change area',
                                onAction: _radiusM < 30000
                                    ? () {
                                        _radiusM = 30000;
                                        _load();
                                      }
                                    : () => Navigator.of(context).maybePop(),
                              )
                            : _Carousel(
                                pros: shown,
                                controller: _cards,
                                selectedId: _selected,
                                service: widget.service,
                                colour: c.base,
                                onSwipe: (p) {
                                  Buzz.tap();
                                  setState(() => _selected = p.userId);
                                },
                                onChoose: _continue,
                              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- the cards

class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.pros,
    required this.controller,
    required this.selectedId,
    required this.service,
    required this.colour,
    required this.onSwipe,
    required this.onChoose,
  });

  final List<NearbyProvider> pros;
  final PageController controller;
  final String? selectedId;
  final Service service;
  final Color colour;
  final ValueChanged<NearbyProvider> onSwipe;
  final ValueChanged<NearbyProvider> onChoose;

  @override
  Widget build(BuildContext context) {
    final free = pros.where((p) => p.availableNow).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Coal.c200,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: Row(children: [
            Expanded(
              child: Text(
                pros.length == 1
                    ? '1 verified professional'
                    : '${pros.length} verified professionals',
                style: Txt.section,
              ),
            ),
            if (free > 0)
              Pill('$free free now',
                  tone: ChipTone.success, icon: Icons.bolt_rounded, dense: true),
          ]),
        ),
        const SizedBox(height: Gap.md),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: pros.length,
            onPageChanged: (i) => onSwipe(pros[i]),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: Gap.md, bottom: Gap.lg),
              child: _ProCard(
                pro: pros[i],
                service: service,
                selected: pros[i].userId == selectedId,
                onChoose: () => onChoose(pros[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({
    required this.pro,
    required this.service,
    required this.selected,
    required this.onChoose,
  });

  final NearbyProvider pro;
  final Service service;
  final bool selected;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final tier = Tier.of(pro.tier);
    final price = pro.priceFor(service.ratePence);
    final first = pro.name.split(' ').first;

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.settle,
      decoration: BoxDecoration(
        color: Surface.raised,
        borderRadius: BorderRadius.circular(Radii.panel),
        border: Border.all(
          color: selected ? tier.base : Colors.transparent,
          width: 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: tier.deep.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : Shade.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Avatar(pro.name, size: 48),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _Medal(tier: tier, size: 22),
                    ),
                  ],
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pro.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.cardTitle.copyWith(fontSize: 16)),
                      const SizedBox(height: 3),
                      _TierLabel(tier: tier),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatRate(price, service.rateUnit),
                        style: Txt.priceLg.copyWith(fontSize: 21)),
                    Text(tier.upliftLabel,
                        style: Txt.meta.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _Fact(
                    icon: Icons.star_rounded,
                    text: pro.ratingAvg == null
                        ? 'New'
                        : pro.ratingAvg!.toStringAsFixed(1),
                    colour: const Color(0xFFE2A83A)),
                _Fact(
                    icon: Icons.task_alt_rounded,
                    text: '${pro.jobsCompleted} jobs'),
                _Fact(
                    icon: Icons.near_me_rounded,
                    text: formatDistance(pro.metres)),
                const Spacer(),
                Pill(
                  pro.availableNow ? 'Free now' : 'Later today',
                  tone: pro.availableNow ? ChipTone.success : ChipTone.neutral,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Btn(
              'Choose $first',
              icon: Icons.arrow_forward_rounded,
              onTap: onChoose,
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.colour});

  final IconData icon;
  final String text;
  final Color? colour;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Gap.md),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: colour ?? Coal.c500),
          const SizedBox(width: 3),
          Text(text, style: Txt.meta.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// A metal medal: the tier's three-stop gradient, a white rim, and a glyph.
class _Medal extends StatelessWidget {
  const _Medal({required this.tier, this.size = 24});

  final Tier tier;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: tier.medal,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: tier.deep.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          tier.key == 'gold'
              ? Icons.workspace_premium_rounded
              : Icons.verified_rounded,
          size: size * 0.55,
          color: Colors.white,
        ),
      );
}

class _TierLabel extends StatelessWidget {
  const _TierLabel({required this.tier});
  final Tier tier;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(
          colors: [tier.deep, tier.base, tier.deep],
        ).createShader(r),
        child: Text(
          '${tier.label.toUpperCase()} PRO',
          style: Txt.label.copyWith(letterSpacing: 1.4, fontSize: 11),
        ),
      );
}

// --------------------------------------------------------- top controls

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.tier,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Tier? tier;

  @override
  Widget build(BuildContext context) {
    final t = tier;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.settle,
        padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
        decoration: BoxDecoration(
          color: selected ? Coal.c900 : Surface.raised,
          borderRadius: BorderRadius.circular(Radii.chip),
          boxShadow: Shade.md,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (t != null) ...[
            _Medal(tier: t, size: 20),
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 4),
          Text(label,
              style: Txt.meta.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Coal.c900,
              )),
          const SizedBox(width: 5),
          Text('$count',
              style: Txt.meta.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Coal.c300 : Coal.c500,
              )),
        ]),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.onTap, this.small = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          padding: EdgeInsets.all(small ? 7 : 10),
          decoration: BoxDecoration(
            color: Surface.raised,
            shape: BoxShape.circle,
            boxShadow: Shade.md,
          ),
          child: Icon(icon, size: small ? 18 : 20, color: Coal.c900),
        ),
      );
}

/// What the medals mean, and what each costs.
class _TierSheet extends StatelessWidget {
  const _TierSheet({required this.basePence, required this.unit});

  final int basePence;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHead(
            title: 'Gold, Silver and Bronze',
            subtitle: 'Earned from ratings and finished jobs — never bought',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            child: Column(children: [
              for (final t in Tier.all) ...[
                Panel(
                  padding: const EdgeInsets.all(Gap.lg),
                  shadow: Shade.sm,
                  child: Row(children: [
                    _Medal(tier: t, size: 38),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.label, style: Txt.cardTitle),
                          const SizedBox(height: 2),
                          Text(t.blurb, style: Txt.meta),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatRate(tierPrice(basePence, t.upliftBps), unit),
                            style: Txt.price),
                        Text(t.upliftLabel, style: Txt.meta),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: Gap.md),
              ],
              Text(
                'Every tier holds the same verified insurance and '
                'credentials. The medal is about track record, not safety.',
                textAlign: TextAlign.center,
                style: Txt.meta,
              ),
            ]),
          ),
        ],
      );
}

// -------------------------------------------------------- sheet states

class _SheetSkeleton extends StatelessWidget {
  const _SheetSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(Gap.page, 30, Gap.page, Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 190, height: 20),
            SizedBox(height: Gap.lg),
            Skeleton(height: 200, radius: Radii.panel),
          ],
        ),
      );
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 28, Gap.page, Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Sky.c50,
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Icon(icon, color: Sky.c700, size: 22),
            ),
            const SizedBox(height: Gap.md),
            Text(title, style: Txt.title),
            const SizedBox(height: Gap.xs),
            Text(body, style: Txt.body),
            const Spacer(),
            Btn(action, onTap: onAction),
          ],
        ),
      );
}
