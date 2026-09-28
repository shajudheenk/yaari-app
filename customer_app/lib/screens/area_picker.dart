import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import '../place.dart';

/// Where are you?
///
/// Grouped by city, and the cities come from the database — the app does not
/// know that Birmingham and London are the two we are in. Areas that are not
/// live yet are listed but unselectable, because "coming to Croydon" is more
/// useful to a Croydon resident than silence.
Future<void> showAreaPicker(BuildContext context, Place place) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Surface.canvas,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _AreaSheet(place: place),
  );
}

class _AreaSheet extends StatelessWidget {
  const _AreaSheet({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final live = place.byCity;
    final soon = place.all.where((a) => !a.isLive).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text('Where do you need someone?', style: text.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Prices and availability change by area, so we ask up front '
              'rather than at checkout.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 20),

            for (final entry in live.entries) ...[
              Text(entry.key.toUpperCase(), style: text.labelSmall),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in entry.value)
                    _AreaChip(
                      area: a,
                      selected: place.area?.name == a.name,
                      onTap: () async {
                        Buzz.pick();
                        await place.choose(a);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            if (soon.isNotEmpty) ...[
              Text('COMING SOON', style: text.labelSmall),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in soon) _AreaChip(area: a, selected: false),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.area, required this.selected, this.onTap});

  final ServiceArea area;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;

    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Brand.c500 : Surface.raised,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? Brand.c500 : Coal.c100,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              area.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : off
                        ? Coal.c500
                        : Coal.c900,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              area.postcodePrefix,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white70
                    : Coal.c500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
