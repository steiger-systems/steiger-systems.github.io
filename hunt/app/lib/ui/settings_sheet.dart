import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/errors.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';

Future<void> showSettingsSheet(BuildContext context, Game game) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SettingsSheet(game: game),
    );

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.game});

  final Game game;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  late final Map<String, dynamic> _s = Map.of(widget.game.settings.raw);
  bool _busy = false;

  int _int(String key) => (_s[key] as num).toInt();

  Widget _stepper(String label, String key, String Function(int) format, {required int min, required int max, int step = 1}) {
    final v = _int(key);
    return ListTile(
      title: Text(label),
      subtitle: Text(format(v), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(
          iconSize: 28,
          onPressed: v - step >= min ? () => setState(() => _s[key] = v - step) : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          iconSize: 28,
          onPressed: v + step <= max ? () => setState(() => _s[key] = v + step) : null,
          icon: const Icon(Icons.add),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final changes = Map.of(_s)..remove('zone_center'); // set on the map screen
      await ref.read(repositoryProvider).updateSettings(widget.game.id, changes);
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pings = _s['pings_enabled'] as bool;
    final zone = _s['zone_enabled'] as bool;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.settingsTitle, style: Theme.of(context).textTheme.headlineSmall),
          ),
          _stepper(l.settingsRound, 'round_minutes', l.minutesValue, min: 5, max: 240, step: 5),
          _stepper(l.settingsHeadstart, 'headstart_minutes', l.minutesValue, min: 0, max: 60),
          SwitchListTile(
            title: Text(l.settingsPings),
            value: pings,
            onChanged: (v) => setState(() => _s['pings_enabled'] = v),
          ),
          if (pings) _stepper(l.settingsPingInterval, 'ping_interval_minutes', l.minutesValue, min: 1, max: 60),
          SwitchListTile(
            title: Text(l.settingsZone),
            value: zone,
            onChanged: (v) => setState(() => _s['zone_enabled'] = v),
          ),
          if (zone) ...[
            _stepper(l.settingsZoneRadius, 'zone_radius_m', l.metersValue, min: 100, max: 20000, step: 100),
            _stepper(l.settingsShrinkInterval, 'zone_shrink_interval_minutes', l.minutesValue, min: 1, max: 60),
            _stepper(l.settingsShrinkPercent, 'zone_shrink_percent', l.percentValue, min: 0, max: 50, step: 5),
          ],
          SwitchListTile(
            title: Text(l.settingsSpectators),
            subtitle: Text(l.settingsSpectatorsHint),
            value: _s['spectator_view'] != 'hunter',
            onChanged: (v) => setState(() => _s['spectator_view'] = v ? 'all' : 'hunter'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: _busy ? null : _save, child: Text(l.settingsSave)),
          ),
        ],
      ),
    );
  }
}
