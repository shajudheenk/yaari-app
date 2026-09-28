import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../apply.dart';
import 'upload_doc.dart';

/// The documents step, and the checklist the dashboard opens afterwards.
///
/// Laid out per trade rather than as one flat list, because that is how the
/// requirement actually works: a care job and a cleaning job ask for
/// different things, and a trade becomes bookable the moment its own set is
/// cleared — not when every trade the person picked is. Seeing "Cleaning:
/// ready" while "Care: 2 to send" is the whole story at a glance.
///
/// A credential two trades share (public liability, photo ID) shows under
/// both, but it is one document: sending it once clears it everywhere.
class OnboardingDocsScreen extends StatefulWidget {
  const OnboardingDocsScreen({
    super.key,
    this.firstRun = false,
    this.onFinish,
  });

  /// True straight after applying. Changes the closing button from "back" to
  /// "go to my dashboard" and says so in the header.
  final bool firstRun;

  /// Called when the applicant leaves the first-run flow, so the app can
  /// route them to the home screen.
  final VoidCallback? onFinish;

  @override
  State<OnboardingDocsScreen> createState() => _OnboardingDocsScreenState();
}

class _OnboardingDocsScreenState extends State<OnboardingDocsScreen> {
  Application? _app;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await ApplyApi.mine();
      if (!mounted) return;
      setState(() {
        _app = a;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'We could not load your checklist. Pull down to try again.';
        });
      }
    }
  }

  Future<void> _send(RequiredDoc doc) async {
    final sent = await showUploadSheet(context, doc);
    if (!sent || !mounted) return;
    Buzz.commit();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${doc.label} sent. We check it against the issuing '
          'register, usually the same day.'),
    ));
  }

  void _finish() {
    Buzz.commit();
    if (widget.firstRun) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      widget.onFinish?.call();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _app;

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.md, Gap.page, 0),
                  child: Row(children: [
                    if (!widget.firstRun)
                      Pressable(
                        onTap: () => Navigator.of(context).maybePop(),
                        scale: 0.9,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: Surface.raised,
                              shape: BoxShape.circle,
                              boxShadow: Shade.sm),
                          child: const Icon(Icons.arrow_back_rounded,
                              size: 19, color: Coal.c900),
                        ),
                      ),
                    if (widget.firstRun)
                      const Expanded(
                        child: Steps(
                            step: 6, of: 6, label: 'Your documents'),
                      ),
                  ]),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.xl, Gap.page, Gap.huge),
              sliver: SliverList.list(children: [
                Text(
                  widget.firstRun ? 'Now, your documents' : 'Your documents',
                  style: Txt.hero.copyWith(fontSize: 30),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'Each job has its own legal requirements. Send what you '
                  'have now — a photo is fine. We check every one against '
                  'the issuing register, usually the same day.',
                  style: Txt.body,
                ),
                const SizedBox(height: Gap.xl),
                if (_loading)
                  ...List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: Gap.md),
                      child: Skeleton(height: 120, radius: Radii.card),
                    ),
                  )
                else if (_error != null || a == null)
                  StateView(
                    icon: Icons.cloud_off_rounded,
                    title: 'Not loaded',
                    body: _error ?? 'Your application was not found.',
                    tone: ChipTone.warning,
                  )
                else ...[
                  Reveal(child: _Progress(app: a)),
                  if (a.needsUtr) ...[
                    const SizedBox(height: Gap.md),
                    const Reveal(
                      delay: Duration(milliseconds: 40),
                      child: _UtrReminder(),
                    ),
                  ],
                  const SizedBox(height: Gap.xl),
                  for (var i = 0; i < a.trades.length; i++) ...[
                    Reveal(
                      delay: Duration(milliseconds: 60 + 50 * i),
                      child: _TradeBlock(
                        slug: a.trades[i].slug,
                        name: a.trades[i].name,
                        docs: a.docsFor(a.trades[i].slug),
                        cleared: a.clearedFor(a.trades[i].slug),
                        onSend: _send,
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                  ],
                  const _WhyWeAsk(),
                ],
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: a == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.md, Gap.page, Gap.md),
                decoration: BoxDecoration(
                  color: Surface.raised,
                  boxShadow: Shade.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (a.toSend.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        child: Text(
                          '${a.toSend.length} still to send — you can finish '
                          'from your dashboard at any time.',
                          textAlign: TextAlign.center,
                          style: Txt.meta,
                        ),
                      ),
                    Btn(
                      widget.firstRun ? 'Go to my dashboard' : 'Done',
                      icon: widget.firstRun
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                      onTap: _finish,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// How far along they are, in the three numbers that matter.
class _Progress extends StatelessWidget {
  const _Progress({required this.app});

  final Application app;

  @override
  Widget build(BuildContext context) {
    final cleared = app.verified.length;
    final withUs = app.withUs.length;
    final toSend = app.toSend.length;
    final total = app.total;
    final ratio = total == 0 ? 0.0 : cleared / total;

    return Panel(
      padding: const EdgeInsets.all(Gap.lg),
      colour: Coal.c900,
      shadow: Shade.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  toSend == 0 && withUs == 0
                      ? 'All cleared'
                      : toSend == 0
                          ? 'Everything is with us'
                          : 'Getting you verified',
                  style: Txt.cardTitle
                      .copyWith(color: Colors.white, fontSize: 17),
                ),
              ),
              Text(
                '$cleared/$total',
                style: Txt.price.copyWith(
                  color: Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: Motion.slow,
              curve: Motion.settle,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(Sky.c400),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              _Count(n: cleared, label: 'cleared', colour: Sky.c300),
              _Count(n: withUs, label: 'being checked', colour: Coal.c300),
              _Count(n: toSend, label: 'to send', colour: Brand.c300),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.n, required this.label, required this.colour});

  final int n;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$n $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.meta.copyWith(color: Coal.c200, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

/// One trade and everything it needs.
class _TradeBlock extends StatelessWidget {
  const _TradeBlock({
    required this.slug,
    required this.name,
    required this.docs,
    required this.cleared,
    required this.onSend,
  });

  final String slug;
  final String name;
  final List<RequiredDoc> docs;
  final bool cleared;
  final ValueChanged<RequiredDoc> onSend;

  @override
  Widget build(BuildContext context) {
    final cat = categoryOf(slug);
    final owed = docs.where((d) => d.isMandatory && d.needsAction).length;

    return Panel(
      padding: EdgeInsets.zero,
      shadow: Shade.md,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.md),
            decoration: BoxDecoration(
              gradient: cat.whisper,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.card)),
            ),
            child: Row(
              children: [
                YaariMark(slug, size: 42),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(name,
                      style: Txt.cardTitle.copyWith(fontSize: 16)),
                ),
                if (cleared)
                  const Pill('Ready to work',
                      tone: ChipTone.success, icon: Icons.check_rounded,
                      dense: true)
                else if (owed > 0)
                  Pill('$owed to send', tone: ChipTone.warning, dense: true)
                else
                  const Pill('Being checked', tone: ChipTone.info, dense: true),
              ],
            ),
          ),
          for (var i = 0; i < docs.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 58),
            _DocLine(doc: docs[i], colour: cat.deep, onTap: () => onSend(docs[i])),
          ],
        ],
      ),
    );
  }
}

/// One credential: what it is, the legal note behind it, and where it stands.
class _DocLine extends StatelessWidget {
  const _DocLine({required this.doc, required this.colour, required this.onTap});

  final RequiredDoc doc;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color tint, String chip, ChipTone tone) =
        switch (doc.state) {
      DocState.verified => (
          Icons.verified_rounded,
          Signal.success,
          'Cleared',
          ChipTone.success
        ),
      DocState.pending => (
          Icons.hourglass_top_rounded,
          Sky.c700,
          'Checking',
          ChipTone.info
        ),
      DocState.rejected => (
          Icons.error_rounded,
          Signal.danger,
          'Send again',
          ChipTone.danger
        ),
      DocState.expired => (
          Icons.event_busy_rounded,
          Signal.danger,
          'Expired',
          ChipTone.danger
        ),
      DocState.missing => (
          Icons.upload_file_rounded,
          colour,
          doc.isMandatory ? 'Send' : 'Optional',
          doc.isMandatory ? ChipTone.brand : ChipTone.neutral
        ),
    };

    // A cleared document is finished; nothing to tap. Everything else opens
    // the upload sheet — including "checking", so a blurry photo can be
    // replaced before anyone reviews it.
    final tappable = doc.state != DocState.verified;

    return Pressable(
      onTap: tappable ? onTap : null,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: tint),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.label,
                      style: Txt.cardTitle.copyWith(fontSize: 14)),
                  if (doc.state == DocState.rejected &&
                      doc.rejectionReason != null) ...[
                    const SizedBox(height: 3),
                    Text(doc.rejectionReason!,
                        style: Txt.meta.copyWith(color: Signal.danger)),
                  ] else if (doc.note != null &&
                      doc.state != DocState.verified) ...[
                    const SizedBox(height: 3),
                    Text(doc.note!, style: Txt.meta),
                  ] else if (doc.state == DocState.verified &&
                      doc.expiresOn != null) ...[
                    const SizedBox(height: 3),
                    Text('Valid until ${_date(doc.expiresOn!)}',
                        style: Txt.meta),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            Pill(chip, tone: tone, dense: true),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }
}

class _UtrReminder extends StatelessWidget {
  const _UtrReminder();

  @override
  Widget build(BuildContext context) => Panel(
        colour: Signal.warningSoft,
        shadow: const [],
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 18, color: Signal.warning),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'We still need your UTR from HMRC before your first payout. '
                'Add it from your account once it arrives.',
                style: Txt.body.copyWith(fontSize: 13, color: Coal.c800),
              ),
            ),
          ],
        ),
      );
}

/// The reason behind the ask, stated once. People send documents faster
/// when they understand nobody is collecting them for the sake of it.
class _WhyWeAsk extends StatelessWidget {
  const _WhyWeAsk();

  @override
  Widget build(BuildContext context) => Panel(
        colour: Sky.c50,
        shadow: const [],
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.shield_rounded, size: 18, color: Sky.c700),
              const SizedBox(width: Gap.sm),
              Text('Why we ask',
                  style: Txt.cardTitle.copyWith(color: Sky.c800)),
            ]),
            const SizedBox(height: Gap.sm),
            Text(
              'You are going into people\'s homes, sometimes to their '
              'children or elderly parents. Every document here is one the '
              'law or our insurer requires for that job. The moment one '
              'expires, that job pauses automatically until it is renewed — '
              'which is what lets customers book you without meeting you '
              'first.',
              style: Txt.body.copyWith(fontSize: 13, color: Coal.c700),
            ),
          ],
        ),
      );
}
