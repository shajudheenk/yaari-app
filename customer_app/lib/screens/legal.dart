import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

/// Privacy policy and terms, carried inside the app.
///
/// Both stores require a reachable privacy policy before they will publish,
/// and a link to a website that might be down is a rejection waiting to
/// happen. Holding the text in the binary means it is always available,
/// including offline — the public URL still exists for the store listing,
/// but the app does not depend on it.
///
/// This is a plain-English starting draft. It describes what the app
/// genuinely does today, which is the part that has to be true; a solicitor
/// should review it before launch, and the wording here is deliberately
/// specific enough to be worth reviewing rather than boilerplate.
enum LegalDocument { privacy, terms }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final doc = document == LegalDocument.privacy ? _privacy : _terms;

    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(doc.title, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(
            'Last updated ${doc.updated}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          for (final section in doc.sections) ...[
            const Divider(height: 1, color: Coal.c200),
            const SizedBox(height: 12),
            Text(section.heading,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 7),
            Text(
              section.body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _Doc {
  const _Doc({
    required this.title,
    required this.updated,
    required this.sections,
  });

  final String title;
  final String updated;
  final List<_Section> sections;
}

class _Section {
  const _Section(this.heading, this.body);
  final String heading;
  final String body;
}

const _privacy = _Doc(
  title: 'Privacy policy',
  updated: '20 September 2026',
  sections: [
    _Section(
      'WHAT WE COLLECT',
      'Your mobile number, your name, and the addresses you save so a '
          'tradesperson knows where to go. For each booking we keep what you '
          'asked for, when, what it cost, and any photographs taken of the '
          'work.\n\n'
          'We do not collect your location in the background. The app only '
          'uses location when you are choosing where a job should happen, and '
          'only while it is open.',
    ),
    _Section(
      'WHY WE HOLD IT',
      'To connect you with a tradesperson, to let both of you see the same '
          'record of the job, and to settle a disagreement about work that was '
          'done. We also keep enough to meet our tax and accounting duties.\n\n'
          'We do not sell your data, and we do not use it for advertising.',
    ),
    _Section(
      'WHO SEES IT',
      'A tradesperson sees your first name and the job before they accept. '
          'They see your full address only once they have accepted, so an '
          'offer that is declined never reveals where you live.\n\n'
          'We share your phone number with an SMS provider purely to deliver '
          'your sign-in code, and card details are handled by Stripe — they '
          'never reach our servers.',
    ),
    _Section(
      'HOW LONG WE KEEP IT',
      'Your account details for as long as you have an account. Booking and '
          'payment records for six years after the job, because HMRC requires '
          'it.\n\n'
          'When you close your account we delete your name, phone number and '
          'saved addresses immediately. Past bookings stay, with your details '
          'removed from them — the tradesperson still needs the record of work '
          'they did and was paid for.',
    ),
    _Section(
      'YOUR RIGHTS',
      'You can ask for a copy of what we hold, ask us to correct it, or ask '
          'us to delete it. You can close your account yourself from the '
          'Account tab, which deletes your personal details straight away.\n\n'
          'If you think we have handled your data badly you can complain to '
          'the Information Commissioner at ico.org.uk.',
    ),
    _Section(
      'CONTACT',
      'Write to us and we will answer within one month, which is the limit UK '
          'law sets us.',
    ),
  ],
);

const _terms = _Doc(
  title: 'Terms of service',
  updated: '20 September 2026',
  sections: [
    _Section(
      'WHAT YAARI IS',
      'Yaari introduces you to self-employed tradespeople and books their '
          'time. The contract for the work itself is between you and them; we '
          'are not the one doing the job.\n\n'
          'What we take responsibility for is who is on the list. Every '
          'tradesperson has their identity, right to work, insurance and trade '
          'registration checked before they appear, and those checks are '
          're-tested every time you search.',
    ),
    _Section(
      'PRICES',
      'The price shown is agreed before anyone comes. Hourly work is quoted '
          'at the first hour; if a job runs longer, your tradesperson agrees '
          'the final figure with you before closing it.\n\n'
          'Nothing is taken until the work is done and you have given the '
          'four-digit completion code.',
    ),
    _Section(
      'CANCELLING',
      'You can cancel or move a booking free of charge at any time before '
          'work starts.\n\n'
          'A repeat plan has no contract and no notice period. Pause it or end '
          'it whenever you like; ending it also cancels the visit already in '
          'the diary.',
    ),
    _Section(
      'THE COMPLETION CODE',
      'Only you can see your four-digit code, and a job cannot be marked '
          'finished without it. Do not give it out before the work is done to '
          'your satisfaction — it is the one thing that protects you.',
    ),
    _Section(
      'IF SOMETHING GOES WRONG',
      'Tell us. Photographs of the work are saved to your booking, so a '
          'disagreement is a matter of record rather than opinion.\n\n'
          'Every tradesperson carries their own public liability insurance, '
          'which we verify and which must be current for them to receive work '
          'at all.',
    ),
    _Section(
      'USING THE APP',
      'Use it for genuine bookings. Do not book people in order to take them '
          'off the platform, and do not use the app to harass anybody. We can '
          'close an account that does either.',
    ),
  ],
);
