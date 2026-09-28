import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../apply.dart';
import '../geo.dart';
import 'onboarding_docs.dart';

/// Joining, in five questions, then the documents.
///
/// Built for a noisy expo hall: one question per screen, large targets, and
/// nothing that needs a document in your hand. Somebody can finish this
/// standing up, in about ninety seconds, and leave with the app installed.
class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _page = PageController();
  int _step = 0;

  final _name = TextEditingController();
  final _area = TextEditingController();
  final _referral = TextEditingController();

  List<TradeOption> _trades = [];
  final _picked = <String>[];
  SignupSource? _source;
  LegalStatus? _legal;
  final _utr = TextEditingController();
  final _company = TextEditingController();
  double? _lat, _lng;
  bool _busy = false;
  String? _error;

  static const _steps = 5;

  static final _utrShape = RegExp(r'^[0-9]{10}$');
  static final _companyShape = RegExp(r'^([0-9]{8}|[A-Z]{2}[0-9]{6})$');

  String get _utrClean => _utr.text.replaceAll(RegExp(r'\s'), '');
  String get _companyClean =>
      _company.text.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Mirrors apply_as_provider's own checks, so a typo is caught on this
  /// screen rather than as an error after the last one.
  bool get _legalValid => switch (_legal) {
        null => false,
        LegalStatus.soleTrader =>
          _utrClean.isEmpty || _utrShape.hasMatch(_utrClean),
        LegalStatus.limitedCompany => _companyShape.hasMatch(_companyClean),
      };

  @override
  void initState() {
    super.initState();
    TradeOption.all().then((t) {
      if (mounted) setState(() => _trades = t);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _area.dispose();
    _referral.dispose();
    _utr.dispose();
    _company.dispose();
    super.dispose();
  }

  bool get _canAdvance => switch (_step) {
        0 => _name.text.trim().length >= 2,
        1 => _picked.isNotEmpty,
        2 => _area.text.trim().length >= 3,
        3 => _legalValid,
        4 => _source != null,
        _ => false,
      };

  void _next() {
    if (!_canAdvance) return;
    Buzz.pick();
    if (_step == _steps - 1) {
      _submit();
      return;
    }
    setState(() => _step++);
    _page.animateToPage(_step,
        duration: Motion.base, curve: Motion.enter);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    Buzz.tap();
    setState(() => _step--);
    _page.animateToPage(_step, duration: Motion.base, curve: Motion.enter);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Best effort. A postcode we cannot place should never block somebody
      // joining — operations can fix a location, they cannot fix a person
      // who gave up at the last screen.
      final area = _area.text.trim();
      if (_lat == null) {
        final place = await Geo.locate(area);
        _lat = place?.lat;
        _lng = place?.lng;
      }

      await ApplyApi.apply(
        fullName: _name.text.trim(),
        tradeSlugs: _picked,
        workArea: area,
        lat: _lat,
        lng: _lng,
        source: _source,
        referredBy: _referral.text.trim().isEmpty
            ? null
            : _referral.text.trim(),
        legalStatus: _legal!,
        utr: _legal == LegalStatus.soleTrader && _utrClean.isNotEmpty
            ? _utrClean
            : null,
        companyNumber:
            _legal == LegalStatus.limitedCompany ? _companyClean : null,
      );
      if (!mounted) return;
      Buzz.commit();
      setState(() => _busy = false);

      // The application is in; now the part that actually decides whether
      // they can work. Straight on, while they still have their wallet out.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnboardingDocsScreen(
          firstRun: true,
          onFinish: widget.onDone,
        ),
      ));
    } catch (e) {
      if (mounted) {
        Buzz.reject();
        setState(() {
          _error = ApplyApi.explain(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Surface.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, Gap.md, Gap.page, Gap.lg),
              child: Row(
                children: [
                  Pressable(
                    onTap: _back,
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
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Steps(
                      step: _step + 1,
                      of: _steps,
                      label: switch (_step) {
                        0 => 'Your name',
                        1 => 'What you do',
                        2 => 'Where you work',
                        3 => 'How you work',
                        4 => 'How you found us',
                        _ => '',
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NameStep(controller: _name, onChanged: () => setState(() {})),
                  _TradeStep(
                    trades: _trades,
                    picked: _picked,
                    onToggle: (slug) {
                      Buzz.tap();
                      setState(() {
                        _picked.contains(slug)
                            ? _picked.remove(slug)
                            : _picked.add(slug);
                      });
                    },
                  ),
                  _AreaStep(controller: _area, onChanged: () => setState(() {})),
                  _LegalStep(
                    value: _legal,
                    utr: _utr,
                    company: _company,
                    utrOk: _utrClean.isEmpty || _utrShape.hasMatch(_utrClean),
                    companyOk: _companyClean.isEmpty ||
                        _companyShape.hasMatch(_companyClean),
                    onPick: (v) {
                      Buzz.tap();
                      setState(() => _legal = v);
                    },
                    onChanged: () => setState(() {}),
                  ),
                  _SourceStep(
                    value: _source,
                    referral: _referral,
                    onPick: (s) {
                      Buzz.tap();
                      setState(() => _source = s);
                    },
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.page, 0, Gap.page, Gap.md),
                child: Panel(
                  colour: Signal.dangerSoft,
                  shadow: const [],
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 17, color: Signal.danger),
                    const SizedBox(width: Gap.md),
                    Expanded(
                        child: Text(_error!,
                            style: Txt.body.copyWith(
                                fontSize: 13,
                                color: Brand.c700))),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Gap.page, 0, Gap.page, Gap.lg),
              child: Btn(
                _step == _steps - 1 ? 'Next: your documents' : 'Continue',
                busy: _busy,
                onTap: _canAdvance && !_busy ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.blurb,
    required this.child,
  });

  final String title;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      children: [
        Text(title, style: Txt.hero.copyWith(fontSize: 30)),
        const SizedBox(height: Gap.sm),
        Text(blurb, style: Txt.body),
        const SizedBox(height: Gap.xxl),
        child,
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'What should we call you?',
      blurb: 'The name customers will see when you turn up at their door.',
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => onChanged(),
        style: Txt.title.copyWith(fontSize: 20),
        decoration: const InputDecoration(hintText: 'Sam Novak'),
      ),
    );
  }
}

class _TradeStep extends StatelessWidget {
  const _TradeStep({
    required this.trades,
    required this.picked,
    required this.onToggle,
  });

  final List<TradeOption> trades;
  final List<String> picked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(Gap.page),
        children: List.generate(
            6,
            (_) => const Padding(
                  padding: EdgeInsets.only(bottom: Gap.md),
                  child: Skeleton(height: 62, radius: Radii.card),
                )),
      );
    }

    return _StepBody(
      title: 'What do you do?',
      blurb: 'Pick everything you would take work for. Each one is checked '
          'separately, so a lapsed certificate on one never stops the others.',
      child: Column(
        children: [
          for (final t in trades) ...[
            _TradePick(
              trade: t,
              selected: picked.contains(t.slug),
              position: picked.indexOf(t.slug),
              onTap: () => onToggle(t.slug),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ],
      ),
    );
  }
}

class _TradePick extends StatelessWidget {
  const _TradePick({
    required this.trade,
    required this.selected,
    required this.position,
    required this.onTap,
  });

  final TradeOption trade;
  final bool selected;

  /// Zero means this is the headline trade — the one shown under their name.
  final int position;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(trade.slug);

    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      shadow: selected ? Shade.tinted(c.base) : Shade.sm,
      border: Border.all(
          color: selected ? c.base : Colors.transparent, width: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: c.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                YaariMark(trade.slug, size: 24, ink: c.deep, accent: c.base),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(trade.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.cardTitle.copyWith(fontSize: 14.5)),
                    ),
                    if (position == 0) ...[
                      const SizedBox(width: Gap.sm),
                      Pill('Main', colour: c.deep, dense: true),
                    ],
                  ],
                ),
                if (trade.blurb != null) ...[
                  const SizedBox(height: 2),
                  Text(trade.blurb!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Txt.meta),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.settle,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? c.base : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? c.base : Coal.c200, width: 2),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}

class _AreaStep extends StatelessWidget {
  const _AreaStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'Where do you work?',
      blurb: 'Your postcode, or the area you cover. We only send you jobs '
          'within a sensible distance of it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => onChanged(),
            style: Txt.title.copyWith(fontSize: 20),
            decoration: const InputDecoration(hintText: 'B29, or Selly Oak'),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: Coal.c500),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                    'We are live in Birmingham and London. You can still '
                    'apply from elsewhere — we will tell you when we open '
                    'near you.',
                    style: Txt.meta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceStep extends StatelessWidget {
  const _SourceStep({
    required this.value,
    required this.referral,
    required this.onPick,
  });

  final SignupSource? value;
  final TextEditingController referral;
  final ValueChanged<SignupSource> onPick;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'How did you hear about us?',
      blurb: 'It tells us where to spend next, which is how we keep the work '
          'coming.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final s in SignupSource.values)
                Pressable(
                  onTap: () => onPick(s),
                  scale: 0.94,
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    curve: Motion.settle,
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg, vertical: 12),
                    decoration: BoxDecoration(
                      color: value == s ? Brand.c500 : Surface.raised,
                      borderRadius: BorderRadius.circular(Radii.chip),
                      border: Border.all(
                          color: value == s ? Brand.c500 : Coal.c100,
                          width: 1.5),
                      boxShadow:
                          value == s ? Shade.tinted(Brand.c500) : Shade.sm,
                    ),
                    child: Text(s.label,
                        style: Txt.cardTitle.copyWith(
                          fontSize: 13.5,
                          color: value == s ? Colors.white : Coal.c800,
                        )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          Text('REFERRAL CODE, IF SOMEONE GAVE YOU ONE', style: Txt.label),
          const SizedBox(height: Gap.sm),
          TextField(
            controller: referral,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Optional'),
          ),
        ],
      ),
    );
  }
}


/// How they work, in law.
///
/// Everyone on Yaari is self-employed and contracts with the customer
/// directly. Asking this up front — and recording the UTR or company number —
/// is what makes that status something we can evidence, rather than a line in
/// the terms. It is also the first thing an insurer and HMRC would ask.
class _LegalStep extends StatelessWidget {
  const _LegalStep({
    required this.value,
    required this.utr,
    required this.company,
    required this.utrOk,
    required this.companyOk,
    required this.onPick,
    required this.onChanged,
  });

  final LegalStatus? value;
  final TextEditingController utr;
  final TextEditingController company;
  final bool utrOk;
  final bool companyOk;
  final ValueChanged<LegalStatus> onPick;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepBody(
      title: 'How do you work?',
      blurb: 'You work for yourself and your customers pay you. We need to '
          'know on what basis — it is also what our insurer asks.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LegalOption(
            icon: Icons.person_rounded,
            title: 'Sole trader',
            body: 'Self-employed, registered with HMRC for Self Assessment.',
            selected: value == LegalStatus.soleTrader,
            onTap: () => onPick(LegalStatus.soleTrader),
          ),
          const SizedBox(height: Gap.md),
          _LegalOption(
            icon: Icons.business_rounded,
            title: 'Limited company',
            body: 'You trade through your own company, registered at '
                'Companies House.',
            selected: value == LegalStatus.limitedCompany,
            onTap: () => onPick(LegalStatus.limitedCompany),
          ),
          const SizedBox(height: Gap.xl),
          if (value == LegalStatus.soleTrader) ...[
            Text('Your UTR', style: Txt.label),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: utr,
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                hintText: '10 digits, e.g. 12345 67890',
                errorText: utrOk ? null : 'A UTR is 10 digits',
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Your Unique Taxpayer Reference is on letters from HMRC. Just '
              'registered and waiting for it? Leave this blank — you can add '
              'it later, but we need it before your first payout.',
              style: Txt.meta,
            ),
          ],
          if (value == LegalStatus.limitedCompany) ...[
            Text('Company number', style: Txt.label),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: company,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                hintText: 'e.g. 12345678 or SC123456',
                errorText: companyOk
                    ? null
                    : 'A company number is 8 characters',
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'We check it against the Companies House register.',
              style: Txt.meta,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegalOption extends StatelessWidget {
  const _LegalOption({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: selected ? Shade.tinted(Brand.c500) : Shade.sm,
      border: Border.all(
          color: selected ? Brand.c500 : Colors.transparent, width: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? Brand.c500 : Brand.c50,
              borderRadius: BorderRadius.circular(Radii.button),
            ),
            child: Icon(icon,
                size: 20, color: selected ? Colors.white : Brand.c600),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Txt.cardTitle),
                const SizedBox(height: 2),
                Text(body, style: Txt.meta),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                size: 22, color: Brand.c500),
        ],
      ),
    );
  }
}
