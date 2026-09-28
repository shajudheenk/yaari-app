import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../data.dart';

/// Credentials.
///
/// The one screen where the product's whole premise is visible to the person
/// it constrains. Nothing here is decorative: a document that lapses removes
/// this professional from search the same day, so the screen shows exactly
/// what is held, what is missing, and what expires next.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.providerId});

  final String providerId;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ProviderApi.myDocuments(widget.providerId);
      if (mounted) setState(() { _docs = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String label(String t) => switch (t) {
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
        _ => t,
      };

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Your documents'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: Brand.c500,
        backgroundColor: Surface.raised,
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(Gap.page),
                children: List.generate(
                    4,
                    (_) => const Padding(
                          padding: EdgeInsets.only(bottom: Gap.md),
                          child: Skeleton(height: 86, radius: Radii.card),
                        )),
              )
            : ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, Gap.sm, Gap.page, Gap.huge),
                children: [
                  Panel(
                    colour: Signal.infoSoft,
                    shadow: const [],
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_rounded,
                            size: 18, color: Signal.info),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            'These are re-checked every time a customer '
                            'searches. If one lapses you stop appearing that '
                            'day — so we will always warn you before it does.',
                            style: Txt.body.copyWith(
                                fontSize: 13, color: Sky.c800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                  if (_docs.isEmpty)
                    const StateView(
                      icon: Icons.folder_off_rounded,
                      title: 'Nothing uploaded yet',
                      body: 'Your documents are added by the Yaari team when '
                          'you join. Contact us if something is missing.',
                    )
                  else
                    for (var i = 0; i < _docs.length; i++) ...[
                      Reveal(
                        delay: Duration(milliseconds: 40 * i),
                        child: _DocRow(doc: _docs[i]),
                      ),
                      const SizedBox(height: Gap.md),
                    ],
                ],
              ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});

  final Map<String, dynamic> doc;

  @override
  Widget build(BuildContext context) {
    final status = (doc['status'] as String?) ?? 'pending';
    final expiresRaw = doc['expires_on'] as String?;
    final expires = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
    final days =
        expires?.difference(DateTime.now()).inDays;

    // Expiring counts as a problem well before it becomes one — thirty days
    // is roughly how long an insurance renewal takes to come through.
    final lapsed = days != null && days < 0;
    final soon = days != null && days >= 0 && days <= 30;

    final (tone, word) = lapsed
        ? (ChipTone.danger, 'Expired')
        : status != 'verified'
            ? (ChipTone.warning, 'Being checked')
            : soon
                ? (ChipTone.warning, 'Expires in $days days')
                : (ChipTone.success, 'Valid');

    final colour = switch (tone) {
      ChipTone.danger => Signal.danger,
      ChipTone.warning => Signal.warning,
      _ => Signal.success,
    };

    return Panel(
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.sm,
      border: lapsed
          ? Border.all(color: Signal.danger.withValues(alpha: 0.4), width: 1.5)
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
                lapsed
                    ? Icons.error_rounded
                    : status == 'verified'
                        ? Icons.verified_rounded
                        : Icons.hourglass_top_rounded,
                size: 17,
                color: colour),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_DocumentsScreenState.label(doc['doc_type'] as String),
                    style: Txt.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Pill(word, tone: tone, dense: true),
                if (expires != null) ...[
                  const SizedBox(height: 5),
                  Text('Expires ${_date(expires)}', style: Txt.meta),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
