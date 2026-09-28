import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../jobs.dart';

/// Earnings.
///
/// One figure dominates — what is owed right now — because that is the only
/// thing anybody opens this screen to see. Everything under it is the working
/// that produced the number.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  List<EarningsRow> _rows = [];
  int _balance = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results =
          await Future.wait([EarningsApi.recent(), EarningsApi.balancePence()]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<EarningsRow>;
        _balance = results[1] as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// This calendar month, which is the period a self-employed person
  /// actually thinks in.
  int get _thisMonth {
    final now = DateTime.now();
    return _rows
        .where((r) =>
            r.completedAt != null &&
            r.completedAt!.year == now.year &&
            r.completedAt!.month == now.month)
        .fold(0, (a, r) => a + r.netPence);
  }

  int get _jobsThisMonth {
    final now = DateTime.now();
    return _rows
        .where((r) =>
            r.completedAt != null &&
            r.completedAt!.year == now.year &&
            r.completedAt!.month == now.month)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Surface.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: _loading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, 80, Gap.page, Gap.huge),
                children: const [
                  Skeleton(height: 168, radius: Radii.panel),
                  SizedBox(height: Gap.xl),
                  Skeleton(height: 84, radius: Radii.card),
                  SizedBox(height: Gap.md),
                  Skeleton(height: 84, radius: Radii.card),
                ],
              )
            : ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, 0, Gap.page, 120),
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(
                          top: Gap.md, bottom: Gap.lg),
                      child: Text('Earnings', style: Txt.hero),
                    ),
                  ),

                  Reveal(child: _BalanceCard(pence: _balance)),
                  const SizedBox(height: Gap.lg),

                  Reveal(
                    delay: const Duration(milliseconds: 60),
                    child: Row(children: [
                      Expanded(
                        child: _Stat(
                          label: 'This month',
                          value: formatPence(_thisMonth),
                          icon: Icons.trending_up_rounded,
                          colour: Signal.success,
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: _Stat(
                          label: 'Jobs done',
                          value: '$_jobsThisMonth',
                          icon: Icons.check_circle_rounded,
                          colour: Signal.info,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: Gap.xxl),

                  if (_rows.isEmpty)
                    const StateView(
                      icon: Icons.receipt_long_rounded,
                      title: 'Nothing yet',
                      body: 'Completed jobs and what you earned from them '
                          'will appear here.',
                    )
                  else ...[
                    const SectionHead('Recent work'),
                    for (var i = 0; i < _rows.length; i++) ...[
                      Reveal(
                        delay: Duration(milliseconds: 80 + 40 * i),
                        child: _EarningRow(row: _rows[i]),
                      ),
                      const SizedBox(height: Gap.md),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// What is owed, set as large as the screen allows.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.pence});

  final int pence;

  @override
  Widget build(BuildContext context) {
    return Panel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Coal.c800, Coal.c900],
      ),
      padding: const EdgeInsets.all(Gap.xxl),
      radius: Radii.panel,
      shadow: Shade.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AVAILABLE TO YOU',
              style: Txt.label.copyWith(color: Coal.c400)),
          const SizedBox(height: Gap.md),
          CountUp(
            value: pence,
            format: (v) => formatPence(v.round()),
            style: Txt.hero.copyWith(color: Colors.white, fontSize: 44),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: Coal.c400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Cash jobs are settled directly with the customer. Card '
                    'jobs are paid out by Stripe.',
                    style: Txt.meta.copyWith(color: Coal.c400)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.colour,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: colour),
          ),
          const SizedBox(height: Gap.md),
          Text(value, style: Txt.price.copyWith(fontSize: 21)),
          const SizedBox(height: 1),
          Text(label, style: Txt.meta),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.row});

  final EarningsRow row;

  @override
  Widget build(BuildContext context) {
    final deducted = row.amountPence - row.netPence;

    return Panel(
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: row.method == 'cash' ? Signal.successSoft : Signal.infoSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
                row.method == 'cash'
                    ? Icons.payments_rounded
                    : Icons.credit_card_rounded,
                size: 16,
                color: row.method == 'cash' ? Signal.success : Signal.info),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.service,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(_when(row.completedAt), style: Txt.meta),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatPence(row.netPence),
                  style: Txt.price.copyWith(fontSize: 15)),
              if (deducted > 0)
                Text('−${formatPence(deducted)} fee',
                    style: Txt.meta.copyWith(fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }

  static String _when(DateTime? d) {
    if (d == null) return 'Completed';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
