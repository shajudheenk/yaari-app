import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend configuration. The publishable key is safe in a client: row
/// level security is what actually protects the data.
class Config {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://capnsntuwdhxrxjfhrgr.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_1_b1CO2K62CW8MfW_r-a5A_QY2mUYNU',
  );
}

SupabaseClient? _testClient;
SupabaseClient get supabase => _testClient ?? Supabase.instance.client;

@visibleForTesting
void useTestClient(SupabaseClient client) => _testClient = client;

/// What a provider is allowed to do right now.
///
/// `canWork` is not a local calculation — it is the same server-side check
/// that decides whether this person appears in a customer's search. The app
/// only reports it.
class ProviderStanding {
  ProviderStanding({
    required this.userId,
    required this.name,
    required this.trade,
    required this.status,
    required this.isOnline,
    required this.isCompliant,
    required this.missingDocs,
    required this.daysToNextExpiry,
    required this.jobsCompleted,
    required this.ratingAvg,
  });

  final String userId;
  final String name;
  final String? trade;
  final String status;
  final bool isOnline;
  final bool isCompliant;
  final List<String> missingDocs;
  final int? daysToNextExpiry;
  final int jobsCompleted;
  final double? ratingAvg;

  bool get isApproved => status == 'approved';

  /// Online alone is not enough. Approval and live credentials both count.
  bool get canWork => isApproved && isOnline && isCompliant;

  /// Compliant today, but something lapses soon.
  bool get expiringSoon =>
      isCompliant && daysToNextExpiry != null && daysToNextExpiry! <= 30;

  factory ProviderStanding.fromMap(Map<String, dynamic> m) => ProviderStanding(
        userId: m['provider_id'] as String,
        name: (m['full_name'] as String?) ?? 'Provider',
        trade: m['trade'] as String?,
        status: m['status'] as String,
        isOnline: m['is_online'] as bool,
        isCompliant: (m['is_compliant'] as bool?) ?? false,
        missingDocs: _asList(m['missing_docs']),
        daysToNextExpiry: (m['days_to_next_expiry'] as num?)?.toInt(),
        jobsCompleted: (m['jobs_completed'] as int?) ?? 0,
        ratingAvg: (m['rating_avg'] as num?)?.toDouble(),
      );

  static List<String> _asList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) {
      final inner = v.replaceAll(RegExp(r'^\{|\}$'), '').trim();
      if (inner.isEmpty) return const [];
      return inner.split(',').map((s) => s.trim()).toList();
    }
    return const [];
  }
}

const docLabels = <String, String>{
  'photo_id': 'Photo ID',
  'right_to_work': 'Right to work',
  'public_liability_insurance': 'Public liability insurance',
  'gas_safe': 'Gas Safe registration',
  'part_p': 'Part P',
  'dbs_basic': 'Basic DBS',
  'trade_qualification': 'Trade qualification',
  // Added with the pet-care trade. A standard public liability policy excludes
  // care, custody and control of animals, so a walker needs cover of its own.
  'pet_care_cover': 'Pet care insurance',
  'treatment_insurance': 'Treatment insurance',
  'special_treatment_licence': 'Special treatment licence',
  // Care, childcare, security, driving, food and events.
  'dbs_enhanced_adult': 'Enhanced DBS (adults)',
  'dbs_enhanced_child': 'Enhanced DBS (children)',
  'care_certificate': 'Care Certificate',
  'first_aid': 'First aid certificate',
  'paediatric_first_aid': 'Paediatric first aid',
  'sia_licence': 'SIA licence',
  'driving_licence': 'Driving licence',
  'private_hire_licence': 'Private hire licence',
  'motor_insurance_hire_reward': 'Hire & reward insurance',
  'food_hygiene_l2': 'Food hygiene Level 2',
  'pat_certificate': 'PAT test certificate',
  'ofsted_registration': 'Ofsted registration',
};

class ProviderApi {
  /// The provider's own standing. RLS restricts this view to their row.
  static Future<ProviderStanding?> myStanding(String providerId) async {
    final rows = await supabase
        .from('provider_compliance_board')
        .select('*')
        .eq('provider_id', providerId)
        .limit(1);
    if (rows.isEmpty) return null;
    return ProviderStanding.fromMap(rows.first);
  }

  /// Toggling online is permitted whatever the credential state — the
  /// server decides separately whether that results in any work. Telling
  /// someone they may not even flip a switch would be needlessly punitive.
  static Future<void> setOnline(String providerId, bool online) async {
    await supabase
        .from('provider_profiles')
        .update({'is_online': online})
        .eq('user_id', providerId);
  }

  static Future<List<Map<String, dynamic>>> myDocuments(String providerId) async {
    final rows = await supabase
        .from('provider_documents')
        .select('id, doc_type, reference, expires_on, status')
        .eq('provider_id', providerId)
        .order('expires_on', nullsFirst: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
