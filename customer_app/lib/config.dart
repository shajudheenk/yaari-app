/// Backend configuration.
///
/// The publishable key is designed to ship inside client apps: every table
/// is protected by row level security, so on its own it grants nothing.
/// The service_role key must never appear here.
///
/// Override at build time if needed:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
class Config {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://capnsntuwdhxrxjfhrgr.supabase.co',
  );

  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_1_b1CO2K62CW8MfW_r-a5A_QY2mUYNU',
  );

  /// Selly Oak, Birmingham — where the company started.
  ///
  /// Only a fallback. The real list of areas lives in `service_areas`, so
  /// opening a city is a database row rather than an app release. These
  /// constants are what the app falls back to on a first run with no network.
  static const fallbackLat = 52.437675;
  static const fallbackLng = -1.947505;
  static const fallbackArea = 'Selly Oak';
  static const fallbackCity = 'Birmingham';
  static const fallbackPostcode = 'B29';
}
