import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';
import 'documents.dart';

/// You.
///
/// Standing, credentials and the account controls. Deliberately quiet — a
/// professional should spend their time on Work, not here.
class ProAccountScreen extends StatelessWidget {
  const ProAccountScreen({
    super.key,
    required this.auth,
    required this.standing,
  });

  final YaariAuth auth;
  final ProviderStanding? standing;

  @override
  Widget build(BuildContext context) {
    final s = standing;

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 120),
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xl),
              child: Row(
                children: [
                  Avatar(s?.name ?? 'Y', size: 56),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s?.name ?? 'Your account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Txt.title.copyWith(fontSize: 20)),
                        if (s?.trade != null) ...[
                          const SizedBox(height: 3),
                          Pill(s!.trade!, tone: ChipTone.brand, dense: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (s != null) ...[
            Reveal(
              child: Row(children: [
                Expanded(
                  child: _Stat(
                    label: 'Jobs done',
                    value: '${s.jobsCompleted}',
                    icon: Icons.check_circle_rounded,
                    colour: Signal.success,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: _Stat(
                    label: 'Rating',
                    value: s.ratingAvg == null
                        ? '—'
                        : s.ratingAvg!.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                    colour: const Color(0xFFC9871A),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Gap.lg),

            Reveal(
              delay: const Duration(milliseconds: 60),
              child: _StandingCard(standing: s),
            ),
            const SizedBox(height: Gap.xxl),
          ],

          const SectionHead('Your account'),
          Panel(
            padding: EdgeInsets.zero,
            shadow: Shade.sm,
            child: Column(children: [
              _Row(
                icon: Icons.verified_user_rounded,
                label: 'Documents and credentials',
                detail: s == null
                    ? null
                    : s.isCompliant
                        ? 'All valid'
                        : '${s.missingDocs.length} need attention',
                tone: s == null
                    ? ChipTone.neutral
                    : s.isCompliant
                        ? ChipTone.success
                        : ChipTone.danger,
                onTap: s == null
                    ? null
                    : () => Navigator.of(context)
                        .go((_) => DocumentsScreen(providerId: s.userId)),
              ),
              const Divider(height: 1, indent: 56),
              const _Row(
                icon: Icons.help_outline_rounded,
                label: 'Get help',
                detail: 'We answer during working hours',
              ),
            ]),
          ),

          const SizedBox(height: Gap.xxl),
          Btn('Sign out',
              kind: BtnKind.secondary, onTap: () => auth.signOut()),
          const SizedBox(height: Gap.xl),
          Center(child: Text('Yaari360 Pro', style: Txt.meta)),
        ],
      ),
    );
  }
}

/// Whether this professional is currently able to receive work, and why.
class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.standing});

  final ProviderStanding standing;

  @override
  Widget build(BuildContext context) {
    final ok = standing.isCompliant;
    final days = standing.daysToNextExpiry;

    return Panel(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ok
            ? [Signal.success, const Color(0xFF115C39)]
            : [Brand.c500, Brand.c700],
      ),
      padding: const EdgeInsets.all(Gap.xl),
      radius: Radii.panel,
      shadow: Shade.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.verified_rounded : Icons.gpp_maybe_rounded,
                  size: 19, color: Colors.white),
              const SizedBox(width: Gap.sm),
              Text(ok ? 'Cleared to work' : 'Not receiving work',
                  style: Txt.cardTitle.copyWith(
                      color: Colors.white, fontSize: 15.5)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            ok
                ? days == null
                    ? 'Every credential is valid and in date.'
                    : days <= 30
                        ? 'All valid — but your next document expires in '
                            '$days days. Renew it before it lapses.'
                        : 'Every credential is valid. Next renewal in '
                            '$days days.'
                : 'Customers cannot see you until your documents are up to '
                    'date.',
            style: Txt.body.copyWith(
                color: Colors.white.withValues(alpha: 0.88), fontSize: 13),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.detail,
    this.tone = ChipTone.neutral,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final ChipTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg, vertical: Gap.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Coal.c50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: Coal.c600),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
              child: Text(label, style: Txt.cardTitle.copyWith(fontSize: 14))),
          if (detail != null) Pill(detail!, tone: tone, dense: true),
          if (onTap != null) ...[
            const SizedBox(width: Gap.sm),
            const Icon(Icons.chevron_right_rounded, size: 19, color: Coal.c400),
          ],
        ],
      ),
    );
    return onTap == null ? body : Pressable(onTap: onTap, child: body);
  }
}
