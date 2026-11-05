import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';

final repositoryProvider = Provider<HuntRepository>((ref) => HuntRepository(Supabase.instance.client));

final gameProvider = StreamProvider.autoDispose.family<Game?, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchGame(gameId),
);

final playersProvider = StreamProvider.autoDispose.family<List<Player>, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchPlayers(gameId),
);

final pingsProvider = StreamProvider.autoDispose.family<List<Ping>, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchPings(gameId),
);

final tagsProvider = StreamProvider.autoDispose.family<List<Tag>, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchTags(gameId),
);

final zoneProvider = StreamProvider.autoDispose.family<ZoneState?, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchZone(gameId),
);

final messagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchMessages(gameId),
);

final locationsProvider = StreamProvider.autoDispose.family<List<PlayerLocation>, String>(
  (ref, gameId) => ref.watch(repositoryProvider).watchLocations(gameId),
);

final statsProvider = FutureProvider.autoDispose.family<List<PlayerStat>, String>(
  (ref, gameId) => ref.watch(repositoryProvider).stats(gameId),
);

/// The signed-in user's player in a game.
final mePlayerProvider = Provider.autoDispose.family<Player?, String>((ref, gameId) {
  final uid = ref.watch(repositoryProvider).userId;
  final players = ref.watch(playersProvider(gameId)).valueOrNull ?? const [];
  for (final p in players) {
    if (p.userId == uid) return p;
  }
  return null;
});

/// Ticks every second; used for countdowns and ping ages.
final clockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
