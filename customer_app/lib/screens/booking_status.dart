import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../booking.dart';
import '../data.dart';

/// What the customer watches while the job runs.
///
/// Updates arrive over Realtime, so the screen moves when the tradesperson
/// presses something — no pull to refresh, and no polling.
class BookingStatusScreen extends StatefulWidget {
  const BookingStatusScreen({super.key, required this.bookingId, this.justCreated});

  final String bookingId;
  final NewBooking? justCreated;

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  BookingSummary? _booking;
  List<BookingEvent> _events = const [];
  String? _code;
  Map<String, String> _photos = const {};
  RealtimeChannel? _channel;
  bool _cancelling = false;
  bool _approving = false;

  @override
  void initState() {
    super.initState();
    _code = widget.justCreated?.completionCode;
    _load();
    _channel = BookingApi.watch(widget.bookingId, _load);
  }

  @override
  void dispose() {
    if (_channel != null) supabase.removeChannel(_channel!);
    super.dispose();
  }

  /// The customer's half of the handshake. Realtime brings the request in
  /// while the professional is standing there, so this has to be one tap.
  Future<void> _approve({required bool start}) async {
    setState(() => _approving = true);
    try {
      if (start) {
        await BookingApi.approveStart(widget.bookingId);
      } else {
        await BookingApi.approveFinish(widget.bookingId);
      }
      Buzz.commit();
      await _load();
    } catch (e) {
      if (mounted) {
        Buzz.reject();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_approvalError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  /// Declining is not a dispute — it is a conversation. Closing the sheet
  /// leaves the job running so the professional can put it right, which is
  /// almost always what both sides actually want.
  Future<void> _raiseIssue() async {
    await showYaariSheet<void>(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHead(
                title: 'Not happy with the work?',
                subtitle: 'The job stays open until you approve it'),
            Text(
              'Tell them what is wrong while they are still there — most '
              'things are fixed on the spot. The job cannot be closed and '
              'nothing is charged until you approve it.',
              style: Txt.body,
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'If you cannot resolve it between you, contact us. The before '
              'and after photographs are saved to this booking, so it is a '
              'matter of record rather than opinion.',
              style: Txt.bodySm,
            ),
            const SizedBox(height: Gap.xl),
            Btn('Got it',
                onTap: () => Navigator.of(context).maybePop()),
          ],
        ),
      ),
    );
  }

  String _approvalError(Object e) {
    final s = e.toString();
    if (s.contains('already closed')) return 'This job is already closed.';
    if (s.contains('nobody has asked')) {
      return 'Nothing to confirm just yet.';
    }
    return 'That did not go through. Please try again.';
  }

  Future<void> _load() async {
    final b = await BookingApi.byId(widget.bookingId);
    final ev = await BookingApi.timeline(widget.bookingId);
    final code = _code ?? await BookingApi.completionCode(widget.bookingId);
    final photos = await BookingApi.photos(widget.bookingId);
    if (!mounted) return;

    // Realtime pushes this screen forward while the phone may be in a pocket,
    // so a state change is worth feeling. Only on an actual change — a plain
    // reload must stay silent.
    final moved = _booking != null && b != null && _booking!.state != b.state;
    if (moved) {
      if (b.state == 'cancelled' || b.state == 'expired') {
        Buzz.reject();
      } else {
        Buzz.commit();
      }
    }

    setState(() {
      _booking = b;
      _events = ev;
      _code = code;
      _photos = photos;
    });
  }

  /// Offers the same day-and-time picker used when booking, then asks the
  /// database to move it.
  Future<void> _reschedule() async {
    final b = _booking;
    if (b == null) return;

    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: b.scheduledFor ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'MOVE THIS BOOKING',
    );
    if (day == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: b.scheduledFor?.hour ?? 9, minute: 0),
      helpText: 'WHAT TIME?',
    );
    if (time == null || !mounted) return;

    final when =
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!when.isAfter(DateTime.now())) {
      Buzz.reject();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future.')),
      );
      return;
    }

    try {
      await BookingApi.reschedule(widget.bookingId, when);
      Buzz.commit();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking moved. We have told them.')),
        );
      }
    } catch (e) {
      Buzz.reject();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_humaniseMove(e))),
        );
      }
    }
  }

  String _humaniseMove(Object e) {
    final s = e.toString();
    if (s.contains('no longer be moved')) {
      return 'Work has already started, so this one cannot be moved. '
          'Cancel it instead if you need to.';
    }
    if (s.contains('two weeks')) return 'Please pick a time within two weeks.';
    if (s.contains('in the future')) return 'Pick a time in the future.';
    return 'Could not move that booking. Please try again.';
  }

  Future<void> _cancel() async {
    // Cancelling one visit of a plan leaves the plan alone. Saying so stops
    // a customer calling off a single week and assuming they have ended the
    // whole arrangement, or the reverse.
    final repeat = _booking?.isRepeat ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(repeat ? 'Cancel this visit?' : 'Cancel this booking?'),
        content: Text(
            'Your tradesperson will be told straight away. There is no charge '
            'for cancelling before work starts.'
            '${repeat ? ' Your ${_booking!.repeatLabel} plan carries on — end it from My bookings if you want it to stop.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(repeat ? 'Cancel this visit' : 'Cancel booking')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _cancelling = true);
    try {
      await BookingApi.cancel(widget.bookingId, 'Cancelled by customer');
      await _load();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;

    if (b == null) {
      return Scaffold(
        backgroundColor: Coal.c900,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final slug = b.tradeSlug ?? '';
    final c = categoryOf(slug);
    final closed = b.isDone || b.isBad;

    return Scaffold(
      // Dark while a job is in flight, paper once it is over. The screen
      // changing character is the clearest possible signal that the thing
      // you were watching has finished.
      backgroundColor: closed ? Surface.canvas : Coal.c900,
      body: RefreshIndicator(
        onRefresh: _load,
        color: Brand.c500,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.md, Gap.page, Gap.lg),
                  child: Row(
                    children: [
                      Pressable(
                        onTap: () => Navigator.of(context).maybePop(),
                        scale: 0.9,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: closed
                                ? Surface.raised
                                : Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            boxShadow: closed ? Shade.sm : null,
                          ),
                          child: Icon(Icons.arrow_back_rounded,
                              size: 19,
                              color: closed ? Coal.c900 : Colors.white),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          b.ref,
                          style: Txt.meta.copyWith(
                            fontWeight: FontWeight.w800,
                            color: closed ? Coal.c500 : Coal.c400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, 0, Gap.page, Gap.huge),
              sliver: SliverList.list(children: [
                if (closed)
                  _ClosedCard(booking: b, colour: c.base)
                else
                  LiveCard(
                    status: b.statusLabel,
                    headline: _headline(b),
                    detail: _detail(b),
                    eta: b.scheduledFor == null
                        ? null
                        : _when(b.scheduledFor!),
                    proName: b.providerName,
                    accent: c.base,
                    actions: [
                      if (!closed)
                        Btn('Move',
                            icon: Icons.edit_calendar_rounded,
                            kind: BtnKind.secondary,
                            onTap: _cancelling ? null : _reschedule),
                      if (!closed)
                        Btn('Cancel',
                            icon: Icons.close_rounded,
                            kind: BtnKind.secondary,
                            colour: Signal.danger,
                            onTap: _cancelling ? null : _cancel),
                    ],
                  ),

                // Somebody is standing in the room waiting on a tap. This
                // outranks everything else on the screen while it is here.
                if (b.needsStartApproval) ...[
                  const SizedBox(height: Gap.lg),
                  ApprovalPrompt(
                    icon: Icons.pan_tool_alt_rounded,
                    title:
                        '${b.providerName?.split(' ').first ?? 'Your professional'} is ready to start',
                    body: 'Confirm only once they are with you and you are '
                        'happy for the work to begin. This is what starts '
                        'the job and your cover.',
                    confirmLabel: 'Yes, they can start',
                    colour: c.base,
                    busy: _approving,
                    onConfirm:
                        _approving ? null : () => _approve(start: true),
                  ),
                ],

                if (b.needsFinishApproval) ...[
                  const SizedBox(height: Gap.lg),
                  ApprovalPrompt(
                    icon: Icons.done_all_rounded,
                    title: 'The work is finished',
                    body: 'Have a look before you approve. Once you accept, '
                        'the job closes and payment is due. If something is '
                        'not right, say so now rather than approving.',
                    confirmLabel: 'Approve the work',
                    declineLabel: 'Something is wrong',
                    colour: Signal.success,
                    busy: _approving,
                    onConfirm:
                        _approving ? null : () => _approve(start: false),
                    onDecline: _approving ? null : _raiseIssue,
                  ),
                ],

                const SizedBox(height: Gap.xl),

                // The completion code: the single most important thing on
                // this screen, because it is what protects the customer.
                if (_code != null && !closed) ...[
                  _CodeCard(code: _code!, dark: true),
                  const SizedBox(height: Gap.xl),
                ],

                _Card(
                  dark: !closed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROGRESS',
                          style: Txt.label.copyWith(
                              color: closed ? Coal.c500 : Coal.c400)),
                      const SizedBox(height: Gap.lg),
                      Timeline(stages: _stages(b), accent: c.base),
                    ],
                  ),
                ),

                const SizedBox(height: Gap.lg),

                _Card(
                  dark: !closed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DETAILS',
                          style: Txt.label.copyWith(
                              color: closed ? Coal.c500 : Coal.c400)),
                      const SizedBox(height: Gap.md),
                      _Line('Service', b.serviceName, dark: !closed),
                      if (b.addressLine != null)
                        _Line('Address', b.addressLine!, dark: !closed),
                      if (b.scheduledFor != null)
                        _Line('When', _when(b.scheduledFor!), dark: !closed),
                      if (b.isRepeat)
                        _Line('Repeats', b.repeatLabel, dark: !closed),
                      _Line(
                        'Price',
                        formatPence(b.finalPence ?? b.quotedPence),
                        dark: !closed,
                        strong: true,
                      ),
                      _Line(
                          'Payment',
                          b.paymentMethod == 'card'
                              ? 'Card through Yaari'
                              : 'Cash or card on the day',
                          dark: !closed),
                    ],
                  ),
                ),

                // Where the job is. Not live tracking — the provider app
                // does not stream GPS — so this shows the agreed location
                // rather than implying a moving dot that does not exist.
                if (bookingHasLocation(b)) ...[
                  const SizedBox(height: Gap.lg),
                  _Card(
                    dark: !closed,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('LOCATION',
                                style: Txt.label.copyWith(
                                    color: closed ? Coal.c500 : Coal.c400)),
                            const Spacer(),
                            if (!closed)
                              Pill('Agreed address',
                                  colour: c.base, dense: true),
                          ],
                        ),
                        const SizedBox(height: Gap.md),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: YaariMap(
                            centre: LatLng(b.lat!, b.lng!),
                            height: 160,
                            interactive: false,
                          ),
                        ),
                        if (b.addressLine != null) ...[
                          const SizedBox(height: Gap.md),
                          Row(
                            children: [
                              Icon(Icons.place_rounded,
                                  size: 14,
                                  color: closed ? Coal.c500 : Coal.c400),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(b.addressLine!,
                                    style: Txt.meta.copyWith(
                                        color: closed
                                            ? Coal.c600
                                            : Coal.c300)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  _Card(
                    dark: !closed,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PHOTOGRAPHS',
                            style: Txt.label.copyWith(
                                color: closed ? Coal.c500 : Coal.c400)),
                        const SizedBox(height: Gap.md),
                        _Photos(photos: _photos),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// The sentence that answers "what is happening", in the customer's terms
  /// rather than the database's.
  static String _headline(BookingSummary b) => switch (b.state) {
        'requested' => 'Finding your professional',
        'accepted' => 'Confirmed and in the diary',
        'on_the_way' => 'On the way to you',
        'in_progress' => 'Work in progress',
        'completed' => 'All done',
        'cancelled' => 'Booking cancelled',
        'expired' => 'Nobody was available',
        _ => b.statusLabel,
      };

  static String? _detail(BookingSummary b) => switch (b.state) {
        'requested' =>
          'We are offering this to checked professionals near you now.',
        'accepted' =>
          'They have your address and will arrive at the agreed time.',
        'on_the_way' => 'Have your four digit code ready for when they finish.',
        'in_progress' =>
          'Read your code out only once you are happy with the work.',
        _ => null,
      };

  /// The stages, derived from the state rather than stored, so the timeline
  /// can never disagree with the booking it is describing.
  List<Stage> _stages(BookingSummary b) {
    const order = [
      'requested',
      'accepted',
      'on_the_way',
      'in_progress',
      'completed'
    ];
    const titles = {
      'requested': ('Requested', Icons.send_rounded),
      'accepted': ('Professional accepted', Icons.how_to_reg_rounded),
      'on_the_way': ('On the way', Icons.directions_car_rounded),
      'in_progress': ('Work started', Icons.handyman_rounded),
      'completed': ('Completed', Icons.verified_rounded),
    };

    if (b.isBad) {
      return [
        const Stage(
            title: 'Requested', state: StageState.done, icon: Icons.send_rounded),
        Stage(
          title: b.state == 'expired' ? 'Nobody available' : 'Cancelled',
          detail: b.state == 'expired'
              ? 'No checked professional could take it in time'
              : 'No charge was made',
          state: StageState.failed,
        ),
      ];
    }

    final now = order.indexOf(b.state);
    return [
      for (var i = 0; i < order.length; i++)
        Stage(
          title: titles[order[i]]!.$1,
          icon: titles[order[i]]!.$2,
          detail: i == now ? _eventDetail(order[i]) : null,
          state: i < now
              ? StageState.done
              : i == now
                  ? StageState.active
                  : StageState.waiting,
        ),
    ];
  }

  String? _eventDetail(String state) {
    final ev = _events.where((e) => e.toState == state).firstOrNull;
    return ev?.ago;
  }

  static String _when(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today, $hh:$mm';
    }
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}, $hh:$mm';
  }
}

/// A surface that works on both the dark live screen and the pale closed one.
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.dark});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Gap.xl),
        decoration: BoxDecoration(
          color: dark ? Coal.c800 : Surface.raised,
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: dark ? null : Shade.sm,
        ),
        child: child,
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value,
      {required this.dark, this.strong = false});

  final String label;
  final String value;
  final bool dark;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: Txt.meta.copyWith(color: dark ? Coal.c400 : Coal.c500)),
          ),
          Expanded(
            child: Text(
              value,
              style: (strong ? Txt.price.copyWith(fontSize: 15) : Txt.body)
                  .copyWith(
                      color: dark ? Colors.white : Coal.c900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// The completion code. Nothing else on the screen is allowed to compete
/// with it — it is the only thing standing between the customer and work
/// being marked done that was not done.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.dark});

  final String code;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B7F4F), Color(0xFF0E5233)],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, size: 15, color: Color(0xFF7BE8A6)),
              const SizedBox(width: 7),
              Text('YOUR COMPLETION CODE',
                  style: Txt.label.copyWith(color: const Color(0xFF7BE8A6))),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              for (final d in code.split('')) ...[
                Container(
                  width: 44,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(d,
                      style: Txt.priceLg.copyWith(
                          color: Colors.white, fontSize: 26)),
                ),
                const SizedBox(width: Gap.sm),
              ],
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            'Read this out only when the work is finished and you are happy '
            'with it. Nobody can close the job without it.',
            style: Txt.body.copyWith(
                color: const Color(0xFFBFE8D2), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// How a finished or cancelled booking presents itself.
class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.booking, required this.colour});

  final BookingSummary booking;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final good = booking.isDone;

    return Panel(
      padding: const EdgeInsets.all(Gap.xl),
      shadow: Shade.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (good)
            const SuccessMark(size: 66)
          else
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Signal.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 30, color: Signal.danger),
            ),
          const SizedBox(height: Gap.lg),
          Text(
            good ? 'All done' : 'Booking cancelled',
            style: Txt.display.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 5),
          Text(
            good
                ? 'The work was completed and closed with your code.'
                : 'Nothing was charged for this booking.',
            style: Txt.body,
          ),
        ],
      ),
    );
  }
}


/// Before-and-after photographs of the work, signed on demand.
///
/// These are the record that settles a disagreement about scope, so they are
/// shown to the customer rather than buried in the provider's app.
class _Photos extends StatelessWidget {
  const _Photos({required this.photos});

  final Map<String, String> photos;

  @override
  Widget build(BuildContext context) {
    final entries = photos.entries.toList();

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          final e = entries[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Image.network(
                  e.value,
                  width: 140,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 140,
                    height: 112,
                    color: Coal.c100,
                    child: const Icon(Icons.image_not_supported_rounded,
                        color: Coal.c400),
                  ),
                ),
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: Pill(
                    e.key == 'before' ? 'Before' : 'After',
                    colour: Coal.c900,
                    solid: true,
                    dense: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


/// A booking only gets a map when the address was actually pinned. Drawing
/// one from a postcode centroid would show the middle of a street the job is
/// not on, which is worse than showing nothing.
bool bookingHasLocation(BookingSummary b) => b.lat != null && b.lng != null;
