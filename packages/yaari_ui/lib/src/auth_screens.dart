import 'dart:async';

import 'package:flutter/material.dart';

import 'ds/category.dart';
import 'ds/story.dart';
import 'ds/tokens.dart';
import 'marks.dart';
import 'package:flutter/services.dart';

import 'auth.dart';
import 'theme.dart';

/// Phone entry. Identical in both apps apart from the accent and the copy,
/// so it lives here rather than being written twice.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.auth,
    required this.brand,
    required this.role,
    required this.title,
    required this.blurb,
    required this.onSignedIn,
    this.footer,
  });

  final YaariAuth auth;
  final YaariBrand brand;

  /// 'customer' or 'provider'. The server rejects a number registered
  /// against the other role, so people cannot end up in the wrong app.
  final String role;
  final String title;
  final String blurb;
  final Widget? footer;
  final void Function(AuthedUser user) onSignedIn;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _valid => looksLikeUkMobile(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final req = await widget.auth.requestCode(
        phone: _controller.text,
        role: widget.role,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            auth: widget.auth,
            brand: widget.brand,
            phone: req.phone ?? _controller.text,
            devCode: req.devCode,
            onSignedIn: widget.onSignedIn,
          ),
        ),
      );
    } on YaariAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = YaariTheme.accentOf(widget.brand);

    return Scaffold(
      body: Column(
        children: [
          _AuthHero(brand: widget.brand, title: widget.title, blurb: widget.blurb),
          Expanded(
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -18, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MOBILE NUMBER',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _valid && !_busy ? _send() : null,
                    onChanged: (_) => setState(() => _error = null),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    decoration: InputDecoration(
                      hintText: '07700 900318',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                        child: Text('🇬🇧 +44',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _ErrorLine(_error!),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _valid && !_busy ? _send : null,
                    child: _busy
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white))
                        : const Text('Send code'),
                  ),
                  const Spacer(),
                  if (widget.footer != null) widget.footer!,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six digit code entry.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.auth,
    required this.brand,
    required this.phone,
    required this.onSignedIn,
    this.devCode,
  });

  final YaariAuth auth;
  final YaariBrand brand;
  final String phone;
  final String? devCode;
  final void Function(AuthedUser user) onSignedIn;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  int _secondsLeft = 300;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.verifyCode(phone: widget.phone, code: code);
      if (!mounted) return;
      widget.onSignedIn(user);
    } on YaariAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
      _controller.clear();
      _focus.requestFocus();
    }
  }

  String get _clock {
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = YaariTheme.accentOf(widget.brand);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          _AuthHero(
            brand: widget.brand,
            title: 'Enter your code',
            blurb: 'Sent to ${widget.phone}',
            showBack: true,
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -18, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIX DIGIT CODE', style: text.labelSmall),
                  const SizedBox(height: 10),
                  _CodeBoxes(
                    controller: _controller,
                    focus: _focus,
                    accent: accent,
                    enabled: !_busy,
                    onComplete: _verify,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorLine(_error!),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 15, color: YaariColors.inkDim),
                      const SizedBox(width: 6),
                      Text(
                        _secondsLeft > 0
                            ? 'Code expires in $_clock'
                            : 'Code expired — go back and request another',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                  if (widget.devCode != null) ...[
                    const SizedBox(height: 18),
                    _DevCodeCard(code: widget.devCode!),
                  ],
                  const Spacer(),
                  if (_busy)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six separate boxes backed by one hidden field, so paste and
/// autofill keep working.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focus,
    required this.accent,
    required this.enabled,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final Color accent;
  final bool enabled;
  final ValueChanged<String> onComplete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: 0,
          child: TextField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (v) {
              if (v.length == 6) onComplete(v);
            },
          ),
        ),
        GestureDetector(
          onTap: () => focus.requestFocus(),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Row(
                children: List.generate(6, (i) {
                  final filled = i < value.text.length;
                  final active = i == value.text.length;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == 5 ? 0 : 8),
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: filled ? accent.withValues(alpha: 0.07) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: filled || active ? accent : YaariColors.line,
                          width: filled || active ? 1.8 : 1.5,
                        ),
                      ),
                      child: Text(
                        filled ? value.text[i] : '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Only shown while codes are delivered on screen instead of by SMS.
class _DevCodeCard extends StatelessWidget {
  const _DevCodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: YaariColors.slateTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: YaariColors.slate.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction, size: 18, color: YaariColors.slate),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Test mode',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: YaariColors.slate)),
                Text('Your code is $code. Real texts start once an SMS gateway is paid for.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.brand,
    required this.title,
    required this.blurb,
    this.showBack = false,
  });

  final YaariBrand brand;
  final String title;
  final String blurb;
  final bool showBack;

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.of(context).padding.top + 22, 24, 44),
      decoration: const BoxDecoration(gradient: Warm.hero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: Colors.white),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: AppIcon(
                glyph: GlyphFill.house,
                family: Category(
                    top: Color(0xFFFFFFFF),
                    base: Color(0xFFFFE3DA),
                    deep: Color(0xFF8A1720),
                    tint: Color(0xFFFFFFFF),
                    glyph: GlyphFill.house),
                size: 52,
              ),
            ),
          Headline.of(title, colour: Colors.white, size: 30),
          const SizedBox(height: 8),
          Text(blurb,
              style: TextStyle(
                  fontFamily: Face.text,
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  height: 1.45)),
        ],
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: YaariColors.emberTint,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: YaariColors.ember.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: YaariColors.emberDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.4, color: YaariColors.emberDeep)),
          ),
        ],
      ),
    );
  }
}
