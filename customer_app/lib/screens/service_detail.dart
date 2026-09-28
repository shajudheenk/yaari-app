import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import '../place.dart';
import 'nearby.dart';

/// Choosing the job.
///
/// A coloured header carries the category's identity through from the tile
/// you pressed, then collapses out of the way once you start comparing
/// prices — the header sells, the list decides, and they should not compete.
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({
    super.key,
    required this.trade,
    required this.place,
  });

  final Trade trade;
  final Place place;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  late Future<List<Service>> _services;
  String? _selectedId;

  final _scroll = ScrollController();

  /// FlexibleSpaceBar draws its `title` at every extent, so handing it one
  /// printed the trade name twice — large in the header and small over the
  /// top of it. The collapsed title is driven from the scroll offset instead.
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _services = Api.servicesFor(widget.trade.id);
    _scroll.addListener(() {
      final past = _scroll.hasClients && _scroll.offset > 128;
      if (past != _collapsed) setState(() => _collapsed = past);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(widget.trade.slug);

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: FutureBuilder<List<Service>>(
        future: _services,
        builder: (context, snap) {
          final services = snap.data ?? [];
          final loading = snap.connectionState == ConnectionState.waiting;
          final chosen = _selectedId == null
              ? null
              : services.where((s) => s.id == _selectedId).firstOrNull;

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _Header(trade: widget.trade, collapsed: _collapsed),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, Gap.xl, Gap.page, Gap.xl),
                      sliver: SliverList.list(children: [
                        Steps(
                          step: 2,
                          of: 4,
                          label: 'Choose what you need',
                          colour: c.base,
                        ),
                        const SizedBox(height: Gap.xl),
                        if (loading)
                          ...List.generate(
                            4,
                            (_) => const Padding(
                              padding: EdgeInsets.only(bottom: Gap.md),
                              child: Skeleton(
                                  height: 112, radius: Radii.card),
                            ),
                          )
                        else if (services.isEmpty)
                          StateView(
                            icon: c.glyph,
                            title: 'Nothing listed here yet',
                            body: 'We have not published prices for this '
                                'trade in ${widget.place.city} yet. It is '
                                'coming.',
                          )
                        else ...[
                          SectionHead('Jobs we price upfront',
                              trailing: Pill('${services.length}',
                                  colour: c.deep, dense: true)),
                          for (var i = 0; i < services.length; i++) ...[
                            Reveal(
                              delay: Duration(milliseconds: 50 + 45 * i),
                              child: ServiceRow(
                                name: services[i].name,
                                slug: widget.trade.slug,
                                description: services[i].description,
                                price: formatRate(services[i].ratePence,
                                    services[i].rateUnit),
                                duration: services[i].durationMinutes == null
                                    ? null
                                    : _mins(services[i].durationMinutes!),
                                popular: services[i].isPopular,
                                fixedPrice: services[i].rateUnit != 'hour',
                                selected: _selectedId == services[i].id,
                                onTap: () {
                                  Buzz.pick();
                                  setState(
                                      () => _selectedId = services[i].id);
                                },
                              ),
                            ),
                            const SizedBox(height: Gap.md),
                          ],
                          const SizedBox(height: Gap.sm),
                          Reveal(
                            delay: const Duration(milliseconds: 260),
                            child: _Assurances(colour: c.deep),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
              ),
              PriceBar(
                caption: chosen == null
                    ? 'Prices agreed before anyone arrives'
                    : chosen.rateUnit == 'hour'
                        ? 'Estimated, first hour'
                        : 'Fixed price, all in',
                price: chosen == null
                    ? (widget.trade.fromPence == null
                        ? '—'
                        : 'from ${formatRate(widget.trade.fromPence!, widget.trade.fromUnit ?? 'job')}')
                    : formatRate(chosen.ratePence, chosen.rateUnit),
                action: chosen == null ? 'Choose a job' : 'Find someone',
                colour: c.base,
                note: chosen == null
                    ? null
                    : 'Free to cancel any time before work starts',
                onAction: chosen == null
                    ? null
                    : () {
                        Buzz.commit();
                        Navigator.of(context).go(
                          (_) => NearbyScreen(
                            trade: widget.trade,
                            place: widget.place,
                            service: chosen,
                          ),
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  static String _mins(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hours = h == 1 ? '1 hour' : '$h hours';
    return m == 0 ? hours : '$hours $m min';
  }
}

/// The category header: its colour at full strength, the mark arriving from
/// the grid, and the name set large. Collapses to a plain bar on scroll.
class _Header extends StatelessWidget {
  const _Header({required this.trade, required this.collapsed});

  final Trade trade;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(trade.slug);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 190,
      backgroundColor: c.deep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Pressable(
          onTap: () => Navigator.of(context).maybePop(),
          scale: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 20, color: Colors.white),
          ),
        ),
      ),
      title: AnimatedOpacity(
        opacity: collapsed ? 1 : 0,
        duration: Motion.fast,
        child: Text(trade.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Txt.cardTitle.copyWith(color: Colors.white, fontSize: 16)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: c.header),
          padding: const EdgeInsets.fromLTRB(Gap.page, 62, Gap.page, Gap.xxl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(trade.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.display.copyWith(
                            color: Colors.white, fontSize: 26)),
                    if (trade.blurb != null) ...[
                      const SizedBox(height: 5),
                      Text(trade.blurb!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.lg),
              Hero(
                tag: 'cat-${trade.id}',
                child: YaariMark(trade.slug, size: 60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the price actually covers, stated before anyone commits.
///
/// Most disputes in home services are about scope rather than quality —
/// somebody expecting the inside of the oven to be included. Saying so here
/// costs one card and removes the argument entirely.
class _Assurances extends StatelessWidget {
  const _Assurances({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    const lines = [
      (Icons.receipt_long_rounded, 'The price you see is the price you pay',
          'Agreed upfront. No doorstep renegotiation.'),
      (Icons.pin_rounded, 'Only you can close the job',
          'A four digit code, shown to you alone.'),
      (Icons.photo_camera_rounded, 'Photographed before and after',
          'Saved to your booking, so scope is a record not an opinion.'),
    ];

    return Panel(
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW THIS WORKS', style: Txt.label),
          const SizedBox(height: Gap.md),
          for (var i = 0; i < lines.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(lines[i].$1, size: 15, color: colour),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lines[i].$2,
                          style: Txt.cardTitle.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(lines[i].$3, style: Txt.meta),
                    ],
                  ),
                ),
              ],
            ),
            if (i < lines.length - 1) const SizedBox(height: Gap.lg),
          ],
        ],
      ),
    );
  }
}
