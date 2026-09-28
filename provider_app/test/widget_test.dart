@Timeout(Duration(minutes: 3))
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaari_provider/data.dart';

void main() {

  group('ProviderStanding', () {
    ProviderStanding make({
      String status = 'approved',
      bool online = true,
      bool compliant = true,
      List<String> missing = const [],
      int? daysToExpiry,
    }) =>
        ProviderStanding.fromMap({
          'provider_id': 'p1',
          'full_name': 'Test Provider',
          'trade': 'Electrician',
          'status': status,
          'is_online': online,
          'is_compliant': compliant,
          'missing_docs': missing,
          'days_to_next_expiry': daysToExpiry,
          'jobs_completed': 3,
          'rating_avg': 4.5,
        });

    test('online alone does not make someone bookable', () {
      expect(make(compliant: false).canWork, isFalse);
      expect(make(status: 'suspended').canWork, isFalse);
      expect(make(online: false).canWork, isFalse);
      expect(make().canWork, isTrue);
    });

    test('expiry warning only applies while still compliant', () {
      expect(make(daysToExpiry: 12).expiringSoon, isTrue);
      expect(make(daysToExpiry: 120).expiringSoon, isFalse);
      expect(make(compliant: false, daysToExpiry: 5).expiringSoon, isFalse);
    });

    test('missing docs parse from a Postgres array literal', () {
      final s = ProviderStanding.fromMap({
        'provider_id': 'p1',
        'full_name': 'T',
        'trade': 'Electrician',
        'status': 'approved',
        'is_online': true,
        'is_compliant': false,
        'missing_docs': '{public_liability_insurance,part_p}',
        'days_to_next_expiry': null,
        'jobs_completed': 0,
        'rating_avg': null,
      });
      expect(s.missingDocs, ['public_liability_insurance', 'part_p']);
      expect(docLabels[s.missingDocs.first], 'Public liability insurance');
    });
  });

  group('live backend', () {
    setUpAll(() {
      HttpOverrides.global = null;
      useTestClient(SupabaseClient(Config.supabaseUrl, Config.supabaseKey));
    });

    _applicationTests();

    test('a provider cannot read another provider documents', () async {
      // RLS hides every document from an anonymous caller.
      final rows = await supabase.from('provider_documents').select('id');
      expect(rows, isEmpty);
    });
  });
}

/// Joining. The provider app ships before the customer app, to strangers at a
/// jobs expo, so these paths are the ones that decide whether the launch works
/// at all.
void _applicationTests() {
  group('applying', () {
    test('a signed-out stranger cannot create a provider profile', () async {
      await expectLater(
        supabase.rpc('apply_as_provider', params: {
          'p_full_name': 'Nobody',
          'p_trade_slugs': ['plumber'],
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'applying writes a profile, so it must require a session',
      );
    });

    test('a signed-out caller cannot read anyone\'s application', () async {
      await expectLater(
        supabase.rpc('my_application'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('required documents are city-aware', () async {
      final london = await supabase.rpc('required_docs_for_trade',
          params: {'p_trade_slug': 'massage', 'p_city': 'London'});
      final brum = await supabase.rpc('required_docs_for_trade',
          params: {'p_trade_slug': 'massage', 'p_city': 'Birmingham'});

      final londonDocs =
          (london as List).map((r) => r['doc_type'] as String).toList();
      final brumDocs =
          (brum as List).map((r) => r['doc_type'] as String).toList();

      // The London Local Authorities Act 1991 licences massage; Birmingham
      // does not. An applicant must be told the truth for where they work.
      expect(londonDocs, contains('special_treatment_licence'));
      expect(brumDocs, isNot(contains('special_treatment_licence')));
      expect(brumDocs, contains('treatment_insurance'),
          reason: 'treatment cover is national, not local');
    });

    test('a trade we do not cover is refused', () async {
      final rows = await supabase.rpc('required_docs_for_trade',
          params: {'p_trade_slug': 'astronaut', 'p_city': null});
      expect(rows, isEmpty);
    });
  });

  group('multi-trade compliance', () {
    test('discovery checks credentials for the trade being booked', () async {
      // Yuki Tanaka holds everything except the London borough licence, so
      // she must not appear for massage in London.
      final list = await supabase.rpc('nearby_providers', params: {
        'p_trade_slug': 'massage',
        'p_lng': -0.1914,
        'p_lat': 51.4515,
        'p_radius_m': 12000,
      });
      final names =
          (list as List).map((r) => r['full_name'] as String).toList();
      expect(names, isNot(contains('Yuki Tanaka')),
          reason: 'missing borough licence must hide her in London');
    });

    test('every provider offers at least one trade', () async {
      final rows = await supabase
          .from('provider_trades')
          .select('provider_id')
          .limit(1);
      expect(rows, isNotEmpty,
          reason: 'the backfill from provider_profiles.trade_id should have '
              'given everyone at least their original trade');
    });
  });
}
