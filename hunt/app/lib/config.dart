/// Build-time configuration, passed with
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// How often the phone sends its position during a game.
  static const locationInterval = Duration(seconds: 5);

  /// How often the map refreshes visible positions from the server.
  static const locationPollInterval = Duration(seconds: 5);

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgentPackageName = 'ch.steigersystems.hunt';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
