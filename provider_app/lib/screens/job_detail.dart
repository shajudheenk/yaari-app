import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../jobs.dart';

/// Doing the job: accept, travel, photograph, close with the code.
///
/// Each button does exactly one thing and says what will happen. The
/// order is enforced by the server, so the screen never has to guess.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.job});

  final Job job;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Job _job = widget.job;
  bool _busy = false;
  String? _error;
  bool _beforePhoto = false;
  bool _afterPhoto = false;
  String? _beforeUrl;
  String? _afterUrl;

  @override
  void initState() {
    super.initState();
    _refreshPhotos();
  }

  Future<void> _refreshPhotos() async {
    final b = await JobsApi.hasPhoto(_job.id, 'before');
    final a = await JobsApi.hasPhoto(_job.id, 'after');
    // Signed, because the bucket is private: there is no permanent URL that
    // could be forwarded to someone who should not see inside the house.
    final bUrl = b ? await JobsApi.photoUrl(_job.id, 'before') : null;
    final aUrl = a ? await JobsApi.photoUrl(_job.id, 'after') : null;
    if (mounted) {
      setState(() {
        _beforePhoto = b;
        _afterPhoto = a;
        _beforeUrl = bUrl;
        _afterUrl = aUrl;
      });
    }
  }

  /// Camera first, gallery as a fallback for a phone with no working camera.
  Future<void> _capture(String kind) async {
    final picker = ImagePicker();
    XFile? shot;
    try {
      shot = await picker.pickImage(
        source: ImageSource.camera,
        // Enough to show what was done, small enough to send on site over a
        // patchy connection.
        maxWidth: 1600,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      shot = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
    }
    if (shot == null) return; // cancelled

    final bytes = await shot.readAsBytes();
    await _run(() => JobsApi.addPhoto(_job.id, kind, bytes));
  }

  Future<void> _reload() async {
    final all = await JobsApi.mine();
    final found = all.where((j) => j.id == _job.id).firstOrNull;
    if (found != null && mounted) setState(() => _job = found);
    await _refreshPhotos();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      Buzz.commit();
      await _reload();
    } catch (e) {
      if (mounted) {
        Buzz.reject();
        setState(() => _error = _humanise(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('before photo')) return 'Take the before photo first.';
    if (s.contains('after photo')) return 'Take the after photo first.';
    if (s.contains('on the way')) {
      return 'Tell the customer you are on the way first.';
    }
    if (s.contains('has not been marked finished')) {
      return 'Mark the work finished before asking them to approve it.';
    }
    if (s.contains('code is not right')) return 'That code is not right. Check with the customer.';
    if (s.contains('credentials are not up to date')) {
      return 'Your credentials have lapsed, so you cannot take work right now.';
    }
    if (s.contains('no longer open')) return 'Somebody else has already taken this job.';
    if (s.contains('offered to someone else')) return 'This job is being offered to someone else.';
    return 'That did not work. Please try again.';
  }

  Future<void> _finish() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (code == null || code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final paid = await JobsApi.complete(_job.id, code);
      Buzz.commit();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _PaidDialog(payment: paid, method: _job.paymentMethod),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        Buzz.reject();
        setState(() => _error = _humanise(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    final c = categoryOf(j.tradeSlug ?? '');

    return Scaffold(
      backgroundColor: Surface.canvas,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            scale: 0.9,
            child: Container(
              decoration: BoxDecoration(
                  color: Surface.raised,
                  shape: BoxShape.circle,
                  boxShadow: Shade.sm),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: Coal.c900),
            ),
          ),
        ),
        title: Text(j.ref, style: Txt.meta.copyWith(fontSize: 13)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.huge),
        children: [
          Reveal(child: _JobHead(job: j, colour: c)),
          const SizedBox(height: Gap.lg),

          // Where the work is. Full address only after acceptance — before
          // that the server hands back the area alone, so a declined offer
          // never reveals where somebody lives.
          Reveal(
            delay: const Duration(milliseconds: 50),
            child: _WhereCard(job: j, colour: c),
          ),
          const SizedBox(height: Gap.lg),

          if (j.state == 'completed') ...[
            const Reveal(child: _DoneBanner()),
            const SizedBox(height: Gap.lg),
          ],

          // The sequence, drawn as the timeline the customer sees too, so
          // both sides of the job are looking at the same picture.
          Reveal(
            delay: const Duration(milliseconds: 100),
            child: Panel(
              padding: const EdgeInsets.all(Gap.xl),
              shadow: Shade.sm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THE JOB', style: Txt.label),
                  const SizedBox(height: Gap.lg),
                  Timeline(accent: c.base, stages: _stages(j)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),

          if (j.state == 'in_progress' || j.state == 'completed') ...[
            Reveal(
              delay: const Duration(milliseconds: 140),
              child: Panel(
                padding: const EdgeInsets.all(Gap.xl),
                shadow: Shade.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EVIDENCE', style: Txt.label),
                    const SizedBox(height: 5),
                    Text(
                      'Both photographs are saved to the booking. They are '
                      'what settles a disagreement about what was done.',
                      style: Txt.bodySm,
                    ),
                    const SizedBox(height: Gap.lg),
                    _PhotoRow(
                      label: 'Before',
                      taken: _beforePhoto,
                      url: _beforeUrl,
                      colour: c,
                      onTake: _busy ? null : () => _capture('before'),
                    ),
                    const SizedBox(height: Gap.md),
                    _PhotoRow(
                      label: 'After',
                      taken: _afterPhoto,
                      url: _afterUrl,
                      colour: c,
                      onTake: _busy || j.state == 'completed'
                          ? null
                          : () => _capture('after'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
          ],

          if (_error != null) ...[
            Panel(
              colour: Signal.dangerSoft,
              shadow: const [],
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 18, color: Signal.danger),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Text(_error!,
                        style: Txt.body.copyWith(
                            color: Brand.c700, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),
          ],

          Reveal(
            delay: const Duration(milliseconds: 180),
            child: _MoneyCard(job: j),
          ),
        ],
      ),
      bottomNavigationBar: j.state == 'completed' || j.state == 'cancelled'
          ? null
          : _ActionBar(
              job: j,
              busy: _busy,
              colour: c.base,
              onAccept: () => _run(() => JobsApi.accept(j.id)),
              onAdvance: (to) => _run(() => JobsApi.advance(j.id, to)),
              onRequestStart: () => _run(() => JobsApi.requestStart(j.id)),
              onRequestFinish: () => _run(() => JobsApi.requestFinish(j.id)),
              onFinishWithCode: _finish,
            ),
    );
  }

  /// The job's progress, mapped onto the shared timeline component.
  List<Stage> _stages(Job j) {
    const order = ['requested', 'accepted', 'en_route', 'in_progress', 'completed'];
    final now = order.indexOf(j.state);

    StageState at(int i) {
      if (j.state == 'cancelled' || j.state == 'expired') {
        return i == 0 ? StageState.failed : StageState.waiting;
      }
      if (now < 0) return StageState.waiting;
      if (i < now) return StageState.done;
      if (i == now) {
        return j.state == 'completed' ? StageState.done : StageState.active;
      }
      return StageState.waiting;
    }

    return [
      Stage(
          title: 'Offered to you',
          detail: 'Accept to see the full address',
          state: at(0),
          icon: Icons.mail_rounded),
      Stage(
          title: 'Accepted',
          detail: 'The customer knows you are coming',
          state: at(1),
          icon: Icons.check_rounded),
      Stage(
          title: 'On the way',
          detail: 'Tell them when you set off',
          state: at(2),
          icon: Icons.directions_car_rounded),
      Stage(
          title: 'Working',
          detail: 'Take the before photograph first',
          state: at(3),
          icon: Icons.construction_rounded),
      Stage(
          title: 'Finished',
          detail: 'Closed with the customer\'s four digit code',
          state: at(4),
          icon: Icons.verified_rounded),
    ];
  }
}

/// The job title, trade mark and current state.
class _JobHead extends StatelessWidget {
  const _JobHead({required this.job, required this.colour});

  final Job job;
  final Category colour;

  @override
  Widget build(BuildContext context) {
    return Panel(
      gradient: colour.header,
      padding: const EdgeInsets.all(Gap.xl),
      radius: Radii.panel,
      shadow: Shade.tinted(colour.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: YaariMark(job.tradeSlug ?? '',
                    size: 28, ink: colour.deep, accent: colour.base),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text(job.stateLabel,
                    style: Txt.meta.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text(job.serviceName,
              style: Txt.display.copyWith(color: Colors.white, fontSize: 24)),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _WhitePill(
                  job.isAsap ? 'As soon as possible' : _when(job.scheduledFor),
                  Icons.schedule_rounded),
              if (job.isRepeat)
                _WhitePill('${job.repeatLabel} · regular slot',
                    Icons.event_repeat_rounded),
            ],
          ),
        ],
      ),
    );
  }

  static String _when(DateTime? d) {
    if (d == null) return 'Scheduled';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]} ${d.day}, $hh:$mm';
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: Txt.meta.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Where the job is, with a map once the address has been released.
class _WhereCard extends StatelessWidget {
  const _WhereCard({required this.job, required this.colour});

  final Job job;
  final Category colour;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      shadow: Shade.sm,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colour.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.place_rounded,
                      size: 16, color: colour.deep),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.isOffer ? 'AREA' : 'ADDRESS',
                          style: Txt.label),
                      const SizedBox(height: 2),
                      Text(job.whereShown,
                          style: Txt.cardTitle.copyWith(fontSize: 14)),
                      if (job.customerName != null) ...[
                        const SizedBox(height: 3),
                        Text(job.customerName!, style: Txt.meta),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (job.hasLocation)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(Radii.card - 1)),
              child: YaariMap(
                centre: LatLng(job.lat!, job.lng!),
                height: 150,
                interactive: false,
              ),
            )
          else if (job.isOffer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg, vertical: 10),
              decoration: const BoxDecoration(
                color: Signal.infoSoft,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(Radii.card - 1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 13, color: Signal.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'The full address is released when you accept',
                        style: Txt.meta.copyWith(color: Signal.info)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What the job pays, and what is deducted.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(Gap.xl),
      shadow: Shade.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAYMENT', style: Txt.label),
          const SizedBox(height: Gap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                    job.paymentMethod == 'cash'
                        ? 'Collected from the customer on the day'
                        : 'Card, paid out by Stripe',
                    style: Txt.bodySm),
              ),
              const SizedBox(width: Gap.md),
              Text(formatPence(job.finalPence ?? job.quotedPence),
                  style: Txt.priceLg.copyWith(fontSize: 27)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one action available right now, pinned where the thumb is.
///
/// Starting and finishing are held rather than tapped, because both hand
/// control to the customer and a mis-tap in a stranger's hallway is
/// embarrassing. Every other transition is an ordinary button.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.job,
    required this.busy,
    required this.colour,
    required this.onAccept,
    required this.onAdvance,
    required this.onRequestStart,
    required this.onRequestFinish,
    required this.onFinishWithCode,
  });

  final Job job;
  final bool busy;
  final Color colour;
  final VoidCallback onAccept;
  final ValueChanged<String> onAdvance;
  final VoidCallback onRequestStart;
  final VoidCallback onRequestFinish;
  final VoidCallback onFinishWithCode;

  @override
  Widget build(BuildContext context) {
    final waiting = job.awaitingStart || job.awaitingFinish;

    return Container(
      decoration: BoxDecoration(
        color: Surface.raised,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(Radii.panel)),
        boxShadow: Shade.lg,
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (waiting)
              _WaitingOnCustomer(
                label: job.awaitingStart
                    ? 'Waiting for ${_firstName(job)} to confirm'
                    : 'Waiting for ${_firstName(job)} to approve the work',
                hint: job.awaitingStart
                    ? 'It appears on their phone now. Ask them to tap Confirm.'
                    : 'They can approve on their phone, or read you their code.',
                colour: colour,
                onFallback: job.awaitingFinish ? onFinishWithCode : null,
              )
            else if (job.state == 'en_route')
              HoldToConfirm(
                label: 'Hold to begin',
                hint: '${_firstName(job)} confirms on their phone before '
                    'the clock starts',
                icon: Icons.play_arrow_rounded,
                colour: colour,
                busy: busy,
                onConfirmed: onRequestStart,
              )
            else if (job.state == 'in_progress')
              HoldToConfirm(
                label: 'Hold when the work is done',
                hint: 'The after photo has to be taken first',
                icon: Icons.done_all_rounded,
                colour: Signal.success,
                busy: busy,
                onConfirmed: onRequestFinish,
              )
            else
              Btn(job.nextActionLabel,
                  busy: busy,
                  colour: colour,
                  onTap: switch (job.state) {
                    'requested' => onAccept,
                    'accepted' => () => onAdvance('en_route'),
                    _ => null,
                  }),
          ],
        ),
      ),
    );
  }

  static String _firstName(Job j) =>
      (j.customerName ?? 'the customer').split(' ').first;
}

/// Shown while the ball is in the customer's court.
class _WaitingOnCustomer extends StatelessWidget {
  const _WaitingOnCustomer({
    required this.label,
    required this.hint,
    required this.colour,
    this.onFallback,
  });

  final String label;
  final String hint;
  final Color colour;

  /// The four digit code, for a customer with no signal or no phone to hand.
  final VoidCallback? onFallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: colour),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Txt.cardTitle.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(hint, style: Txt.meta),
                ],
              ),
            ),
          ],
        ),
        if (onFallback != null) ...[
          const SizedBox(height: Gap.md),
          Btn('Enter their code instead',
              kind: BtnKind.secondary, onTap: onFallback, colour: colour),
        ],
      ],
    );
  }
}

/// One evidence photograph, with a preview and a retake.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.label,
    required this.taken,
    required this.url,
    required this.colour,
    required this.onTake,
  });

  final String label;
  final bool taken;
  final String? url;
  final Category colour;
  final VoidCallback? onTake;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: taken ? colour.tint : Coal.c50,
            borderRadius: BorderRadius.circular(13),
          ),
          child: url != null
              ? Image.network(url!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.image_rounded,
                      size: 20, color: colour.deep))
              : Icon(
                  taken ? Icons.check_rounded : Icons.photo_camera_rounded,
                  size: 20,
                  color: taken ? Signal.success : Coal.c400),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Txt.cardTitle.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(taken ? 'Saved to the booking' : 'Not taken yet',
                  style: Txt.meta.copyWith(
                      color: taken ? Signal.success : Coal.c500)),
            ],
          ),
        ),
        if (onTake != null)
          Btn(taken ? 'Retake' : 'Take',
              onTap: onTake,
              kind: BtnKind.secondary,
              full: false,
              colour: colour.base),
      ],
    );
  }
}

/// Asking for the customer's completion code.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Surface.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel)),
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Brand.c50,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.pin_rounded, size: 20, color: Brand.c600),
            ),
            const SizedBox(height: Gap.lg),
            Text('Ask for the code', style: Txt.display.copyWith(fontSize: 22)),
            const SizedBox(height: 5),
            Text(
              'The customer has a four digit code on their phone. Only they '
              'can see it, and only it can close this job.',
              style: Txt.bodySm,
            ),
            const SizedBox(height: Gap.xl),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: Face.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 12),
              decoration: const InputDecoration(
                  counterText: '', hintText: '0000'),
            ),
            const SizedBox(height: Gap.xl),
            Btn('Close the job',
                onTap: () => Navigator.pop(context, _controller.text)),
            const SizedBox(height: Gap.sm),
            Btn('Back',
                kind: BtnKind.ghost,
                onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

/// The moment a job closes and the money is confirmed.
class _PaidDialog extends StatelessWidget {
  const _PaidDialog({required this.payment, required this.method});

  final JobPayment payment;
  final String method;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Surface.canvas,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel)),
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SuccessMark(size: 84),
            const SizedBox(height: Gap.lg),
            Text('Job closed', style: Txt.display.copyWith(fontSize: 22)),
            const SizedBox(height: Gap.sm),
            CountUp(
              value: payment.netPence,
              format: (v) => formatPence(v.round()),
              style: Txt.priceLg.copyWith(color: Signal.success),
            ),
            const SizedBox(height: Gap.md),
            Text(
              method == 'cash'
                  ? payment.commissionPence == 0
                      ? 'Collect this in cash. No commission during the '
                          'launch offer.'
                      : 'Collect ${formatPence(payment.amountPence)} in cash. '
                          '${formatPence(payment.commissionPence)} commission '
                          'is settled later.'
                  : 'The card hold is taken and paid out to you by Stripe.',
              textAlign: TextAlign.center,
              style: Txt.bodySm,
            ),
            const SizedBox(height: Gap.xl),
            Btn('Done', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  const _DoneBanner();

  @override
  Widget build(BuildContext context) {
    return Panel(
      colour: Signal.successSoft,
      shadow: const [],
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 19, color: Signal.success),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text('This job is finished and recorded.',
                style: Txt.body.copyWith(
                    color: const Color(0xFF14613C), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
