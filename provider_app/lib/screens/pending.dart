import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../apply.dart';
import 'upload_doc.dart';

/// Waiting to be approved.
///
/// The screen somebody stares at after the expo. It exists to do two things:
/// make the wait feel like progress rather than silence, and get the
/// documents in without anybody having to telephone them.
///
/// Every credential listed is one their own trades genuinely require — a
/// London massage therapist sees the borough licence, a Birmingham one does
/// not, because the requirement is attached to the council rather than the
/// job title.
class PendingScreen extends StatefulWidget {
  const PendingScreen({
    super.key,
    required this.application,
    required this.auth,
    required this.onRefresh,
  });

  final Application application;
  final YaariAuth auth;
  final Future<void> Function() onRefresh;

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  @override
  Widget build(BuildContext context) {
    final a = widget.application;

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: ListView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding:
              const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.huge),
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.xl),
                child: Reveal(child: _StatusCard(application: a)),
              ),
            ),
            const SizedBox(height: Gap.xl),

            if (a.isRejected)
              const StateView(
                icon: Icons.info_outline_rounded,
                title: 'We could not take this one forward',
                body: 'Get in touch if you think that is wrong, or if your '
                    'circumstances have changed.',
                tone: ChipTone.warning,
              )
            else ...[
              Reveal(
                delay: const Duration(milliseconds: 60),
                child: SectionHead(
                  'What we still need',
                  trailing: Pill('${a.outstanding.length}',
                      tone: a.outstanding.isEmpty
                          ? ChipTone.success
                          : ChipTone.warning,
                      dense: true),
                ),
              ),

              if (a.outstanding.isEmpty)
                Reveal(
                  delay: const Duration(milliseconds: 80),
                  child: Panel(
                    colour: Signal.successSoft,
                    shadow: const [],
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 19, color: Signal.success),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          'Everything is in. We are doing the final checks '
                          'against the issuing registers.',
                          style: Txt.body.copyWith(
                              fontSize: 13, color: const Color(0xFF14613C)),
                        ),
                      ),
                    ]),
                  ),
                )
              else
                for (var i = 0; i < a.outstanding.length; i++) ...[
                  Reveal(
                    delay: Duration(milliseconds: 80 + 40 * i),
                    child: _DocRow(
                      doc: a.outstanding[i],
                      held: false,
                      onTap: () async {
                        final sent = await showUploadSheet(
                            context, a.outstanding[i]);
                        if (sent && context.mounted) {
                          await widget.onRefresh();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Sent for checking. We verify against '
                                    'the issuing register, usually same day.'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                ],

              if (a.verified.isNotEmpty) ...[
                const SizedBox(height: Gap.xl),
                SectionHead('Already verified',
                    trailing: Pill('${a.verified.length}',
                        tone: ChipTone.success, dense: true)),
                for (final d in a.verified) ...[
                  _DocRow(doc: d, held: true),
                  const SizedBox(height: Gap.md),
                ],
              ],

              const SizedBox(height: Gap.xl),
              Reveal(
                delay: const Duration(milliseconds: 220),
                child: _HowToSend(),
              ),
            ],

            const SizedBox(height: Gap.xxl),
            Btn('Sign out',
                kind: BtnKind.ghost, onTap: () => widget.auth.signOut()),
          ],
        ),
      ),
    );
  }
}

/// Where the application stands, and what happens next.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.application});

  final Application application;

  @override
  Widget build(BuildContext context) {
    final a = application;
    final done = a.verified.length;

    return Panel(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: a.isRejected
            ? [Coal.c600, Coal.c700]
            : [Brand.c500, Brand.c700],
      ),
      padding: const EdgeInsets.all(Gap.xxl),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                    a.isRejected
                        ? Icons.info_rounded
                        : Icons.hourglass_top_rounded,
                    size: 18,
                    color: Colors.white),
              ),
              const SizedBox(width: Gap.md),
              Text(
                  a.isRejected
                      ? 'Application closed'
                      : a.status == 'in_review'
                          ? 'Being checked'
                          : 'Application received',
                  style: Txt.label.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text(
            a.isRejected
                ? 'Thanks for your interest'
                : a.outstanding.isEmpty
                    ? 'Nothing left for you to do'
                    : 'We need ${a.outstanding.length} more '
                        '${a.outstanding.length == 1 ? "document" : "documents"}',
            style: Txt.display.copyWith(color: Colors.white, fontSize: 25),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            a.isRejected
                ? 'We are not able to take this one forward right now.'
                : 'Once everything is verified you will start receiving work '
                    'in ${a.workArea ?? "your area"}.',
            style: Txt.body.copyWith(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5),
          ),

          if (!a.isRejected) ...[
            const SizedBox(height: Gap.xl),
            // A bar rather than a number, because "3 of 7" is a fact and a
            // bar is a feeling, and the feeling is what keeps people going.
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: a.progress,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text('$done of ${a.total} verified',
                style: Txt.meta.copyWith(
                    color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: Gap.lg),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in a.trades)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(t.name,
                        style: Txt.meta.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.held, this.onTap});

  final RequiredDoc doc;
  final bool held;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: held
                  ? Signal.success.withValues(alpha: 0.12)
                  : Coal.c50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                held
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                size: 16,
                color: held ? Signal.success : Coal.c500),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.label, style: Txt.cardTitle.copyWith(fontSize: 14)),
                if (doc.note != null) ...[
                  const SizedBox(height: 3),
                  Text(doc.note!, style: Txt.meta),
                ],
                const SizedBox(height: 6),
                Pill(
                  held ? 'Verified' : 'For ${doc.tradeName.toLowerCase()}',
                  tone: held ? ChipTone.success : ChipTone.neutral,
                  dense: true,
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: Gap.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md, vertical: 8),
              decoration: BoxDecoration(
                color: Brand.c500,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text('Send',
                  style: Txt.meta.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}

/// What happens once a document is sent.
///
/// Replaced a card that told people to email us. Telling somebody to leave
/// the app to finish joining is how you lose them.
class _HowToSend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.upload_rounded, 'You send it',
          'A photo, or the PDF your insurer emailed you.'),
      (Icons.fact_check_rounded, 'We check the register',
          'Not just the certificate — Gas Safe, NICEIC and council '
          'registers are the real source.'),
      (Icons.notifications_active_rounded, 'We remind you before it lapses',
          'An expired document stops your work that day, so we chase you '
          'well before it does.'),
    ];

    return Panel(
      padding: const EdgeInsets.all(Gap.xl),
      shadow: Shade.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW CHECKING WORKS', style: Txt.label),
          const SizedBox(height: Gap.lg),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Brand.c50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(steps[i].$1, size: 15, color: Brand.c600),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$2,
                          style: Txt.cardTitle.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(steps[i].$3, style: Txt.meta),
                    ],
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1) const SizedBox(height: Gap.lg),
          ],
        ],
      ),
    );
  }
}
