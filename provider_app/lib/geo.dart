import 'dart:convert';

import 'package:http/http.dart' as http;

/// Turning what somebody types into a point on the map.
///
/// postcodes.io is Royal Mail open data: no key, no billing, no quota. An
/// applicant who types something we cannot place still gets through — an
/// operator can fix a location later, but nobody can fix a person who gave
/// up on the last screen.
class Geo {
  static Future<({double lat, double lng})?> locate(String text) async {
    final q = text.trim();
    if (q.isEmpty) return null;
    try {
      final r = await http
          .get(Uri.parse(
              'https://api.postcodes.io/postcodes/${Uri.encodeComponent(q)}'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final res = (jsonDecode(r.body) as Map)['result'] as Map;
        return (
          lat: (res['latitude'] as num).toDouble(),
          lng: (res['longitude'] as num).toDouble()
        );
      }

      // Not a full postcode — try it as an outcode ("B29") or a place name.
      final o = await http
          .get(Uri.parse(
              'https://api.postcodes.io/outcodes/${Uri.encodeComponent(q)}'))
          .timeout(const Duration(seconds: 6));
      if (o.statusCode == 200) {
        final res = (jsonDecode(o.body) as Map)['result'] as Map;
        return (
          lat: (res['latitude'] as num).toDouble(),
          lng: (res['longitude'] as num).toDouble()
        );
      }
    } catch (_) {
      // Offline or slow. Not a reason to block an application.
    }
    return null;
  }
}
