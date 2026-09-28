import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'ds/tokens.dart';
import 'theme.dart';

/// OpenStreetMap, drawn with flutter_map.
///
/// Chosen over Google Maps because Google requires a billing account even
/// inside its free tier. OSM needs no key and no card, and the attribution
/// below is a condition of using the tiles, not decoration.
class YaariMap extends StatefulWidget {
  const YaariMap({
    super.key,
    required this.centre,
    this.height = 180,
    this.zoom = 15.5,
    this.onMoved,
    this.interactive = true,
  });

  final LatLng centre;
  final double height;
  final double zoom;

  /// Called as the map is dragged, with whatever is now under the pin.
  /// Non-null makes this a pin-adjuster rather than a picture.
  final ValueChanged<LatLng>? onMoved;

  final bool interactive;

  @override
  State<YaariMap> createState() => _YaariMapState();
}

class _YaariMapState extends State<YaariMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(YaariMap old) {
    super.didUpdateWidget(old);
    // A new postcode was looked up: move the map to it rather than rebuilding.
    if (old.centre != widget.centre) {
      _controller.move(widget.centre, widget.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adjustable = widget.onMoved != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: widget.centre,
                initialZoom: widget.zoom,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.drag |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom
                      : InteractiveFlag.none,
                ),
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) widget.onMoved?.call(camera.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // The OSM tile policy requires apps to identify themselves.
                  userAgentPackageName: 'uk.yaari',
                  maxZoom: 19,
                ),
                // When the pin can be moved it stays fixed to the centre of the
                // frame and the map slides underneath, which is how every maps
                // app does it — a marker you drag instead is fiddly on a phone.
                if (!adjustable)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.centre,
                        width: 40,
                        height: 40,
                        child: const _Pin(),
                      ),
                    ],
                  ),
              ],
            ),
            if (adjustable) const Center(child: _Pin(lifted: true)),
            const Positioned(right: 0, bottom: 0, child: _Attribution()),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({this.lifted = false});
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        // A pin points at its tip, so lift it by half its height to put the
        // tip on the centre of the map rather than the middle of the glyph.
        offset: Offset(0, lifted ? -16 : 0),
        child: const Icon(
          Icons.location_on,
          size: 34,
          color: YaariColors.ember,
          shadows: [
            Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

/// Required by the OpenStreetMap tile usage policy.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: const Color(0xCCFFFFFF),
        child: const Text(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 9, color: YaariColors.inkDim),
        ),
      );
}

// ------------------------------------------------------------ professionals

/// One professional on the map.
///
/// [at] is the display point the server computed — the neighbourhood, never
/// the home. Nothing in this widget can make it more precise than it arrived.
@immutable
class ProMapPin {
  const ProMapPin({
    required this.id,
    required this.at,
    required this.tier,
    required this.price,
    this.freeNow = true,
  });

  final String id;
  final LatLng at;
  final Tier tier;

  /// Already formatted: "£54". The map shows what the customer would pay
  /// this person, which is the thing they are actually choosing between.
  final String price;
  final bool freeNow;
}

/// The nearby-professionals map.
///
/// Built like the booking maps people already trust: a quiet, desaturated
/// base so the only colour on screen is the professionals, each pin a price
/// bubble ringed in their tier's metal, and the customer's own address as a
/// soft pulsing point. Selecting a card elsewhere flies the map to that pin,
/// and tapping a pin selects the card — the two views are one choice.
class ProMap extends StatefulWidget {
  const ProMap({
    super.key,
    required this.home,
    required this.pins,
    required this.onSelect,
    this.selectedId,
    this.bottomInset = 0,
  });

  final LatLng home;
  final List<ProMapPin> pins;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Height covered by a sheet at the bottom, so fitting and flying keep pins
  /// in the visible part of the map rather than under the cards.
  final double bottomInset;

  @override
  State<ProMap> createState() => _ProMapState();
}

class _ProMapState extends State<ProMap> with TickerProviderStateMixin {
  final _controller = MapController();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();
  AnimationController? _fly;

  @override
  void didUpdateWidget(ProMap old) {
    super.didUpdateWidget(old);
    final id = widget.selectedId;
    if (id != null && id != old.selectedId) {
      final pin = widget.pins.where((p) => p.id == id).firstOrNull;
      if (pin != null) _flyTo(pin.at);
    }
  }

  /// A short eased flight rather than a jump, so the eye can follow where
  /// the selected professional is relative to home.
  void _flyTo(LatLng to) {
    final camera = _controller.camera;
    final from = camera.center;
    final zoom = camera.zoom < 14 ? 14.0 : camera.zoom;
    final fromZoom = camera.zoom;

    // Aim a little below the pin so it sits above the sheet, not under it.
    final shift = widget.bottomInset / 2;

    _fly?.dispose();
    final c = AnimationController(vsync: this, duration: Motion.slow);
    _fly = c;
    final t = CurvedAnimation(parent: c, curve: Motion.settle);
    c.addListener(() {
      final lat = from.latitude + (to.latitude - from.latitude) * t.value;
      final lng = from.longitude + (to.longitude - from.longitude) * t.value;
      final z = fromZoom + (zoom - fromZoom) * t.value;
      _controller.move(LatLng(lat, lng), z, offset: Offset(0, -shift));
    });
    c.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _fly?.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Muted, slightly cool base map. Colour is reserved for the pins.
  static const _mute = ColorFilter.matrix(<double>[
    0.30, 0.55, 0.10, 0, 18, //
    0.25, 0.60, 0.10, 0, 20, //
    0.25, 0.55, 0.20, 0, 26, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final points = [widget.home, ...widget.pins.map((p) => p.at)];
    final fit = points.length < 2
        ? null
        : CameraFit.coordinates(
            coordinates: points,
            maxZoom: 15,
            padding: EdgeInsets.fromLTRB(
                60, 120, 60, 60 + widget.bottomInset),
          );

    // Selected pin drawn last so it sits on top of any it overlaps.
    final ordered = [...widget.pins]
      ..sort((a, b) => (a.id == widget.selectedId ? 1 : 0)
          .compareTo(b.id == widget.selectedId ? 1 : 0));

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.home,
            initialZoom: 13.5,
            initialCameraFit: fit,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'uk.yaari',
              maxZoom: 19,
              tileBuilder: (context, tile, _) =>
                  ColorFiltered(colorFilter: _mute, child: tile),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.home,
                  width: 64,
                  height: 64,
                  child: _HomeDot(pulse: _pulse),
                ),
                for (final p in ordered)
                  Marker(
                    point: p.at,
                    width: 104,
                    height: 58,
                    alignment: Alignment.topCenter,
                    child: _PricePin(
                      pin: p,
                      selected: p.id == widget.selectedId,
                      onTap: () => widget.onSelect(p.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(right: 0, bottom: 0, child: _Attribution()),
      ],
    );
  }
}

/// The customer's address: a solid point inside a ring that breathes out.
class _HomeDot extends StatelessWidget {
  const _HomeDot({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: pulse,
          builder: (_, _) {
            final t = Curves.easeOut.transform(pulse.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 18 + 44 * t,
                  height: 18 + 44 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Brand.c500.withValues(alpha: 0.28 * (1 - t)),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Brand.c500,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: Shade.tinted(Brand.c500),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

/// A price bubble ringed in the professional's tier.
class _PricePin extends StatelessWidget {
  const _PricePin({
    required this.pin,
    required this.selected,
    required this.onTap,
  });

  final ProMapPin pin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = pin.tier;
    final dim = !pin.freeNow && !selected;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: selected ? 1.14 : 1.0,
        duration: Motion.base,
        curve: Motion.spring,
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          opacity: dim ? 0.62 : 1,
          duration: Motion.fast,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.base,
                curve: Motion.settle,
                padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
                decoration: BoxDecoration(
                  color: selected ? Coal.c900 : Surface.raised,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: (selected ? Coal.c900 : tier.deep)
                          .withValues(alpha: 0.30),
                      blurRadius: selected ? 16 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: tier.medal,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 1.5),
                      ),
                      child: Icon(
                        tier.key == 'gold'
                            ? Icons.workspace_premium_rounded
                            : Icons.verified_rounded,
                        size: 13,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: tier.deep.withValues(alpha: 0.6),
                              blurRadius: 3),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pin.price,
                      style: TextStyle(
                        fontFamily: 'packages/yaari_ui/Manrope',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : Coal.c900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              // The stem, so the bubble reads as pointing at a place.
              CustomPaint(
                size: const Size(12, 7),
                painter: _Stem(selected ? Coal.c900 : Surface.raised),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stem extends CustomPainter {
  _Stem(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    // ui.Path: flutter_map exports a Path of its own that shadows this one.
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_Stem old) => old.colour != colour;
}
