library bacchus_diary.service.photo_shop;

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/model/location.dart';
import 'package:bacchus_diary/util/file_reader.dart';

final _logger = new Logger('PhotoShop');

class PhotoShop {
  static const CONTENT_TYPE = 'image/jpeg';

  static String makeUrl(Blob blob) {
    final String url = Url.createObjectUrlFromBlob(blob);
    _logger.fine("Url of blob => ${url}");
    return url;
  }

  static Future<Blob> photo(bool take) async {
    final result = new Completer<Blob>();
    try {
      final params = {
        'correctOrientation': true,
        'destinationType': context['Camera']['DestinationType']['DATA_URL'],
        'sourceType': take
            ? context['Camera']['PictureSourceType']['CAMERA']
            : context['Camera']['PictureSourceType']['PHOTOLIBRARY']
      };
      context['navigator']['camera'].callMethod('getPicture', [
        (data) async {
          try {
            _logger.finest(() => "Loaging choosed photo data...");
            final list = new Base64Decoder().convert(data);
            final blob = new Blob([new Uint8List.fromList(list)], CONTENT_TYPE);
            _logger.fine(() => "Get photo data: ${blob}");
            result.complete(blob);
          } catch (ex) {
            result.completeError("Failed to read photo data: ${ex}");
          }
        },
        (error) {
          _logger.warning("Failed to get photo: ${error}");
          result.completeError(error);
        },
        new JsObject.jsify(params)
      ]);
    } catch (ex) {
      _logger.warning("Failed to get photo file: ${ex}");
      result.completeError(ex);
    }
    return result.future;
  }
}

class ExifInfo {
  final DateTime timestamp;
  final GeoInfo location;

  ExifInfo(this.timestamp, this.location);

  static Future<ExifInfo> fromBlob(Blob blob) async {
    _logger.fine("Exif Loading on ${blob}");

    final array = await fileReader_readAsArrayBuffer(blob.slice(0, 128 * 1024));

    final exif = new JsObject(context['ExifReader'], []);
    exif.callMethod('load', [array]);

    get(String name) => exif.callMethod('getTagDescription', [name]);

    getTimestamp() {
      try {
        String text = get('DateTimeOriginal');
        if (text == null) text = get('DateTimeDigitized');
        if (text == null) text = get('DateTime');
        final a = text.split(' ').expand((e) => e.split(':')).map(int.parse).toList();
        _logger.fine("Exif: Timestamp: ${a}");
        return new DateTime(a[0], a[1], a[2], a[3], a[4], a[5]);
      } catch (ex) {
        _logger.warning("Exif: Timestamp: Error: ${ex}");
        return null;
      }
    }

    getLocation() {
      try {
        final double lat = get('GPSLatitude');
        final double lon = get('GPSLongitude');
        _logger.fine("Exif: GPS: latitude=${lat}, longitude=${lon}");
        if (lat != null && lon != null) {
          return new GeoInfo.fromMap({'latitude': lat, 'longitude': lon});
        } else {
          _logger.warning("Exif: GPS: Error: null value");
          return null;
        }
      } catch (ex) {
        _logger.warning("Exif: GPS: Error: ${ex}");
        return null;
      }
    }
    return new ExifInfo(getTimestamp(), getLocation());
  }
}
