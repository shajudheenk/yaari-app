
import 'booking.dart';
import 'data.dart';

/// Standing arrangements — the same job, same address, same slot, repeating.
///
/// This is the shape most home-services work actually takes. A cleaner is a
/// weekly habit, not a one-off purchase, and an app that can only sell single
/// visits is asking to be re-chosen fifty times a year.
///
/// As with bookings, nothing here writes to the table. `create_plan`,
/// `set_plan_state` and `ensure_plan_bookings` are database functions, so a
/// plan cannot put a visit in the diary that the compliance gate would have
/// refused.

enum PlanFrequency { weekly, fortnightly, everyFourWeeks }

extension PlanFrequencyX on PlanFrequency {
  String get wire => switch (this) {
        PlanFrequency.weekly => 'weekly',
        PlanFrequency.fortnightly => 'fortnightly',
        PlanFrequency.everyFourWeeks => 'every_4_weeks',
      };

  String get label => switch (this) {
        PlanFrequency.weekly => 'Every week',
        PlanFrequency.fortnightly => 'Every two weeks',
        PlanFrequency.everyFourWeeks => 'Every four weeks',
      };

  /// What the customer is committing to, said in full. "Every week" on its
  /// own does not tell you how many visits you are agreeing to pay for.
  String get blurb => switch (this) {
        PlanFrequency.weekly => 'The most popular choice for cleaning.',
        PlanFrequency.fortnightly => 'A lighter rhythm, same person.',
        PlanFrequency.everyFourWeeks => 'Monthly, for gardens and windows.',
      };

  static PlanFrequency fromWire(String s) => switch (s) {
        'weekly' => PlanFrequency.weekly,
        'fortnightly' => PlanFrequency.fortnightly,
        _ => PlanFrequency.everyFourWeeks,
      };
}

class RepeatPlan {
  RepeatPlan({
    required this.id,
    required this.serviceName,
    required this.tradeName,
    required this.tradeSlug,
    required this.addressLine,
    required this.providerName,
    required this.frequency,
    required this.weekday,
    required this.startTime,
    required this.ratePence,
    required this.rateUnit,
    required this.state,
    required this.nextDueAt,
  });

  final String id;
  final String serviceName;
  final String tradeName;
  final String tradeSlug;
  final String addressLine;

  /// Null once the tradesperson the plan was set up with has stopped
  /// appearing — the plan carries on, the continuity does not.
  final String? providerName;

  final PlanFrequency frequency;

  /// ISO weekday, 1 = Monday.
  final int weekday;
  final String startTime;
  final int ratePence;
  final String rateUnit;

  /// 'active', 'paused' or 'cancelled'.
  final String state;
  final DateTime nextDueAt;

  bool get isActive => state == 'active';
  bool get isPaused => state == 'paused';
  bool get isOver => state == 'cancelled';

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  String get dayName => _days[(weekday - 1).clamp(0, 6)];

  /// "Every week, Tuesday at 09:00" — the whole arrangement in one line, so
  /// a glance at the list is enough to know what is going to happen.
  String get rhythm => '${frequency.label}, $dayName at ${startTime.substring(0, 5)}';

  factory RepeatPlan.fromMap(Map<String, dynamic> m) {
    final service = m['services'] as Map<String, dynamic>?;
    final trade = service?['trades'] as Map<String, dynamic>?;
    final address = m['addresses'] as Map<String, dynamic>?;
    final provider = m['provider'] as Map<String, dynamic>?;

    return RepeatPlan(
      id: m['id'] as String,
      serviceName: (service?['name'] as String?) ?? 'Service',
      tradeName: (trade?['name'] as String?) ?? '',
      tradeSlug: (trade?['slug'] as String?) ?? '',
      addressLine: (address?['line1'] as String?) ?? '',
      providerName: provider?['full_name'] as String?,
      frequency: PlanFrequencyX.fromWire(m['frequency'] as String),
      weekday: (m['weekday'] as num).toInt(),
      startTime: m['start_time'] as String,
      ratePence: (m['rate_pence'] as num).toInt(),
      rateUnit: (service?['rate_unit'] as String?) ?? 'job',
      state: m['state'] as String,
      nextDueAt: DateTime.parse(m['next_due_at'] as String).toLocal(),
    );
  }
}

class PlanApi {
  /// What a repeat plan saves against the one-off rate, read from the
  /// database rather than written into the app, so the offer can change
  /// without a release. Returns basis points: 1500 is 15%.
  static Future<int> discountBps() async {
    final rows = await supabase
        .from('platform_settings')
        .select('plan_discount_bps')
        .eq('id', 1)
        .limit(1);
    if (rows.isEmpty) return 0;
    return ((rows.first['plan_discount_bps'] as num?) ?? 0).toInt();
  }

  /// The same arithmetic the database does when it creates the plan. Shown
  /// before the customer commits so the price on screen is the price
  /// charged, not an estimate that moves at the last step.
  static int planRate(int ratePence, int discountBps) {
    final discounted = (ratePence * (10000 - discountBps) / 10000).round();
    return discounted < 1 ? 1 : discounted;
  }

  /// Creates the plan and its first visit together, and hands back the visit
  /// in the same shape a one-off booking returns — so the customer lands on
  /// the same status screen, with the same completion code, either way.
  /// [optionId] and [quantity] are what make a weekly three-bedroom clean
  /// cost a three-bedroom price every week; the server prices from them.
  static Future<(String planId, NewBooking first)> create({
    required String serviceId,
    required String addressId,
    String? providerId,
    required PlanFrequency frequency,
    required DateTime firstAt,
    String? note,
    String? optionId,
    int quantity = 1,
  }) async {
    final rows = await supabase.rpc('create_plan', params: {
      'p_service_id': serviceId,
      'p_address_id': addressId,
      'p_provider_id': providerId,
      'p_frequency': frequency.wire,
      'p_first_at': firstAt.toUtc().toIso8601String(),
      'p_note': note,
      'p_option_id': optionId,
      'p_quantity': quantity,
    });
    final r = (rows as List).first as Map<String, dynamic>;
    return (
      r['plan_id'] as String,
      NewBooking(
        id: r['booking_id'] as String,
        ref: r['booking_ref'] as String,
        completionCode: r['completion_code'] as String,
        pricePence: (r['rate_pence'] as num).toInt(),
      ),
    );
  }

  static Future<List<RepeatPlan>> mine() async {
    // Tops the plans up before reading them, so a plan whose last visit has
    // been done already shows its next one rather than looking finished.
    try {
      await supabase.rpc('ensure_plan_bookings');
    } catch (_) {
      // A top-up failure must not stop the customer seeing their plans.
    }

    final rows = await supabase
        .from('booking_plans')
        .select(
          'id, frequency, weekday, start_time, rate_pence, state, next_due_at, '
          'services!inner(name, rate_unit, trades!inner(name, slug)), '
          'addresses!inner(line1), '
          'provider:app_users!booking_plans_provider_id_fkey(full_name)',
        )
        .neq('state', 'cancelled')
        .order('next_due_at', ascending: true);

    return rows.map<RepeatPlan>((r) => RepeatPlan.fromMap(r)).toList();
  }

  static Future<void> pause(String planId) => _setState(planId, 'paused');
  static Future<void> resume(String planId) => _setState(planId, 'active');
  static Future<void> end(String planId) => _setState(planId, 'cancelled');

  static Future<void> _setState(String planId, String state) async {
    await supabase.rpc('set_plan_state', params: {
      'p_plan': planId,
      'p_state': state,
    });
  }
}
