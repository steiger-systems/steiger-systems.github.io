import 'package:flutter_test/flutter_test.dart';
import 'package:hunt/data/models.dart';

void main() {
  test('Game.fromJson parses an RPC row', () {
    final g = Game.fromJson({
      'id': 'g1',
      'code': 'ABC234',
      'host_id': 'u1',
      'status': 'running',
      'settings': {
        'round_minutes': 20,
        'zone_center': {'lat': 47.37, 'lng': 8.54},
        'spectator_view': 'hunter',
      },
      'winner': null,
      'ends_at': '2026-11-05T20:00:00+00:00',
    });
    expect(g.status, GameStatus.running);
    expect(g.isLive, isTrue);
    expect(g.settings.roundMinutes, 20);
    expect(g.settings.pingIntervalMinutes, 3); // default
    expect(g.settings.zoneCenter!.latitude, 47.37);
    expect(g.settings.spectatorsSeeAll, isFalse);
    expect(g.endsAt!.toUtc(), DateTime.utc(2026, 11, 5, 20));
  });

  test('unknown enum values fall back safely', () {
    final p = Player.fromJson({
      'id': 'p1',
      'game_id': 'g1',
      'user_id': 'u1',
      'name': 'Rita',
      'team': 'something',
      'status': 'tagged',
      'distance_m': 12,
    });
    expect(p.team, Team.runner);
    expect(p.status, PlayerStatus.tagged);
    expect(p.isActive, isFalse);
    expect(p.distanceM, 12.0);
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 12, seconds: 3)), '12:03');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatDuration(const Duration(seconds: -4)), '0:00');
  });
}
