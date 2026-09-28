import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_ui/yaari_ui.dart';

import 'config.dart';
import 'data.dart';
import 'place.dart';
import 'screens/intro.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabaseKey,
  );
  runApp(const YaariCustomerApp());
}

class YaariCustomerApp extends StatelessWidget {
  const YaariCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaari',
      debugShowCheckedModeBanner: false,
      theme: buildYaariTheme(),
      home: const _Gate(),
    );
  }
}

/// Splash, then either the home screen or sign-in, depending on whether a
/// session was restored from the last run.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  late final YaariAuth _auth = YaariAuth(supabase);
  bool _splashDone = false;
  Place? _place;

  /// Whether the three-screen story has been seen on this device. Null until
  /// read, so the story never flashes up for someone who has seen it.
  bool? _introSeen;

  static const _introKey = 'yaari.intro.seen';

  Future<void> _finishIntro() async {
    setState(() => _introSeen = true);
    try {
      await (await SharedPreferences.getInstance()).setBool(_introKey, true);
    } catch (_) {/* seeing it twice is harmless */}
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => p.getBool(_introKey) ?? false)
        .catchError((_) => false)
        .then((seen) {
      if (mounted) setState(() => _introSeen = seen);
    });
    // The chosen area loads while the splash is on screen, so the home
    // screen never appears with the wrong location and then correct itself.
    Place.load().then((p) {
      if (mounted) setState(() => _place = p);
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone || _place == null || _introSeen == null) {
      return const YaariSplash(
        brand: YaariBrand.customer,
        wordmark: 'Yaari',
        strapline: 'Every service, one app',
      );
    }

    return StreamBuilder<AuthState>(
      stream: _auth.changes,
      builder: (context, _) {
        if (_auth.isSignedIn) {
          return CustomerShell(auth: _auth, place: _place!);
        }

        // First launch: the story before the phone number.
        if (_introSeen == false) {
          return IntroScreen(onDone: _finishIntro);
        }

        return PhoneLoginScreen(
          auth: _auth,
          brand: YaariBrand.customer,
          role: 'customer',
          title: 'Book a trusted trade',
          blurb: 'Enter your mobile number and we will text you a code.',
          onSignedIn: (_) {
            // The stream rebuilds this gate, so just clear the auth stack.
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          footer: const _TrustFooter(),
        );
      },
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 15, color: YaariColors.slate),
              const SizedBox(width: 9),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(Icons.verified_user_outlined, 'Every tradesperson is ID checked and insured'),
        line(Icons.price_check, 'Fixed prices agreed before anyone turns up'),
        line(Icons.photo_camera_outlined, 'Photos of the work, before and after'),
      ],
    );
  }
}
