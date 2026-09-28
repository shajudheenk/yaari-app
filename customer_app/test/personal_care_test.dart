@Tags(['live'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_customer/config.dart';
import 'package:yaari_customer/data.dart';

/// Hair, beauty and massage — and the local licensing rule underneath them.
///
/// The claim this product makes to a safety panel is that the right to receive
/// work is gated on credentials, in the database, in real time. Personal care
/// tests that claim harder than trades do, because its requirements are not
/// national: a massage therapist needs a borough licence in London and does
/// not need one in Birmingham. These assert the gate knows the difference.
void main() {
  // Selly Oak, Birmingham, and Clapham and Wandsworth in London.
  const birmingham = (lng: -1.9385, lat: 52.4409);
  const clapham = (lng: -0.136471, lat: 51.460976);
  const wandsworth = (lng: -0.191447, lat: 51.451524);

  setUpAll(() {
    HttpOverrides.global = null;
    useTestClient(SupabaseClient(Config.supabaseUrl, Config.supabaseKey));
  });

  Future<List<String>> nearby(String trade, ({double lat, double lng}) at) async {
    final rows = await supabase.rpc('nearby_providers', params: {
      'p_trade_slug': trade,
      'p_lng': at.lng,
      'p_lat': at.lat,
      'p_radius_m': 12000,
    });
    return (rows as List)
        .map<String>((r) => (r as Map<String, dynamic>)['full_name'] as String)
        .toList();
  }

  group('the catalogue', () {
    test('lists hair, beauty and massage', () async {
      final slugs = (await Api.trades()).map((t) => t.slug).toList();
      expect(slugs, containsAll(['hairdresser', 'beauty', 'massage']));
    });

    test('every personal care trade is priced per treatment, not per hour',
        () async {
      final trades = await Api.trades();
      for (final slug in ['hairdresser', 'beauty', 'massage']) {
        final trade = trades.firstWhere((t) => t.slug == slug);
        final services = await Api.servicesFor(trade.id);
        expect(services, isNotEmpty, reason: '$slug has no services');
        for (final s in services) {
          expect(s.rateUnit, 'job',
              reason: 'nobody books "two hours of haircut" — ${s.name}');
        }
      }
    });

    test('search finds them by what a customer would actually type', () async {
      final catalogue = await CatalogueSearch.load();

      void findsTrade(String query, String slug) {
        final hits = catalogue.query(query);
        expect(hits.map((h) => h.trade.slug), contains(slug),
            reason: '"$query" did not reach $slug');
      }

      findsTrade('haircut', 'hairdresser');
      findsTrade('barber', 'hairdresser');
      findsTrade('nails', 'beauty');
      findsTrade('wax', 'beauty');
      findsTrade('deep tissue', 'massage');
      findsTrade('masseuse', 'massage');
    });
  });

  group('local licensing', () {
    // The London Local Authorities Act 1991 licenses massage by borough.
    // Birmingham does not. The same paperwork therefore produces a different
    // answer in each city, and that is the behaviour being asserted.
    test('an unlicensed massage therapist is hidden in London', () async {
      final found = await nearby('massage', wandsworth);
      expect(found, isNot(contains('Yuki Tanaka')),
          reason: 'Yuki holds no borough licence and must not be bookable '
              'in London');
      expect(found, isNotEmpty,
          reason: 'hiding her must not empty the category');
    });

    test('an unlicensed beauty therapist is hidden in London', () async {
      final found = await nearby('beauty', clapham);
      expect(found, isNot(contains('Leah Okafor')));
      expect(found, isNotEmpty);
    });

    test('the same gap does not hide a Birmingham therapist', () async {
      // Tomasz holds exactly what Yuki holds. He is bookable because his
      // council does not license massage — without this the London result
      // above would be indistinguishable from a bug.
      final found = await nearby('massage', birmingham);
      expect(found, contains('Tomasz Lewandowski'),
          reason: 'Birmingham does not licence massage, so the licence must '
              'not be demanded there');
    });

    test('a licensed London therapist is bookable', () async {
      expect(await nearby('massage', wandsworth), isNotEmpty);
      expect(await nearby('beauty', clapham), isNotEmpty);
    });
  });

  group('coverage', () {
    test('no live area shows an empty list for the new trades', () async {
      final areas = await supabase
          .from('service_areas')
          .select('name, city, lat, lng')
          .eq('is_live', true);

      final empty = <String>[];
      for (final a in areas) {
        for (final slug in ['hairdresser', 'beauty', 'massage']) {
          final found = await nearby(
            slug,
            (lat: (a['lat'] as num).toDouble(), lng: (a['lng'] as num).toDouble()),
          );
          if (found.isEmpty) empty.add('$slug in ${a['name']}');
        }
      }

      // A brand new category that returns nothing on its first search is
      // worse than one that was never launched.
      expect(empty, isEmpty, reason: 'nobody available for: ${empty.join(', ')}');
    });
  });

  group('credentials', () {
    test('the compliance detail of a therapist is not public', () async {
      await expectLater(
        supabase.rpc('provider_is_compliant',
            params: {'p_provider': '00000000-0000-0000-0000-000000000000'}),
        throwsA(isA<PostgrestException>()),
        reason: 'a signed-out caller must not be able to probe compliance',
      );
    });

    test('the city a provider works in is not public either', () async {
      await expectLater(
        supabase.rpc('provider_city',
            params: {'p_provider': '00000000-0000-0000-0000-000000000000'}),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
