This plugin is used to implement circular and polygon geofencing service.

<img src="https://github.com/user-attachments/assets/b11c5728-43bc-4792-bc55-a8cd237944a4" width="700" />

> [!CAUTION]
> It does not use the geofencing api implemented in the platform. 
> Therefore, battery efficiency cannot be guaranteed. 
> Instead, this plugin can provide more accurate and real-time geofencing by navigating your location while your app is alive.

## Features

* Can create a circular type geofence.
* Can create a polygon type geofence.
* Can listen to geofence status changes in real-time.
* Can listen to location changes in real-time.
* Can request or check location permission.

## Support version

- Flutter: `3.10.0+`
- Dart: `3.0.0+`
- Android: `5.0+ (minSdkVersion: 21)`
- iOS: `12.0+`

## Getting started

To use this plugin, add `geofencing_api` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/). For example:

```yaml
dependencies:
  geofencing_api: ^1.4.2
```

After adding the plugin to your flutter project, we need to declare the platform-specific permissions to use for this plugin to work properly.

### :baby_chick: Android

Since the geofencing service works based on location, we need to declare location permission.

Open the `AndroidManifest.xml` file and declare permission between the `<manifest>` and `<application>` tags.

```
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### :baby_chick: iOS

Open the `ios/Runner/Info.plist` file and declare description within the `<dict>` tag.

```
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to collect location data.</string>
```

### :baby_chick: Background Mode

To perform geofencing in the background, declare permissions and descriptions.

```
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

```
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Used to collect location data in the background.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Used to collect location data in the background.</string>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>location</string>
</array>
```

Then use [flutter_foreground_task](https://github.com/Dev-hwang/flutter_foreground_task) to implement a background geofencing service.

demo: https://github.com/Dev-hwang/flutter_foreground_task_example/tree/main/geofencing_service

## How to use

1. Request location permission. To start the geofencing service, the permission result must be `always` or `whileInUse`.

```dart
Future<bool> requestLocationPermission({bool background = false}) async {
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
  // iOS 13+: You can only request whileInUse permission. When the app enters the background,
  // a prompt will appear asking for always permission.
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
```

2. Set up the geofencing service.
* `interval`: The millisecond interval at which to update the geofence status. This value may be delayed by device platform limitations. The default is `5000`.
* `accuracy`: The accuracy of the geofencing service in meters. The default is `100`.
* `statusChangeDelay`: The status change delay in milliseconds. `GeofenceStatus.enter` and `GeofenceStatus.exit` events may be called frequently when the location is near the boundary of the geofence. If the option value is too large, real-time geofencing is not possible, so use it carefully. The default is `10000`.
* `allowsMockLocation`: Whether to allow mock location. The default is `false`.
* `printsDebugLog`: Whether to print debug logs in plugin. The default is `true`.

```dart
void setupGeofencing() {
  Geofencing.instance.setup(
    interval: 5000,
    accuracy: 100,
    statusChangeDelay: 10000,
    allowsMockLocation: false,
    printsDebugLog: true,
  );
}
```

3. Create geofence regions. Use the `.circular` or `.polygon` constructor.
* `id`: The unique id of the geofence region.
* `data`: The data of the geofence region.
* `loiteringDelay`: The delay between `GeofenceStatus.enter` and `GeofenceStatus.dwell` in milliseconds. The default is `30000`.
* `center`: The center coordinates of the geofence. (circular)
* `radius`: The radius of the geofence. This value should be 10 meters or greater. (circular)
* `polygon`: The polygon coordinates of the geofence. This value must have size 3 or greater. (polygon)

```dart
final Set<GeofenceRegion> _regions = {
  GeofenceRegion.circular(
    id: 'circular_region',
    data: {
      'name': 'National Museum of Korea',
    },
    center: const LatLng(37.523085, 126.979619),
    radius: 250,
    loiteringDelay: 60 * 1000,
  ),
  GeofenceRegion.polygon(
    id: 'polygon_region',
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
};
```

4. Start the geofencing service. You can add geofence regions before starting the service using the `regions` parameter.

```dart
void startGeofencing() async {
  Geofencing.instance.addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
  Geofencing.instance.addGeofenceErrorCallbackListener(_onGeofenceError);
  
  // You can add listeners as needed.
  Geofencing.instance.addLocationChangedListener(LocationChanged);
  Geofencing.instance.addLocationServicesStatusChangedListener(LocationServicesStatusChanged);
  
  await Geofencing.instance.start(regions: _regions);
}

Future<void> _onGeofenceStatusChanged(
  GeofenceRegion geofenceRegion,
  GeofenceStatus geofenceStatus,
  Location location,
) async {
  final String regionId = geofenceRegion.id;
  final String statusName = geofenceStatus.name;
  print('region(id: $regionId) $statusName');
}

void _onGeofenceError(Object error, StackTrace stackTrace) {
  print('error: $error\n$stackTrace');
}
```

5. You can add or remove regions even after the service starts.

```dart
void addRegions() {
  Geofencing.instance.addRegion(GeofenceRegion);
  Geofencing.instance.addRegions(Set<GeofenceRegion>);
}

void removeRegions() {
  Geofencing.instance.removeRegion(GeofenceRegion);
  Geofencing.instance.removeRegions(Set<GeofenceRegion>);
  Geofencing.instance.removeRegionById(String);
  Geofencing.instance.clearAllRegions();
}
```

6. You can pause or resume the service.

```dart
void pauseGeofencing() {
  Geofencing.instance.pause();
}

void resumeGeofencing() {
  Geofencing.instance.resume();
}
```

7. Stop the geofencing service. If you want to keep added regions, set `keepsRegions` to `true`.

```dart
void stopGeofencing() async {
  Geofencing.instance.removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
  Geofencing.instance.removeGeofenceErrorCallbackListener(_onGeofenceError);
  Geofencing.instance.removeLocationChangedListener(LocationChanged);
  Geofencing.instance.removeLocationServicesStatusChangedListener(LocationServicesStatusChanged);
  
  await Geofencing.instance.stop(keepsRegions: true);
}
```

## More Documentation

Go [here](./documentation/models_documentation.md) to learn about the `models` provided by this plugin.

Go [here](./documentation/migration_documentation.md) to `migrate` to the new version.

## Support

If you find any bugs or issues while using the plugin, please register an issues on [GitHub](https://github.com/Dev-hwang/geofencing_api/issues). You can also contact us at <hwj930513@naver.com>.
