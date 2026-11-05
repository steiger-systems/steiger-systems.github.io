import 'package:latlong2/latlong.dart';

enum GameStatus { lobby, headstart, running, ended }

enum Team { hunter, runner }

enum PlayerStatus { active, tagged, spectator }

enum TagStatus { pending, confirmed, rejected, cancelled }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _ts(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

double _d(Object? v) => (v as num).toDouble();

/// Mirrors private.default_settings() in the database.
class GameSettings {
  const GameSettings(this.raw);

  final Map<String, dynamic> raw;

  int get roundMinutes => (raw['round_minutes'] as num?)?.toInt() ?? 30;
  int get headstartMinutes => (raw['headstart_minutes'] as num?)?.toInt() ?? 5;
  bool get pingsEnabled => raw['pings_enabled'] as bool? ?? true;
  int get pingIntervalMinutes => (raw['ping_interval_minutes'] as num?)?.toInt() ?? 3;
  bool get zoneEnabled => raw['zone_enabled'] as bool? ?? true;
  double get zoneRadiusM => (raw['zone_radius_m'] as num?)?.toDouble() ?? 1000;
  int get zoneShrinkIntervalMinutes => (raw['zone_shrink_interval_minutes'] as num?)?.toInt() ?? 5;
  int get zoneShrinkPercent => (raw['zone_shrink_percent'] as num?)?.toInt() ?? 15;
  int get zoneGraceSeconds => (raw['zone_grace_seconds'] as num?)?.toInt() ?? 30;
  int get tagConfirmSeconds => (raw['tag_confirm_seconds'] as num?)?.toInt() ?? 30;
  bool get spectatorsSeeAll => (raw['spectator_view'] as String?) != 'hunter';

  LatLng? get zoneCenter {
    final c = raw['zone_center'];
    if (c is Map && c['lat'] is num && c['lng'] is num) {
      return LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
    }
    return null;
  }
}

class Game {
  Game({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.settings,
    this.winner,
    this.startedAt,
    this.headstartEndsAt,
    this.endsAt,
    this.endedAt,
    this.nextPingAt,
  });

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'] as String,
        code: j['code'] as String,
        hostId: j['host_id'] as String,
        status: _enumByName(GameStatus.values, j['status'], GameStatus.lobby),
        settings: GameSettings(Map<String, dynamic>.from(j['settings'] as Map)),
        winner: j['winner'] == null ? null : _enumByName(Team.values, j['winner'], Team.runner),
        startedAt: _ts(j['started_at']),
        headstartEndsAt: _ts(j['headstart_ends_at']),
        endsAt: _ts(j['ends_at']),
        endedAt: _ts(j['ended_at']),
        nextPingAt: _ts(j['next_ping_at']),
      );

  final String id;
  final String code;
  final String hostId;
  final GameStatus status;
  final GameSettings settings;
  final Team? winner;
  final DateTime? startedAt;
  final DateTime? headstartEndsAt;
  final DateTime? endsAt;
  final DateTime? endedAt;
  final DateTime? nextPingAt;

  bool get isLive => status == GameStatus.headstart || status == GameStatus.running;
}

class Player {
  Player({
    required this.id,
    required this.gameId,
    required this.userId,
    required this.name,
    required this.team,
    required this.status,
    this.taggedAt,
    this.outOfZoneSince,
    this.distanceM = 0,
  });

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        gameId: j['game_id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        team: _enumByName(Team.values, j['team'], Team.runner),
        status: _enumByName(PlayerStatus.values, j['status'], PlayerStatus.active),
        taggedAt: _ts(j['tagged_at']),
        outOfZoneSince: _ts(j['out_of_zone_since']),
        distanceM: (j['distance_m'] as num?)?.toDouble() ?? 0,
      );

  final String id;
  final String gameId;
  final String userId;
  final String name;
  final Team team;
  final PlayerStatus status;
  final DateTime? taggedAt;
  final DateTime? outOfZoneSince;
  final double distanceM;

  bool get isActive => status == PlayerStatus.active;
}

class PlayerLocation {
  PlayerLocation({required this.playerId, required this.position, this.accuracy, required this.updatedAt});

  factory PlayerLocation.fromJson(Map<String, dynamic> j) => PlayerLocation(
        playerId: j['player_id'] as String,
        position: LatLng(_d(j['lat']), _d(j['lng'])),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        updatedAt: _ts(j['updated_at'])!,
      );

  final String playerId;
  final LatLng position;
  final double? accuracy;
  final DateTime updatedAt;
}

class Ping {
  Ping({required this.id, required this.runnerId, required this.position, required this.capturedAt, required this.createdAt});

  factory Ping.fromJson(Map<String, dynamic> j) => Ping(
        id: (j['id'] as num).toInt(),
        runnerId: j['runner_id'] as String,
        position: LatLng(_d(j['lat']), _d(j['lng'])),
        capturedAt: _ts(j['captured_at'])!,
        createdAt: _ts(j['created_at'])!,
      );

  final int id;
  final String runnerId;
  final LatLng position;
  final DateTime capturedAt;
  final DateTime createdAt;
}

class Tag {
  Tag({
    required this.id,
    required this.hunterId,
    required this.runnerId,
    required this.status,
    required this.ts,
    this.resolvedByHost = false,
  });

  factory Tag.fromJson(Map<String, dynamic> j) => Tag(
        id: j['id'] as String,
        hunterId: j['hunter_id'] as String,
        runnerId: j['runner_id'] as String,
        status: _enumByName(TagStatus.values, j['status'], TagStatus.pending),
        ts: _ts(j['ts'])!,
        resolvedByHost: j['resolved_by_host'] as bool? ?? false,
      );

  final String id;
  final String hunterId;
  final String runnerId;
  final TagStatus status;
  final DateTime ts;
  final bool resolvedByHost;
}

class ZoneState {
  ZoneState({required this.center, required this.radiusM, this.nextShrinkAt});

  factory ZoneState.fromJson(Map<String, dynamic> j) => ZoneState(
        center: LatLng(_d(j['center_lat']), _d(j['center_lng'])),
        radiusM: _d(j['radius_m']),
        nextShrinkAt: _ts(j['next_shrink_at']),
      );

  final LatLng center;
  final double radiusM;
  final DateTime? nextShrinkAt;
}

class ChatMessage {
  ChatMessage({required this.id, required this.playerId, required this.text, required this.ts});

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        playerId: j['player_id'] as String,
        text: j['text'] as String,
        ts: _ts(j['ts'])!,
      );

  final int id;
  final String playerId;
  final String text;
  final DateTime ts;
}

class PlayerStat {
  PlayerStat({
    required this.playerId,
    required this.name,
    required this.team,
    required this.status,
    this.survivedSeconds,
    required this.distanceM,
    required this.tags,
  });

  factory PlayerStat.fromJson(Map<String, dynamic> j) => PlayerStat(
        playerId: j['player_id'] as String,
        name: j['name'] as String,
        team: _enumByName(Team.values, j['team'], Team.runner),
        status: _enumByName(PlayerStatus.values, j['status'], PlayerStatus.active),
        survivedSeconds: (j['survived_seconds'] as num?)?.toInt(),
        distanceM: (j['distance_m'] as num?)?.toDouble() ?? 0,
        tags: (j['tags'] as num?)?.toInt() ?? 0,
      );

  final String playerId;
  final String name;
  final Team team;
  final PlayerStatus status;
  final int? survivedSeconds;
  final double distanceM;
  final int tags;
}

/// Formats a duration as m:ss or h:mm:ss.
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
