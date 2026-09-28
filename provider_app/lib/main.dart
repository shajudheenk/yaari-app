import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_ui/yaari_ui.dart';

import 'apply.dart';
import 'data.dart';
import 'screens/apply.dart';
import 'screens/pending.dart';
import 'screens/pro_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabaseKey,
  );
  runApp(const YaariProviderApp());
}

class YaariProviderApp extends StatelessWidget {
  const YaariProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaari Pro',
      debugShowCheckedModeBanner: false,
      theme: buildYaariTheme(),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  late final YaariAuth _auth = YaariAuth(supabase);
  bool _splashDone = false;

  /// Null while we have not looked yet; loaded once signed in.
  Application? _application;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _splashDone = true);
    });
    _auth.changes.listen((_) {
      if (mounted) {
        setState(() => _checked = false);
        _check();
      }
    });
    _check();
  }

  /// Decides which of the three worlds this person is in: hasn't applied,
  /// applied and waiting, or working. Everything hangs off this one call.
  Future<void> _check() async {
    if (!_auth.isSignedIn) {
      if (mounted) setState(() => _checked = true);
      return;
    }
    try {
      final app = await ApplyApi.mine();
      if (mounted) {
        setState(() {
          _application = app;
          _checked = true;
        });
      }
    } catch (_) {
      // Offline. Treat as unknown rather than sending somebody who is
      // already approved back through the application flow.
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return const YaariSplash(
        brand: YaariBrand.customer,
        wordmark: 'Yaari Pro',
        strapline: 'Work near you',
      );
    }

    return StreamBuilder<AuthState>(
      stream: _auth.changes,
      builder: (context, _) {
        if (!_auth.isSignedIn) {
          return PhoneLoginScreen(
            auth: _auth,
            brand: YaariBrand.customer,
            role: 'provider',
            title: 'Yaari Pro',
            blurb: 'Enter your number. New here? This is where you join too.',
            onSignedIn: (_) {
              _check();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            footer: const _SupplyPitch(),
          );
        }

        if (!_checked) {
          return const Scaffold(
            backgroundColor: Surface.canvas,
            body: Center(child: CircularProgressIndicator(color: Brand.c500)),
          );
        }

        final app = _application;

        // Signed in but never applied — the expo case.
        if (app == null) {
          return ApplyScreen(onDone: _check);
        }
        // Turned down: the only state that is not the app proper.
        if (app.isRejected) {
          return PendingScreen(
            application: app,
            auth: _auth,
            onRefresh: _check,
          );
        }
        // Applied or approved, they are in — the way Uber and Swiggy do it.
        // The home screen shows how verification is going and what is still
        // owed; the database decides when they can actually take work, so
        // letting them in early costs nothing in safety.
        return ProShell(auth: _auth);
      },
    );
  }
}

/// The pitch on the sign-in screen. This is the first thing a stranger at an
/// expo reads, so it leads with the thing that actually differs from the
/// lead-generation sites they are already paying.
class _SupplyPitch extends StatelessWidget {
  const _SupplyPitch();

  @override
  Widget build(BuildContext context) {
    return Panel(
      colour: Signal.successSoft,
      shadow: const [],
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.savings_rounded, size: 18, color: Signal.success),
            const SizedBox(width: Gap.sm),
            Text('No lead fees. Ever.',
                style: Txt.cardTitle.copyWith(
                    fontSize: 14.5, color: const Color(0xFF14613C))),
          ]),
          const SizedBox(height: Gap.sm),
          Text(
            'You are charged on work you actually complete — never for a '
            'lead that went nowhere. Nothing at all for your first six '
            'months.',
            style: Txt.body.copyWith(
                fontSize: 13, color: const Color(0xFF14613C)),
          ),
        ],
      ),
    );
  }
}
