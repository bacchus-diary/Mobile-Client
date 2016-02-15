library bacchus_diary.model.location;

import 'dart:math';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/_json_support.dart';

final Logger _logger = new Logger('Location');

abstract class GeoInfo implements JsonSupport {
  double latitude;
  double longitude;

  factory GeoInfo.fromMap(Map data) => new _GeoInfoImpl(data);

  double distance(GeoInfo other);
}

class _GeoInfoImpl extends JsonSupport implements GeoInfo {
  final Map _data;
  _GeoInfoImpl(this._data);
  Map get asMap => _data;

  double get latitude => _data['latitude'];
  set latitude(double v) => _data['latitude'] = v;

  double get longitude => _data['longitude'];
  set longitude(double v) => _data['longitude'] = v;

  static _toRadian(double v) => v * 2 * PI / 360;
  static const radiusEq = 6378137.000;
  static const radiusPl = 6356752.314;
  static final radiusEq2 = pow(radiusEq, 2);
  static final radiusPl2 = pow(radiusPl, 2);
  static final ecc2 = (radiusEq2 - radiusPl2) / radiusEq2;
  static final rM = radiusEq * (1 - ecc2);

  double distance(GeoInfo other) {
    final srcLat = _toRadian(latitude);
    final srcLng = _toRadian(longitude);
    final dstLat = _toRadian(other.latitude);
    final dstLng = _toRadian(other.longitude);

    final mLat = (srcLat + dstLat) / 2;
    final W = sqrt(1 - ecc2 * pow(sin(mLat), 2));

    final vLat = (srcLat - dstLat) * rM / pow(W, 3);
    final vLng = (srcLng - dstLng) * cos(mLat) * radiusEq / W;
    return sqrt(pow(vLat, 2) + pow(vLng, 2));
  }
}
