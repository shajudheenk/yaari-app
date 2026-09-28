import 'dart:convert';
import 'package:http/http.dart' as http;

/// UK postcode lookup.
///
/// postcodes.io serves Royal Mail's open postcode data. No key, no account,
/// no quota, and it only knows about the UK — which is the whole market.
/// Google's geocoder would need a billing account to answer the same question.
class Geocode {
  static const _base = 'https://api.postcodes.io';

  /// Where a postcode actually is. Null if it is not a real UK postcode,
  /// which is also how the form validates one.
  static Future<PostcodePlace?> lookup(String postcode) async {
    final clean = postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.length < 5) return null;

    final res = await http
        .get(Uri.parse('$_base/postcodes/$clean'))
        .timeout(const Duration(seconds: 8));

    // 404 means "no such postcode", which is an answer, not a failure.
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Postcode lookup failed (${res.statusCode})');
    }

    final r = jsonDecode(res.body)['result'] as Map<String, dynamic>;
    return PostcodePlace(
      postcode: r['postcode'] as String,
      lat: (r['latitude'] as num).toDouble(),
      lng: (r['longitude'] as num).toDouble(),
      ward: r['admin_ward'] as String?,
      district: r['admin_district'] as String?,
    );
  }

  /// Suggestions while someone is still typing.
  static Future<List<String>> suggest(String partial) async {
    final clean = partial.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (clean.length < 2) return const [];

    try {
      final res = await http
          .get(Uri.parse('$_base/postcodes/$clean/autocomplete'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final list = jsonDecode(res.body)['result'] as List?;
      return list?.cast<String>() ?? const [];
    } catch (_) {
      // Suggestions are a convenience: if they fail, typing still works.
      return const [];
    }
  }
}

class PostcodePlace {
  const PostcodePlace({
    required this.postcode,
    required this.lat,
    required this.lng,
    this.ward,
    this.district,
  });

  final String postcode;
  final double lat;
  final double lng;
  final String? ward;
  final String? district;

  String get area => ward ?? district ?? postcode;
}
