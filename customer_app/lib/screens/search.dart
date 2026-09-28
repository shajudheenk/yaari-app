import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import '../place.dart';
import 'nearby.dart';
import 'service_detail.dart';

/// Search across every trade and every priced job.
///
/// Opens with the keyboard already up, because nobody navigates here by
/// accident. Until something is typed it shows what people actually book,
/// so the screen is useful before any input at all.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.place, this.catalogue});

  final Place place;

  /// Passed in when the home screen has already loaded it, so the common
  /// path costs nothing.
  final CatalogueSearch? catalogue;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  CatalogueSearch? _catalogue;
  Object? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _catalogue = widget.catalogue;
    if (_catalogue == null) _load();
    _field.addListener(() => setState(() => _q = _field.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _load() async {
    try {
      final c = await CatalogueSearch.load();
      if (mounted) setState(() => _catalogue = c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open(SearchHit hit) {
    Buzz.pick();
    final nav = Navigator.of(context);

    // A hit on a specific job goes straight to who can do it. A hit on a
    // trade goes to its price list, because the job is not chosen yet.
    if (hit.service != null) {
      nav.go((_) => NearbyScreen(
            trade: hit.trade,
            service: hit.service!,
            place: widget.place,
          ));
    } else {
      nav.go(
          (_) => ServiceDetailScreen(trade: hit.trade, place: widget.place));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _catalogue;
    final hits = cat == null ? const <SearchHit>[] : cat.query(_q);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _Field(controller: _field, focus: _focus),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_error != null) {
            return YaariEmpty(
              icon: Icons.cloud_off,
              title: 'Could not load the catalogue',
              body: 'Check your connection and try again.\n\n$_error',
            );
          }
          if (cat == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_q.trim().isEmpty) {
            return _Popular(
              catalogue: cat,
              place: widget.place,
              onPick: (word) {
                _field.text = word;
                _field.selection =
                    TextSelection.collapsed(offset: word.length);
              },
            );
          }

          if (hits.isEmpty) {
            return YaariEmpty(
              icon: Icons.search_off,
              title: 'Nothing matches "${_q.trim()}"',
              body: 'Try the trade instead — electrician, plumber, cleaner — '
                  'or describe the problem, like "leak" or "boiler".',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: hits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _HitRow(
              hit: hits[i],
              query: _q.trim(),
              onTap: () => _open(hits[i]),
            ),
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focus,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: 'Search electrician, plumber, leak…',
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => controller.clear(),
              ),
      ),
    );
  }
}

/// The resting state: real trades and the jobs people book most, so the
/// screen answers something even before a single character is typed.
class _Popular extends StatelessWidget {
  const _Popular({
    required this.catalogue,
    required this.place,
    required this.onPick,
  });

  final CatalogueSearch catalogue;
  final Place place;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final popular = <SearchHit>[
      for (final t in catalogue.trades)
        for (final s in catalogue.servicesByTrade[t.id] ?? const <Service>[])
          if (s.isPopular) SearchHit(trade: t, service: s, score: 0),
    ].take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Text('BROWSE BY TRADE', style: text.labelSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in catalogue.trades)
              ActionChip(
                label: Text(t.shortName),
                onPressed: () {
                  Buzz.tap();
                  onPick(t.shortName);
                },
                backgroundColor: Surface.raised,
                side: const BorderSide(color: Coal.c100),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        if (popular.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('BOOKED MOST OFTEN', style: text.labelSmall),
          const SizedBox(height: 10),
          for (final h in popular) ...[
            _HitRow(
              hit: h,
              query: '',
              onTap: () {
                Buzz.pick();
                Navigator.of(context).go(
                  (_) => NearbyScreen(
                    trade: h.trade,
                    service: h.service!,
                    place: place,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.query, required this.onTap});

  final SearchHit hit;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = hit.service;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            YaariMark(hit.trade.slug, size: 38),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Highlighted(text: hit.title, query: query),
                  if (hit.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hit.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (s != null)
              Text(
                formatRate(s.ratePence, s.rateUnit),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Brand.c700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Coal.c500),
          ],
        ),
      ),
    );
  }
}

/// Shows which part of the row matched what was typed.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800);

    final at = query.isEmpty
        ? -1
        : text.toLowerCase().indexOf(query.toLowerCase());
    if (at < 0) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + query.length),
            style: const TextStyle(color: Brand.c700),
          ),
          TextSpan(text: text.substring(at + query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
