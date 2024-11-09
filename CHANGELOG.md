## 1.4.2

* [**FIX**] Fix an issue related to `requestLocationPermission` on iOS [#23](https://github.com/Dev-hwang/flutter_location/issues/23)

## 1.4.1+1

* [**DOCS**] Fix incorrect API usage in the `README`

## 1.4.1

* [**CHORE**] Upgrade dependencies
  - Fix an issue where an error occurs when parsing the location JSON in release mode [#22](https://github.com/Dev-hwang/flutter_location/issues/22)

## 1.4.0

* [**CHORE**] Upgrade dependencies
  - Change the behavior of `Geofencing.instance.requestLocationPermission` [#21](https://github.com/Dev-hwang/flutter_location/issues/21)
  - Allow incremental location permission requests
  - Check [How to use-1](https://pub.dev/packages/geofencing_api#how-to-use) for more details

## 1.3.0

* [**FEAT**] Add `GeofenceRegion.distanceTo(Location)` function
* [**FIX**] Fix `GeofenceRegion.fromJson` parsing error

## 1.2.0

* [**CHORE**] Upgrade dependencies
  - Allow use of `Geofencing.instance.getLocationPermission` in the background
  - Allow `ACCESS_COARSE_LOCATION` permission

## 1.1.0

* [**FEAT**] Add `GeofenceRegion.fromJson` constructor
* [**FEAT**] Add `LatLng.fromJson` constructor

## 1.0.0

* Initial release.
