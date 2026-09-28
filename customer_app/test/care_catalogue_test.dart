@Tags(['live'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_customer/config.dart';
import 'package:yaari_customer/data.dart';
import 'package:yaari_ui/yaari_ui.dart';

/// Care, childcare, security, cooking, household help, driving, DJing and
/// personal shopping — and the credential rules underneath them.
///
/// These eight are a different order of risk from a leaking tap. Three put a
/// worker alone with someone vulnerable, one is a criminal offence to perform
/// unlicensed, and one carries passengers for hire. So the tests that matter
/// here are not "does the tile render" but "does the gate know that a basic
/// DBS is not enough to sit with somebody's mother".
void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    useTestClient(SupabaseClient(Config.supabaseUrl, Config.supabaseKey));
  });

  Future<Set<String>> requiredDocs(String trade, {String? city}) async {
    final rows = await supabase.rpc('required_docs_for_trade',
        params: {'p_trade_slug': trade, 'p_city': city});
    return (rows as List)
        .map<String>((r) => (r as Map)['doc_type'] as String)
        .toSet();
  }

  group('the catalogue', () {
    test('every new trade is live and priced', () async {
      final trades = await Api.trades();
      final bySlug = {for (final t in trades) t.slug: t};

      const added = [
        'care', 'childcare', 'security', 'cook',
        'maid', 'driver', 'dj', 'personal-shopper',
      ];

      for (final slug in added) {
        final t = bySlug[slug];
        expect(t, isNotNull, reason: '$slug is not being served');
        expect(t!.fromPence, isNotNull,
            reason: '$slug has no from-price, so its tile is silent');
        expect(t.fromPence, greaterThan(0));

        final services = await Api.servicesFor(t.id);
        expect(services, isNotEmpty, reason: '$slug has nothing to book');
        for (final s in services) {
          expect(s.ratePence, greaterThan(0),
              reason: '${s.name} is free, which it is not');
          expect(s.description, isNotNull,
              reason: '${s.name} has no description');
        }
      }
    });

    test('a trade never advertises less than it charges', () async {
      // The tile says "from £X". If any service costs less than X the price
      // is a lie in the customer's favour, which is still a lie.
      final trades = await Api.trades();
      for (final t in trades) {
        final services = await Api.servicesFor(t.id);
        if (services.isEmpty) continue;
        final cheapest =
            services.map((s) => s.ratePence).reduce((a, b) => a < b ? a : b);
        expect(t.fromPence, lessThanOrEqualTo(cheapest),
            reason: '${t.slug} advertises from ${t.fromPence} but its '
                'cheapest service is $cheapest');
      }
    });
  });

  group('credential rules', () {
    test('care needs an enhanced DBS on the adult barred list', () async {
      final docs = await requiredDocs('care');
      expect(docs, contains('dbs_enhanced_adult'),
          reason: 'sitting with a vulnerable adult on a basic DBS');
      expect(docs, contains('care_certificate'));
      expect(docs, contains('first_aid'));
      expect(docs, isNot(contains('dbs_basic')),
          reason: 'a basic DBS must not stand in for the enhanced one');
    });

    test('childcare needs an enhanced DBS on the children\'s barred list',
        () async {
      final docs = await requiredDocs('childcare');
      expect(docs, contains('dbs_enhanced_child'));
      expect(docs, contains('paediatric_first_aid'),
          reason: 'general first aid is not paediatric first aid');
      expect(docs, isNot(contains('dbs_basic')));
    });

    test('security cannot be worked without an SIA licence', () async {
      // Not a policy choice: working front-line security unlicensed is an
      // offence under the Private Security Industry Act 2001.
      final docs = await requiredDocs('security');
      expect(docs, contains('sia_licence'));
    });

    test('a driver needs a licence, hire-and-reward cover and a PHV badge',
        () async {
      final docs = await requiredDocs('driver');
      expect(docs, contains('driving_licence'));
      expect(docs, contains('motor_insurance_hire_reward'),
          reason: 'an ordinary social and domestic policy does not cover '
              'carrying passengers for money');
      expect(docs, contains('private_hire_licence'));
    });

    test('a cook needs food hygiene', () async {
      expect(await requiredDocs('cook'), contains('food_hygiene_l2'));
    });

    test('a DJ needs their equipment PAT tested', () async {
      expect(await requiredDocs('dj'), contains('pat_certificate'));
    });

    test('every new trade requires identity and right to work', () async {
      for (final slug in ['care', 'childcare', 'security', 'cook', 'maid',
        'driver', 'dj', 'personal-shopper']) {
        final docs = await requiredDocs(slug);
        expect(docs, contains('photo_id'), reason: '$slug skips identity');
        expect(docs, contains('right_to_work'),
            reason: '$slug skips right to work');
      }
    });

    test('an optional badge is not a barrier to working', () async {
      // Ofsted registration is voluntary for a sitter working in the child's
      // own home. Listing it as mandatory would lock out lawful sitters.
      final mandatory = await requiredDocs('childcare');
      expect(mandatory, isNot(contains('ofsted_registration')));
    });
  });

  group('the compliance gate covers the new trades', () {
    test('nobody is bookable for care without the care credentials', () async {
      // Nothing has been verified against the new document types yet, so the
      // correct answer today is an empty list. A name appearing here would
      // mean the gate is not reading the new rules.
      final rows = await supabase.rpc('nearby_providers', params: {
        'p_trade_slug': 'care',
        'p_lng': -1.9385,
        'p_lat': 52.4409,
        'p_radius_m': 20000,
      });
      expect(rows, isEmpty,
          reason: 'someone is being offered care work without an enhanced '
              'DBS, a care certificate or first aid');
    });

    test('the gate still lets compliant trades through', () async {
      // The control. If this is also empty the test above proves nothing.
      final rows = await supabase.rpc('nearby_providers', params: {
        'p_trade_slug': 'cleaner',
        'p_lng': -1.9385,
        'p_lat': 52.4409,
        'p_radius_m': 20000,
      });
      expect(rows, isNotEmpty,
          reason: 'no compliant cleaner in Birmingham — the care result '
              'above cannot be read as the gate working');
    });
  });

  group('pricing by size and by room', () {
    Future<int> quote(String serviceId, String? optionId, int qty) async {
      final rows = await supabase.rpc('quote_service', params: {
        'p_service': serviceId,
        'p_option': optionId,
        'p_qty': qty,
      });
      return ((rows as List).first as Map)['price_pence'] as int;
    }

    late String cleanerId;
    setUpAll(() async {
      final trades = await Api.trades();
      cleanerId = trades.firstWhere((t) => t.slug == 'cleaner').id;
    });

    test('a regular clean is sold by the size of the place', () async {
      final services = await Api.servicesFor(cleanerId);
      final regular = services.firstWhere((s) => s.name.contains('Regular'));
      final options = await Api.optionsFor(regular.id);

      expect(options, isNotEmpty);
      expect(options.map((o) => o.label), contains('Studio'));
      expect(options.map((o) => o.label), contains('3 bedrooms'));

      // Bigger place, bigger price — in order, with no ties.
      final sizes = options.where((o) => !o.isCountable).toList();
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i].ratePence, greaterThan(sizes[i - 1].ratePence),
            reason: '${sizes[i].label} is not dearer than ${sizes[i - 1].label}');
      }
    });

    test('a by-the-room clean multiplies by the count', () async {
      final services = await Api.servicesFor(cleanerId);
      final byRoom = services.firstWhere((s) => s.name.contains('by the room'));
      final options = await Api.optionsFor(byRoom.id);

      final bathroom = options.firstWhere((o) => o.label == 'Bathrooms');
      expect(bathroom.isCountable, isTrue);
      expect(bathroom.maxQty, greaterThan(1));

      expect(await quote(byRoom.id, bathroom.id, 3), bathroom.ratePence * 3);
      expect(bathroom.priceFor(3), bathroom.ratePence * 3,
          reason: 'the app and the server disagree about the price');
    });

    test('the server refuses a quantity outside the option range', () async {
      final services = await Api.servicesFor(cleanerId);
      final byRoom = services.firstWhere((s) => s.name.contains('by the room'));
      final bathroom = (await Api.optionsFor(byRoom.id))
          .firstWhere((o) => o.label == 'Bathrooms');

      await expectLater(
        quote(byRoom.id, bathroom.id, bathroom.maxQty + 5),
        throwsA(isA<PostgrestException>()),
        reason: 'a tampered quantity must not price the job',
      );
    });

    test('an option cannot be borrowed from another service', () async {
      final services = await Api.servicesFor(cleanerId);
      final regular = services.firstWhere((s) => s.name.contains('Regular'));
      final deep = services.firstWhere((s) => s.name.contains('Deep'));
      final deepOption = (await Api.optionsFor(deep.id)).first;

      await expectLater(
        quote(regular.id, deepOption.id, 1),
        throwsA(isA<PostgrestException>()),
        reason: 'a cheap option from one service must not price another',
      );
    });

    test('a service with no options still quotes its own price', () async {
      final trades = await Api.trades();
      final care = trades.firstWhere((t) => t.slug == 'care');
      final visit = (await Api.servicesFor(care.id)).first;

      expect(await Api.optionsFor(visit.id), isEmpty);
      expect(await quote(visit.id, null, 1), visit.ratePence);
    });
  });

  group('gold, silver and bronze', () {
    test('the map never carries a home coordinate', () async {
      final rows = await supabase.rpc('map_providers', params: {
        'p_trade_slug': 'hairdresser',
        'p_lng': -1.9385,
        'p_lat': 52.4409,
        'p_radius_m': 20000,
      }) as List;
      expect(rows, isNotEmpty, reason: 'no hairdressers to test against');
      for (final r in rows.cast<Map>()) {
        expect(r.containsKey('home_point'), isFalse);
        expect(r['metres'] % 250, 0,
            reason: 'a precise distance can be crossed with the pin square '
                'to narrow a home back down');
        expect(['gold', 'silver', 'bronze'], contains(r['tier']));
      }
    });

    test('the app prices a tier exactly as the server charges it', () async {
      // The screen shows tierPrice(); create_booking charges quote_service().
      // If these ever differ by a penny the customer was shown one price and
      // charged another.
      final pros = await Api.mapProviders('hairdresser',
          lat: 52.4409, lng: -1.9385, radiusM: 20000);
      final trades = await Api.trades();
      final hair = trades.firstWhere((t) => t.slug == 'hairdresser');
      final services = await Api.servicesFor(hair.id);

      for (final pro in pros) {
        for (final s in services) {
          final rows = await supabase.rpc('quote_service', params: {
            'p_service': s.id,
            'p_option': null,
            'p_qty': 1,
            'p_provider': pro.userId,
          });
          final server = ((rows as List).first as Map)['price_pence'] as int;
          expect(pro.priceFor(s.ratePence), server,
              reason: '${pro.tier} ${s.name}: app shows '
                  '${pro.priceFor(s.ratePence)}, server charges $server');
        }
      }
    });

    test('odd totals round the same way on both sides', () {
      // 3 bathrooms at £26 for a Silver pro: 7800 x 1.1 = 8580, which sits
      // between two 50p steps. Both sides must land on 8600.
      expect(tierPrice(7800, 1000), 8600);
      expect(tierPrice(8500, 2000), 10200);
      expect(tierPrice(4500, 0), 4500);
    });
  });
}
