import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../booking.dart';
import '../data.dart';
import '../place.dart';
import '../plan.dart';
import 'booking_status.dart';
import 'nearby.dart';
import 'plan_sheet.dart';

/// History, and a way back into a job that is still running.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.place});

  final Place place;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<BookingSummary>> _bookings;

  /// Standing arrangements, loaded alongside the history. Reading them also
  /// tops each one up with its next visit, so a plan whose last job is done
  /// shows what is coming rather than looking finished.
  List<RepeatPlan> _plans = const [];

  @override
  void initState() {
    super.initState();
    _bookings = BookingApi.myBookings();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await PlanApi.mine();
      if (mounted) setState(() => _plans = plans);
    } catch (_) {
      // The history is the point of this screen; plans are additional.
    }
  }

  void _refresh() {
    setState(() => _bookings = BookingApi.myBookings());
    _loadPlans();
  }

  /// Pull to refresh needs a future to await, so the spinner stays until the
  /// list has actually been replaced.
  Future<void> _reload() async {
    final next = BookingApi.myBookings();
    setState(() => _bookings = next);
    await next;
    await _loadPlans();
  }

  Future<void> _managePlan(RepeatPlan plan) async {
    Buzz.tap();
    final changed = await showPlanSheet(context, plan);
    if (changed == true) _refresh();
  }

  /// Starts the same job again, straight at the list of people who can do it.
  ///
  /// The catalogue is re-read rather than trusted from the old booking: a
  /// price may have changed, or the service may have been withdrawn, and
  /// quietly booking last month's price would be wrong.
  Future<void> _rebook(BookingSummary b) async {
    Buzz.pick();
    try {
      final found = await Api.tradeAndService(b.tradeSlug!, b.serviceId!);
      if (!mounted) return;
      if (found == null) {
        Buzz.reject();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That job is no longer listed in your area.'),
          ),
        );
        return;
      }
      final (trade, service) = found;
      await Navigator.of(context).go(
        (_) => NearbyScreen(trade: trade, service: service, place: widget.place),
      );
      if (mounted) setState(() => _bookings = BookingApi.myBookings());
    } catch (_) {
      if (mounted) {
        Buzz.reject();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start that again just now.')),
        );
      }
    }
  }

  Future<void> _open(BookingSummary b) async {
    Buzz.tap();
    await Navigator.of(context)
        .go((_) => BookingStatusScreen(bookingId: b.id));
    if (mounted) setState(() => _bookings = BookingApi.myBookings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Surface.canvas,
      body: RefreshIndicator(
        onRefresh: _reload,
        color: Brand.c500,
        child: FutureBuilder<List<BookingSummary>>(
          future: _bookings,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, 90, Gap.page, Gap.huge),
                children: const [
                  Skeleton(width: 170, height: 30),
                  SizedBox(height: Gap.xl),
                  Skeleton(height: 132, radius: Radii.card),
                  SizedBox(height: Gap.md),
                  Skeleton(height: 96, radius: Radii.card),
                ],
              );
            }

            final all = snap.data ?? [];
            final live = all.where((b) => b.isLive).toList();
            final past = all.where((b) => !b.isLive).toList();

            if (all.isEmpty && _plans.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                StateView(
                  icon: Icons.calendar_today_rounded,
                  title: 'Nothing booked yet',
                  body: 'When you book someone, it will appear here — with '
                      'live progress while they are working.',
                ),
              ]);
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, Gap.xl, Gap.page, Gap.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your bookings', style: Txt.hero),
                          const SizedBox(height: 3),
                          Text(
                            live.isEmpty
                                ? '${all.length} in total'
                                : '${live.length} happening now',
                            style: Txt.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Anything running dominates. It is the only reason anybody
                // opens this tab while a job is in flight.
                if (live.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, 0, Gap.page, Gap.xl),
                    sliver: SliverList.list(children: [
                      for (var i = 0; i < live.length; i++) ...[
                        Reveal(
                          delay: Duration(milliseconds: 40 * i),
                          child: _LiveBooking(
                              booking: live[i], onTap: () => _open(live[i])),
                        ),
                        const SizedBox(height: Gap.md),
                      ],
                    ]),
                  ),

                if (_plans.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, 0, Gap.page, Gap.xl),
                    sliver: SliverList.list(children: [
                      const SectionHead('Repeat plans'),
                      for (final plan in _plans) ...[
                        _PlanCard(
                          plan: plan,
                          onManage: () => _managePlan(plan),
                        ),
                        const SizedBox(height: Gap.md),
                      ],
                    ]),
                  ),

                if (past.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.page, 0, Gap.page, 120),
                    sliver: SliverList.list(children: [
                      const SectionHead('Past bookings'),
                      for (var i = 0; i < past.length; i++) ...[
                        Reveal(
                          delay: Duration(milliseconds: 30 * i),
                          child: _PastBooking(
                            booking: past[i],
                            onTap: () => _open(past[i]),
                            onRebook: past[i].canRebook
                                ? () => _rebook(past[i])
                                : null,
                          ),
                        ),
                        const SizedBox(height: Gap.md),
                      ],
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A job in flight, given the dark treatment so it separates completely from
/// the history beneath it.
class _LiveBooking extends StatelessWidget {
  const _LiveBooking({required this.booking, required this.onTap});

  final BookingSummary booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(booking.tradeSlug ?? '');

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(Gap.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Coal.c800, Coal.c900],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: Shade.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusStrip(
                    label: booking.statusLabel,
                    tone: ChipTone.success,
                    live: true),
                const Spacer(),
                Text(booking.ref,
                    style: Txt.meta.copyWith(color: Coal.c500)),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.base.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: YaariMark(booking.tradeSlug ?? '', size: 26),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.cardTitle.copyWith(
                              color: Colors.white, fontSize: 15.5)),
                      if (booking.providerName != null) ...[
                        const SizedBox(height: 2),
                        Text('with ${booking.providerName}',
                            style: Txt.meta.copyWith(color: Coal.c400)),
                      ],
                    ],
                  ),
                ),
                Text(formatPence(booking.quotedPence),
                    style: Txt.price.copyWith(color: Colors.white)),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Row(
              children: [
                const Icon(Icons.arrow_forward_rounded,
                    size: 15, color: Brand.c300),
                const SizedBox(width: 7),
                Text('Track this booking',
                    style: Txt.meta.copyWith(
                        color: Brand.c300, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A finished booking. Quieter, with the one action that matters on it.
class _PastBooking extends StatelessWidget {
  const _PastBooking({
    required this.booking,
    required this.onTap,
    this.onRebook,
  });

  final BookingSummary booking;
  final VoidCallback onTap;
  final VoidCallback? onRebook;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(booking.tradeSlug ?? '');

    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: c.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: YaariMark(booking.tradeSlug ?? '', size: 26),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusStrip(
                      label: booking.statusLabel,
                      tone: booking.isDone
                          ? ChipTone.success
                          : ChipTone.neutral,
                    ),
                    const SizedBox(width: Gap.sm),
                    Text(
                        formatPence(
                            booking.finalPence ?? booking.quotedPence),
                        style: Txt.meta.copyWith(
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          if (onRebook != null)
            Pressable(
              onTap: onRebook,
              scale: 0.9,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md, vertical: 8),
                decoration: BoxDecoration(
                  color: c.tint,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text('Book again',
                    style: Txt.meta.copyWith(
                        color: c.deep, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A standing arrangement, with its next visit and a way to stop it.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onManage});

  final RepeatPlan plan;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(plan.tradeSlug);

    return Panel(
      onTap: onManage,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      border: Border.all(color: c.base.withValues(alpha: 0.3), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: c.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: YaariMark(plan.tradeSlug, size: 24),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.serviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.cardTitle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(plan.rhythm, style: Txt.meta),
                  ],
                ),
              ),
              Pill(
                plan.isPaused ? 'Paused' : 'Active',
                tone: plan.isPaused ? ChipTone.warning : ChipTone.success,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.md, vertical: 9),
            decoration: BoxDecoration(
              color: c.tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 14, color: c.deep),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    plan.isPaused
                        ? 'Paused — no visits booked'
                        : 'Next visit ${_next(plan.nextDueAt)}',
                    style: Txt.meta.copyWith(
                        color: c.deep, fontWeight: FontWeight.w700),
                  ),
                ),
                if (plan.providerName != null)
                  Text(plan.providerName!.split(' ').first,
                      style: Txt.meta.copyWith(color: c.deep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _next(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]} ${d.day}/${d.month}, $hh:$mm';
  }
}
