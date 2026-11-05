import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'models.dart';

/// Thin wrapper around Supabase. All writes are RPCs; the database checks
/// every rule (see hunt/supabase/migrations).
class HuntRepository {
  HuntRepository(this._db);

  final SupabaseClient _db;

  String? get userId => _db.auth.currentUser?.id;

  Future<void> ensureSignedIn() async {
    if (_db.auth.currentSession == null) {
      await _db.auth.signInAnonymously();
    }
  }

  // ---- lobby ---------------------------------------------------------------

  Future<Game> createGame(String name) async =>
      Game.fromJson(await _rpc('create_game', {'p_name': name}) as Map<String, dynamic>);

  Future<Game> joinGame(String code, String name) async =>
      Game.fromJson(await _rpc('join_game', {'p_code': code, 'p_name': name}) as Map<String, dynamic>);

  Future<void> setPlayerTeam(String playerId, Team team) =>
      _rpc('set_player_team', {'p_player': playerId, 'p_team': team.name});

  Future<void> updateSettings(String gameId, Map<String, dynamic> settings) =>
      _rpc('update_settings', {'p_game': gameId, 'p_settings': settings});

  Future<void> removePlayer(String playerId) => _rpc('remove_player', {'p_player': playerId});

  Future<void> leaveGame(String gameId) => _rpc('leave_game', {'p_game': gameId});

  /// Games this (anonymous) user is still part of, newest first.
  Future<List<Game>> myOpenGames() async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await _db
        .from('games')
        .select()
        .neq('status', 'ended')
        .order('created_at', ascending: false)
        .limit(5);
    return rows.map(Game.fromJson).toList();
  }

  // ---- game ----------------------------------------------------------------

  Future<void> startGame(String gameId) => _rpc('start_game', {'p_game': gameId});

  Future<void> endGame(String gameId) => _rpc('end_game', {'p_game': gameId});

  Future<void> updateLocation(String gameId, double lat, double lng, double? accuracy) =>
      _rpc('update_location', {'p_game': gameId, 'p_lat': lat, 'p_lng': lng, 'p_accuracy': accuracy});

  Future<void> reportTag(String gameId, String runnerId) =>
      _rpc('report_tag', {'p_game': gameId, 'p_runner': runnerId});

  Future<void> respondTag(String tagId, bool confirm) =>
      _rpc('respond_tag', {'p_tag': tagId, 'p_confirm': confirm});

  Future<void> resolveTag(String tagId, bool confirm) =>
      _rpc('resolve_tag', {'p_tag': tagId, 'p_confirm': confirm});

  Future<void> sendMessage(String gameId, String text) =>
      _rpc('send_message', {'p_game': gameId, 'p_text': text});

  Future<List<PlayerStat>> stats(String gameId) async {
    final rows = await _rpc('game_stats', {'p_game': gameId}) as List<dynamic>;
    return rows.map((r) => PlayerStat.fromJson(r as Map<String, dynamic>)).toList();
  }

  // ---- live data -------------------------------------------------------------
  // Realtime streams respect RLS, so every client only receives what it may see.

  Stream<Game?> watchGame(String gameId) => _db
      .from('games')
      .stream(primaryKey: ['id'])
      .eq('id', gameId)
      .map((rows) => rows.isEmpty ? null : Game.fromJson(rows.first));

  Stream<List<Player>> watchPlayers(String gameId) => _db
      .from('players')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('joined_at', ascending: true)
      .map((rows) => rows.map(Player.fromJson).toList());

  Stream<List<Ping>> watchPings(String gameId) => _db
      .from('pings')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(Ping.fromJson).toList());

  Stream<List<Tag>> watchTags(String gameId) => _db
      .from('tags')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('ts', ascending: true)
      .map((rows) => rows.map(Tag.fromJson).toList());

  Stream<ZoneState?> watchZone(String gameId) => _db
      .from('zone_state')
      .stream(primaryKey: ['game_id'])
      .eq('game_id', gameId)
      .map((rows) => rows.isEmpty ? null : ZoneState.fromJson(rows.first));

  Stream<List<ChatMessage>> watchMessages(String gameId) => _db
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('ts', ascending: true)
      .map((rows) => rows.map(ChatMessage.fromJson).toList());

  /// Positions are polled instead of streamed: what a hunter may see changes
  /// over time (runner leaves/re-enters the zone), and a fresh SELECT always
  /// applies the current RLS rules, also for rows that became invisible.
  Stream<List<PlayerLocation>> watchLocations(String gameId) async* {
    while (true) {
      try {
        final rows = await _db.from('locations').select().eq('game_id', gameId);
        yield rows.map(PlayerLocation.fromJson).toList();
      } catch (_) {
        // keep the last known state on network hiccups
      }
      await Future<void>.delayed(Config.locationPollInterval);
    }
  }

  /// Lobby presence: who has the app open right now.
  RealtimeChannel joinPresence(String gameId, String playerId, void Function(Set<String>) onChange) {
    final channel = _db.channel('lobby:$gameId');
    channel
        .onPresenceSync((_) {
          final online = <String>{};
          for (final state in channel.presenceState()) {
            for (final p in state.presences) {
              final id = p.payload['player_id'];
              if (id is String) online.add(id);
            }
          }
          onChange(online);
        })
        .subscribe((status, _) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({'player_id': playerId});
          }
        });
    return channel;
  }

  Future<void> leaveChannel(RealtimeChannel channel) => _db.removeChannel(channel);

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) => _db.rpc(fn, params: params);
}
