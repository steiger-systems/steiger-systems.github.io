import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';

/// Maps the error codes raised by the database RPCs to German UI texts.
String errorText(AppLocalizations l, Object error) {
  final msg = error is PostgrestException ? error.message : error.toString();
  bool has(String code) => msg.contains(code);
  if (has('game_not_found')) return l.errorGameNotFound;
  if (has('game_already_started')) return l.errorAlreadyStarted;
  if (has('game_full')) return l.errorGameFull;
  if (has('invalid_name')) return l.errorInvalidName;
  if (has('need_both_teams')) return l.errorNeedBothTeams;
  if (has('zone_center_missing')) return l.errorZoneMissing;
  if (has('not_host')) return l.errorNotHost;
  if (has('tag_already_pending')) return l.errorTagPending;
  if (has('tag_not_decidable')) return l.errorTagNotDecidable;
  if (has('invalid_setting')) return l.errorInvalidSettings;
  if (has('not_running')) return l.errorNotRunning;
  if (error is AuthException || has('SocketException') || has('Failed host lookup')) {
    return l.connectionError;
  }
  return l.errorGeneric;
}
