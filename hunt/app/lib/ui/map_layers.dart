import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../theme.dart';

/// OpenStreetMap tiles (free; attribution required by the tile policy).
Widget osmTileLayer() => TileLayer(
      urlTemplate: Config.osmTileUrl,
      userAgentPackageName: Config.userAgentPackageName,
    );

Widget osmAttribution() => RichAttributionWidget(
      attributions: [TextSourceAttribution('OpenStreetMap contributors')],
    );

CircleMarker zoneCircle(LatLng center, double radiusM) => CircleMarker(
      point: center,
      radius: radiusM,
      useRadiusInMeter: true,
      color: HuntColors.zone.withValues(alpha: 0.08),
      borderColor: HuntColors.zone,
      borderStrokeWidth: 3,
    );

/// Round marker with the first letter of the name.
class PlayerDot extends StatelessWidget {
  const PlayerDot({super.key, required this.label, required this.color, this.faded = false, this.isMe = false});

  final String label;
  final Color color;
  final bool faded;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: isMe ? 4 : 2),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black54)],
        ),
        alignment: Alignment.center,
        child: Text(
          label.isEmpty ? '?' : label.characters.first.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
    );
  }
}
