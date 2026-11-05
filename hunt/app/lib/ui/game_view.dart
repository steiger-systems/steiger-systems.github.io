import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/errors.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../location/location_tracker.dart';
import '../theme.dart';
import 'chat_sheet.dart';
import 'map_layers.dart';

class GameView extends ConsumerStatefulWidget {
  const GameView({super.key, required this.game, required this.me});

  final Game game;
  final Player me;

  @override
  ConsumerState<GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<GameView> {
  final _map = MapController();
  final _handledTags = <String>{};
  bool _centeredOnce = false;
  bool _dialogOpen = false;

  Game get game => widget.game;
  Player get me => widget.me;
  bool get _isHost => game.hostId == me.userId;

  @override
  void initState() {
    super.initState();
    // React to tag changes: confirmation dialog for runners, news for everyone.
    ref.listenManual<AsyncValue<List<Tag>>>(tagsProvider(game.id), (prev, next) {
      final tags = next.valueOrNull;
      if (tags == null) return;
      final firstLoad = prev?.valueOrNull == null;
      for (final t in tags) {
        if (firstLoad && t.status != TagStatus.pending) {
          _handledTags.add('${t.id}:${t.status.name}');
          continue;
        }
        final key = '${t.id}:${t.status.name}';
        if (_handledTags.contains(key)) continue;
        _handledTags.add(key);
        if (t.status == TagStatus.pending && t.runnerId == me.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _askRunner(t));
        } else if (t.status == TagStatus.confirmed && !firstLoad) {
          HapticFeedback.heavyImpact();
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.tagConfirmedSnack(_name(t.runnerId)))),
          );
        }
      }
    }, fireImmediately: true);
  }

  String _name(String playerId) {
    final players = ref.read(playersProvider(game.id)).valueOrNull ?? const <Player>[];
    for (final p in players) {
      if (p.id == playerId) return p.name;
    }
    return '?';
  }

  Future<void> _call(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<void> _askRunner(Tag t) async {
    if (!mounted || _dialogOpen) return;
    final l = AppLocalizations.of(context);
    HapticFeedback.vibrate();
    _dialogOpen = true;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l.tagIncomingTitle),
        content: Text(l.tagIncomingText(_name(t.hunterId))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.tagReject)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.tagConfirm)),
        ],
      ),
    );
    _dialogOpen = false;
    if (confirm != null) await _call(() => ref.read(repositoryProvider).respondTag(t.id, confirm));
  }

  Future<void> _reportTag(List<Player> players, List<Tag> tags) async {
    final l = AppLocalizations.of(context);
    final pending = tags.where((t) => t.status == TagStatus.pending).map((t) => t.runnerId).toSet();
    final runners = players.where((p) => p.team == Team.runner && p.isActive && !pending.contains(p.id)).toList();
    final runner = await showModalBottomSheet<Player>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(l.tagChooseRunner, style: Theme.of(context).textTheme.titleLarge)),
            for (final r in runners)
              ListTile(
                minTileHeight: 64,
                leading: const Icon(Icons.directions_run, color: HuntColors.runner),
                title: Text(r.name, style: const TextStyle(fontSize: 20)),
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
    if (runner == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _call(() async {
      await ref.read(repositoryProvider).reportTag(game.id, runner.id);
      messenger.showSnackBar(SnackBar(content: Text(l.tagReported)));
    });
  }

  Future<void> _hostDecide(Tag t) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.tagHostDecideTitle),
        content: Text('${l.tagHostDecideText(_name(t.hunterId), _name(t.runnerId))} '
            '${t.status == TagStatus.rejected ? l.tagReasonRejected : l.tagReasonNoAnswer}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.tagHostReject)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.tagHostConfirm)),
        ],
      ),
    );
    if (confirm != null) await _call(() => ref.read(repositoryProvider).resolveTag(t.id, confirm));
  }

  Future<void> _endGame() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.endGameConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.endGame)),
        ],
      ),
    );
    if (ok == true) await _call(() => ref.read(repositoryProvider).endGame(game.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final players = ref.watch(playersProvider(game.id)).valueOrNull ?? const <Player>[];
    final locations = ref.watch(locationsProvider(game.id)).valueOrNull ?? const <PlayerLocation>[];
    final pings = ref.watch(pingsProvider(game.id)).valueOrNull ?? const <Ping>[];
    final tags = ref.watch(tagsProvider(game.id)).valueOrNull ?? const <Tag>[];
    final zone = ref.watch(zoneProvider(game.id)).valueOrNull;
    final tracker = ref.watch(locationTrackerProvider);

    final byId = {for (final p in players) p.id: p};
    final running = game.status == GameStatus.running;
    final LatLng? myPos = tracker.lastPosition ??
        locations.where((x) => x.playerId == me.id).map((x) => x.position).firstOrNull;

    if (!_centeredOnce && (myPos != null || zone != null)) {
      _centeredOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _map.move(myPos ?? zone!.center, 16);
      });
    }

    // Latest ping per runner (only rows this player may see arrive at all).
    final latestPing = <String, Ping>{};
    for (final p in pings) {
      final cur = latestPing[p.runnerId];
      if (cur == null || p.createdAt.isAfter(cur.createdAt)) latestPing[p.runnerId] = p;
    }
    final liveIds = locations.map((x) => x.playerId).toSet();

    final hostDecisions = !_isHost
        ? const <Tag>[]
        : tags.where((t) {
            final runnerActive = byId[t.runnerId]?.isActive ?? false;
            if (!runnerActive) return false;
            if (t.status == TagStatus.rejected) return true;
            return t.status == TagStatus.pending &&
                now.difference(t.ts).inSeconds >= game.settings.tagConfirmSeconds;
          }).toList();

    final markers = <Marker>[
      // pings: faded dot + age, unless the runner is live-visible anyway
      for (final ping in latestPing.values)
        if (!liveIds.contains(ping.runnerId) && (byId[ping.runnerId]?.isActive ?? false))
          Marker(
            point: ping.position,
            width: 90,
            height: 64,
            child: Column(children: [
              SizedBox(
                width: 36,
                height: 36,
                child: PlayerDot(label: byId[ping.runnerId]?.name ?? '?', color: HuntColors.runner, faded: true),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  l.pingAge(formatDuration(now.difference(ping.capturedAt))),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ]),
          ),
      for (final loc in locations)
        if (loc.playerId != me.id && byId[loc.playerId] != null)
          Marker(
            point: loc.position,
            width: 40,
            height: 40,
            child: PlayerDot(
              label: byId[loc.playerId]!.name,
              color: HuntColors.team(byId[loc.playerId]!.team),
              faded: !byId[loc.playerId]!.isActive,
            ),
          ),
      if (myPos != null)
        Marker(
          point: myPos,
          width: 44,
          height: 44,
          child: PlayerDot(label: me.name, color: HuntColors.team(me.team), isMe: true, faded: !me.isActive),
        ),
    ];

    // ---- status texts ----
    final phaseEnd = game.status == GameStatus.headstart ? game.headstartEndsAt : game.endsAt;
    final remaining = phaseEnd == null ? Duration.zero : phaseEnd.difference(now);
    final infoLines = <String>[
      if (game.status == GameStatus.headstart) me.team == Team.runner ? l.headstartRunner : l.headstartHunter,
      if (running && game.settings.pingsEnabled && game.nextPingAt != null)
        l.nextPingIn(formatDuration(game.nextPingAt!.difference(now))),
      if (running && zone?.nextShrinkAt != null) l.zoneShrinksIn(formatDuration(zone!.nextShrinkAt!.difference(now))),
    ];

    final banners = <Widget>[
      if (!me.isActive) _Banner(text: l.taggedBanner, color: Colors.grey.shade800),
      if (me.isActive && me.team == Team.runner && me.outOfZoneSince != null && running)
        _Banner(
          text: now.difference(me.outOfZoneSince!).inSeconds >= game.settings.zoneGraceSeconds
              ? l.outOfZoneVisible
              : l.outOfZoneWarning,
          color: HuntColors.hunter,
        ),
      if (me.isActive && tracker.state == TrackerState.serviceDisabled) _Banner(text: l.locationOff, color: Colors.orange.shade800),
      if (me.isActive && tracker.state == TrackerState.permissionDenied) _Banner(text: l.locationDenied, color: Colors.orange.shade800),
      for (final t in hostDecisions)
        _Banner(
          text: '${l.tagHostDecideTitle}: ${l.tagHostDecideText(_name(t.hunterId), _name(t.runnerId))}',
          color: Colors.deepPurple,
          onTap: () => _hostDecide(t),
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: myPos ?? zone?.center ?? const LatLng(47.3769, 8.5417), initialZoom: 16),
            children: [
              osmTileLayer(),
              if (zone != null) CircleLayer(circles: [zoneCircle(zone.center, zone.radiusM)]),
              MarkerLayer(markers: markers),
              osmAttribution(),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: HuntColors.surface.withValues(alpha: 0.92),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              game.status == GameStatus.headstart ? l.phaseHeadstart : l.phaseRunning,
                              style: TextStyle(color: HuntColors.team(me.team), fontWeight: FontWeight.w800),
                            ),
                            for (final line in infoLines) Text(line),
                          ]),
                        ),
                        Text(
                          formatDuration(remaining),
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        if (_isHost)
                          PopupMenuButton<String>(
                            onSelected: (_) => _endGame(),
                            itemBuilder: (_) => [PopupMenuItem(value: 'end', child: Text(l.endGame))],
                          ),
                      ]),
                    ),
                  ),
                  ...banners,
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            IconButton.filledTonal(
              iconSize: 32,
              tooltip: l.zoneMyPosition,
              onPressed: myPos == null ? null : () => _map.move(myPos, _map.camera.zoom),
              icon: const Icon(Icons.my_location),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              iconSize: 32,
              tooltip: l.chat,
              onPressed: () => showChatSheet(context, game, me),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
            const SizedBox(width: 12),
            if (me.team == Team.hunter && me.isActive)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: HuntColors.hunter, foregroundColor: Colors.white),
                  onPressed: running ? () => _reportTag(players, tags) : null,
                  icon: const Icon(Icons.back_hand, size: 28),
                  label: Text(l.tagButton),
                ),
              )
            else
              const Spacer(),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, this.onTap});

  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ),
    );
  }
}
