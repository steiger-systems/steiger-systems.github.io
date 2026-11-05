import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../data/providers.dart';
import '../data/repository.dart';

enum TrackerState { off, starting, running, serviceDisabled, permissionDenied }

/// Streams the phone's position to the server while a game is live.
/// Android: foreground service (notification) keeps it running when locked.
/// iOS: background mode "location" + allowBackgroundLocationUpdates.
class LocationTracker extends ChangeNotifier {
  LocationTracker(this._repo);

  final HuntRepository _repo;
  StreamSubscription<Position>? _sub;
  String? _gameId;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sending = false;

  TrackerState state = TrackerState.off;
  LatLng? lastPosition;
  double? lastAccuracy;

  /// Notification texts for the Android foreground service (German UI texts
  /// are passed in from the widget layer).
  Future<void> start(String gameId, {required String notificationTitle, required String notificationText}) async {
    if (_gameId == gameId && _sub != null) return;
    await stop();
    _gameId = gameId;
    _set(TrackerState.starting);

    if (!await Geolocator.isLocationServiceEnabled()) {
      _set(TrackerState.serviceDisabled);
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // On iOS a second request upgrades "while in use" to "always".
    if (!kIsWeb && Platform.isIOS && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _set(TrackerState.permissionDenied);
      return;
    }
    if (_gameId != gameId) return; // stopped meanwhile

    _sub = Geolocator.getPositionStream(
      locationSettings: _settings(notificationTitle, notificationText),
    ).listen(_onPosition, onError: (Object _) {});
    _set(TrackerState.running);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _gameId = null;
    if (state != TrackerState.off) _set(TrackerState.off);
  }

  Future<void> _onPosition(Position p) async {
    lastPosition = LatLng(p.latitude, p.longitude);
    lastAccuracy = p.accuracy;
    notifyListeners();

    final gameId = _gameId;
    final now = DateTime.now();
    if (gameId == null || _sending || now.difference(_lastSent) < Config.locationInterval) return;
    _sending = true;
    _lastSent = now;
    try {
      await _repo.updateLocation(gameId, p.latitude, p.longitude, p.accuracy);
    } catch (e) {
      // 'not_running' => game over, stop sharing. Other errors: retry next fix.
      if (e.toString().contains('not_running')) await stop();
    } finally {
      _sending = false;
    }
  }

  LocationSettings _settings(String title, String text) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Config.locationInterval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: title,
          notificationText: text,
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  void _set(TrackerState s) {
    state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final locationTrackerProvider = ChangeNotifierProvider<LocationTracker>(
  (ref) => LocationTracker(ref.watch(repositoryProvider)),
);
