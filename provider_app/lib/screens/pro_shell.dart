import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import '../jobs.dart';
import 'dashboard.dart';
import 'earnings.dart';
import 'pro_account.dart';
import 'schedule.dart';

/// The professional's frame.
///
/// Same design system and the same brand colour as the customer app — one
/// company, one language. The two are told apart by their icons and by the
/// fact that this one opens on work, not on shopping.
class ProShell extends StatefulWidget {
  const ProShell({super.key, required this.auth});

  final YaariAuth auth;

  @override
  State<ProShell> createState() => _ProShellState();
}

class _ProShellState extends State<ProShell> {
  int _tab = 0;
  int _offers = 0;
  ProviderStanding? _standing;

  @override
  void initState() {
    super.initState();
    _countOffers();
    _loadStanding();
  }

  /// Held here rather than fetched twice, because both the account tab and
  /// the compliance banner on the dashboard need it.
  Future<void> _loadStanding() async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return;
    try {
      final s = await ProviderApi.myStanding(id);
      if (mounted) setState(() => _standing = s);
    } catch (_) {
      // The account tab shows its own empty state.
    }
  }

  /// The badge on Work is the whole reason this app gets opened, so it is
  /// refreshed whenever the tab bar is touched rather than only on launch.
  Future<void> _countOffers() async {
    try {
      final offers = await JobsApi.offers();
      if (mounted) setState(() => _offers = offers.length);
    } catch (_) {
      // Offline; the badge simply stays hidden.
    }
  }

  void _go(int i) {
    if (i == _tab) return;
    Buzz.tap();
    setState(() => _tab = i);
    _countOffers();
    if (i == 3) _loadStanding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(
            auth: widget.auth,
            onChanged: () {
              _countOffers();
              _loadStanding();
            },
          ),
          const ScheduleScreen(),
          const EarningsScreen(),
          ProAccountScreen(auth: widget.auth, standing: _standing),
        ],
      ),
      bottomNavigationBar: _ProTabs(
        index: _tab,
        onTap: _go,
        offers: _offers,
      ),
    );
  }
}

class _ProTabs extends StatelessWidget {
  const _ProTabs({
    required this.index,
    required this.onTap,
    required this.offers,
  });

  final int index;
  final ValueChanged<int> onTap;
  final int offers;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: Coal.c900,
          borderRadius: BorderRadius.circular(Radii.chip),
          boxShadow: Shade.lg,
        ),
        child: Row(
          children: [
            _ProTab(
                icon: Icons.work_rounded,
                label: 'Work',
                selected: index == 0,
                badge: offers,
                onTap: () => onTap(0)),
            _ProTab(
                icon: Icons.calendar_month_rounded,
                label: 'Hours',
                selected: index == 1,
                onTap: () => onTap(1)),
            _ProTab(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
                selected: index == 2,
                onTap: () => onTap(2)),
            _ProTab(
                icon: Icons.person_rounded,
                label: 'You',
                selected: index == 3,
                onTap: () => onTap(3)),
          ],
        ),
      ),
    );
  }
}

class _ProTab extends StatelessWidget {
  const _ProTab({
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
                      size: 19, color: selected ? Coal.c900 : Coal.c400),
                  if (badge > 0)
                    Positioned(
                      right: -5,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Brand.c500,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: selected ? Colors.white : Coal.c900,
                              width: 1.5),
                        ),
                        child: Text('$badge',
                            style: const TextStyle(
                                fontFamily: Face.text,
                                fontSize: 9,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.spring,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(label,
                            style: Txt.meta.copyWith(
                                color: Coal.c900,
                                fontSize: 11,
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
