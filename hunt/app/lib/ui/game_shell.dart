import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../location/location_tracker.dart';
import 'end_view.dart';
import 'game_view.dart';
import 'lobby_view.dart';

/// Should this phone share its position right now?
final _shouldTrackProvider = Provider.autoDispose.family<bool, String>((ref, gameId) {
  final game = ref.watch(gameProvider(gameId)).valueOrNull;
  final me = ref.watch(mePlayerProvider(gameId));
  return game != null && game.isLive && me != null && me.isActive;
});

/// Switches between lobby, game and end screen depending on the game status.
class GameShell extends ConsumerStatefulWidget {
  const GameShell({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<GameShell> {
  late final LocationTracker _tracker;

  @override
  void initState() {
    super.initState();
    _tracker = ref.read(locationTrackerProvider);
    ref.listenManual<bool>(_shouldTrackProvider(widget.gameId), (_, track) {
      if (track) {
        // After the frame: localizations are not readable during initState.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !ref.read(_shouldTrackProvider(widget.gameId))) return;
          final l = AppLocalizations.of(context);
          _tracker.start(
            widget.gameId,
            notificationTitle: l.trackingNotificationTitle,
            notificationText: l.trackingNotificationText,
          );
        });
      } else {
        _tracker.stop();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _tracker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gameAsync = ref.watch(gameProvider(widget.gameId));
    final playersAsync = ref.watch(playersProvider(widget.gameId));
    final me = ref.watch(mePlayerProvider(widget.gameId));

    // Game closed by host, or this player was removed from the lobby.
    final gone = (gameAsync.hasValue && gameAsync.value == null) ||
        (playersAsync.hasValue && me == null && gameAsync.valueOrNull?.status == GameStatus.lobby);
    if (gone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    }

    return gameAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.connectionError),
            const SizedBox(height: 12),
            TextButton(onPressed: () => ref.invalidate(gameProvider(widget.gameId)), child: Text(l.retry)),
          ]),
        ),
      ),
      data: (game) {
        if (game == null || me == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return switch (game.status) {
          GameStatus.lobby => LobbyView(game: game, me: me),
          GameStatus.headstart || GameStatus.running => GameView(game: game, me: me),
          GameStatus.ended => EndView(game: game),
        };
      },
    );
  }
}
