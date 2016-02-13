library bacchus_diary.service.cvision;

import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';
import 'package:bacchus_diary/util/file_reader.dart';

final Logger _logger = new Logger('CVision');

class CVision {
  static const urlGCV = "https://vision.googleapis.com/v1/images:annotate";

  static Future<Map> request(Blob data, Map<String, int> featuresMap) async {
    final result = new Completer<Map>();

    final settings = await Settings;
    final url = "{urlGCV}?key=${settings.googleKey}";

    try {
      final features = [];
      featuresMap.forEach((name, max) => features.add({'type': name, 'maxResults': max}));

      final dataMap = {
        'requests': [
          {
            'image': {'content': base64(data)},
            'features': features
          }
        ]
      };

      final req = new HttpRequest()
        ..open('POST', url)
        ..setRequestHeader('Content-Type', 'application/json')
        ..send(JSON.encode(dataMap));

      req.onLoadEnd.listen((event) {
        final text = req.responseText;
        _logger.fine(() => "Response: (Status:${req.status}) ${text}");
        if (req.status == 200) {
          try {
            final map = JSON.decode(text);
            result.complete(map);
          } catch (ex) {
            _logger.warning(() => "Could not parse as json: ${text}");
            result.completeError(ex);
          }
        } else {
          _logger.warning(() => "Response status ${req.status}: ${text}");
          result.completeError(text);
        }
      });
      req.onError.listen((event) {
        _logger.warning(() => "Response status ${req.status}: ${event}");
        result.completeError(event);
      });
      req.onTimeout.listen((event) {
        _logger.warning(() => "Timeout to request: ${event}");
        result.completeError(event);
      });
    } catch (ex) {
      _logger.warning(() => "Failed to request: ${ex}");
      result.completeError(ex);
    }

    return result.future;
  }

  static Future<String> base64(Blob data) async {
    final list = await readAsList(data);
    return BASE64.encode(list);
  }

  final Blob srcData;

  CVision(this.srcData);

  Future<String> readText() async {
    final result = await request(srcData, {'TEXT_DETECTION': 1});

    return result['responses'][0]['textAnnotations'][0]['description'];
  }
}
