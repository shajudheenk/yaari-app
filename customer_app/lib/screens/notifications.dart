import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../booking.dart';

/// What has happened on this customer's bookings.
///
/// Built from the same append-only `booking_events` table that the audit
/// trail uses, so a notification and the record of what occurred cannot
/// drift apart — there is no second list to keep in step.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Notice>> _notices = BookingApi.notices();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        color: Brand.c500,
        onRefresh: () async {
          setState(() => _notices = BookingApi.notices());
          await _notices;
        },
        child: FutureBuilder<List<Notice>>(
          future: _notices,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return YaariEmpty(
                icon: Icons.cloud_off,
                title: 'Could not load your activity',
                body: 'Pull down to try again.\n\n${snap.error}',
              );
            }

            final all = snap.data ?? [];
            if (all.isEmpty) {
              return const YaariEmpty(
                icon: Icons.notifications_none_rounded,
                title: 'Nothing yet',
                body: 'When you book someone, every step of the job appears '
                    'here — accepted, on the way, started, finished.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => YaariReveal(
                delay: Duration(milliseconds: 26 * i),
                child: _NoticeRow(notice: all[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});
  final Notice notice;

  @override
  Widget build(BuildContext context) {
    final (icon, tint, ink) = switch (notice.state) {
      'accepted' => (Icons.check_circle_outline, Coal.c50, Signal.success),
      'completed' => (Icons.task_alt, Coal.c50, Signal.success),
      'en_route' => (Icons.directions_car_outlined, Brand.c50, Brand.c700),
      'in_progress' => (Icons.handyman_outlined, Brand.c50, Brand.c700),
      'cancelled' || 'expired' => (Icons.cancel_outlined, Surface.canvas, Coal.c500),
      _ => (Icons.schedule, Surface.canvas, Coal.c500),
    };

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Surface.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Coal.c100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.headline,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${notice.serviceName} · ${notice.bookingRef}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(notice.ago, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
