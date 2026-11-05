import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

class EndView extends ConsumerWidget {
  const EndView({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stats = ref.watch(statsProvider(game.id));

    final (title, color) = switch (game.winner) {
      Team.hunter => (l.endTitleHunters, HuntColors.hunter),
      Team.runner => (l.endTitleRunners, HuntColors.runner),
      null => (l.endTitleAborted, Colors.grey),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            Text(l.endStats, style: Theme.of(context).textTheme.titleMedium),
            Expanded(
              child: stats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: TextButton(onPressed: () => ref.invalidate(statsProvider(game.id)), child: Text(l.retry)),
                ),
                data: (rows) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final s in rows)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            s.team == Team.hunter ? Icons.back_hand : Icons.directions_run,
                            color: HuntColors.team(s.team),
                          ),
                          title: Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          subtitle: Text([
                            if (s.team == Team.runner && s.survivedSeconds != null)
                              l.statSurvived(formatDuration(Duration(seconds: s.survivedSeconds!))),
                            if (s.team == Team.runner && s.status == PlayerStatus.tagged) l.statusTagged,
                            if (s.team == Team.hunter) l.statTags(s.tags),
                            l.statDistance((s.distanceM / 1000).toStringAsFixed(2)),
                          ].join(' · ')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(onPressed: () => context.go('/'), child: Text(l.endBackHome)),
            ),
          ],
        ),
      ),
    );
  }
}
