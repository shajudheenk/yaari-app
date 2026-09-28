import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../booking.dart';
import '../place.dart';
import 'account.dart';
import 'home.dart';
import 'my_bookings.dart';

/// The app frame.
///
/// A custom bar rather than Material's NavigationBar: the stock one brings
/// its own indicator pill, ripple and label treatment, none of which match
/// the rest of the app, and fighting it costs more than replacing it.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.auth, required this.place});

  final YaariAuth auth;
  final Place place;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _tab = 0;
  int _live = 0;

  @override
  void initState() {
    super.initState();
    _countLive();
  }

  Future<void> _countLive() async {
    try {
      final all = await BookingApi.myBookings();
      if (!mounted) return;
      setState(() => _live = all.where((b) => b.isLive).length);
    } catch (_) {
      // Offline or not signed in yet; the dot simply stays hidden.
    }
  }

  void _go(int i) {
    if (i == _tab) return;
    Buzz.tap();
    setState(() => _tab = i);
    if (i == 1) _countLive();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            auth: widget.auth,
            place: widget.place,
            onOpenAccount: () => setState(() => _tab = 2),
            onOpenBookings: () => _go(1),
          ),
          MyBookingsScreen(place: widget.place),
          AccountScreen(auth: widget.auth, place: widget.place),
        ],
      ),
      bottomNavigationBar: _TabBar(
        index: _tab,
        onTap: _go,
        liveCount: _live,
      ),
    );
  }
}

/// A floating bar, inset from the edges so it reads as a control sitting on
/// the page rather than a strip welded to the bottom of the phone.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.onTap,
    required this.liveCount,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Coal.c900,
          borderRadius: BorderRadius.circular(Radii.chip),
          boxShadow: Shade.lg,
        ),
        child: Row(
          children: [
            _Tab(
              icon: Icons.grid_view_rounded,
              label: 'Explore',
              selected: index == 0,
              onTap: () => onTap(0),
            ),
            _Tab(
              icon: Icons.receipt_long_rounded,
              label: 'Bookings',
              selected: index == 1,
              badge: liveCount,
              onTap: () => onTap(1),
            ),
            _Tab(
              icon: Icons.person_rounded,
              label: 'Account',
              selected: index == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    // The selected tab grows a label beside its icon rather than under it,
    // so the bar animates width instead of swapping a highlight in and out.
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.spring,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon,
                      size: 20,
                      color: selected ? Coal.c900 : Coal.c400),
                  if (badge > 0)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Brand.c400,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected ? Colors.white : Coal.c900,
                              width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.spring,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(label,
                            style: Txt.meta.copyWith(
                                color: Coal.c900,
                                fontWeight: FontWeight.w800)),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
