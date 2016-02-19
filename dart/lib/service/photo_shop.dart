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

  static String makeUrl(String data) {
    _logger.finest(() => "Loading Base64 data to Uri ...");
    final url = Url.createObjectUrlFromBlob(decodeBase64(data));
    _logger.fine("Url of data => ${url}");
    return url;
  }

  static Blob decodeBase64(String encoded) {
    final list = BASE64.decode(encoded);
    return new Blob([new Uint8List.fromList(list)], CONTENT_TYPE);
  }

  static Future<String> encodeBase64(Blob data) async {
    final list = await readAsList(data);
    return BASE64.encode(list);
  }

  static Future<String> photo(bool take) async {
    final result = new Completer<String>();
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
            _logger.finest(() => "Choosed photo data received");
            result.complete(data);
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
