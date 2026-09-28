import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';

/// Booking lifecycle, as the customer sees it.
///
/// Nothing here writes to `bookings` directly. Every change goes through a
/// database function that checks the transition is legal and records it,
/// so the app cannot put a job into a state the business rules forbid.

enum PayBy { cash, card }

class NewBooking {
  const NewBooking({
    required this.id,
    required this.ref,
    required this.completionCode,
    required this.pricePence,
  });

  final String id;
  final String ref;

  /// Shown to the customer and read aloud when the job is done. The
  /// provider cannot read it — that is what makes it proof.
  final String completionCode;
  final int pricePence;
}

class BookingSummary {
  BookingSummary({
    required this.id,
    required this.ref,
    required this.state,
    required this.serviceName,
    required this.quotedPence,
    required this.finalPence,
    required this.paymentMethod,
    required this.providerName,
    required this.scheduledFor,
    required this.isAsap,
    required this.createdAt,
    this.addressLine,
    this.lat,
    this.lng,
    this.serviceId,
    this.tradeSlug,
    this.repeatEvery,
    this.startRequestedAt,
    this.finishRequestedAt,
  });

  final String id;
  final String ref;
  final String state;
  final String serviceName;
  final int quotedPence;
  final int? finalPence;
  final String paymentMethod;
  final String? providerName;
  final DateTime? scheduledFor;
  final bool isAsap;
  final DateTime createdAt;

  /// Where the job is. Carried on the booking so the live screen can draw a
  /// map without a second query.
  final String? addressLine;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  /// Enough to start the same booking again without the customer having to
  /// find the trade and the job in the catalogue a second time.
  final String? serviceId;
  final String? tradeSlug;

  bool get canRebook => serviceId != null && tradeSlug != null;

  /// Set when this visit belongs to a standing arrangement, so the screen can
  /// say "one of your weekly visits" rather than treating every job as a
  /// one-off the customer has to think about afresh.
  final String? repeatEvery;

  bool get isRepeat => repeatEvery != null;

  /// Set when the professional is waiting on a tap from this customer.
  final DateTime? startRequestedAt;
  final DateTime? finishRequestedAt;

  /// Somebody is standing in the room waiting for an answer.
  bool get needsStartApproval =>
      state == 'en_route' && startRequestedAt != null;
  bool get needsFinishApproval =>
      state == 'in_progress' && finishRequestedAt != null;

  String get repeatLabel => switch (repeatEvery) {
        'weekly' => 'weekly',
        'fortnightly' => 'fortnightly',
        'every_4_weeks' => 'four-weekly',
        _ => '',
      };

  bool get isLive =>
      state == 'requested' || state == 'accepted' || state == 'en_route' || state == 'in_progress';
  bool get isDone => state == 'completed';

  /// Closed without the work happening. Kept separate from isDone because
  /// the status screen presents the two very differently.
  bool get isBad => state == 'cancelled' || state == 'expired';

  /// Plain words, not database states.
  String get statusLabel => switch (state) {
        'requested' => 'Finding your tradesperson',
        'accepted' => 'Accepted',
        'en_route' => 'On the way',
        'in_progress' => 'Work in progress',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'expired' => 'Nobody available',
        'disputed' => 'Under review',
        _ => state,
      };

  factory BookingSummary.fromMap(Map<String, dynamic> m) {
    final service = m['services'] as Map<String, dynamic>?;
    final provider = m['provider'] as Map<String, dynamic>?;
    final address = m['addresses'] as Map<String, dynamic>?;
    return BookingSummary(
      id: m['id'] as String,
      ref: m['ref'] as String,
      state: m['state'] as String,
      serviceName: (service?['name'] as String?) ?? 'Service',
      quotedPence: (m['quoted_pence'] as num).toInt(),
      finalPence: (m['final_pence'] as num?)?.toInt(),
      paymentMethod: (m['payment_method'] as String?) ?? 'cash',
      providerName: provider?['full_name'] as String?,
      scheduledFor: m['scheduled_for'] == null
          ? null
          : DateTime.parse(m['scheduled_for'] as String).toLocal(),
      isAsap: (m['is_asap'] as bool?) ?? true,
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      addressLine: address == null
          ? null
          : '${address['line1']}, ${address['postcode']}',
      lat: (address?['lat'] as num?)?.toDouble(),
      lng: (address?['lng'] as num?)?.toDouble(),
      serviceId: m['service_id'] as String?,
      tradeSlug:
          (service?['trades'] as Map<String, dynamic>?)?['slug'] as String?,
      repeatEvery:
          (m['booking_plans'] as Map<String, dynamic>?)?['frequency'] as String?,
    );
  }
}

class BookingEvent {
  BookingEvent({required this.toState, required this.at});
  final String toState;

  /// How long ago this happened, in words. Shown against the active stage of
  /// the timeline so "on the way" carries a sense of how long that has been
  /// true.
  String get ago {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return '${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }
  final DateTime at;

  String get label => switch (toState) {
        'requested' => 'Requested',
        'accepted' => 'Accepted',
        'en_route' => 'On the way',
        'in_progress' => 'Work started',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => toState,
      };

  factory BookingEvent.fromMap(Map<String, dynamic> m) => BookingEvent(
        toState: m['to_state'] as String,
        at: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// A line in the notifications list: one state change on one booking.
class Notice {
  Notice({
    required this.state,
    required this.at,
    required this.bookingRef,
    required this.serviceName,
  });

  final String state;
  final DateTime at;
  final String bookingRef;
  final String serviceName;

  /// Written as something that happened, because that is what a notification
  /// is — not a status label.
  String get headline => switch (state) {
        'requested' => 'Booking requested',
        'accepted' => 'Your booking was accepted',
        'en_route' => 'Your tradesperson is on the way',
        'in_progress' => 'Work has started',
        'completed' => 'Job completed',
        'cancelled' => 'Booking cancelled',
        'expired' => 'Booking expired',
        _ => state,
      };

  bool get isGood => state == 'accepted' || state == 'completed';
  bool get isBad => state == 'cancelled' || state == 'expired';

  String get ago {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${at.day}/${at.month}';
  }
}

class Address {
  Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.postcode,
    this.lat,
    this.lng,
  });

  final String id;
  final String label;
  final String line1;
  final String postcode;

  /// Where the pin sits. Null for addresses saved before the map existed;
  /// the screen falls back to the postcode centroid in that case.
  final double? lat;
  final double? lng;

  bool get isPinned => lat != null && lng != null;

  String get oneLine => '$line1, $postcode';

  factory Address.fromMap(Map<String, dynamic> m) => Address(
        id: m['id'] as String,
        label: (m['label'] as String?) ?? 'Address',
        line1: m['line1'] as String,
        postcode: m['postcode'] as String,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}

class BookingApi {
  static Future<List<Address>> myAddresses() async {
    final rows = await supabase
        .from('addresses')
        .select('id, label, line1, postcode, lat, lng')
        .order('created_at', ascending: true);
    return rows.map<Address>((r) => Address.fromMap(r)).toList();
  }

  /// Saves an address, with the pin the customer confirmed on the map.
  ///
  /// Goes through `save_address` rather than a plain insert: the location is a
  /// PostGIS geography, which the client cannot construct, and routing it
  /// through one function means the point can only ever be set here.
  static Future<Address> addAddress({
    required String label,
    required String line1,
    required String postcode,
    double? lat,
    double? lng,
    String? city,
  }) async {
    final row = await supabase.rpc('save_address', params: {
      'p_label': label,
      'p_line1': line1,
      'p_postcode': postcode.toUpperCase(),
      'p_lat': lat,
      'p_lng': lng,
      // Comes from the postcode lookup rather than a default, now that the
      // company is in more than one city.
      if (city != null && city.isNotEmpty) 'p_city': city,
    });
    return Address.fromMap(
        (row is List ? row.first : row) as Map<String, dynamic>);
  }

  /// [optionId] and [quantity] carry the customer's choice — "3 bedrooms",
  /// "5 rooms". The server re-prices from the option row and ignores anything
  /// we might think the total is, so this is a statement of what was chosen,
  /// never of what it costs.
  static Future<NewBooking> create({
    required String serviceId,
    required String addressId,
    required String providerId,
    bool asap = true,
    DateTime? scheduledFor,
    String? note,
    String? optionId,
    int quantity = 1,
  }) async {
    final rows = await supabase.rpc('create_booking', params: {
      'p_service_id': serviceId,
      'p_address_id': addressId,
      'p_provider_id': providerId,
      'p_is_asap': asap,
      'p_scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      'p_note': note,
      'p_option_id': optionId,
      'p_quantity': quantity,
    });

    final r = (rows as List).first as Map<String, dynamic>;
    return NewBooking(
      id: r['booking_id'] as String,
      ref: r['booking_ref'] as String,
      completionCode: r['completion_code'] as String,
      pricePence: (r['price_pence'] as num).toInt(),
    );
  }

  /// Confirm the professional may begin. Their app is waiting on this, and
  /// the timestamp it writes is what opens the insured window.
  static Future<void> approveStart(String bookingId) async {
    await supabase.rpc('approve_start', params: {'p_booking': bookingId});
  }

  /// Accept the finished work. This is what closes the job and the money —
  /// the professional cannot do it alone.
  static Future<void> approveFinish(String bookingId) async {
    await supabase.rpc('approve_finish', params: {'p_booking': bookingId});
  }

  static Future<void> setPaymentMethod(String bookingId, PayBy method) async {
    await supabase.rpc('set_booking_payment_method', params: {
      'p_booking': bookingId,
      'p_method': method == PayBy.cash ? 'cash' : 'card',
    });
  }

  static Future<void> cancel(String bookingId, String reason) async {
    await supabase.rpc('cancel_booking', params: {
      'p_booking': bookingId,
      'p_reason': reason,
    });
  }

  static Future<List<BookingSummary>> myBookings() async {
    final rows = await supabase
        .from('bookings')
        .select(
          'id, ref, state, quoted_pence, final_pence, payment_method, is_asap, '
          'scheduled_for, created_at, service_id, '
          'start_requested_at, finish_requested_at, '
          'services(name, trades(slug)), '
          'provider:provider_id(full_name), booking_plans(frequency)',
        )
        .order('created_at', ascending: false);
    return rows.map<BookingSummary>((r) => BookingSummary.fromMap(r)).toList();
  }

  static Future<BookingSummary?> byId(String id) async {
    final rows = await supabase
        .from('bookings')
        .select(
          'id, ref, state, quoted_pence, final_pence, payment_method, is_asap, '
          'scheduled_for, created_at, service_id, '
          'start_requested_at, finish_requested_at, '
          'services(name, trades(slug)), '
          'provider:provider_id(full_name), addresses(line1, postcode, lat, lng), '
          'booking_plans(frequency)',
        )
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    return BookingSummary.fromMap(rows.first);
  }

  static Future<List<BookingEvent>> timeline(String bookingId) async {
    final rows = await supabase
        .from('booking_events')
        .select('to_state, created_at')
        .eq('booking_id', bookingId)
        .order('id', ascending: true);
    return rows.map<BookingEvent>((r) => BookingEvent.fromMap(r)).toList();
  }

  /// Everything that has happened across this customer's bookings, newest
  /// first. Row level security already limits the rows to their own jobs, so
  /// this needs no filter of its own.
  static Future<List<Notice>> notices({int limit = 40}) async {
    final rows = await supabase
        .from('booking_events')
        .select('to_state, created_at, bookings!inner(ref, services!inner(name))')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows.map<Notice>((r) {
      final b = r['bookings'] as Map<String, dynamic>;
      return Notice(
        state: r['to_state'] as String,
        at: DateTime.parse(r['created_at'] as String).toLocal(),
        bookingRef: b['ref'] as String,
        serviceName: (b['services'] as Map<String, dynamic>)['name'] as String,
      );
    }).toList();
  }

  /// Moves a booking to a different time.
  ///
  /// The database decides whether the move is allowed — only before work has
  /// started, only into the next fortnight — so the app does not have to
  /// duplicate those rules and get them subtly wrong.
  static Future<void> reschedule(String bookingId, DateTime when) async {
    await supabase.rpc('reschedule_booking', params: {
      'p_booking': bookingId,
      'p_scheduled_for': when.toUtc().toIso8601String(),
    });
  }

  /// Signed links to the before and after photographs.
  ///
  /// The bucket is private and these expire, so a link cannot be forwarded to
  /// someone who has no business seeing inside the house. Row level security
  /// already limits the rows to bookings this person is party to.
  static Future<Map<String, String>> photos(String bookingId) async {
    final rows = await supabase
        .from('booking_photos')
        .select('kind, storage_path')
        .eq('booking_id', bookingId);

    final out = <String, String>{};
    for (final r in rows) {
      try {
        out[r['kind'] as String] = await supabase.storage
            .from('job-photos')
            .createSignedUrl(r['storage_path'] as String, 60 * 30);
      } catch (_) {
        // A row whose object is missing is skipped rather than shown broken.
      }
    }
    return out;
  }

  /// The code the customer reads out on arrival. Held in its own table so
  /// that row level security can withhold it from the provider.
  static Future<String?> completionCode(String bookingId) async {
    final rows = await supabase
        .from('booking_codes')
        .select('code')
        .eq('booking_id', bookingId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['code'] as String;
  }

  /// Live updates while a job is running, so the status screen moves
  /// without anyone pulling to refresh.
  static RealtimeChannel watch(String bookingId, void Function() onChange) {
    return supabase
        .channel('booking:$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
