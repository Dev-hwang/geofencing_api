import 'dart:async';
import 'dart:developer' as dev;

import 'package:fl_location/fl_location.dart';
import 'package:flutter/foundation.dart';
import 'src/errors/geofencing_already_started_exception.dart';
import 'src/errors/location_permission_denied_exception.dart';
import 'src/errors/location_permission_permanently_denied_exception.dart';
import 'src/errors/location_services_disabled_exception.dart';
import 'src/models/geofence_region.dart';
import 'src/models/geofence_status.dart';
import 'src/models/geofencing_options.dart';
import 'src/models/geofencing_types.dart';
import 'src/utils/polygon_utils.dart';

export 'package:fl_location/fl_location.dart'
    show Location, LocationServicesStatus, LocationPermission;
export 'src/errors/geofencing_already_started_exception.dart';
export 'src/errors/location_permission_denied_exception.dart';
export 'src/errors/location_permission_permanently_denied_exception.dart';
export 'src/errors/location_services_disabled_exception.dart';
export 'src/models/geofence_region.dart';
export 'src/models/geofence_type.dart';
export 'src/models/geofence_status.dart';
export 'src/models/geofencing_options.dart';
export 'src/models/geofencing_types.dart';
export 'src/models/lat_lng.dart';

part 'src/geofencing.dart';
