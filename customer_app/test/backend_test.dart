@Tags(['live'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_ui/yaari_ui.dart';

import 'package:yaari_customer/config.dart';
import 'package:yaari_customer/data.dart';

/// Talks to the real Supabase project. Run with:
///   flutter test test/backend_test.dart
///
/// These assert the behaviour the whole product rests on: that a provider
/// whose credentials have lapsed cannot be booked, without the app having
/// to know anything about credentials.
void main() {
  setUpAll(() {
    // flutter_test installs an HttpClient that refuses real requests.
    // These tests deliberately hit the live project, so restore networking.
    HttpOverrides.global = null;

    // A plain client avoids Supabase.initialize, which needs platform
    // plugins that do not exist in the test VM.
    useTestClient(SupabaseClient(Config.supabaseUrl, Config.supabaseKey));
  });

  test('the catalogue loads', () async {
    final trades = await Api.trades();
    expect(trades, isNotEmpty);
    expect(trades.map((t) => t.slug), contains('electrician'));
  });

  test('every trade on the home grid has a mark drawn for it', () async {
    final trades = await Api.trades();
    // Not pinned to a count: the catalogue grows. What must hold is that
    // every trade the database serves has a mark, which is checked below.
    expect(trades.length, greaterThanOrEqualTo(15));

    // The catalogue used to carry a photograph per trade, fetched from
    // storage. The app draws its own marks now, so what has to be true is
    // that every trade the database serves has one — a trade going live
    // without a mark would fall back to a generic spanner and look like an
    // oversight, which is exactly what it would be.
    final missing = trades
        .where((t) => !YaariMark.has(t.slug))
        .map((t) => t.slug)
        .toList();

    expect(missing, isEmpty,
        reason: 'no mark drawn for: ${missing.join(', ')} — add it to '
            'packages/yaari_ui/lib/src/marks.dart');

    for (final t in trades) {
      expect(t.shortName.length, lessThanOrEqualTo(20),
          reason: '${t.slug} short name is too long for a register row');
      expect(t.blurb, isNotNull,
          reason: '${t.slug} has no description, so its row has a blank line');
    }
  });

  test('services carry a published price in pence', () async {
    final trades = await Api.trades();
    final electrician = trades.firstWhere((t) => t.slug == 'electrician');
    final services = await Api.servicesFor(electrician.id);

    expect(services, isNotEmpty);
    for (final s in services) {
      expect(s.ratePence, greaterThan(0));
      expect(['hour', 'job'], contains(s.rateUnit));
    }
  });

  test('both cities have live coverage and reachable supply', () async {
    final areas = await Api.areas();
    final cities = areas.where((a) => a.isLive).map((a) => a.city).toSet();
    expect(cities, containsAll(<String>['Birmingham', 'London']),
        reason: 'the app reads its cities from service_areas, not from code');

    // A city with coverage but no tradespeople is worse than no city at all,
    // so assert supply rather than merely the row existing.
    for (final city in cities) {
      final area = areas.firstWhere((a) => a.isLive && a.city == city);
      final electricians =
          await Api.nearby('electrician', lat: area.lat, lng: area.lng);
      expect(electricians, isNotEmpty,
          reason: '$city has coverage but nobody bookable near ${area.name}');
    }
  });

  test('coverage is decided by the database, not by a list of city names',
      () async {
    // Selly Oak and Clapham are both live.
    expect(await Api.coveredArea(52.437675, -1.947505), isNotNull);
    expect((await Api.coveredArea(51.460976, -0.136471))?.city, 'London');

    // Croydon exists as an area but is not live yet, and Manchester is not an
    // area at all. Both must come back as not covered.
    expect(await Api.coveredArea(51.373248, -0.077953), isNull,
        reason: 'Croydon is staged, not live');
    expect(await Api.coveredArea(53.478, -2.236), isNull,
        reason: 'Manchester is not a service area');
  });

  test('a lapsed certificate blocks work in London too', () async {
    // The gate is enforced per provider, not per city. Femi Balogun is
    // approved and online in London with insurance that expired yesterday.
    final near = await Api.nearby('electrician', lat: 51.472831, lng: -0.065572);
    expect(near.map((p) => p.name), isNot(contains('Femi Balogun')));
    expect(near, isNotEmpty,
        reason: 'other London electricians should still be bookable');
  });

  test('discovery returns providers sorted by distance', () async {
    final list = await Api.nearby('electrician');
    expect(list, isNotEmpty);

    for (var i = 1; i < list.length; i++) {
      expect(list[i].metres, greaterThanOrEqualTo(list[i - 1].metres));
    }
  });

  test('a provider with lapsed insurance cannot be booked', () async {
    // Tom Baxter is approved and online, and his public liability lapsed
    // yesterday. He must not be offerable, and the app never asks why.
    final list = await Api.nearby('electrician');
    final names = list.map((p) => p.name).toList();

    expect(names, isNot(contains('Tom Baxter')),
        reason: 'lapsed public liability must remove a provider from discovery');

    // Deliberately not asserting that a particular named electrician is
    // present. Discovery also filters on working hours, so whoever is
    // returned depends on the day and time the suite happens to run — an
    // earlier version of this test named Rahul Krishnan and failed every
    // Sunday, because he does not work Sundays and the gate was right.
    expect(list, isNotEmpty,
        reason: 'removing Tom must not empty the trade');
  });

  test('an unapproved applicant is never offered work', () async {
    final list = await Api.nearby('plumber');
    expect(list.map((p) => p.name), isNot(contains('Mo Karim')));
  });

  test('discovery never leaks provider home coordinates', () async {
    final rows = await supabase.rpc('nearby_providers', params: {
      'p_trade_slug': 'electrician',
      'p_lng': Config.fallbackLng,
      'p_lat': Config.fallbackLat,
      'p_radius_m': 12000,
    }) as List;

    expect(rows, isNotEmpty);
    final keys = (rows.first as Map).keys;
    expect(keys, isNot(contains('home_point')));
    expect(keys, contains('metres'));
  });

  test('job photographs are invisible to anyone outside the booking', () async {
    // Photos of the inside of somebody's home are the most sensitive thing in
    // the system. An anonymous client must not be able to list them, fetch one
    // directly, or mint a signed link to one.
    final rows = await supabase.from('booking_photos').select('storage_path');
    expect(rows, isEmpty,
        reason: 'row level security should hide every photo row from anon');

    // A real object exists at this shape of path; anon must still be refused.
    final probe = await supabase.from('bookings').select('id').limit(1);
    final bookingId =
        probe.isEmpty ? '00000000-0000-0000-0000-000000000000' : probe.first['id'];
    final path = '$bookingId/before.jpg';

    final res = await HttpClient()
        .getUrl(Uri.parse(
            '${Config.supabaseUrl}/storage/v1/object/public/job-photos/$path'))
        .then((r) => r.close());
    await res.drain<void>();
    expect(res.statusCode, isNot(200),
        reason: 'job photos must never be publicly readable');

    await expectLater(
      supabase.storage.from('job-photos').createSignedUrl(path, 60),
      throwsA(isA<StorageException>()),
      reason: 'an anonymous client must not be able to sign a photo URL',
    );
  });

  test('an anonymous caller cannot reach the booking or money functions',
      () async {
    // This regressed once already: `create or replace function` with a changed
    // signature makes a NEW function, and Postgres grants EXECUTE on a new
    // function to PUBLIC. So every rewrite silently reopens the API unless the
    // grant is reapplied. Hence a test rather than a one-off fix.
    const locked = {
      'create_booking': {
        'p_service_id': '00000000-0000-0000-0000-000000000001',
        'p_address_id': '00000000-0000-0000-0000-000000000002',
        'p_provider_id': '00000000-0000-0000-0000-000000000003',
        'p_is_asap': true,
      },
      'accept_booking': {'p_booking': '00000000-0000-0000-0000-000000000001'},
      'cancel_booking': {
        'p_booking': '00000000-0000-0000-0000-000000000001',
        'p_reason': 'test',
      },
      'provider_is_compliant': {
        'p_provider': '00000000-0000-0000-0000-000000000001',
      },
    };

    for (final entry in locked.entries) {
      await expectLater(
        supabase.rpc(entry.key, params: entry.value),
        throwsA(predicate(
          (e) => e is PostgrestException && e.code == '42501',
          'permission denied for ${entry.key}',
        )),
        reason: '${entry.key} must not be callable before sign-in',
      );
    }
  });

  test('browsing still works before sign-in', () async {
    // The lockout must not go so far that a visitor cannot look around:
    // discovery and coverage are deliberately open.
    expect(await Api.trades(), isNotEmpty);
    expect(await Api.nearby('electrician', lat: 51.460976, lng: -0.136471),
        isNotEmpty);
    expect(await Api.coveredArea(51.460976, -0.136471), isNotNull);
  });

  test('credential documents are unreadable by an unauthenticated client', () async {
    final rows = await supabase.from('provider_documents').select('id');
    expect(rows, isEmpty,
        reason: 'row level security must hide every document from an anonymous caller');
  });
}
