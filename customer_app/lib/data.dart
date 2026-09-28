import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_ui/yaari_ui.dart';

import 'config.dart';

SupabaseClient? _testClient;

/// The app uses the initialised singleton. Tests can substitute a plain
/// client so they can reach the real backend without the Flutter plugin
/// layer (shared_preferences and friends are unavailable in the test VM).
SupabaseClient get supabase => _testClient ?? Supabase.instance.client;

@visibleForTesting
void useTestClient(SupabaseClient client) => _testClient = client;

// ---------- models ----------

class Trade {
  Trade({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.blurb,
    required this.accent,
    required this.imageUrl,
    required this.heroUrl,
    this.fromPence,
    this.fromUnit,
  });

  final String id;
  final String slug;
  final String name;

  /// What the home grid shows. A tile is about a third of a phone screen
  /// wide, so the full name does not always fit.
  final String shortName;

  final String icon;
  final String? blurb;

  /// 'ember' or 'slate'. Set in the database so the grid keeps alternating
  /// when a trade is added or retired without an app release.
  final String accent;

  /// 4:3, for the home grid.
  final String? imageUrl;

  /// 16:9, for the screen header.
  final String? heroUrl;

  /// The cheapest live service in this trade. Every competitor prices the
  /// category itself — "from £17.90/hr" — before you have chosen anything.
  /// Hiding it until the third screen reads as having something to hide.
  final int? fromPence;

  /// 'hour' or 'job'. An hourly trade and a fixed-price one need different
  /// wording; the two cannot be shown the same way without lying about one.
  final String? fromUnit;

  /// Null when the trade has no published prices yet, so the tile can stay
  /// quiet rather than print "from £0".
  String? get fromLabel => fromPence == null
      ? null
      : 'from ${formatRate(fromPence!, fromUnit ?? 'job')}';

  factory Trade.fromMap(Map<String, dynamic> m) => Trade(
        id: m['id'] as String,
        slug: m['slug'] as String,
        name: m['name'] as String,
        shortName: (m['short_name'] as String?) ?? m['name'] as String,
        icon: (m['icon'] as String?) ?? 'wheel',
        blurb: m['blurb'] as String?,
        accent: (m['accent'] as String?) ?? 'ember',
        imageUrl: m['image_url'] as String?,
        heroUrl: m['hero_url'] as String?,
        fromPence: (m['from_pence'] as num?)?.toInt(),
        fromUnit: m['from_unit'] as String?,
      );
}

class Service {
  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.ratePence,
    required this.rateUnit,
    required this.durationMinutes,
    required this.isPopular,
    required this.heroUrl,
  });

  final String id;
  final String name;
  final String? description;
  final int ratePence;
  final String rateUnit;

  /// How long the job usually takes. Shown so the price has a shape to it.
  final int? durationMinutes;
  final bool isPopular;
  final String? heroUrl;

  factory Service.fromMap(Map<String, dynamic> m) => Service(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        ratePence: m['rate_pence'] as int,
        rateUnit: m['rate_unit'] as String,
        durationMinutes: m['duration_minutes'] as int?,
        isPopular: (m['is_popular'] as bool?) ?? false,
        heroUrl: m['hero_url'] as String?,
      );
}

/// One way of buying a service.
///
/// Cleaning is the reason this exists: nobody knows how many hours their flat
/// takes, but everybody knows how many bedrooms it has. Every UK platform
/// prices it that way, so the catalogue has to be able to.
///
/// [maxQty] above one means the customer picks a count — five rooms, three
/// hours — and the price is the option rate times that count. The price is
/// recomputed on the server at booking time; this is only what we show.
class ServiceOption {
  ServiceOption({
    required this.id,
    required this.slug,
    required this.label,
    required this.detail,
    required this.ratePence,
    required this.rateUnit,
    required this.minQty,
    required this.maxQty,
  });

  final String id;
  final String slug;
  final String label;
  final String? detail;
  final int ratePence;
  final String rateUnit;
  final int minQty;
  final int maxQty;

  /// Whether this option asks the customer for a number.
  bool get isCountable => maxQty > minQty;

  int priceFor(int qty) => ratePence * qty.clamp(minQty, maxQty);

  factory ServiceOption.fromMap(Map<String, dynamic> m) => ServiceOption(
        id: m['id'] as String,
        slug: m['slug'] as String,
        label: m['label'] as String,
        detail: m['detail'] as String?,
        ratePence: m['rate_pence'] as int,
        rateUnit: m['rate_unit'] as String,
        minQty: (m['min_qty'] as num?)?.toInt() ?? 1,
        maxQty: (m['max_qty'] as num?)?.toInt() ?? 1,
      );
}

class NearbyProvider {
  NearbyProvider({
    required this.userId,
    required this.name,
    required this.metres,
    required this.ratingAvg,
    required this.ratingCount,
    required this.jobsCompleted,
    required this.hourlyRatePence,
    required this.bio,
    this.tier = 'bronze',
    this.upliftBps = 0,
    this.availableNow = true,
    this.displayLat,
    this.displayLng,
  });

  final String userId;
  final String name;
  final double metres;
  final double? ratingAvg;
  final int ratingCount;
  final int jobsCompleted;
  final int? hourlyRatePence;
  final String? bio;

  /// 'gold', 'silver' or 'bronze' — earned, computed on the server.
  final String tier;

  /// What their tier adds to the price, in basis points. The server charges
  /// it; this is only so the screen can show the same figure first.
  final int upliftBps;

  /// Online and inside their working hours right now. False means they can
  /// take the booking for later today, not this minute.
  final bool availableNow;

  /// The map position — their neighbourhood, never their home. Null from
  /// the plain list query, which never carried a position at all.
  final double? displayLat;
  final double? displayLng;

  /// This professional's price for a job whose base price is [basePence].
  int priceFor(int basePence) => tierPrice(basePence, upliftBps);

  factory NearbyProvider.fromMap(Map<String, dynamic> m) => NearbyProvider(
        userId: m['user_id'] as String,
        name: (m['full_name'] as String?) ?? 'Provider',
        metres: (m['metres'] as num).toDouble(),
        ratingAvg: (m['rating_avg'] as num?)?.toDouble(),
        ratingCount: (m['rating_count'] as int?) ?? 0,
        jobsCompleted: (m['jobs_completed'] as int?) ?? 0,
        hourlyRatePence: m['hourly_rate_pence'] as int?,
        bio: m['bio'] as String?,
        tier: (m['tier'] as String?) ?? 'bronze',
        upliftBps: (m['uplift_bps'] as num?)?.toInt() ?? 0,
        availableNow: (m['available_now'] as bool?) ?? true,
        displayLat: (m['display_lat'] as num?)?.toDouble(),
        displayLng: (m['display_lng'] as num?)?.toDouble(),
      );
}

/// Somewhere Yaari operates, or intends to.
///
/// The app holds no list of cities of its own. Opening a new area is a row in
/// this table, not a release — which is the whole reason London took no app
/// change to add.
class ServiceArea {
  ServiceArea({
    required this.name,
    required this.city,
    required this.postcodePrefix,
    required this.isLive,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String city;
  final String postcodePrefix;
  final bool isLive;
  final double lat;
  final double lng;

  /// "Selly Oak, Birmingham" — used wherever the city is not already obvious.
  String get full => '$name, $city';

  factory ServiceArea.fromMap(Map<String, dynamic> m) => ServiceArea(
        name: m['name'] as String,
        city: (m['city'] as String?) ?? 'Birmingham',
        postcodePrefix: m['postcode_prefix'] as String,
        isLive: m['is_live'] as bool,
        lat: (m['lat'] as num?)?.toDouble() ?? Config.fallbackLat,
        lng: (m['lng'] as num?)?.toDouble() ?? Config.fallbackLng,
      );
}

// ---------- queries ----------

class Api {
  /// The view adds the cheapest live rate to each trade, so the grid can
  /// price the category without a second round trip.
  static const _tradeColumns =
      'id, slug, name, short_name, icon, blurb, accent, image_url, hero_url, '
      'from_pence, from_unit';

  static Future<List<Trade>> trades() async {
    final rows = await supabase
        .from('trade_catalogue')
        .select(_tradeColumns)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map<Trade>((r) => Trade.fromMap(r)).toList();
  }

  static Future<List<Service>> servicesFor(String tradeId) async {
    final rows = await supabase
        .from('services')
        .select('id, name, description, rate_pence, rate_unit, duration_minutes, is_popular, hero_url')
        .eq('trade_id', tradeId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map<Service>((r) => Service.fromMap(r)).toList();
  }

  /// Every live service in one round trip, each paired with the trade it
  /// belongs to. Used to warm search; the per-trade query is still there for
  /// the screen that only needs one trade's worth.
  static Future<List<(String, Service)>> allServices() async {
    final rows = await supabase
        .from('services')
        .select('id, trade_id, name, description, rate_pence, rate_unit, '
            'duration_minutes, is_popular, hero_url')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return rows
        .map<(String, Service)>(
            (r) => (r['trade_id'] as String, Service.fromMap(r)))
        .toList();
  }

  /// The ways a service can be bought — property sizes, room counts, hourly.
  ///
  /// An empty list is the normal case and means the service has one flat
  /// price. Screens must handle that without showing an empty picker.
  static Future<List<ServiceOption>> optionsFor(String serviceId) async {
    final rows = await supabase
        .from('service_options')
        .select('id, slug, label, detail, rate_pence, rate_unit, '
            'min_qty, max_qty')
        .eq('service_id', serviceId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map<ServiceOption>((r) => ServiceOption.fromMap(r)).toList();
  }

  /// Fetches one trade and one service by id, so a past booking can be
  /// started again without the customer navigating the catalogue afresh.
  static Future<(Trade, Service)?> tradeAndService(
      String tradeSlug, String serviceId) async {
    final tradeRows = await supabase
        .from('trade_catalogue')
        .select(_tradeColumns)
        .eq('slug', tradeSlug)
        .eq('is_active', true)
        .limit(1);
    if (tradeRows.isEmpty) return null;

    final serviceRows = await supabase
        .from('services')
        .select('id, name, description, rate_pence, rate_unit, '
            'duration_minutes, is_popular, hero_url')
        .eq('id', serviceId)
        .eq('is_active', true)
        .limit(1);
    if (serviceRows.isEmpty) return null;

    return (
      Trade.fromMap(tradeRows.first),
      Service.fromMap(serviceRows.first),
    );
  }

  /// Everywhere we operate. Live areas first, then grouped by city.
  static Future<List<ServiceArea>> areas({bool liveOnly = false}) async {
    var q = supabase
        .from('service_areas')
        .select('name, city, postcode_prefix, is_live, lat, lng');
    if (liveOnly) q = q.eq('is_live', true);

    final rows = await q
        .order('is_live', ascending: false)
        .order('city', ascending: true)
        .order('name', ascending: true);
    return rows.map<ServiceArea>((r) => ServiceArea.fromMap(r)).toList();
  }

  /// Which live area covers a point, if any.
  ///
  /// Asked of the database rather than matched against a list of city names in
  /// the app, so coverage cannot drift out of step with where supply exists.
  static Future<ServiceArea?> coveredArea(double lat, double lng) async {
    final rows = await supabase
        .rpc('covered_area', params: {'p_lng': lng, 'p_lat': lat}) as List;
    if (rows.isEmpty) return null;

    final r = rows.first as Map<String, dynamic>;
    return ServiceArea(
      name: r['name'] as String,
      city: r['city'] as String,
      postcodePrefix: r['postcode_prefix'] as String,
      isLive: true,
      lat: lat,
      lng: lng,
    );
  }

  /// Providers who may actually be offered this job right now.
  ///
  /// The database decides: approved, online, not blocked, and holding every
  /// credential their trade requires, unexpired as at this moment. A lapsed
  /// insurance certificate removes someone here with no app change.
  static Future<List<NearbyProvider>> nearby(
    String tradeSlug, {
    double? lat,
    double? lng,
    int radiusM = 12000,
  }) async {
    final rows = await supabase.rpc('nearby_providers', params: {
      'p_trade_slug': tradeSlug,
      'p_lng': lng ?? Config.fallbackLng,
      'p_lat': lat ?? Config.fallbackLat,
      'p_radius_m': radiusM,
    });
    return (rows as List)
        .map<NearbyProvider>((r) => NearbyProvider.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Everyone bookable near a point, with tier and a map position.
  ///
  /// Wider than [nearby]: it includes professionals who are online but
  /// outside their hours this minute, flagged rather than hidden, so the
  /// screen can offer "later today" instead of "nobody free". The position
  /// is a neighbourhood, never a home — see map_providers() for how.
  static Future<List<NearbyProvider>> mapProviders(
    String tradeSlug, {
    double? lat,
    double? lng,
    int radiusM = 15000,
  }) async {
    final rows = await supabase.rpc('map_providers', params: {
      'p_trade_slug': tradeSlug,
      'p_lng': lng ?? Config.fallbackLng,
      'p_lat': lat ?? Config.fallbackLat,
      'p_radius_m': radiusM,
    });
    return (rows as List)
        .map<NearbyProvider>(
            (r) => NearbyProvider.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// How many providers are bookable per trade right now. Shown on the
  /// browse list so expectations are set before the tap, not after.
  static Future<Map<String, int>> supplyByTrade(List<Trade> trades) async {
    final counts = <String, int>{};
    await Future.wait(trades.map((t) async {
      try {
        counts[t.slug] = (await nearby(t.slug)).length;
      } catch (_) {
        counts[t.slug] = 0;
      }
    }));
    return counts;
  }
}

/// One row in the search results: a service, and the trade it belongs to.
class SearchHit {
  SearchHit({required this.trade, required this.service, required this.score});

  final Trade trade;

  /// Null when the trade itself matched rather than one of its services.
  final Service? service;

  /// Lower sorts first. Not shown; it only decides the order.
  final int score;

  String get title => service?.name ?? trade.name;
  String? get subtitle => service == null ? trade.blurb : trade.name;
}

/// Search over the catalogue.
///
/// The whole catalogue is twelve trades and about three dozen services, so it
/// is fetched once and matched in memory. That makes every keystroke instant
/// and keeps working on a bad connection — a server round trip per character
/// would be slower and worse, not more serious.
class CatalogueSearch {
  CatalogueSearch(this.trades, this.servicesByTrade);

  final List<Trade> trades;
  final Map<String, List<Service>> servicesByTrade;

  static Future<CatalogueSearch> load() async {
    // One query for every service, not one per trade. The previous version
    // fanned out a request per trade — fifteen of them now — which is fine on
    // office wifi and slow enough to be noticed on mobile data, for a screen
    // that is meant to open instantly.
    final trades = await Api.trades();
    final all = await Api.allServices();

    final byTrade = <String, List<Service>>{for (final t in trades) t.id: []};
    for (final (tradeId, service) in all) {
      byTrade[tradeId]?.add(service);
    }

    return CatalogueSearch(trades, byTrade);
  }

  /// Extra words people actually type that do not appear in any name.
  /// "My boiler is broken" should find the gas engineer.
  static const _also = <String, List<String>>{
    'electrician': ['socket', 'plug', 'fuse', 'light', 'bulb', 'wiring', 'power', 'switch'],
    'plumber': ['leak', 'tap', 'toilet', 'sink', 'drain', 'blocked', 'water', 'shower'],
    'gas-engineer': ['boiler', 'heating', 'radiator', 'gas', 'safety certificate', 'landlord'],
    'cleaner': ['clean', 'housekeeping', 'tenancy', 'hoover', 'ironing'],
    'gardener': ['lawn', 'grass', 'hedge', 'weeds', 'mowing', 'garden'],
    'handyman': ['odd jobs', 'flat pack', 'shelf', 'mount', 'tv', 'repair'],
    'painter': ['paint', 'decorating', 'wallpaper', 'walls'],
    'carpenter': ['door', 'wood', 'floor', 'shelving', 'skirting'],
    'pet-care': ['dog', 'puppy', 'cat', 'walk', 'pet', 'feeding'],
    'appliance-repair': ['washing machine', 'oven', 'fridge', 'dishwasher', 'dryer'],
    'removals': ['move', 'van', 'moving', 'house move', 'clearance'],
    'window-cleaning': ['window', 'glass', 'gutter', 'sills'],
    'hairdresser': ['hair', 'haircut', 'cut', 'barber', 'colour', 'color',
        'highlights', 'blow dry', 'trim', 'stylist', 'roots', 'fringe'],
    'beauty': ['nails', 'manicure', 'pedicure', 'gel', 'wax', 'waxing',
        'facial', 'brows', 'eyebrows', 'lashes', 'threading', 'tint',
        'beautician', 'spray tan'],
    'massage': ['massage', 'masseuse', 'masseur', 'deep tissue', 'sports',
        'swedish', 'back', 'shoulders', 'knot', 'physio', 'aches'],
  };

  List<SearchHit> query(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final hits = <SearchHit>[];

    for (final t in trades) {
      final name = t.name.toLowerCase();
      final short = t.shortName.toLowerCase();
      final synonyms = _also[t.slug] ?? const [];

      // A name that starts with what was typed beats one that merely
      // contains it, which is what makes "pl" put Plumber above Appliances.
      int? tradeScore;
      if (name.startsWith(q) || short.startsWith(q)) {
        tradeScore = 0;
      } else if (name.contains(q) || short.contains(q)) {
        tradeScore = 2;
      } else if (synonyms.any((w) => w.startsWith(q))) {
        tradeScore = 3;
      } else if (synonyms.any((w) => w.contains(q))) {
        tradeScore = 5;
      }

      if (tradeScore != null) {
        hits.add(SearchHit(trade: t, service: null, score: tradeScore));
      }

      for (final s in servicesByTrade[t.id] ?? const <Service>[]) {
        final sn = s.name.toLowerCase();
        final sd = (s.description ?? '').toLowerCase();
        int? score;
        if (sn.startsWith(q)) {
          score = 1;
        } else if (sn.contains(q)) {
          score = 3;
        } else if (sd.contains(q)) {
          score = 6;
        } else if (tradeScore != null) {
          // The trade matched, so its services are still relevant — just
          // below anything that matched on its own name.
          score = tradeScore + 7;
        }
        if (score != null) {
          hits.add(SearchHit(trade: t, service: s, score: score));
        }
      }
    }

    hits.sort((a, b) {
      final c = a.score.compareTo(b.score);
      return c != 0 ? c : a.title.compareTo(b.title);
    });
    return hits.take(40).toList();
  }
}
