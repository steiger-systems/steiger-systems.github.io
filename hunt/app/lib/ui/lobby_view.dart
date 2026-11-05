import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/errors.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'settings_sheet.dart';

class LobbyView extends ConsumerStatefulWidget {
  const LobbyView({super.key, required this.game, required this.me});

  final Game game;
  final Player me;

  @override
  ConsumerState<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends ConsumerState<LobbyView> {
  RealtimeChannel? _presence;
  Set<String> _online = const {};
  bool _busy = false;

  bool get _isHost => widget.game.hostId == widget.me.userId;

  @override
  void initState() {
    super.initState();
    _presence = ref.read(repositoryProvider).joinPresence(widget.game.id, widget.me.id, (online) {
      if (mounted) setState(() => _online = online);
    });
  }

  @override
  void dispose() {
    final channel = _presence;
    if (channel != null) ref.read(repositoryProvider).leaveChannel(channel);
    super.dispose();
  }

  Future<void> _do(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRemove(Player p) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.lobbyRemoveTitle(p.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.lobbyRemove)),
        ],
      ),
    );
    if (ok == true) await _do(() => ref.read(repositoryProvider).removePlayer(p.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final repo = ref.read(repositoryProvider);
    final players = ref.watch(playersProvider(widget.game.id)).valueOrNull ?? const <Player>[];
    final s = widget.game.settings;

    Widget teamSection(Team team) {
      final members = players.where((p) => p.team == team).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              '${team == Team.hunter ? l.teamHunter : l.teamRunner} (${members.length})',
              style: TextStyle(color: HuntColors.team(team), fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          for (final p in members)
            Card(
              child: ListTile(
                leading: Icon(Icons.circle, size: 12, color: _online.contains(p.id) ? Colors.greenAccent : Colors.grey),
                title: Text(p.name, style: const TextStyle(fontSize: 18)),
                subtitle: Text([
                  if (p.userId == widget.game.hostId) l.hostLabel,
                  if (p.id == widget.me.id) l.youLabel,
                ].join(' · ')),
                trailing: _isHost ? const Icon(Icons.swap_horiz) : null,
                onTap: _isHost && !_busy
                    ? () => _do(() => repo.setPlayerTeam(p.id, team == Team.hunter ? Team.runner : Team.hunter))
                    : null,
                onLongPress: _isHost && p.userId != widget.game.hostId ? () => _confirmRemove(p) : null,
              ),
            ),
        ],
      );
    }

    final zoneText = !s.zoneEnabled
        ? l.lobbyZoneOff
        : s.zoneCenter == null
            ? l.lobbyZoneMissing
            : l.lobbyZoneSet(s.zoneRadiusM.round());

    return Scaffold(
      appBar: AppBar(
        title: Text(l.lobbyTitle),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => _do(() async {
                      await repo.leaveGame(widget.game.id);
                      if (context.mounted) context.go('/');
                    }),
            child: Text(l.lobbyLeave),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: SelectableText(
                      widget.game.code,
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 10),
                    ),
                  ),
                  Text(l.lobbyShareHint, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: Text('${l.settingsRound}: ${l.minutesValue(s.roundMinutes)} · '
                          '${l.settingsHeadstart}: ${l.minutesValue(s.headstartMinutes)}'),
                      subtitle: Text([
                        if (s.pingsEnabled) '${l.settingsPingInterval} ${l.minutesValue(s.pingIntervalMinutes)}',
                        zoneText,
                      ].join(' · ')),
                      trailing: _isHost ? const Icon(Icons.chevron_right) : null,
                      onTap: _isHost ? () => showSettingsSheet(context, widget.game) : null,
                    ),
                  ),
                  if (_isHost && s.zoneEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/game/${widget.game.id}/zone'),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(l.lobbySetZone),
                      ),
                    ),
                  if (_isHost)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(l.lobbyHostHint, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  teamSection(Team.hunter),
                  teamSection(Team.runner),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isHost
                  ? FilledButton(
                      onPressed: _busy ? null : () => _do(() => repo.startGame(widget.game.id)),
                      child: Text(l.lobbyStart),
                    )
                  : Text(l.lobbyWaitingForHost, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
