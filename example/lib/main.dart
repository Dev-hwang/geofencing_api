import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as map;

/*
 * This example uses google maps. You need to get the API key from Google Cloud.
 * Please check the page below for more details.
 *
 * https://pub.dev/packages/google_maps_flutter
 */

const Color _kEnterColor = Color(0xFF4CAF50);
const Color _kExitColor = Color(0xFFF44336);
const Color _kDwellColor = Color(0xFF9C27B0);

final Set<GeofenceRegion> _regions = {
  GeofenceRegion.circular(
    id: 'region_1',
    data: {
      'name': 'National Museum of Korea',
    },
    center: const LatLng(37.523085, 126.979619),
    radius: 250,
    loiteringDelay: 60 * 1000,
  ),
  GeofenceRegion.circular(
    id: 'region_2',
    data: {
      'name': 'Dongdaemun Market',
    },
    center: const LatLng(37.566878, 127.010093),
    radius: 800,
  ),
  GeofenceRegion.polygon(
    id: 'region_3',
    data: {
      'name': 'Gyeongbokgung Palace',
    },
    polygon: [
      const LatLng(37.583696, 126.973739),
      const LatLng(37.583441, 126.979361),
      const LatLng(37.582506, 126.980198),
      const LatLng(37.579054, 126.979490),
      const LatLng(37.576112, 126.979061),
      const LatLng(37.576503, 126.974126),
      const LatLng(37.580959, 126.973568),
    ],
    loiteringDelay: 60 * 1000,
  ),
  GeofenceRegion.polygon(
    id: 'region_4',
    data: {
      'name': 'N Seoul Tower',
    },
    polygon: [
      const LatLng(37.556355, 126.984041),
      const LatLng(37.552307, 126.982067),
      const LatLng(37.546931, 126.984556),
      const LatLng(37.545468, 126.990178),
      const LatLng(37.542644, 126.991594),
      const LatLng(37.541010, 126.998117),
      const LatLng(37.543324, 127.001035),
      const LatLng(37.549551, 127.000906),
      const LatLng(37.555845, 126.993182),
    ],
  ),
  GeofenceRegion.polygon(
    id: 'region_5',
    data: {
      'name': 'Hongdae Street',
    },
    polygon: [
      const LatLng(37.555918, 126.932728),
      const LatLng(37.563946, 126.921913),
      const LatLng(37.558503, 126.907322),
      const LatLng(37.550474, 126.913588),
      const LatLng(37.548296, 126.930067),
      const LatLng(37.555237, 126.935904),
    ],
  ),
};

void main() {
  // set fullscreen
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DemoPage(),
    ),
  );
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<StatefulWidget> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  Future<bool> _requestLocationPermission({bool background = false}) async {
    if (!await Geofencing.instance.isLocationServicesEnabled) {
      // Location services is disabled.
      return false;
    }

    LocationPermission permission =
        await Geofencing.instance.getLocationPermission();
    if (permission == LocationPermission.denied) {
      // Android: ACCESS_COARSE_LOCATION or ACCESS_FINE_LOCATION
      // iOS 12-: NSLocationWhenInUseUsageDescription or NSLocationAlwaysAndWhenInUseUsageDescription
      // iOS 13+: NSLocationWhenInUseUsageDescription
      permission = await Geofencing.instance.requestLocationPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Location permission has been ${permission.name}.
      return false;
    }

    // Web: Only allow whileInUse permission.
    if (kIsWeb || kIsWasm) {
      return true;
    }

    // Android: You must request location permission one more time to access background location.
    // iOS 12-: You can request always permission through the above request.
    // iOS 13+: You can only request whileInUse permission through the above request.
    // When the app enters the background, a prompt will appear asking for always permission.
    if (Platform.isAndroid &&
        background &&
        permission == LocationPermission.whileInUse) {
      // You need a clear explanation of why your app's feature needs access to background location.
      // https://developer.android.com/develop/sensors-and-location/location/permissions#request-background-location

      // Android: ACCESS_BACKGROUND_LOCATION
      permission = await Geofencing.instance.requestLocationPermission();

      if (permission != LocationPermission.always) {
        // Location permission must always be granted to collect location in the background.
        return false;
      }
    }

    return true;
  }

  void _setupGeofencing() {
    try {
      Geofencing.instance.setup(
        interval: 5 * 1000,
        accuracy: 100,
        statusChangeDelay: 10 * 1000,
        allowsMockLocation: true,
        printsDebugLog: true,
      );
    } catch (e, s) {
      _onError(e, s);
    }
  }

  void _startGeofencing() async {
    try {
      Geofencing.instance
          .addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
      Geofencing.instance.addGeofenceErrorCallbackListener(_onError);

      await Geofencing.instance.start(regions: _regions);

      // refresh GoogleMap
      _refreshPage();
    } catch (e, s) {
      _onError(e, s);
    }
  }

  void _stopGeofencing() async {
    try {
      Geofencing.instance
          .removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
      Geofencing.instance.removeGeofenceErrorCallbackListener(_onError);

      await Geofencing.instance.stop();

      // refresh GoogleMap
      _refreshPage();
    } catch (e, s) {
      _onError(e, s);
    }
  }

  void _refreshPage() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion geofenceRegion,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    final String regionId = geofenceRegion.id;
    final String statusName = geofenceStatus.name;
    dev.log('region(id: $regionId) $statusName');

    // refresh GoogleMap
    _refreshPage();
  }

  void _onError(Object error, StackTrace stackTrace) {
    dev.log('error: $error\n$stackTrace');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestLocationPermission();
      _setupGeofencing();
      _startGeofencing();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMapView(
        regions: Geofencing.instance.regions,
      ),
    );
  }

  @override
  void dispose() {
    _stopGeofencing();
    super.dispose();
  }
}

class GoogleMapView extends StatefulWidget {
  const GoogleMapView({
    super.key,
    required this.regions,
  });

  final Set<GeofenceRegion> regions;

  @override
  State<StatefulWidget> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  final Set<map.Circle> _circles = {};
  final Set<map.Polygon> _polygons = {};

  Color _getFillColorByStatus(GeofenceStatus status) {
    switch (status) {
      case GeofenceStatus.enter:
        return _kEnterColor.withOpacity(0.5);
      case GeofenceStatus.exit:
        return _kExitColor.withOpacity(0.5);
      case GeofenceStatus.dwell:
        return _kDwellColor.withOpacity(0.5);
    }
  }

  void _updateMapsObject() {
    _circles.clear();
    _polygons.clear();

    map.Circle circle;
    map.Polygon polygon;
    for (final GeofenceRegion region in widget.regions) {
      if (region is GeofenceCircularRegion) {
        circle = map.Circle(
          circleId: map.CircleId(region.id),
          center: map.LatLng(region.center.latitude, region.center.longitude),
          radius: region.radius,
          strokeWidth: 2,
          strokeColor: Colors.black,
          fillColor: _getFillColorByStatus(region.status),
        );
        _circles.add(circle);
        continue;
      }

      if (region is GeofencePolygonRegion) {
        polygon = map.Polygon(
          polygonId: map.PolygonId(region.id),
          points: region.polygon
              .map((e) => map.LatLng(e.latitude, e.longitude))
              .toList(),
          strokeWidth: 2,
          strokeColor: Colors.black,
          fillColor: _getFillColorByStatus(region.status),
        );
        _polygons.add(polygon);
        continue;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _updateMapsObject();
  }

  @override
  void didUpdateWidget(covariant GoogleMapView oldWidget) {
    _updateMapsObject();
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return map.GoogleMap(
      initialCameraPosition: const map.CameraPosition(
        target: map.LatLng(37.5479, 126.9904),
        zoom: 12.5,
      ),
      circles: _circles,
      polygons: _polygons,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
