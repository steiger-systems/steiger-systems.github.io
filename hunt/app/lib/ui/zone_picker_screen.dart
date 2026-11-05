import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../data/errors.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import 'map_layers.dart';

/// Host sets the zone center by tapping the map.
class ZonePickerScreen extends ConsumerStatefulWidget {
  const ZonePickerScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<ZonePickerScreen> createState() => _ZonePickerScreenState();
}

class _ZonePickerScreenState extends ConsumerState<ZonePickerScreen> {
  static const _fallback = LatLng(47.3769, 8.5417); // Zurich
  final _map = MapController();
  LatLng? _center;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _center = ref.read(gameProvider(widget.gameId)).valueOrNull?.settings.zoneCenter;
    if (_center == null) _goToMyPosition(setCenter: true);
  }

  Future<void> _goToMyPosition({bool setCenter = false}) async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      final here = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        if (setCenter || _center == null) _center = here;
      });
      _map.move(here, 15);
    } catch (_) {
      // no position available: user taps the map instead
    }
  }

  Future<void> _save() async {
    final c = _center;
    if (c == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).updateSettings(widget.gameId, {
        'zone_center': {'lat': c.latitude, 'lng': c.longitude},
      });
      if (mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final radius = ref.watch(gameProvider(widget.gameId)).valueOrNull?.settings.zoneRadiusM ?? 1000;

    return Scaffold(
      appBar: AppBar(title: Text(l.zoneTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center ?? _fallback,
              initialZoom: 14,
              onTap: (_, point) => setState(() => _center = point),
            ),
            children: [
              osmTileLayer(),
              if (_center != null) CircleLayer(circles: [zoneCircle(_center!, radius)]),
              if (_center != null)
                MarkerLayer(markers: [
                  Marker(point: _center!, width: 24, height: 24, child: const Icon(Icons.add, size: 24)),
                ]),
              osmAttribution(),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(l.zoneHint))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l.zoneMyPosition,
        onPressed: () => _goToMyPosition(),
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _center == null || _busy ? null : _save, child: Text(l.zoneSave)),
        ),
      ),
    );
  }
}
