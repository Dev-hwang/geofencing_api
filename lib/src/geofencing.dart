part of '../geofencing_api.dart';

class Geofencing {
  Geofencing._();

  /// Singleton instance of [Geofencing].
  static final instance = Geofencing._();

  // Geofencing service state
  GeofencingOptions _options = GeofencingOptions();
  final Map<String, GeofenceRegion> _regions = {};
  bool _isRunningService = false;

  // stream subscriptions
  StreamSubscription<Location>? _locationSubscription;

  // listeners
  final List<GeofenceStatusChanged> _geofenceStatusChangedListeners = [];
  final List<GeofenceErrorCallback> _geofenceErrorCallbackListeners = [];

  /// Set up the geofencing service.
  void setup({
    int? interval,
    int? accuracy,
    int? statusChangeDelay,
    bool? allowsMockLocation,
    bool? printsDebugLog,
  }) {
    _options = _options.copyWith(
      interval: interval,
      accuracy: accuracy,
      statusChangeDelay: statusChangeDelay,
      allowsMockLocation: allowsMockLocation,
      printsDebugLog: printsDebugLog,
    );
  }

  /// Start the geofencing service with [regions].
  Future<void> start({Set<GeofenceRegion> regions = const {}}) async {
    if (_isRunningService) {
      throw GeofencingAlreadyStartedException();
    }

    await _checkPermissions();
    await _subscribeStreams();

    addRegions(regions);

    _isRunningService = true;
    _printDebugLog('Geofencing service has started.');
  }

  /// Stop the geofencing service.
  ///
  /// Setting the [keepsRegions] value to `true` will remove all regions.
  Future<void> stop({bool keepsRegions = false}) async {
    if (_isRunningService) {
      await _unsubscribeStreams();

      if (!keepsRegions) {
        clearAllRegions();
      }

      _isRunningService = false;
      _printDebugLog('Geofencing service has stopped.');
    }
  }

  /// Pause the geofencing service.
  void pause() {
    if (_isRunningService) {
      _locationSubscription?.pause();
      _printDebugLog('Geofencing service has paused.');
    }
  }

  /// Resume the geofencing service.
  void resume() {
    if (_isRunningService) {
      _locationSubscription?.resume();
      _printDebugLog('Geofencing service has resumed.');
    }
  }

  /// Whether the geofencing service is running.
  bool get isRunningService => _isRunningService;

  /// Get geofence regions.
  Set<GeofenceRegion> get regions => _regions.values.toSet();

  /// Add geofence region.
  void addRegion(GeofenceRegion region) {
    _regions[region.id] = region;
  }

  /// Add geofence regions.
  void addRegions(Set<GeofenceRegion> regions) {
    regions.forEach(addRegion);
  }

  /// Remove geofence region.
  void removeRegion(GeofenceRegion region) {
    removeRegionById(region.id);
  }

  /// Remove geofence regions.
  void removeRegions(Set<GeofenceRegion> regions) {
    regions.forEach(removeRegion);
  }

  /// Remove geofence region by [GeofenceRegion.id].
  void removeRegionById(String id) {
    _regions.remove(id);
  }

  /// Clear all geofence regions.
  void clearAllRegions() {
    _regions.clear();
  }

  /// Register a closure to be called when the [GeofenceStatus] changes.
  void addGeofenceStatusChangedListener(GeofenceStatusChanged listener) {
    _geofenceStatusChangedListeners.add(listener);
  }

  /// Remove a previously registered closure from the list of closures that
  /// are notified when the [GeofenceStatus] changes.
  void removeGeofenceStatusChangedListener(GeofenceStatusChanged listener) {
    _geofenceStatusChangedListeners.remove(listener);
  }

  /// Register a closure to be called when a geofence error occurs.
  void addGeofenceErrorCallbackListener(GeofenceErrorCallback listener) {
    _geofenceErrorCallbackListeners.add(listener);
  }

  /// Remove a previously registered closure from the list of closures that
  /// are notified when a geofence error occurs.
  void removeGeofenceErrorCallbackListener(GeofenceErrorCallback listener) {
    _geofenceErrorCallbackListeners.remove(listener);
  }

  /// Clear all listeners registered in the service.
  void clearAllListeners() {
    _geofenceStatusChangedListeners.clear();
    _geofenceErrorCallbackListeners.clear();
  }

  Future<void> _checkPermissions() async {
    if (!await FlLocation.isLocationServicesEnabled) {
      throw LocationServicesDisabledException();
    }

    LocationPermission permission = await FlLocation.checkLocationPermission();
    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionPermanentlyDeniedException();
    } else if (permission == LocationPermission.denied) {
      permission = await FlLocation.requestLocationPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDeniedException();
      } else if (permission == LocationPermission.deniedForever) {
        throw LocationPermissionPermanentlyDeniedException();
      }
    }
  }

  Future<void> _subscribeStreams() async {
    _locationSubscription = FlLocation.getLocationStream(
      accuracy: LocationAccuracy.navigation,
      interval: _options.interval,
    ).handleError(_onError).listen(_onLocation);
  }

  Future<void> _unsubscribeStreams() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _onLocation(Location location) async {
    if (!_options.allowsMockLocation && location.isMock) {
      _printDebugLog(
          'The location was rejected. reason: options.allowsMockLocation != location.isMock');
      return;
    }

    if (_options.accuracy < location.accuracy) {
      _printDebugLog(
          'The location was rejected. reason: options.accuracy(${_options.accuracy}) < location.accuracy(${location.accuracy})');
      return;
    }

    // Pause location for synchronous processing of region
    _locationSubscription?.pause();

    GeofenceStatus status;
    for (final GeofenceRegion region in _regions.values.toList()) {
      status = _determineStatus(location, region);
      if (region.status == status) {
        continue;
      }

      if (_regions.containsKey(region.id)) {
        _regions[region.id] =
            region.updateWith(status: status, timestamp: location.timestamp);
      }

      for (final listener in _geofenceStatusChangedListeners.toList()) {
        await listener(region, status, location);
      }
    }

    // Resume location
    _locationSubscription?.resume();
  }

  GeofenceStatus _determineStatus(Location location, GeofenceRegion region) {
    // Check whether location is contained in region
    bool containsLocation = false;
    if (region is GeofenceCircularRegion) {
      final double remaining = LocationUtils.distanceBetween(location.latitude,
          location.longitude, region.center.latitude, region.center.longitude);
      containsLocation = remaining <= region.radius;
    } else if (region is GeofencePolygonRegion) {
      containsLocation = PolygonUtils.containsLocation(
          location.latitude, location.longitude, region.polygon);
    }

    // Since the elapsed time is unknown, the status is determined immediately
    final DateTime? regionTimestamp = region.timestamp;
    if (regionTimestamp == null) {
      return containsLocation ? GeofenceStatus.enter : GeofenceStatus.exit;
    }

    final int elapsedTime =
        location.timestamp.difference(regionTimestamp).inMilliseconds;

    final GeofenceStatus oldStatus = region.status;
    GeofenceStatus newStatus;
    if (containsLocation) {
      if (oldStatus == GeofenceStatus.dwell) {
        return GeofenceStatus.dwell;
      }

      if (oldStatus == GeofenceStatus.enter &&
          elapsedTime > region.loiteringDelay) {
        newStatus = GeofenceStatus.dwell;
      } else {
        newStatus = GeofenceStatus.enter;
      }
    } else {
      newStatus = GeofenceStatus.exit;
    }

    if (newStatus != GeofenceStatus.dwell &&
        elapsedTime < _options.statusChangeDelay) {
      return oldStatus;
    }

    return newStatus;
  }

  void _onError(Object error, StackTrace stackTrace) {
    for (final listener in _geofenceErrorCallbackListeners.toList()) {
      listener(error, stackTrace);
    }
  }

  void _printDebugLog(String message) {
    if (kDebugMode && _options.printsDebugLog) {
      dev.log("[Geofencing] $message");
    }
  }
}
