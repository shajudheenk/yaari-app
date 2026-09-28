import 'data.dart';

/// Closing an account, from inside the app.
///
/// Both stores require this before they will publish — Apple since June 2022,
/// Google likewise — and a UK data subject is entitled to erasure without
/// having to email anybody.
///
/// The database keeps completed bookings and destroys everything personal
/// attached to them. That is deliberate: a finished job is a financial record
/// the other party may still need, and they did not ask to be erased. What
/// survives is a transaction with no person on it.
class AccountApi {
  /// Returns how many past bookings were kept, so the app can say plainly
  /// what was and was not destroyed.
  static Future<int> deleteMyAccount({String? reason}) async {
    final rows = await supabase
        .rpc('delete_my_account', params: {'p_reason': reason});
    final r = (rows as List).first as Map<String, dynamic>;
    return (r['bookings_kept'] as num).toInt();
  }

  /// The database refuses while a job is still running, which is right —
  /// walking away mid-booking would leave a tradesperson with nobody to
  /// contact. This turns that into something a person can act on.
  static String explain(Object error) {
    final s = error.toString();
    final open = RegExp(r'finish or cancel your (\d+) open booking')
        .firstMatch(s)
        ?.group(1);
    if (open != null) {
      return open == '1'
          ? 'You have a booking still running. Finish or cancel it, then '
              'come back here.'
          : 'You have $open bookings still running. Finish or cancel them, '
              'then come back here.';
    }
    return 'Could not close the account just now. Please try again.';
  }
}
