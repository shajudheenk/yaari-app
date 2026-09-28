import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../account_api.dart';
import '../data.dart';
import '../place.dart';
import 'legal.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.auth, required this.place});

  final YaariAuth auth;
  final Place place;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _closing = false;

  /// Two deliberate steps. Closing an account destroys addresses and ends any
  /// standing plans, and none of that can be undone, so a single mistaken tap
  /// must not be enough.
  Future<void> _close() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Close your account?'),
        content: const Text(
          'Your name, phone number and saved addresses are deleted, any '
          'repeat plans stop, and you will be signed out.\n\n'
          'Past bookings are kept without your details on them, because the '
          'tradesperson needs the record of work they did.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Keep my account')),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(backgroundColor: Brand.c500),
            child: const Text('Close account'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _closing = true);
    try {
      final kept = await AccountApi.deleteMyAccount();
      if (!mounted) return;
      Buzz.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kept == 0
              ? 'Your account has been closed.'
              : 'Your account has been closed. $kept past '
                  '${kept == 1 ? 'booking was' : 'bookings were'} kept '
                  'without your details.'),
        ),
      );
      await widget.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      Buzz.reject();
      setState(() => _closing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AccountApi.explain(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?) ?? 'Your account';
    final phone =
        (user?.userMetadata?['phone'] as String?) ?? user?.email ?? 'Signed in';

    return Scaffold(
      backgroundColor: Surface.canvas,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // A brand-coloured cap carrying the identity, with the rest of the
          // screen on paper beneath it.
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Brand.c500, Brand.c700],
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(Radii.panel)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.page, Gap.xl, Gap.page, Gap.xxl),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Avatar(name, size: 58),
                      ),
                      const SizedBox(width: Gap.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Txt.display.copyWith(
                                    color: Colors.white, fontSize: 23)),
                            const SizedBox(height: 3),
                            Text(phone,
                                style: Txt.meta.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding:
                const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, 120),
            sliver: SliverList.list(children: [
              const SectionHead('How Yaari protects you'),
              Panel(
                padding: EdgeInsets.zero,
                shadow: Shade.sm,
                child: Column(children: const [
                  _Promise(
                    icon: Icons.verified_user_rounded,
                    colour: Signal.success,
                    title: 'Checked, and checked again',
                    body: 'Insurance and trade registrations are re-checked '
                        'every time you search.',
                  ),
                  Divider(height: 1, indent: 58),
                  _Promise(
                    icon: Icons.pin_rounded,
                    colour: Signal.info,
                    title: 'Your code closes the job',
                    body: 'Nobody can mark work finished without the four '
                        'digits only you can see.',
                  ),
                  Divider(height: 1, indent: 58),
                  _Promise(
                    icon: Icons.photo_camera_rounded,
                    colour: Signal.warning,
                    title: 'Photographed, before and after',
                    body: 'Saved to your booking, so a disagreement is a '
                        'record rather than an opinion.',
                  ),
                ]),
              ),

              const SizedBox(height: Gap.xxl),
              const SectionHead('Legal'),
              Panel(
                padding: EdgeInsets.zero,
                shadow: Shade.sm,
                child: Column(children: [
                  _LinkRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy policy',
                    onTap: () => Navigator.of(context).go((_) =>
                        const LegalScreen(document: LegalDocument.privacy)),
                  ),
                  const Divider(height: 1, indent: 58),
                  _LinkRow(
                    icon: Icons.description_outlined,
                    label: 'Terms of service',
                    onTap: () => Navigator.of(context).go(
                        (_) => const LegalScreen(document: LegalDocument.terms)),
                  ),
                ]),
              ),

              const SizedBox(height: Gap.xxl),
              Btn('Sign out',
                  kind: BtnKind.secondary,
                  icon: Icons.logout_rounded,
                  onTap: _closing ? null : () => widget.auth.signOut()),
              const SizedBox(height: Gap.md),
              Btn('Close my account',
                  kind: BtnKind.ghost,
                  colour: Signal.danger,
                  busy: _closing,
                  onTap: _closing ? null : _close),

              const SizedBox(height: Gap.xl),
              Center(
                child: AnimatedBuilder(
                  animation: widget.place,
                  builder: (context, _) => Text(
                    'Yaari · ${widget.place.city}',
                    style: Txt.meta.copyWith(color: Coal.c500),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({
    required this.icon,
    required this.colour,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: colour),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Txt.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(body, style: Txt.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Coal.c50,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: Coal.c600),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
                child: Text(label,
                    style: Txt.cardTitle.copyWith(fontSize: 14))),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Coal.c400),
          ],
        ),
      ),
    );
  }
}
