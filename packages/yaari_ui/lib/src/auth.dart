import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Phone sign-in, shared by both apps.
///
/// The six digit code is checked by an edge function holding the service
/// role; the client never sees the stored hash and cannot read the codes
/// table at all. On success the function returns a GoTrue `token_hash`
/// which we redeem for a genuine session, so tokens rotate and can be
/// revoked — unlike a hand-rolled JWT.
class YaariAuth {
  YaariAuth(this._client);

  final SupabaseClient _client;

  Session? get session => _client.auth.currentSession;
  String? get userId => _client.auth.currentUser?.id;
  bool get isSignedIn => session != null;

  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  /// Ask for a code. In dev mode the code comes back in the response so
  /// the app can show it, because an SMS gateway costs money per message.
  Future<OtpRequest> requestCode({required String phone, required String role}) async {
    try {
      final res = await _client.functions.invoke(
        'request-otp',
        body: {'phone': phone, 'role': role},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      return OtpRequest(
        ok: data['ok'] == true,
        phone: data['phone'] as String?,
        devCode: data['dev_code'] as String?,
        expiresInSeconds: (data['expires_in_seconds'] as num?)?.toInt() ?? 300,
      );
    } on FunctionException catch (e) {
      // status 0 means the request never left the device — no network, or no
      // INTERNET permission in the manifest. Saying "could not send a code"
      // there sends people hunting for a server problem that does not exist.
      throw YaariAuthException(e.status == 0
          ? 'Could not reach Yaari. Check your connection.'
          : _message(e.details, 'Could not send a code.'));
    } catch (_) {
      throw const YaariAuthException('Could not reach Yaari. Check your connection.');
    }
  }

  /// Redeem the code for a session.
  Future<AuthedUser> verifyCode({required String phone, required String code}) async {
    Map<String, dynamic> data;
    try {
      final res = await _client.functions.invoke(
        'verify-otp',
        body: {'phone': phone, 'code': code},
      );
      data = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      throw YaariAuthException(_message(e.details, 'That code was not accepted.'));
    } catch (_) {
      throw const YaariAuthException('Could not reach Yaari. Check your connection.');
    }

    final tokenHash = data['token_hash'] as String?;
    if (tokenHash == null) {
      throw const YaariAuthException('That code was not accepted.');
    }

    await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);

    final user = Map<String, dynamic>.from(data['user'] as Map);
    return AuthedUser(
      id: user['id'] as String,
      role: user['role'] as String,
      fullName: user['full_name'] as String?,
      phone: user['phone'] as String,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Edge functions return {error, message}; surface the message when present.
  ///
  /// `details` is not always a decoded Map. Depending on the response's
  /// content type it can arrive as the raw JSON string, or wrapped a level
  /// deeper — and when that happened the app fell back to "Could not send a
  /// code", hiding a perfectly clear explanation like "Too many codes
  /// requested. Try again in an hour." Every shape is unwrapped here.
  static String _message(Object? details, String fallback) =>
      messageFrom(details, fallback);

  /// Exposed so the unwrapping can be tested directly — it is the part that
  /// silently swallowed a good error message once already.
  @visibleForTesting
  static String messageFrom(Object? details, String fallback) =>
      _digForMessage(details, 0) ?? fallback;

  static String? _digForMessage(Object? value, int depth) {
    if (depth > 3) return null;

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      // A raw JSON body arrives as a string; decode it and look inside.
      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          return _digForMessage(jsonDecode(text), depth + 1);
        } catch (_) {
          return null;
        }
      }
      return text;
    }

    if (value is Map) {
      for (final key in const ['message', 'error_description', 'msg']) {
        final v = value[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      // Some layers nest the real body under 'error' or 'details'.
      for (final key in const ['error', 'details', 'data', 'body']) {
        if (value.containsKey(key)) {
          final found = _digForMessage(value[key], depth + 1);
          if (found != null) return found;
        }
      }
    }

    return null;
  }
}

class OtpRequest {
  const OtpRequest({
    required this.ok,
    required this.phone,
    required this.devCode,
    required this.expiresInSeconds,
  });

  final bool ok;
  final String? phone;

  /// Present only while codes are delivered on screen rather than by SMS.
  final String? devCode;
  final int expiresInSeconds;
}

class AuthedUser {
  const AuthedUser({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
  });

  final String id;
  final String role;
  final String? fullName;
  final String phone;
}

class YaariAuthException implements Exception {
  const YaariAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Formats as the user types: 07700 900318
String prettyUkPhone(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length <= 5) return d;
  if (d.length <= 11) return '${d.substring(0, 5)} ${d.substring(5)}';
  return '${d.substring(0, 5)} ${d.substring(5, 11)}';
}

/// A UK mobile, entered as 07… or 447…
bool looksLikeUkMobile(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('44') && d.length == 12) return true;
  if (d.startsWith('0') && d.length == 11) return true;
  if (d.startsWith('7') && d.length == 10) return true;
  return false;
}
