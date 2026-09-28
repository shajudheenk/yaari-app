@Tags(['live'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_customer/config.dart';
import 'package:yaari_customer/data.dart';
import 'package:yaari_customer/account_api.dart';
import 'package:yaari_customer/plan.dart';

/// Repeat plans — the arithmetic in the app has to agree with the arithmetic
/// in the database, and a signed-out caller must not be able to create one.
void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    useTestClient(SupabaseClient(Config.supabaseUrl, Config.supabaseKey));
  });

  group('plan pricing', () {
    test('the app discounts a rate exactly as the database does', () {
      // 2500 * 0.85 = 2125, the figure create_plan stored when this was
      // exercised against the live project.
      expect(PlanApi.planRate(2500, 1500), 2125);
      expect(PlanApi.planRate(3500, 1500), 2975);

      // No discount configured means the plan costs the same as a one-off,
      // which must not silently become free.
      expect(PlanApi.planRate(4500, 0), 4500);
    });

    test('rounding never produces a free visit', () {
      expect(PlanApi.planRate(1, 5000), 1);
      expect(PlanApi.planRate(3, 5000), 2);
    });

    test('the discount is read from the database, not hardcoded', () async {
      final bps = await PlanApi.discountBps();
      expect(bps, greaterThanOrEqualTo(0));
      expect(bps, lessThanOrEqualTo(5000),
          reason: 'a discount above 50% is almost certainly a typo');
    });
  });

  group('frequencies', () {
    test('every frequency has a wire value the database accepts', () {
      expect(
        PlanFrequency.values.map((f) => f.wire),
        containsAll(<String>['weekly', 'fortnightly', 'every_4_weeks']),
      );
    });

    test('wire values round-trip', () {
      for (final f in PlanFrequency.values) {
        expect(PlanFrequencyX.fromWire(f.wire), f);
      }
    });

    test('every frequency has something to show the customer', () {
      for (final f in PlanFrequency.values) {
        expect(f.label, isNotEmpty);
        expect(f.blurb, isNotEmpty);
      }
    });
  });

  group('signed out', () {
    test('cannot create a plan', () async {
      await expectLater(
        PlanApi.create(
          serviceId: '00000000-0000-0000-0000-000000000000',
          addressId: '00000000-0000-0000-0000-000000000000',
          frequency: PlanFrequency.weekly,
          firstAt: DateTime.now().add(const Duration(days: 3)),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('cannot pause or end someone else\'s plan', () async {
      await expectLater(
        PlanApi.pause('00000000-0000-0000-0000-000000000000'),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        PlanApi.end('00000000-0000-0000-0000-000000000000'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('cannot read anybody\'s plans', () async {
      // Row level security is the guard, not an empty table: this must stay
      // empty even once real customers have plans.
      final rows = await supabase.from('booking_plans').select('id');
      expect(rows, isEmpty);
    });
  });

  _deletionTests();

  group('catalogue prices', () {
    test('every trade on the grid carries a from-price', () async {
      final trades = await Api.trades();
      expect(trades, isNotEmpty);

      for (final t in trades) {
        expect(t.fromPence, isNotNull,
            reason: '${t.slug} has no published price, so its tile is silent');
        expect(t.fromPence, greaterThan(0));
        // Units the price bar knows how to render. A unit added to the
        // database without a matching label here prints a bare number.
        expect(t.fromUnit,
            anyOf('hour', 'job', 'room', 'day', 'visit', 'week'),
            reason: '${t.slug} is priced in a unit the app cannot label');
        expect(t.fromLabel, startsWith('from £'));
      }
    });

    test('the from-price is the cheapest live service in the trade', () async {
      final trades = await Api.trades();
      for (final t in trades.take(4)) {
        final services = await Api.servicesFor(t.id);
        expect(services, isNotEmpty);
        final cheapest =
            services.map((s) => s.ratePence).reduce((a, b) => a < b ? a : b);
        expect(t.fromPence, cheapest,
            reason: '${t.slug} advertises a price it does not sell');
      }
    });
  });
}

/// Account closure — required by both stores before they will publish, and a
/// destructive path that must never run for the wrong caller.
void _deletionTests() {
  group('closing an account', () {
    test('a signed-out caller cannot delete anything', () async {
      await expectLater(
        supabase.rpc('delete_my_account', params: {'p_reason': 'test'}),
        throwsA(isA<PostgrestException>()),
        reason: 'erasure must require a session — it deletes real data',
      );
    });

    test('the open-booking refusal is explained in plain English', () {
      expect(
        AccountApi.explain(Exception(
            'finish or cancel your 1 open booking(s) first')),
        contains('still running'),
      );
      expect(
        AccountApi.explain(Exception(
            'finish or cancel your 3 open booking(s) first')),
        contains('3 bookings'),
      );
      // Anything unrecognised must still say something useful rather than
      // leaking a Postgres error at a customer.
      expect(AccountApi.explain(Exception('boom')), contains('try again'));
    });
  });
}
