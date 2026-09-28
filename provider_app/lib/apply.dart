import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';

/// Joining Yaari.
///
/// The provider app launches before the customer app, to strangers at a jobs
/// expo. Everything here exists so that somebody who has never heard of us
/// can go from scanning a QR code to a submitted application in about a
/// minute and a half, and then know exactly what to send us next.

/// Where an applicant came from.
///
/// Carried because marketing spend across buses, leaflets and expo stands is
/// only worth anything if you can tell which of them produced somebody who
/// completed a job.
enum SignupSource { expo, busAd, leaflet, wordOfMouth, social, search, other }

extension SignupSourceX on SignupSource {
  String get wire => switch (this) {
        SignupSource.expo => 'expo',
        SignupSource.busAd => 'bus_ad',
        SignupSource.leaflet => 'leaflet',
        SignupSource.wordOfMouth => 'word_of_mouth',
        SignupSource.social => 'social',
        SignupSource.search => 'search',
        SignupSource.other => 'other',
      };

  String get label => switch (this) {
        SignupSource.expo => 'At a jobs fair',
        SignupSource.busAd => 'Saw it on a bus',
        SignupSource.leaflet => 'Picked up a leaflet',
        SignupSource.wordOfMouth => 'A friend told me',
        SignupSource.social => 'Social media',
        SignupSource.search => 'Searched online',
        SignupSource.other => 'Somewhere else',
      };
}

/// Where one credential stands.
///
/// Four states the applicant has to be able to tell apart, because each needs
/// a different thing from them: send it, wait, re-send it, or nothing.
enum DocState { missing, pending, verified, rejected, expired }

DocState _docState(String? s) => switch (s) {
      'pending' => DocState.pending,
      'verified' => DocState.verified,
      'rejected' => DocState.rejected,
      'expired' => DocState.expired,
      _ => DocState.missing,
    };

/// One credential an applicant needs, and where it stands.
class RequiredDoc {
  const RequiredDoc({
    required this.tradeSlug,
    required this.tradeName,
    required this.docType,
    required this.note,
    required this.held,
    required this.expiresOn,
    this.state = DocState.missing,
    this.rejectionReason,
    this.isMandatory = true,
  });

  final String tradeSlug;
  final String tradeName;
  final String docType;
  final String? note;
  final bool held;
  final DateTime? expiresOn;
  final DocState state;
  final String? rejectionReason;
  final bool isMandatory;

  String get label => docLabels[docType] ?? docType;

  /// Needs the applicant to do something: never sent, turned down, or lapsed.
  bool get needsAction =>
      state == DocState.missing ||
      state == DocState.rejected ||
      state == DocState.expired;
}

/// How someone works with us. Everyone on Yaari is self-employed and
/// contracts with the customer directly — this records on what basis.
enum LegalStatus { soleTrader, limitedCompany }

extension LegalStatusX on LegalStatus {
  String get wire => switch (this) {
        LegalStatus.soleTrader => 'sole_trader',
        LegalStatus.limitedCompany => 'limited_company',
      };
  String get label => switch (this) {
        LegalStatus.soleTrader => 'Sole trader',
        LegalStatus.limitedCompany => 'Limited company',
      };
}

/// An application in progress, with everything still outstanding.
class Application {
  const Application({
    required this.status,
    required this.headlineTrade,
    required this.workArea,
    required this.docs,
    this.legalStatus,
    this.hasUtr = false,
    this.companyNumber,
  });

  final String status;
  final String headlineTrade;
  final String? workArea;
  final List<RequiredDoc> docs;
  final String? legalStatus;
  final bool hasUtr;
  final String? companyNumber;

  /// Sole traders can apply before HMRC issues their UTR, but cannot be paid
  /// without one. Shown on the checklist rather than blocking the application.
  bool get needsUtr => legalStatus == 'sole_trader' && !hasUtr;

  /// Mandatory credentials, once each. Two trades both needing public
  /// liability ask for it once.
  List<RequiredDoc> get _mandatoryDistinct {
    final seen = <String>{};
    return docs.where((d) => d.isMandatory && seen.add(d.docType)).toList();
  }

  /// Still waiting on the applicant.
  List<RequiredDoc> get toSend =>
      _mandatoryDistinct.where((d) => d.needsAction).toList();

  /// With us, being checked.
  List<RequiredDoc> get withUs =>
      _mandatoryDistinct.where((d) => d.state == DocState.pending).toList();

  /// Every credential this trade needs, mandatory first, for the per-trade
  /// view of the checklist.
  List<RequiredDoc> docsFor(String tradeSlug) =>
      docs.where((d) => d.tradeSlug == tradeSlug).toList();

  /// Whether a trade is fully cleared — the moment it becomes bookable.
  bool clearedFor(String tradeSlug) =>
      docsFor(tradeSlug).where((d) => d.isMandatory).every((d) => d.held);

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'applied' || status == 'in_review';

  /// Distinct credentials still owed. Distinct because two trades can both
  /// need public liability and it should be asked for once.
  List<RequiredDoc> get outstanding =>
      _mandatoryDistinct.where((d) => !d.held).toList();

  List<RequiredDoc> get verified =>
      _mandatoryDistinct.where((d) => d.held).toList();

  int get total => outstanding.length + verified.length;

  double get progress => total == 0 ? 0 : verified.length / total;

  /// The trades applied for, in the order they were chosen.
  List<({String slug, String name})> get trades {
    final seen = <String>{};
    return docs
        .where((d) => seen.add(d.tradeSlug))
        .map((d) => (slug: d.tradeSlug, name: d.tradeName))
        .toList();
  }
}

/// Sending a credential in.
///
/// The provider uploads the file and states what it is; they can never state
/// that it is valid. Verification is an operator checking it against the
/// issuing register — a Gas Safe card is trivially forged, the Gas Safe
/// Register is free and definitive.
class DocsApi {
  static const bucket = 'provider-docs';

  /// Returns the storage path written, so the caller can show a preview.
  static Future<String> submit({
    required String docType,
    required Uint8List bytes,
    required String extension,
    String? reference,
    DateTime? expiresOn,
  }) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) throw StateError('not signed in');

    // Foldered by owner because the storage policy keys off the first path
    // segment. Timestamped so a replacement never collides with a cached
    // copy of the old one.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$me/${docType}_$stamp.$extension';

    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
            upsert: true,
          ),
        );

    // Deliberately does not send `status`. The database forces 'pending' and
    // a trigger rejects anything else from a non-admin.
    final existing = await supabase
        .from('provider_documents')
        .select('id, status')
        .eq('provider_id', me)
        .eq('doc_type', docType)
        .limit(1);

    final row = {
      'provider_id': me,
      'doc_type': docType,
      'reference': reference?.trim().isEmpty ?? true ? null : reference!.trim(),
      'expires_on': expiresOn?.toIso8601String().substring(0, 10),
      'storage_path': path,
    };

    if (existing.isNotEmpty && existing.first['status'] == 'pending') {
      // Still unreviewed, so replace it rather than leaving two.
      await supabase
          .from('provider_documents')
          .update(row)
          .eq('id', existing.first['id'] as String);
    } else {
      await supabase.from('provider_documents').insert(row);
    }

    return path;
  }

  /// A short-lived link. The bucket is private: there is no permanent URL
  /// that could be forwarded to somebody who should not see a passport.
  static Future<String?> previewUrl(String path) async {
    try {
      return await supabase.storage.from(bucket).createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  static String explain(Object e) {
    final s = e.toString();
    if (s.contains('not marked verified')) {
      return 'Documents are checked by us before they count. Yours has been '
          'sent for checking.';
    }
    if (s.contains('Payload too large') || s.contains('413')) {
      return 'That file is too big. Try a photo rather than a scan.';
    }
    if (s.contains('mime') || s.contains('415')) {
      return 'Send a photo or a PDF.';
    }
    return 'That upload did not go through. Please try again.';
  }
}

class ApplyApi {
  /// Submits, or re-submits while still undecided. The first trade in the
  /// list becomes the headline shown under their name.
  static Future<void> apply({
    required String fullName,
    required List<String> tradeSlugs,
    String? workArea,
    double? lat,
    double? lng,
    SignupSource? source,
    String? sourceDetail,
    String? referredBy,
    required LegalStatus legalStatus,
    String? utr,
    String? companyNumber,
  }) async {
    await supabase.rpc('apply_as_provider', params: {
      'p_full_name': fullName,
      'p_trade_slugs': tradeSlugs,
      'p_work_area': workArea,
      'p_lat': lat,
      'p_lng': lng,
      'p_source': source?.wire,
      'p_source_detail': sourceDetail,
      'p_referred_by': referredBy,
      'p_legal_status': legalStatus.wire,
      'p_utr': utr,
      'p_company_number': companyNumber,
    });
  }

  /// Null when this person has not applied yet, which is what routes a new
  /// arrival into the application flow rather than the app proper.
  static Future<Application?> mine() async {
    final rows = await supabase.rpc('my_application');
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return null;

    final head = list.first;
    return Application(
      status: head['status'] as String,
      headlineTrade: head['headline_trade'] as String,
      workArea: head['work_area'] as String?,
      legalStatus: head['legal_status'] as String?,
      hasUtr: (head['has_utr'] as bool?) ?? false,
      companyNumber: head['company_number'] as String?,
      docs: list
          .map((r) => RequiredDoc(
                tradeSlug: r['trade_slug'] as String,
                tradeName: r['trade_name'] as String,
                docType: r['doc_type'] as String,
                note: r['note'] as String?,
                held: (r['held'] as bool?) ?? false,
                expiresOn: r['expires_on'] == null
                    ? null
                    : DateTime.parse(r['expires_on'] as String),
                state: _docState(r['doc_status'] as String?),
                rejectionReason: r['rejection_reason'] as String?,
                isMandatory: (r['is_mandatory'] as bool?) ?? true,
              ))
          .toList(),
    );
  }

  /// Database refusals, said the way a person would say them.
  static String explain(Object e) {
    final s = e.toString();
    if (s.contains('already been decided')) {
      return 'Your application has already been reviewed. Get in touch if '
          'something needs changing.';
    }
    if (s.contains('at least one trade')) return 'Choose at least one trade.';
    if (s.contains('not one we cover')) {
      return 'One of those trades is not something we cover yet.';
    }
    if (s.contains('tell us your name')) return 'We need your name.';
    if (s.contains('sole trader or limited company')) {
      return 'Tell us whether you work as a sole trader or a limited company.';
    }
    if (s.contains('UTR is 10 digits')) {
      return 'A UTR is 10 digits. You will find it on letters from HMRC.';
    }
    if (s.contains('company number')) {
      return 'A company number is 8 characters, like 12345678 or SC123456.';
    }
    return 'That did not go through. Please try again.';
  }
}

/// Trades offered, for the picker. Read live so a trade added to the
/// catalogue appears without an app release.
class TradeOption {
  const TradeOption({required this.slug, required this.name, required this.blurb});

  final String slug;
  final String name;
  final String? blurb;

  static Future<List<TradeOption>> all() async {
    final rows = await supabase
        .from('trades')
        .select('slug, name, blurb')
        .eq('is_active', true)
        .order('sort_order');
    return rows
        .map<TradeOption>((r) => TradeOption(
              slug: r['slug'] as String,
              name: r['name'] as String,
              blurb: r['blurb'] as String?,
            ))
        .toList();
  }
}
