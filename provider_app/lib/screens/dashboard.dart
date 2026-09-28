import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import '../jobs.dart';
import 'job_detail.dart';
import 'onboarding_docs.dart';

/// Work.
///
/// A professional opens this for one reason: is there anything for me. So
/// offers come first, in full, and everything else — today's diary, standing,
/// commission — sits underneath.
///
/// If they are not compliant nothing else matters, so that takes the whole
/// screen until it is fixed.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.auth, this.onChanged});

  final YaariAuth auth;

  /// Lets the shell refresh its badges when something here changes.
  final VoidCallback? onChanged;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ProviderStanding? _standing;
  List<Job> _offers = [];
  List<Job> _mine = [];
  Commission? _commission;
  bool _loading = true;
  bool _toggling = false;

  String? get _me => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _me;
    if (id == null) return;
    try {
      final results = await Future.wait([
        ProviderApi.myStanding(id),
        JobsApi.offers(),
        JobsApi.mine(),
        Commission.current(),
      ]);
      if (!mounted) return;
      setState(() {
        _standing = results[0] as ProviderStanding?;
        _offers = results[1] as List<Job>;
        _mine = results[2] as List<Job>;
        _commission = results[3] as Commission;
        _loading = false;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnline(bool v) async {
    final id = _me;
    if (id == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      await ProviderApi.setOnline(id, v);
      Buzz.pick();
      await _load();
    } catch (e) {
      if (!mounted) return;
      Buzz.reject();
      // The database refuses going online until approval and credentials are
      // in place. Say which, rather than letting the switch spring back.
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.contains('approved')
            ? 'You can go online once your documents are checked.'
            : msg.contains('document')
                ? 'A required document is missing or out of date.'
                : 'That did not go through. Please try again.'),
        action: SnackBarAction(label: 'Documents', onPressed: _openDocs),
      ));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _openDocs() async {
    await Navigator.of(context).go((_) => const OnboardingDocsScreen());
    _load();
  }

  Future<void> _open(Job job) async {
    await Navigator.of(context).go((_) => JobDetailScreen(job: job));
    _load();
  }

  /// Anything running now. This is what the professional is actually doing,
  /// so it outranks everything including new offers.
  Job? get _active {
    final live = _mine.where((j) => j.isActive).toList();
    return live.isEmpty ? null : live.first;
  }

  List<Job> get _upcoming =>
      _mine.where((j) => j.state == 'accepted' && !j.isActive).toList();

  @override
  Widget build(BuildContext context) {
    final s = _standing;

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: _loading
            ? const _DashSkeleton()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, Gap.md, Gap.page, Gap.lg),
                        child: _Header(
                          standing: s,
                          busy: _toggling,
                          onToggle: _toggleOnline,
                        ),
                      ),
                    ),
                  ),

                  // Not approved yet: the verification card is the whole
                  // point of the screen until it is.
                  if (s != null && !s.isApproved)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, Gap.xl),
                        child: Reveal(
                          child: _VerifyCard(
                            missing: s.missingDocs.length,
                            onOpen: _openDocs,
                          ),
                        ),
                      ),
                    )
                  // Compliance beats everything. A lapsed certificate means
                  // no work at all, so it is stated once, loudly, with the
                  // fix one tap away.
                  else if (s != null && !s.isCompliant)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, Gap.xl),
                        child: Reveal(
                          child: _BlockedCard(
                            standing: s,
                            onFix: _openDocs,
                          ),
                        ),
                      ),
                    ),

                  if (_active != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, Gap.xl),
                        child: Reveal(
                          child: LiveCard(
                            status: _active!.stateLabel,
                            headline: _active!.serviceName,
                            detail: _active!.whereShown,
                            proName: _active!.customerName,
                            accent: Brand.c400,
                            actions: [
                              Btn(_active!.nextActionLabel,
                                  onTap: () => _open(_active!)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_offers.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, 0),
                        child: SectionHead(
                          _offers.length == 1
                              ? 'One job offered to you'
                              : '${_offers.length} jobs offered to you',
                          trailing: const Pill('New',
                              tone: ChipTone.brand, dense: true),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, Gap.xl),
                      sliver: SliverList.separated(
                        itemCount: _offers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Gap.md),
                        itemBuilder: (context, i) => Reveal(
                          delay: Duration(milliseconds: 60 + 50 * i),
                          child: _JobCard(
                            job: _offers[i],
                            offer: true,
                            onTap: () => _open(_offers[i]),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_upcoming.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, 0, Gap.page, 0),
                        child: SectionHead('Coming up',
                            trailing: Pill('${_upcoming.length}', dense: true)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, Gap.xl),
                      sliver: SliverList.separated(
                        itemCount: _upcoming.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Gap.md),
                        itemBuilder: (context, i) => Reveal(
                          delay: Duration(milliseconds: 60 + 50 * i),
                          child: _JobCard(
                            job: _upcoming[i],
                            onTap: () => _open(_upcoming[i]),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_offers.isEmpty && _active == null && _upcoming.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.xl),
                        child: StateView(
                          icon: (s?.isOnline ?? false)
                              ? Icons.notifications_active_rounded
                              : Icons.toggle_off_rounded,
                          title: (s?.isOnline ?? false)
                              ? 'Nothing right now'
                              : "You're offline",
                          body: (s?.isOnline ?? false)
                              ? 'You are visible to customers nearby. We will '
                                  'tell you the moment a job comes in.'
                              : 'Customers cannot see you while you are '
                                  'offline. Switch on to start receiving work.',
                          action: (s?.isOnline ?? false)
                              ? null
                              : 'Go online',
                          onAction: (s?.isOnline ?? false)
                              ? null
                              : () => _toggleOnline(true),
                        ),
                      ),
                    ),

                  if (_commission != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 0, Gap.page, 120),
                      sliver: SliverToBoxAdapter(
                        child: _CommissionCard(commission: _commission!),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Name, trade, and the one control that matters: online or not.
class _Header extends StatelessWidget {
  const _Header({
    required this.standing,
    required this.busy,
    required this.onToggle,
  });

  final ProviderStanding? standing;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = standing;
    final online = s?.isOnline ?? false;
    final blocked = s != null && !s.isCompliant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Avatar(s?.name ?? 'Y', size: 44),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s?.name ?? 'Your account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.title.copyWith(fontSize: 18)),
                  if (s?.trade != null)
                    Text(s!.trade!, style: Txt.meta),
                ],
              ),
            ),
            if (s?.ratingAvg != null)
              Pill(s!.ratingAvg!.toStringAsFixed(1),
                  icon: Icons.star_rounded,
                  colour: const Color(0xFFC9871A)),
          ],
        ),
        const SizedBox(height: Gap.lg),

        // The availability switch. Deliberately large and unambiguous — a
        // professional who thinks they are online and is not will blame the
        // platform for having no work.
        Panel(
          padding: const EdgeInsets.all(Gap.lg),
          shadow: Shade.sm,
          colour: online ? Signal.successSoft : Surface.raised,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (online ? Signal.success : Coal.c400)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                    online ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                    size: 18,
                    color: online ? Signal.success : Coal.c500),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(online ? 'Taking work' : 'Not taking work',
                        style: Txt.cardTitle.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 1),
                    Text(
                      blocked
                          ? 'Blocked until your documents are up to date'
                          : online
                              ? 'Customers nearby can see you'
                              : 'You are hidden from search',
                      style: Txt.meta,
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Switch(
                  value: online,
                  onChanged: blocked ? null : onToggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Signal.success,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An applicant's home screen, until they are cleared.
///
/// The Uber pattern: you are in the app, you can see what it will look like,
/// and the one thing standing between you and work is stated with a button.
class _VerifyCard extends StatelessWidget {
  const _VerifyCard({required this.missing, required this.onOpen});

  final int missing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final waiting = missing == 0;
    return Panel(
      onTap: onOpen,
      padding: const EdgeInsets.all(Gap.xl),
      shadow: Shade.tinted(Brand.c500),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Brand.c500, Brand.c700],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Icon(
                  waiting
                      ? Icons.hourglass_top_rounded
                      : Icons.assignment_rounded,
                  size: 20,
                  color: Colors.white),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                waiting ? 'We are checking your documents' : 'Finish getting verified',
                style: Txt.cardTitle
                    .copyWith(color: Colors.white, fontSize: 17),
              ),
            ),
          ]),
          const SizedBox(height: Gap.md),
          Text(
            waiting
                ? 'Everything is in. We check each one against the issuing '
                    'register, usually the same day. You can go online the '
                    'moment one of your trades is cleared.'
                : '$missing ${missing == 1 ? "document" : "documents"} still '
                    'to send. Each trade you do has its own legal '
                    'requirements — you can go online as soon as one trade '
                    'is fully cleared.',
            style: Txt.body.copyWith(
                fontSize: 13.5, color: Colors.white.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: Gap.lg),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg, vertical: Gap.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.button),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(waiting ? 'See my checklist' : 'Send my documents',
                    style: Txt.button.copyWith(color: Brand.c600)),
                const SizedBox(width: Gap.sm),
                const Icon(Icons.arrow_forward_rounded,
                    size: 18, color: Brand.c600),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the compliance gate is holding them back.
class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.standing, required this.onFix});

  final ProviderStanding standing;
  final VoidCallback onFix;

  static String _label(String docType) => switch (docType) {
        'photo_id' => 'Photo ID',
        'right_to_work' => 'Right to work',
        'public_liability_insurance' => 'Public liability insurance',
        'treatment_insurance' => 'Treatment liability insurance',
        'special_treatment_licence' => 'Borough treatment licence',
        'gas_safe' => 'Gas Safe registration',
        'part_p' => 'Part P certification',
        'dbs_basic' => 'Basic DBS check',
        'trade_qualification' => 'Trade qualification',
        'pet_care_cover' => 'Pet care cover',
        _ => docType,
      };

  @override
  Widget build(BuildContext context) {
    return Panel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Brand.c500, Brand.c700],
      ),
      padding: const EdgeInsets.all(Gap.xl),
      radius: Radii.panel,
      shadow: Shade.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, size: 20, color: Colors.white),
              const SizedBox(width: Gap.sm),
              Text('Not receiving work',
                  style: Txt.cardTitle.copyWith(
                      color: Colors.white, fontSize: 16)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            standing.missingDocs.isEmpty
                ? 'Something on your account needs attention before customers '
                    'can book you.'
                : 'Customers cannot see you until these are valid and in date:',
            style: Txt.body.copyWith(color: Brand.c100, fontSize: 13),
          ),
          if (standing.missingDocs.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in standing.missingDocs)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(_label(d),
                        style: Txt.meta.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Gap.xl),
          Btn('Update my documents',
              onTap: onFix, kind: BtnKind.primary, colour: Colors.white),
        ],
      ),
    );
  }
}

/// One job, offered or booked.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap, this.offer = false});

  final Job job;
  final VoidCallback onTap;
  final bool offer;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(job.tradeSlug ?? '');

    return Panel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      shadow: offer ? Shade.md : Shade.sm,
      border: offer
          ? Border.all(color: Brand.c500.withValues(alpha: 0.45), width: 1.5)
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: YaariMark(job.tradeSlug ?? '',
                      size: 28, ink: c.deep, accent: c.base),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(job.serviceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Txt.cardTitle.copyWith(fontSize: 15)),
                          ),
                          Text(formatPence(job.finalPence ?? job.quotedPence),
                              style: Txt.price.copyWith(fontSize: 15.5)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_rounded,
                              size: 13, color: Coal.c400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(job.whereShown,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Txt.meta),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          Pill(
                            job.isAsap
                                ? 'As soon as possible'
                                : _when(job.scheduledFor),
                            icon: Icons.schedule_rounded,
                            colour: c.deep,
                            dense: true,
                          ),
                          if (job.isRepeat)
                            Pill(job.repeatLabel,
                                icon: Icons.event_repeat_rounded,
                                tone: ChipTone.success,
                                dense: true),
                          Pill(
                              job.paymentMethod == 'cash'
                                  ? 'Cash or card on the day'
                                  : 'Paid by card',
                              tone: ChipTone.neutral,
                              dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (offer)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg, vertical: 10),
              decoration: BoxDecoration(
                color: Brand.c50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(Radii.card - 2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: Brand.c600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Offered to you — tap to accept or pass',
                        style: Txt.meta.copyWith(
                            color: Brand.c700, fontWeight: FontWeight.w800)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Brand.c600),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _when(DateTime? d) {
    if (d == null) return 'Scheduled';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final today =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return today
        ? 'Today $hh:$mm'
        : '${days[d.weekday - 1]} ${d.day}, $hh:$mm';
  }
}

/// What Yaari takes, read from the database rather than promised in code.
class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.commission});

  final Commission commission;

  @override
  Widget build(BuildContext context) {
    return Panel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Coal.c800, Coal.c900],
      ),
      padding: const EdgeInsets.all(Gap.xl),
      radius: Radii.panel,
      shadow: Shade.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Signal.success.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.savings_rounded,
                    size: 18, color: Color(0xFF4ADE80)),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                    commission.isFree
                        ? 'You keep everything you earn'
                        : 'Yaari takes ${commission.rate}',
                    style: Txt.cardTitle.copyWith(
                        color: Colors.white, fontSize: 15.5)),
              ),
            ],
          ),
          if (commission.note != null) ...[
            const SizedBox(height: Gap.md),
            Text(commission.note!,
                style: Txt.body.copyWith(color: Coal.c300, fontSize: 13)),
          ],
          const SizedBox(height: Gap.md),
          Text('You are only ever charged on work you complete.',
              style: Txt.meta.copyWith(color: Coal.c400)),
        ],
      ),
    );
  }
}

class _DashSkeleton extends StatelessWidget {
  const _DashSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.huge),
        children: [
          Row(children: const [
            Skeleton(width: 44, height: 44, radius: 99),
            SizedBox(width: Gap.md),
            Expanded(child: Skeleton(height: 18)),
          ]),
          const SizedBox(height: Gap.lg),
          const Skeleton(height: 72, radius: Radii.card),
          const SizedBox(height: Gap.xxl),
          const Skeleton(width: 160, height: 18),
          const SizedBox(height: Gap.md),
          const Skeleton(height: 150, radius: Radii.card),
          const SizedBox(height: Gap.md),
          const Skeleton(height: 150, radius: Radii.card),
        ],
      ),
    );
  }
}
