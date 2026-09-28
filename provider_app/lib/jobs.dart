import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';

/// The provider's side of a job.
///
/// Every move calls a database function that checks the transition is
/// allowed, so the app cannot skip the photo or close a job it never
/// started, however it is built.

class Job {
  Job({
    required this.id,
    required this.ref,
    required this.state,
    required this.serviceName,
    required this.customerName,
    required this.addressLine,
    required this.postcode,
    required this.quotedPence,
    required this.finalPence,
    required this.paymentMethod,
    required this.isAsap,
    required this.scheduledFor,
    required this.createdAt,
    this.tradeSlug,
    this.lat,
    this.lng,
    this.repeatEvery,
    this.startRequestedAt,
    this.finishRequestedAt,
  });

  final String id;
  final String ref;
  final String state;
  final String serviceName;
  final String? customerName;
  final String? addressLine;
  final String? postcode;
  final int quotedPence;
  final int? finalPence;
  final String paymentMethod;
  final bool isAsap;
  final DateTime? scheduledFor;
  final DateTime createdAt;

  /// Which trade's mark to draw on the card. Replaced a photograph: the
  /// mark is a few bytes, stays crisp, and matches what the customer saw
  /// when they booked.
  final String? tradeSlug;

  /// Only populated once the job is accepted — an offer must not reveal
  /// where somebody lives before it has been taken.
  final double? lat;
  final double? lng;

  /// 'weekly', 'fortnightly' or 'every_4_weeks' when this job is one visit
  /// of a standing arrangement; null for a one-off.
  ///
  /// Worth showing prominently: a regular slot is a different proposition to
  /// a single afternoon's work, and it is the reason to take the job.
  final String? repeatEvery;

  /// Set when this side has asked and the customer has not yet answered.
  final DateTime? startRequestedAt;
  final DateTime? finishRequestedAt;

  /// True while a professional is standing there waiting on a tap.
  bool get awaitingStart =>
      state == 'en_route' && startRequestedAt != null;
  bool get awaitingFinish =>
      state == 'in_progress' && finishRequestedAt != null;

  bool get isRepeat => repeatEvery != null;

  String get repeatLabel => switch (repeatEvery) {
        'weekly' => 'Every week',
        'fortnightly' => 'Every two weeks',
        'every_4_weeks' => 'Every four weeks',
        _ => '',
      };

  bool get hasLocation => lat != null && lng != null && state != 'requested';

  bool get isOffer => state == 'requested';
  bool get isActive =>
      state == 'accepted' || state == 'en_route' || state == 'in_progress';
  bool get isDone => state == 'completed';

  /// The exact address is only released once the job is accepted, so a
  /// declined offer never reveals where someone lives.
  String get whereShown => state == 'requested'
      ? (postcode ?? 'Nearby')
      : [addressLine, postcode].whereType<String>().join(', ');

  /// The state in the customer's words, for the live card.
  String get stateLabel => switch (state) {
        'requested' => 'Offered to you',
        'accepted' => 'Accepted',
        'en_route' => 'On the way',
        'in_progress' => 'Working',
        'completed' => 'Finished',
        'cancelled' => 'Cancelled',
        'expired' => 'Expired',
        'disputed' => 'Disputed',
        _ => state,
      };

  String get nextActionLabel => switch (state) {
        'accepted' => "I'm on my way",
        'en_route' => 'Start work',
        'in_progress' => 'Finish and get paid',
        _ => '',
      };

  factory Job.fromMap(Map<String, dynamic> m) {
    final service = m['services'] as Map<String, dynamic>?;
    final customer = m['customer'] as Map<String, dynamic>?;
    final address = m['addresses'] as Map<String, dynamic>?;
    return Job(
      id: m['id'] as String,
      ref: m['ref'] as String,
      state: m['state'] as String,
      serviceName: (service?['name'] as String?) ?? 'Job',
      customerName: customer?['full_name'] as String?,
      addressLine: address?['line1'] as String?,
      postcode: address?['postcode'] as String?,
      quotedPence: (m['quoted_pence'] as num).toInt(),
      finalPence: (m['final_pence'] as num?)?.toInt(),
      paymentMethod: (m['payment_method'] as String?) ?? 'cash',
      isAsap: (m['is_asap'] as bool?) ?? true,
      scheduledFor: m['scheduled_for'] == null
          ? null
          : DateTime.parse(m['scheduled_for'] as String).toLocal(),
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      tradeSlug:
          (service?['trades'] as Map<String, dynamic>?)?['slug'] as String?,
      lat: (address?['lat'] as num?)?.toDouble(),
      lng: (address?['lng'] as num?)?.toDouble(),
      repeatEvery:
          (m['booking_plans'] as Map<String, dynamic>?)?['frequency'] as String?,
    );
  }
}

const _jobSelect =
    'id, ref, state, quoted_pence, final_pence, payment_method, is_asap, '
    'scheduled_for, created_at, start_requested_at, finish_requested_at, '
    'services(name, trades(slug)), '
    'customer:customer_id(full_name), addresses(line1, postcode, lat, lng), '
    'booking_plans(frequency)';

class JobsApi {
  /// Offers waiting for an answer. Row level security already limits this
  /// to jobs pointed at this provider.
  static Future<List<Job>> offers() async {
    final me = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('bookings')
        .select(_jobSelect)
        .eq('state', 'requested')
        .eq('offered_to', me)
        .order('created_at', ascending: false);
    return rows.map<Job>((r) => Job.fromMap(r)).toList();
  }

  static Future<List<Job>> mine() async {
    final me = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('bookings')
        .select(_jobSelect)
        .eq('provider_id', me)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map<Job>((r) => Job.fromMap(r)).toList();
  }

  static Future<void> accept(String bookingId) =>
      supabase.rpc('accept_booking', params: {'p_booking': bookingId});

  /// Ask the customer to confirm the work can begin. Does not start it —
  /// only their tap does that, which is what makes the start time evidence
  /// rather than an assertion.
  static Future<void> requestStart(String bookingId) async {
    await supabase.rpc('request_start', params: {'p_booking': bookingId});
  }

  /// Tell the customer the work is done and wait for them to accept it.
  static Future<void> requestFinish(String bookingId) async {
    await supabase.rpc('request_finish', params: {'p_booking': bookingId});
  }

  static Future<void> advance(String bookingId, String toState) =>
      supabase.rpc('advance_booking', params: {
        'p_booking': bookingId,
        'p_to': toState,
      });

  /// Uploads a photograph of the work and records it against the booking.
  ///
  /// The file goes up first. Only if that succeeds is the row written, because
  /// the row is what the state machine treats as proof the photo exists — and
  /// a row pointing at an object that was never uploaded is worse than no row
  /// at all. Both parties can read it afterwards; nobody else can.
  static Future<void> addPhoto(
    String bookingId,
    String kind,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) {
      throw Exception('That photo came back empty. Please take it again.');
    }

    // Path starts with the booking id because the storage policy reads the
    // first folder segment to decide who may see it.
    final path = '$bookingId/$kind.jpg';

    await supabase.storage.from('job-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    await supabase.from('booking_photos').upsert({
      'booking_id': bookingId,
      'kind': kind,
      'storage_path': path,
      'uploaded_by': supabase.auth.currentUser!.id,
    }, onConflict: 'booking_id,kind');
  }

  /// A short-lived link to a photograph. The bucket is private, so there is
  /// no permanent URL to leak.
  static Future<String?> photoUrl(String bookingId, String kind) async {
    final rows = await supabase
        .from('booking_photos')
        .select('storage_path')
        .eq('booking_id', bookingId)
        .eq('kind', kind)
        .limit(1);
    if (rows.isEmpty) return null;

    return supabase.storage
        .from('job-photos')
        .createSignedUrl(rows.first['storage_path'] as String, 60 * 30);
  }

  static Future<bool> hasPhoto(String bookingId, String kind) async {
    final rows = await supabase
        .from('booking_photos')
        .select('id')
        .eq('booking_id', bookingId)
        .eq('kind', kind)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Close the job with the customer's code. Returns what was earned.
  static Future<JobPayment> complete(String bookingId, String code) async {
    final rows = await supabase.rpc('complete_booking', params: {
      'p_booking': bookingId,
      'p_code': code,
    });
    final r = (rows as List).first as Map<String, dynamic>;
    return JobPayment(
      amountPence: (r['amount_pence'] as num).toInt(),
      commissionPence: (r['commission_pence'] as num).toInt(),
      netPence: (r['net_pence'] as num).toInt(),
    );
  }

  /// New offers arriving while the app is open.
  static RealtimeChannel watchOffers(void Function() onChange) {
    final me = supabase.auth.currentUser!.id;
    return supabase
        .channel('offers:$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'offered_to',
            value: me,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}

class JobPayment {
  const JobPayment({
    required this.amountPence,
    required this.commissionPence,
    required this.netPence,
  });

  final int amountPence;
  final int commissionPence;
  final int netPence;
}

class EarningsRow {
  EarningsRow({
    required this.service,
    required this.completedAt,
    required this.method,
    required this.amountPence,
    required this.netPence,
  });

  final String service;
  final DateTime? completedAt;
  final String method;
  final int amountPence;
  final int netPence;

  factory EarningsRow.fromMap(Map<String, dynamic> m) => EarningsRow(
        service: (m['service'] as String?) ?? 'Job',
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.parse(m['completed_at'] as String).toLocal(),
        method: (m['method'] as String?) ?? 'cash',
        amountPence: (m['amount_pence'] as num?)?.toInt() ?? 0,
        netPence: (m['provider_net_pence'] as num?)?.toInt() ?? 0,
      );
}

class EarningsApi {
  static Future<List<EarningsRow>> recent() async {
    final me = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('provider_earnings')
        .select('service, completed_at, method, amount_pence, provider_net_pence')
        .eq('provider_id', me)
        .order('completed_at', ascending: false)
        .limit(30);
    return rows.map<EarningsRow>((r) => EarningsRow.fromMap(r)).toList();
  }

  /// Negative means commission owed to the platform from cash jobs.
  static Future<int> balancePence() async {
    final me = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('provider_balances')
        .select('balance_pence')
        .eq('provider_id', me)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['balance_pence'] as num?)?.toInt() ?? 0;
  }
}

/// What Yaari actually charges, read from the database.
///
/// Hardcoding "zero commission" in the app is how a launch offer quietly
/// becomes a lie the day the rate changes. The rate and the wording both come
/// from `platform_settings`, so the app cannot contradict the ledger.
class Commission {
  Commission({required this.bps, required this.note});

  final int bps;
  final String? note;

  bool get isFree => bps == 0;

  /// "10%" or "2.5%" — trailing zeroes dropped, because £ amounts elsewhere
  /// are exact and a percentage that reads "10.0%" looks like a rounding.
  String get rate {
    final pct = bps / 100;
    final s = pct.toStringAsFixed(2);
    return '${s.endsWith('.00') ? pct.toStringAsFixed(0) : s}%';
  }

  static Future<Commission> current() async {
    final rows = await supabase
        .from('platform_settings')
        .select('commission_bps, launch_offer_note')
        .limit(1);
    if (rows.isEmpty) return Commission(bps: 0, note: null);
    return Commission(
      bps: (rows.first['commission_bps'] as num?)?.toInt() ?? 0,
      note: rows.first['launch_offer_note'] as String?,
    );
  }
}
